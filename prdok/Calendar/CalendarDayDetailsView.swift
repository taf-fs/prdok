//
//  CalendarDayDetailsView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine

final class CalendarDayDetailsViewModel: ObservableObject {
    @Published var offeredShifts: [Shift] = []
    @Published var plannedShifts: [Shift] = []
    @Published var actualShifts: [Shift] = []
    
    @Published var isRemovingOfferedShift: Bool = false
    @Published var isOfferingShift: Bool = false
    
    var shifts: [Shift] = []
    let repo = ShiftRepository()
    
    func fetchShift(date: Date?) {
        guard let date else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        Task {
            do {
                let allShifts = try await repo.getShifts(for: date)
                await MainActor.run {
                    self.shifts = allShifts
                    
                    self.offeredShifts = allShifts.filter {
                        $0.kind == .offered && $0.dayStart == dayStart
                    }
                    self.plannedShifts = allShifts.filter {
                        $0.kind == .planned && $0.dayStart == dayStart
                    }
                    self.actualShifts = allShifts.filter {
                        $0.kind == .actual && $0.dayStart == dayStart
                    }
                }
            } catch {
                // TODO: you may want some error handling here
                // idea: the sheet could be blank or something if shifts fail to fetch
            }
        }
    }
    
    @MainActor
    func removeOfferedShiftIfAny(for date: Date?) async -> Result<Void, Error> {
        guard !isRemovingOfferedShift else { return .failure(ShiftActionError.busy) }
        guard let date else { return .failure(ShiftActionError.noDateSelected) }
        
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let shiftToRemove = offeredShifts.first(where: { $0.kind == .offered && $0.dayStart == dayStart }) else {
            return .failure(ShiftActionError.noOfferedShiftToRemove)
        }
        
        isRemovingOfferedShift = true
        defer { isRemovingOfferedShift = false }
        
        do {
            let result = try await ShiftService.removeShift(shift: shiftToRemove)
            switch result {
            case .removed:
                fetchShift(date: date)
                return .success(())
            case .notFound:
                return .failure(ShiftActionError.shiftNotFoundOnServer)
            case .unexpected(let message):
                return .failure(ShiftActionError.unexpectedServerResponse(message: message))
            }
        } catch {
            return .failure(error)
        }
    }
    
    @MainActor
    func offerShift(for date: Date?, startHour: Int, endHour: Int) async -> Result<Void, Error> {
        guard !isOfferingShift else { return .failure(ShiftActionError.busy) }
        guard let date else { return .failure(ShiftActionError.noDateSelected) }
        guard startHour < endHour else {
            return .failure(ShiftActionError.invalidTimeRange)
        }
        
        isOfferingShift = true
        defer { isOfferingShift = false }
        
        do {
            let result = try await ShiftService.offerShift(when: date, start: startHour, end: endHour)
            switch result {
            case .saved:
                fetchShift(date: date)
                return .success(())
            case .rejected(let message):
                return .failure(ShiftActionError.serverRejected(message: message))
            case .unexpected(let message):
                return .failure(ShiftActionError.unexpectedServerResponse(message: message))
            }
        } catch {
            return .failure(error)
        }
    }
}

