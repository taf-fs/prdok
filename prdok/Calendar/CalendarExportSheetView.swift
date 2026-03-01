//
//  CalendarExportSheetView.swift
//  prdok
//
//  Created by David Horňák on 01.03.2026.
//

import SwiftUI
import EventKit
import Foundation
import Combine

@MainActor
final class CalendarExportSheetViewModel: ObservableObject {
    struct Outcome: Equatable {
        let success: Bool
        let message: String
    }

    private let service: ShiftCalendarSyncService

    @Published var isLoadingCalendars: Bool = false
    @Published var isPlanningExport: Bool = false
    @Published var isExporting: Bool = false

    @Published var writableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIdentifier: String? = nil

    /// nil = no alarm
    @Published var alarmMinutesBefore: Int? = 30

    private static let defaultEventTitleLocalizationKey = "calendarExport.defaultEventTitle"

    /// User-editable.
    @Published var eventTitle: String

    @Published var exportPlan: ShiftCalendarPlan? = nil

    init(service: ShiftCalendarSyncService) {
        self.service = service
        self.eventTitle = NSLocalizedString(
            Self.defaultEventTitleLocalizationKey,
            comment: "Default calendar event title for exported shifts."
        )
    }

    var selectedCalendar: EKCalendar? {
        guard let selectedCalendarIdentifier else { return nil }
        return writableCalendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier })
    }

    func canRun(monthDate: Date?) -> Bool {
        !isLoadingCalendars && !isPlanningExport && !isExporting && selectedCalendar != nil && monthDate != nil
    }

    func loadCalendarsIfNeeded() async {
        guard writableCalendars.isEmpty else { return }
        guard !isLoadingCalendars else { return }

        isLoadingCalendars = true
        defer { isLoadingCalendars = false }

        do {
            // Permission prompt stays on main actor.
            try await service.requestAccessIfNeeded()

            // Calendar list is fast, keep it on main.
            writableCalendars = service.writableCalendars()

            if selectedCalendarIdentifier == nil {
                selectedCalendarIdentifier = writableCalendars.first?.calendarIdentifier
            } else if let selectedCalendarIdentifier,
                      !writableCalendars.contains(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
                self.selectedCalendarIdentifier = writableCalendars.first?.calendarIdentifier
            }
        } catch {
            // keep state; let caller show toast
            exportPlan = nil
        }
    }

    func planIfPossible(monthDate: Date?) async {
        guard !isPlanningExport else { return }
        guard let monthDate else { return }
        guard let cal = selectedCalendar else { return }

        isPlanningExport = true
        defer { isPlanningExport = false }

        do {
            // Run the heavy EventKit + repository work off-main.
            let plan = try await Task.detached(priority: .userInitiated) { [service] in
                try await service.plan(forMonthContaining: monthDate, calendar: cal)
            }.value

            exportPlan = plan
        } catch {
            exportPlan = nil
        }
    }

    func addOnly(monthDate: Date?) async -> Outcome {
        guard !isExporting else { return Outcome(success: false, message: ShiftActionError.busy.localizedDescription) }
        guard let monthDate else { return Outcome(success: false, message: ShiftCalendarServiceError.invalidMonthDate.localizedDescription) }
        guard let cal = selectedCalendar else { return Outcome(success: false, message: ShiftCalendarServiceError.calendarNotWritable.localizedDescription) }

        isExporting = true
        defer { isExporting = false }

        do {
            // Ensure we have permission before starting heavy work.
            try await service.requestAccessIfNeeded()

            let summary = try await Task.detached(priority: .userInitiated) { [service, eventTitle, alarmMinutesBefore] in
                try await service.addOnly(
                    forMonthContaining: monthDate,
                    calendar: cal,
                    eventTitle: eventTitle,
                    alarmMinutesBefore: alarmMinutesBefore
                )
            }.value

            let msg = String(format: String(localized: "calendarExport.toast.addOnly"), summary.created)
            return Outcome(success: true, message: msg)
        } catch {
            return Outcome(success: false, message: error.localizedDescription)
        }
    }

    func sync(monthDate: Date?) async -> Outcome {
        guard !isExporting else { return Outcome(success: false, message: ShiftActionError.busy.localizedDescription) }
        guard let monthDate else { return Outcome(success: false, message: ShiftCalendarServiceError.invalidMonthDate.localizedDescription) }
        guard let cal = selectedCalendar else { return Outcome(success: false, message: ShiftCalendarServiceError.calendarNotWritable.localizedDescription) }

        isExporting = true
        defer { isExporting = false }

        do {
            // Ensure we have permission before starting heavy work.
            try await service.requestAccessIfNeeded()

            let summary = try await Task.detached(priority: .userInitiated) { [service, eventTitle, alarmMinutesBefore] in
                try await service.sync(
                    forMonthContaining: monthDate,
                    calendar: cal,
                    eventTitle: eventTitle,
                    alarmMinutesBefore: alarmMinutesBefore
                )
            }.value

            let msg = String(format: String(localized: "calendarExport.toast.sync"), summary.created, summary.updated, summary.deleted)
            return Outcome(success: true, message: msg)
        } catch {
            return Outcome(success: false, message: error.localizedDescription)
        }
    }
}

