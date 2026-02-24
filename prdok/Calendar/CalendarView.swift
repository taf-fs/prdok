//
//  CalendarView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine
import HorizonCalendar
import UIKit

let calendar = Calendar.current

final class CalendarViewModel: ObservableObject {
    @Published var plannedDays: Set<Date> = []
    @Published var offeredDays: Set<Date> = []
    
    let repo = ShiftRepository()
    var loadedYear: Int?
    
    func year(_ date: Date ) -> Int {
        return calendar.component(.year, from: date)
    }
    
    func loadShiftsForYear(dateContainingYear: Date) {
        let year = year(dateContainingYear)
        Task {
            do {
                let result = try await repo.preloadYear(year)
                await MainActor.run {
                    plannedDays = result.plannedDaySet(using: calendar)
                    offeredDays = result.offeredDaySet(using: calendar)
                    loadedYear = year
                }
            } catch {
                // TODO: some error handling
            }
        }
    }
    
    func checkYear(displayedMonthAndYear: DateComponents) {
        guard let displayedYear = displayedMonthAndYear.year else { return }
        guard loadedYear != displayedYear else { return }
        
        if let date = calendar.date(from: displayedMonthAndYear) {
            loadShiftsForYear(dateContainingYear: date)
        }
    }
}

struct CalendarView: View {

    @State var calendarStartBound = calendar.date(byAdding: .year, value: -1, to: Date())!
    @State var calendarEndBound = calendar.date(byAdding: .year, value: 1, to: Date())!
    
    @StateObject var vm = CalendarViewModel()
    @StateObject var proxy: CalendarViewProxy = .init()
    
    @State var selectedDate: Date?
    @State var displayedMonth: DateComponents = calendar.dateComponents([.year, .month], from: Date())
    @State var daySheetIsPresented: Bool = false
    @State var offerShiftSheetIsPresented: Bool = false
    @State var selectedDetent: PresentationDetent = .medium
    
    // Web sheet driven by the actual selected date (avoids race between Bool (day sheet) + payload)
    @State private var plannedShiftsWebItem: PlannedShiftsWebItem?
    
    @State private var toastIsPresented: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIsSuccess: Bool = true
    @State private var toastToken: UUID = UUID()
    @State private var toastHideTask: Task<Void, Never>?
    @State private var toastPresentationTask: Task<Void, Never>? // serializes hide-show animations to support fast user actions
    
    @State private var isRefreshingMonth: Bool = false
    
    private let toastTransitionDuration: TimeInterval = 0.2 // duration of the toast hide-show animation.
    
    /// UX: ensure the refresh spinner stays visible for at least this long so it doesn't "blink".
    private let minRefreshSpinnerDuration: Duration = .milliseconds(350)
    
