//
//  MultiOfferShiftView.swift
//  prdok
//
//  Created by David Horňák on 18.01.2026.
//

import SwiftUI
import Combine
import HorizonCalendar

final class ShiftMultiOfferViewModel: ObservableObject {
    @Published var offeredDays: Set<Date> = []
    
    @Published var isSubmitting: Bool = false
    @Published var submittedCount: Int = 0
    @Published var totalToSubmit: Int = 0
    
    @Published var lastOfferErrorMessage: String? = nil

    // Set when the initial month load fails. The view reacts by dismissing itself and toasting from CalendarView.
    @Published var loadErrorMessage: String? = nil

    var progress: Double {
        guard totalToSubmit > 0 else { return 0 }
        return Double(submittedCount) / Double(totalToSubmit)
    }
    
    let repo = ShiftRepository()
    
    /// - Parameter reportFailure: when false, a failed load stays silent. Used for the post-submit reload,
    ///   where the sheet is closing anyway and the offer result toast must not be replaced.
    func loadShifts(month: Date, reportFailure: Bool = true) {
        Task {
            do {
                let result = try await repo.getShifts(for: month, forceRefresh: true)
                await MainActor.run {
                    offeredDays = result.offeredDaySet(using: calendar)
                }
            } catch {
                guard reportFailure else { return }

                let base = NSLocalizedString(
                    "shiftMultiOffer.load.failure",
                    comment: "Toast shown when the offered shifts for the month couldn't be loaded, so the sheet closes."
                )
                let detail = error.localizedDescription
                await MainActor.run {
                    loadErrorMessage = detail.isEmpty ? base : base + "\n" + detail
                }
            }
        }
    }
    
    @MainActor
    func offerShiftsOneByOne(
        dates: Set<Date>,
        startHour: Int,
        endHour: Int,
        displayedMonth: Date,
        onToast: @escaping (_ success: Bool, _ message: String) -> Void
    ) async {
        guard !isSubmitting else {
            onToast(false, ShiftActionError.busy.localizedDescription)
            return
        }
        
        guard !dates.isEmpty else { return }
        
        guard startHour < endHour else {
            onToast(false, ShiftActionError.invalidTimeRange.localizedDescription)
            return
        }
        
        let sortedDates = dates.sorted()
        
        isSubmitting = true
        submittedCount = 0
        totalToSubmit = sortedDates.count
        lastOfferErrorMessage = nil
        defer {
            isSubmitting = false
        }
        
        // UX: ensure each offer attempt takes at least this long so progress doesn't "blink".
        let minPerOfferDelay: Duration = .milliseconds(125)
        let clock = ContinuousClock()
        
        for day in sortedDates {
            let startedAt = clock.now
            
            do {
                let result = try await ShiftService.offerShift(when: day, start: startHour, end: endHour)
                
                switch result {
                case .saved:
                    submittedCount += 1
                    
                case .rejected(let message):
                    lastOfferErrorMessage = ShiftActionError.serverRejected(message: message).localizedDescription
                    
                case .unexpected(let message):
                    lastOfferErrorMessage = ShiftActionError.unexpectedServerResponse(message: message).localizedDescription
                }
            } catch {
                lastOfferErrorMessage = error.localizedDescription
            }
            
            // Minimum duration per attempt (slow network won't be slowed further).
            let elapsed = startedAt.duration(to: clock.now)
            let remaining = minPerOfferDelay - elapsed
            if remaining > .zero {
                try? await clock.sleep(for: remaining)
            }
        }
        
        // Refresh cache + reload offered day dots for the month after all attempts
        do {
            try await repo.refresh(for: displayedMonth)
            loadShifts(month: displayedMonth, reportFailure: false)
        } catch {
            // If refresh fails, treat it as "last error", but don't override a more relevant offer error if we already have one.
            if lastOfferErrorMessage == nil {
                lastOfferErrorMessage = error.localizedDescription
            }
        }
        
        let failedCount = totalToSubmit - submittedCount
        
        if failedCount == 0 {
            var format: String
            if submittedCount == 1 {
                format = NSLocalizedString(
                    "shiftAction.multiOffer.single.success",
                    comment: "Multi-offer success toast. One shift submitted. Use %d for number of shifts successfully offered."
                )
            }
            else if submittedCount <= 4 {
                format = NSLocalizedString(
                    "shiftAction.multiOffer.twoToFour.success",
                    comment: "Multi-offer success toast. 2-4 shifts submitted. Use %d for number of shifts successfully offered."
                )
            }
            else {
                format = NSLocalizedString(
                    "shiftAction.multiOffer.mutliple.success",
                    comment: "Multi-offer success toast. More than 4 shifts submitted. Use %d for number of shifts successfully offered."
                )
            }
            onToast(true, String(format: format, submittedCount))
        } else {
            var format: String
            if failedCount == 1 { // this is mostly assuming that one shift was selected to offer and failed. but this message could be used for a single failure in multiple offers
                format = NSLocalizedString(
                    "shiftAction.multiOffer.single.failure",
                    comment: "Multi-offer failure toast. One shift failed. Use %d for number of shifts."
                )
            }
            else if failedCount <= 4 {
                format = NSLocalizedString(
                    "shiftAction.multiOffer.twoToFour.failure",
                    comment: "Multi-offer failure toast. 2-4 shifts failed. Use %d for number of shifts."
                )
            }
            else {
                format = NSLocalizedString(
                    "shiftAction.multiOffer.mutliple.failure",
                    comment: "Multi-offer failure toast. More than 4 failed. Use %d for number of shifts."
                )
            }
            
            let base = String(format: format, failedCount)
            if let lastOfferErrorMessage, !lastOfferErrorMessage.isEmpty {
                onToast(false, base + "\n" + lastOfferErrorMessage)
            } else {
                onToast(false, base)
            }
        }
    }
}