struct CalendarExportSheetView: View {
    let monthLabel: String
    let monthDate: Date?

    /// (success, message)
    let onDone: (Bool, String) -> Void

    @StateObject private var vm = CalendarExportSheetViewModel(service: ShiftCalendarSyncService())

    private static let eventTitlePlaceholderLocalizationKey = "calendarExport.eventTitle.placeholder"

    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                Text("calendarExport.title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.serif)
                Text(monthLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
            }

            Form {
                Section("calendarExport.section.eventName.title") {
                    TextField(
                        NSLocalizedString(Self.eventTitlePlaceholderLocalizationKey, comment: "Placeholder for the event title text field."),
                        text: $vm.eventTitle
                    )
                    .font(.title2)
                    .fontWeight(.semibold)
                    .autocorrectionDisabled(false)
                }
                Section("calendarExport.section.calendarSettings.title") {
                    if vm.isLoadingCalendars {
                        HStack {
                            ProgressView()
                            Text("calendarExport.loadingCalendars", comment: "Calendar loading in progress text.")
                        }
                    } else if vm.writableCalendars.isEmpty {
                        Text("calendarExport.noCalendarsFound", comment: "No writable calendar found.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("calendarExport.picker.calendar", selection: $vm.selectedCalendarIdentifier) {
                            Text(verbatim: "—").tag(Optional<String>.none)
                            ForEach(vm.writableCalendars, id: \.calendarIdentifier) { cal in
                                Text(truncated(cal.title)).tag(Optional(cal.calendarIdentifier))
                            }
                        }
                    }
                    Picker("calendarExport.picker.notification", selection: Binding(
                        get: { vm.alarmMinutesBefore ?? -1 },
                        set: { newValue in vm.alarmMinutesBefore = (newValue == -1 ? nil : newValue) }
                    )) {
                        Text("calendarExport.notificationOption.none").tag(-1)
                        Text("calendarExport.notificationOption.30min").tag(30)
                        Text("calendarExport.notificationOption.1h").tag(60)
                        Text("calendarExport.notificationOption.2h").tag(120)
                        Text("calendarExport.notificationOption.6h").tag(360)
                        Text("calendarExport.notificationOption.12h").tag(720)
                        Text("calendarExport.notificationOption.24h").tag(1440)
                    }
                }

                Section {
                    if vm.exportPlan?.shouldOfferSync == true {
                        Button {
                            Task { @MainActor in
                                let result = await vm.sync(monthDate: monthDate)
                                onDone(result.success, result.message)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if vm.isExporting {
                                    ProgressView()
                                } else {
                                    Text("calendarExport.button.sync").fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!vm.canRun(monthDate: monthDate))
                    } else {
                        Button {
                            Task { @MainActor in
                                let result = await vm.addOnly(monthDate: monthDate)
                                onDone(result.success, result.message)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if vm.isExporting {
                                    ProgressView()
                                } else {
                                    Text("calendarExport.button.add").fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!vm.canRun(monthDate: monthDate))
                    }
                } footer: {
                    if vm.isPlanningExport {
                        HStack {
                            ProgressView()
                            Text("calendarExport.isPlanningExportMessage", comment: "Check in progress.")
                        }
                    } else if let exportPlan = vm.exportPlan, exportPlan.shouldOfferSync {
                        Text("calendarExport.button.sync.footer", comment: "V kalendáři už jsou uložené směny z této aplikace. Můžeš je synchronizovat.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                Task { @MainActor in
                    await vm.loadCalendarsIfNeeded()
                    await vm.planIfPossible(monthDate: monthDate)
                }
            }
            .onChange(of: vm.selectedCalendarIdentifier) { _ in
                Task { @MainActor in
                    await vm.planIfPossible(monthDate: monthDate)
                }
            }
        }
        .padding(.top, 24)
        .background(Color(.systemGroupedBackground))
    }

    private func truncated(_ title: String, maxLength: Int = 18) -> String {
        title.count > maxLength ? String(title.prefix(maxLength)) + "…" : title
    }
}

#Preview {
    CalendarView()
}