    var currentMonthLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMMMy")
        let date = calendar.date(from: displayedMonth)!
        return df.string(from: date).capitalized(with: df.locale)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("calendar.title")
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                    
                    HStack {
                        Text(currentMonthLabel)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.semibold)
                        Spacer()
                        HStack {
                            PrevMonthButton {
                                let baseComponents = displayedMonth
                                if let baseDate = calendar.date(from: baseComponents) {
                                    let target = calendar.date(byAdding: .month, value: -1, to: baseDate)!
                                    scrollToMonthAndUpdateState(dateContainingMonth: target)
                                }
                            }
                            .disabled(isRefreshingMonth)
                            
                            NextMonthButton {
                                let baseComponents = displayedMonth
                                if let baseDate = calendar.date(from: baseComponents) {
                                    let target = calendar.date(byAdding: .month, value: 1, to: baseDate)!
                                    scrollToMonthAndUpdateState(dateContainingMonth: target)
                                }
                            }
                            .disabled(isRefreshingMonth)
                            
                            RefreshMonthButton(isRefreshing: isRefreshingMonth) {
                                Task { @MainActor in
                                    await refreshDisplayedMonth()
                                }
                            }
                        }
                    }
                    
                    CalendarViewRepresentable(
                        calendar: calendar,
                        visibleDateRange: calendarStartBound...calendarEndBound,
                        monthsLayout: .horizontal(options: HorizontalMonthsLayoutOptions()),
                        dataDependency: (selectedDate, vm.plannedDays, vm.offeredDays),
                        proxy: proxy
                    )
                    .dayOfWeekHeaders { month, index in
                        Text(dayOfWeekName(index: index).uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.gray)
                    }
                    .days { day in
                        let date = calendar.date(from: day.components)!
                        let isToday = calendar.isDateInToday(date)
                        let backgroundOpacity: Double = getBackgroundOpacity(date: date)

                        let dayKey = calendar.startOfDay(for: date)
                        let hasPlannedShift = vm.plannedDays.contains(dayKey)
                        let hasOfferedShift = vm.offeredDays.contains(dayKey)

                        CalendarDayCell(
                            dayNumber: day.day,
                            isToday: isToday,
                            hasPlannedShift: hasPlannedShift,
                            hasOfferedShift: hasOfferedShift,
                            backgroundOpacity: backgroundOpacity
                        ) {
                            selectedDate = date
                            selectedDetent = .medium
                            daySheetIsPresented = true
                        }
                    }
                    .monthHeaders { content in
                        // empty view
                    }
                    .onDeceleratingEnd { visibleDayRange in
                        displayedMonth = visibleDayRange.lowerBound.components
                        if let dateContainingMonth = calendar.date(from: displayedMonth) {
                            setVisibleRange(around: dateContainingMonth)
                        }
                        vm.checkYear(displayedMonthAndYear: displayedMonth)
                    }
                    .disabled(isRefreshingMonth)
                    .onAppear {
                        selectedDate = Date()
                        scrollToMonthAndUpdateState(dateContainingMonth: selectedDate!, animated: false)
                        vm.loadShiftsForYear(dateContainingYear: selectedDate!)
                    }
                    .sheet(isPresented: $daySheetIsPresented) {
                        CalendarDayDetailsView(
                            date: $selectedDate,
                            selectedDetent: $selectedDetent,
                            onActionFinished: handleActionFinished(success:message:),
                            onShowPlannedShifts: handleShowPlannedShifts(date:)
                        )
                        .presentationDetents([.medium, .large], selection: $selectedDetent)
                    }
                    .sheet(item: $plannedShiftsWebItem) { item in
                        ShiftsListWebView(date: item.date)
                    }
                    
                    HStack {
                        Button("navolit směny") {
                            offerShiftSheetIsPresented = true
                        }
                        
                        Button("nahrát do kalendáře") {}
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $offerShiftSheetIsPresented) {
                        
                        if let displayedMonthDate = calendar.date(from: displayedMonth) {
                            ShiftMultiOfferView(
                                displayedMonth: displayedMonthDate,
                                onToast: handleMultiOfferFinished(success:message:)
                            )
                        }
                    }
                    .aspectRatio(7, contentMode: .fit)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 24)
            }
            if toastIsPresented {
                ToastBanner(message: toastMessage, isSuccess: toastIsSuccess)
                    .id(toastToken)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Refresh
    
    @MainActor
    func refreshDisplayedMonth() async {
        guard !isRefreshingMonth else { return }
        guard let date = calendar.date(from: displayedMonth) else { return }
        
        let clock = ContinuousClock()
        let startedAt = clock.now
        
        isRefreshingMonth = true
        defer {
            isRefreshingMonth = false
        }
        
        do {
            // Force-refresh the displayed month cache.
            _ = try await vm.repo.getShifts(for: date, forceRefresh: true)
            
            // Then recompute day dots across the year (keeps current behavior consistent).
            vm.loadShiftsForYear(dateContainingYear: date)
            
            // Minimum spinner duration (slow network won't be slowed further).
            let elapsed = startedAt.duration(to: clock.now)
            let remaining = minRefreshSpinnerDuration - elapsed
            if remaining > .zero {
                try await clock.sleep(for: remaining)
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
        } catch is CancellationError {
            // Pull-to-refresh / SwiftUI Tasks can be cancelled as the UI changes.
            // Not a user-visible failure.
            return
            
        } catch {
            // Minimum spinner duration even on error (optional but keeps UX consistent).
            let elapsed = startedAt.duration(to: clock.now)
            let remaining = minRefreshSpinnerDuration - elapsed
            if remaining > .zero {
                try? await clock.sleep(for: remaining)
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            await presentToast(success: false, message: error.localizedDescription)
        }
    }
    
    // MARK: - Action Handlers
    
    func handleActionFinished(success: Bool, message: String) {
        daySheetIsPresented = false // close sheet
        
        // cancel any hide-show sequence in progress and start a fresh one.
        toastPresentationTask?.cancel()
        toastPresentationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000) // wait for sheet to be closed in the UI
            
            await presentToast(success: success, message: message)
            
            guard success, let selectedDate else { return }  // refresh shifts after successful offer/removal
            do {
                try await vm.repo.refresh(for: selectedDate)
                vm.loadShiftsForYear(dateContainingYear: selectedDate)
            } catch { // toast for failure to refresh shifts
                await presentToast(success: false, message: error.localizedDescription)
            }
        }
    }
    
    func handleMultiOfferFinished(success: Bool, message: String) {
        // cancel any hide-show sequence in progress and start a fresh one.
        toastPresentationTask?.cancel()
        toastPresentationTask = Task { @MainActor in
            await presentToast(success: success, message: message)
            
            guard success else { return }
            guard let monthDate = calendar.date(from: displayedMonth) else { return }
            do {
                try await vm.repo.refresh(for: monthDate)
                vm.loadShiftsForYear(dateContainingYear: monthDate)
            } catch {
                await presentToast(success: false, message: error.localizedDescription)
            }
        }
    }
    
    func handleShowPlannedShifts(date: Date) {
        // dismiss details sheet first
        daySheetIsPresented = false
        
        // then drive web sheet with an item payload.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            plannedShiftsWebItem = PlannedShiftsWebItem(date: date)
        }
    }
    
    // MARK: - Toast
    
    @MainActor
    func presentToast(success: Bool, message: String) async {
        toastHideTask?.cancel() // cancel hiding of a toast if there was one shown
        
        // If a toast is already visible, animate hiding it first.
        if toastIsPresented {
            withAnimation(.easeInOut(duration: toastTransitionDuration)) {
                toastIsPresented = false
            }
            try? await Task.sleep(nanoseconds: UInt64(toastTransitionDuration * 1_000_000_000))
        }
        
        toastIsSuccess = success //
        toastMessage = message   // toast state
        toastToken = UUID()      //
        
        withAnimation(.easeInOut(duration: toastTransitionDuration)) {
            toastIsPresented = true // show toast
        }
        
        let myToken = toastToken
        toastHideTask = Task { @MainActor in // schedule hiding
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard myToken == toastToken else { return }
            withAnimation(.easeInOut(duration: toastTransitionDuration)) {
                toastIsPresented = false
            }
        }
    }
    
    // MARK: - Calendar
    
    func scrollToMonthAndUpdateState(dateContainingMonth: Date, animated: Bool = true) {
        setVisibleRange(around: dateContainingMonth)
        DispatchQueue.main.async {
            proxy.scrollToMonth(containing: dateContainingMonth, scrollPosition: .centered, animated: animated)
        }
        displayedMonth = calendar.dateComponents([.year, .month], from: dateContainingMonth)
        vm.checkYear(displayedMonthAndYear: displayedMonth)
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
    
    func getBackgroundOpacity(date: Date) -> Double {
        guard let selectedDate = selectedDate else { return 0 }
        if calendar.isDateInToday(date) { return 1 }
        if calendar.isDate(date, inSameDayAs: selectedDate) { return 0.2 }
        return 0
    }
    
    func setVisibleRange(around date: Date, monthsBefore: Int = 12, monthsAfter: Int = 12) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: comps),
              let start = calendar.date(byAdding: .month, value: -monthsBefore, to: startOfMonth),
              let endMonthStart = calendar.date(byAdding: .month, value: monthsAfter + 1, to: startOfMonth),
              let end = calendar.date(byAdding: .day, value: -1, to: endMonthStart) else { return }

        calendarStartBound = start
        calendarEndBound = end
    }
}