struct ShiftMultiOfferView: View {
    var displayedMonth: Date
    var onToast: (_ success: Bool, _ message: String) -> Void = { _, _ in }
    
    @Environment(\.dismiss) var dismiss
    @StateObject var vm = ShiftMultiOfferViewModel()
    @State var selectedDates: Set<Date> = []
    @State var startHour: Int = 7
    @State var endHour: Int = 25
    
    private var canSubmit: Bool {
        !vm.isSubmitting && !selectedDates.isEmpty && startHour < endHour
    }

    var startOfMonth: Date { calendar.dateInterval(of: .month, for: displayedMonth)!.start }
    var endOfMonth: Date { calendar.dateInterval(of: .month, for: displayedMonth)!.end.addingTimeInterval(-1) }
    var currentMonthLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMMMy")
        return df.string(from: displayedMonth).capitalized(with: df.locale)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("shiftMultiOffer.title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.serif)
                    Text(currentMonthLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                }
                
                CalendarViewRepresentable(
                    calendar: calendar,
                    visibleDateRange: startOfMonth...endOfMonth,
                    monthsLayout: .vertical(options: VerticalMonthsLayoutOptions()),
                    dataDependency: (selectedDates)
                )
                .dayOfWeekHeaders { _, index in
                    Text(dayOfWeekName(index: index).uppercased())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                }
                .days { day in
                    let date = calendar.date(from: day.components)!
                    let dayKey = calendar.startOfDay(for: date)
                    let hasOfferedShift = vm.offeredDays.contains(dayKey)
                    let isSelected = selectedDates.contains(dayKey)
                    
                    CalendarDayCell(
                        dayNumber: day.day,
                        hasOfferedShift: hasOfferedShift,
                        isSelected: isSelected
                    ) {
                        guard !vm.isSubmitting else { return }
                        
                        if !hasOfferedShift && !isSelected {
                            selectedDates.insert(dayKey)
                        } else if isSelected {
                            selectedDates.remove(dayKey)
                        }
                    }
                }
                .monthHeaders { _ in
                    // empty view
                }
                .monthBackgrounds { _ in
                    
                }
                .backgroundColor(.cpBackgroundSecondary)
                
                .onAppear {
                    vm.loadShifts(month: displayedMonth)
                }
                .onChange(of: vm.loadErrorMessage) { message in
                    // Nothing to offer against without the month's shifts: report it in CalendarView's toast and get out.
                    guard let message, !vm.isSubmitting else { return }
                    onToast(false, message)
                    dismiss()
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Spacer()
                
                VStack {
                    HStack {
                        Spacer()
                        Text("shiftMultiOffer.picker.start")
                            .frame(maxWidth: .infinity)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                        Spacer()
                        Text("shiftMultiOffer.picker.end")
                            .frame(maxWidth: .infinity)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                        Spacer()
                    }
                }
                
                // SHIFT HOUR PICKERS
                HStack(spacing: 0) {
                    Picker("shiftMultiOffer.picker.start", selection: $startHour) {
                        ForEach(7...24, id: \.self) { number in
                            Text(hourString(from: number))
                                .font(.system(.title3, design: .monospaced))
                        }
                    }
                    .pickerStyle(.wheel)
                    .disabled(vm.isSubmitting)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .foregroundStyle(Color.cpForegroundPrimary.opacity(0.7))
                        .frame(maxWidth: 15, maxHeight: 2)
                    
                    Picker("shiftMultiOffer.picker.end", selection: $endHour) {
                        ForEach(8...25, id: \.self) { number in
                            Text(hourString(from: number))
                                .font(.system(.title3, design: .monospaced))
                        }
                    }
                    .pickerStyle(.wheel)
                    .disabled(vm.isSubmitting)
                }
                .frame(maxHeight: 150)
                
                Spacer()
                
                // SUBMIT SHIFTS BUTTON
                Button {
                    Task { @MainActor in
                        await vm.offerShiftsOneByOne(
                            dates: selectedDates,
                            startHour: startHour,
                            endHour: endHour,
                            displayedMonth: displayedMonth,
                            onToast: onToast
                        )

                        // Always dismiss: the toast lives in CalendarView and can't be
                        // seen from under this sheet. Partial/total failure is reported there.
                        //
                        // TODO: a partial batch loses detail here, the toast only reports how many failed plus the last error, never which days or why each one.
                        selectedDates.removeAll()
                        dismiss()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.cpForegroundPrimary.opacity(0.1))
                        
                        if vm.isSubmitting {
                            VStack(spacing: 10) {
                                ProgressView(value: vm.progress)
                                    .progressViewStyle(.linear)
                                    .padding(.horizontal, 16)
                                
                                Text(verbatim: "\(vm.submittedCount)/\(vm.totalToSubmit)")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Color.cpForegroundPrimary.opacity(0.7))
                            }
                            .padding(.vertical, 10)
                        } else {
                            Group {
                                if selectedDates.count == 1 {
                                    Text("shiftMultiOffer.submit.single.button", comment: "Button to submit multiple shifts. Count of offered shifts is 1.")
                                } else {
                                    Text("shiftMultiOffer.submit.multiple.button", comment: "Button to submit multiple shifts. Count of offered shifts more than 1.")
                                }
                            }
                            .font(.headline)
                            .opacity(canSubmit ? 1 : 0.5)
                            .foregroundStyle(Color.cpForegroundPrimary)
                        }
                    }
                    .aspectRatio(7, contentMode: .fit)
                }
                .disabled(!canSubmit)
                .padding(.vertical, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .background(Color.cpBackgroundPrimary)
            
            if vm.isSubmitting {
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
    }
    
    func dayOfWeekName(index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let names = formatter.weekdaySymbols ?? []
        guard names.indices.contains(index) else {
            return "error"
        }
        return String(names[index].prefix(2))
    }
    
    func hourString(from hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

private struct CalendarDayCell: View {
    let dayNumber: Int
    let hasOfferedShift: Bool
    let isSelected: Bool
    
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .padding(3)
                    .foregroundStyle(.cpForegroundPrimary.opacity(isSelected ? 0.8 : 0))
                
                VStack(spacing: 5) {
                    Text(verbatim: "\(dayNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.cpBackgroundPrimary : Color.cpForegroundPrimary)
                    
                    HStack {
                        
                            Circle()
                                .frame(width: 5, height: 5)
                                .foregroundStyle(.cpForegroundSecondary)
                                .opacity(hasOfferedShift ? 0.3 : 0)
                        
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
//    ShiftMultiOfferView(displayedMonth: Date())
    CalendarView()
        .environment(\.locale, .init(identifier: "cs"))
}