struct CalendarDayDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject var vm = CalendarDayDetailsViewModel()
    @Binding var date: Date?

    @Binding var selectedDetent: PresentationDetent
    @State var isShiftSelectorShown: Bool = false
    @State var startHour: Int = 7
    @State var endHour: Int = 25
    
    /// (success, message)
    var onActionFinished: (Bool, String) -> Void = { _, _ in }
    
    /// Lifted action: parent will dismiss this sheet and present the web sheet separately.
    var onShowPlannedShifts: (Date) -> Void = { _ in }
    
    private var offeredShiftForBoundDate: Shift? {
        guard let date else { return nil }
        let dayStart = Calendar.current.startOfDay(for: date)
        return vm.offeredShifts.first(where: { $0.kind == .offered && $0.dayStart == dayStart })
    }
    
    private var canRemoveOfferedShift: Bool {
        offeredShiftForBoundDate != nil && !vm.isRemovingOfferedShift
    }
    
    private var canSubmitOffer: Bool {
        !vm.isOfferingShift && !vm.isRemovingOfferedShift && startHour < endHour && date != nil
    }
    
    var fulldate: String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("dMMMMY")
        guard let date else { return "-" }
        return df.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Text(fulldate)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Offered Shift
            VStack(spacing: 6) {
                HStack {
                    Text("calendarDayDetails.offeredShift.title")
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(.semibold)
                    Spacer()
                    if offeredShiftForBoundDate != nil {
                        // remove shift button
                        Button(role: .destructive) {
                            Task {
                                let outcome = await vm.removeOfferedShiftIfAny(for: date)
                                switch outcome {
                                case .success:
                                    dismiss()
                                    onActionFinished(true, NSLocalizedString("shiftAction.success.removed", comment: "Shift removed successfully."))
                                case .failure(let error):
                                    onActionFinished(false, error.localizedDescription)
                                }
                            }
                        } label: {
                            HStack {
                                if vm.isRemovingOfferedShift {
                                    ProgressView().controlSize(.small)
                                }
                                Text("calendarDayDetails.offeredShift.removeButton", comment: "Title of a button to remove offered shift.")
                                    .font(.system(.footnote, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .underline()
                            }
                        }
                    } else {
                        // show sheet selector button
                        Button {
                            withAnimation {
                                isShiftSelectorShown = true
                            }
                            selectedDetent = .large
                        } label: {
                            Text("calendarDayDetails.offeredShift.offerButton", comment: "Title of a button to extend the sheet to show the picker.")
                                .font(.system(.footnote, design: .monospaced))
                                .fontWeight(.semibold)
                                .underline()
                        }
                        .disabled(selectedDetent == .large)
                    }
                }
                ShiftIndicatorView(
                    shifts: vm.offeredShifts,
                    color: Color(red: 102/255, green: 1, blue: 51/255, opacity: 0.5))
            }
            
            // Planned Shift
            VStack(spacing: 6) {
                HStack {
                    Text("calendarDayDetails.plannedShift.title")
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        // dismisses this view and pops a different sheet
                        guard let date = date else { return }
                        onShowPlannedShifts(date)
                    } label: {
                        Text("calendarDayDetails.showShiftWebView", comment: "view/zobrazit")
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.semibold)
                            .underline()
                            .foregroundStyle(Color.cpForegroundPrimary)
                    }
                }
                ShiftIndicatorView(
                    shifts: vm.plannedShifts,
                    color: Color(red: 76/255, green: 196/255, blue: 23/255, opacity: 0.5))
            }
            
            // Actual Shift
            VStack(spacing: 6) {
                HStack {
                    Text("calendarDayDetails.actualShift.title")
                        .font(.system(.footnote, design: .monospaced))
                        .fontWeight(.semibold)
                    Spacer()
                }
                ShiftIndicatorView(
                    shifts: vm.actualShifts,
                    color: Color(red: 189/255, green: 183/255, blue: 107/255, opacity: 0.5))
            }
            
            Spacer()
            
            if isShiftSelectorShown {
                VStack {
                    HStack {
                        Spacer()
                        Text("calendarDayDetails.shiftOffer.picker.start")
                            .frame(maxWidth: .infinity)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                        Spacer()
                        Text("calendarDayDetails.shiftOffer.picker.end")
                            .frame(maxWidth: .infinity)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.cpForegroundPrimary.opacity(0.6))
                        Spacer()
                    }
                    
                    HStack(spacing: 0) {
                        Picker("calendarDayDetails.shiftOffer.picker.start", selection: $startHour) {
                            ForEach(7...24, id: \.self) { number in
                                Text(hourString(from: number))
                                    .font(.system(.title3, design: .monospaced))
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .foregroundStyle(Color.cpForegroundPrimary.opacity(0.7))
                            .frame(maxWidth: 15, maxHeight: 2)
                        
                        Picker("calendarDayDetails.shiftOffer.picker.end", selection: $endHour) {
                            ForEach(8...25, id: \.self) { number in
                                Text(hourString(from: number))
                                    .font(.system(.title3, design: .monospaced))
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(maxHeight: 150)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            let outcome = await vm.offerShift(for: date, startHour: startHour, endHour: endHour)
                            switch outcome {
                            case .success:
                                dismiss()
                                onActionFinished(true, NSLocalizedString("shiftAction.success.saved", comment: "Shift saved successfully."))
                            case .failure(let error):
                                onActionFinished(false, error.localizedDescription)
                            }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .foregroundStyle(.tint.opacity(0.1))
                            if vm.isOfferingShift {
                                ProgressView()
                            } else {
                                Text("calendarDayDetails.offerShift.button", comment: "submit offered shift button")
                                    .font(.headline)
                                    .foregroundStyle(Color.cpForegroundPrimary)
                            }
                        }
                        .aspectRatio(7, contentMode: .fit)
                        .opacity(canSubmitOffer ? 1 : 0.5)
                    }
                    .disabled(!canSubmitOffer)
                    .padding(.vertical, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .onChange(of: selectedDetent) { newValue in
            if selectedDetent == .medium {
                withAnimation {
                    isShiftSelectorShown = false
                }
            } else {
                withAnimation {
                    isShiftSelectorShown = true
                }
            }
        }
        .onAppear {
            vm.fetchShift(date: date)
        }
    }
    
    func hourString(from hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

enum ShiftActionError: Error, LocalizedError, Equatable {
    case busy
    case noDateSelected
    case invalidTimeRange
    case noOfferedShiftToRemove
    case shiftNotFoundOnServer
    case serverRejected(message: String)
    case unexpectedServerResponse(message: String?)

    var errorDescription: String? {
        switch self {
        case .busy:
            return NSLocalizedString("shiftAction.error.busy", comment: "User tried to run an action while it is already running.")
        case .noDateSelected:
            return NSLocalizedString("shiftAction.error.noDateSelected", comment: "No date selected.")
        case .invalidTimeRange:
            return NSLocalizedString("shiftAction.error.invalidTimeRange", comment: "Start must be before end.")
        case .noOfferedShiftToRemove:
            return NSLocalizedString("shiftAction.error.noOfferedShiftToRemove", comment: "No offered shift exists for this day.")
        case .shiftNotFoundOnServer:
            return NSLocalizedString("shiftAction.error.shiftNotFoundOnServer", comment: "Shift to remove was not found on server.")
        case .serverRejected(let message):
            // Decision: message is server-provided (often Czech). Keep it, but prefix with a localized label.
            let prefix = NSLocalizedString("shiftAction.error.serverRejected.prefix", comment: "Prefix shown before server rejection message.")
            return "\(prefix) \(message)"
        case .unexpectedServerResponse(let message):
            let base = NSLocalizedString("shiftAction.error.unexpectedServerResponse", comment: "Unexpected server response.")
            if let message, !message.isEmpty {
                return "\(base) (\(message))"
            } else {
                return base
            }
        }
    }
}


// A wrapper just for previewing the sheet presentation style
private struct CalendarDayDetailsSheetPreviewContainer: View {
    @State private var isPresented = true
    @State private var date: Date? = calendar.date(byAdding: .day, value: 60, to: Date())
    @State private var selectedDetent: PresentationDetent = .medium
    
    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                CalendarDayDetailsView(date: $date, selectedDetent: $selectedDetent)
                    .presentationDetents([.medium, .large], selection: $selectedDetent)
            }
    }
}

struct CalendarDayDetailsViewPreviews: PreviewProvider {
    static var previews: some View {
        CalendarDayDetailsSheetPreviewContainer()
            .environment(\.locale, .init(identifier: "cs"))
    }
}