private struct PlannedShiftsWebItem: Identifiable {
    let id = UUID()
    let date: Date
}

private struct ToastBanner: View {
    let message: String
    let isSuccess: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(isSuccess ? .green : .red)
            Text(message)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
    }
}

private struct CalendarDayCell: View {
    let dayNumber: Int
    let isToday: Bool
    let hasPlannedShift: Bool
    let hasOfferedShift: Bool
    let backgroundOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .padding(2)
                    .foregroundStyle(.tint.opacity(backgroundOpacity))

                VStack(spacing: 5) {
                    Text("\(dayNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(isToday ? Color.white : Color.primary)

                    HStack {
                        Circle()
                            .frame(width: 5, height: 5)
                            .opacity(hasOfferedShift ? 1 : 0)
                            .foregroundStyle(.tint.opacity(hasPlannedShift ? 1 : 0.3))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct NextMonthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .frame(width: 35, height: 35)
        }
        .buttonStyle(.plain)
    }
}

private struct PrevMonthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .frame(width: 35, height: 35)
        }
        .buttonStyle(.plain)
    }
}

private struct RefreshMonthButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(width: 35, height: 35)
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
    }
}

extension Collection where Element == Shift {
    func plannedDaySet(using calendar: Calendar) -> Set<Date> {
        Set(self.filter { $0.kind == .planned }.map { calendar.startOfDay(for: $0.start) })
    }
    
    func offeredDaySet(using calendar: Calendar) -> Set<Date> {
        Set(self.filter { $0.kind == .offered }.map { calendar.startOfDay(for: $0.start) })
    }
}

#Preview {
    CalendarView()
}

