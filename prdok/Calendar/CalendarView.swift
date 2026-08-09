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
import EventKit
import os

let calendar = Calendar.current

final class CalendarViewModel: ObservableObject {
    @Published var plannedDays: Set<Date> = []
    @Published var offeredDays: Set<Date> = []
    @Published var actualDays: Set<Date> = []
    @Published var displayedMonthShifts: [Shift] = []
    @Published var displayedMonthOpenDays: Int?

    let repo = ShiftRepository()
    let openDaysRepo = OpenDaysRepository()
    var loadedYear: Int?
    
    func year(_ date: Date ) -> Int {
        return calendar.component(.year, from: date)
    }
    
    // The three `load…` methods are all `async` and none of them start a `Task` of their
    // own: the caller decides whether to await (the refresh button, so its spinner covers
    // the work) or to fire and forget (`Task { … }` from the calendar's scroll handlers).

    func loadShiftsForYear(dateContainingYear: Date) async {
        let year = year(dateContainingYear)
        do {
            let result = try await repo.preloadYear(year)
            await MainActor.run {
                plannedDays = result.plannedDaySet(using: calendar)
                offeredDays = result.offeredDaySet(using: calendar)
                actualDays = result.actualDaySet(using: calendar)
                loadedYear = year
            }
        } catch {
            // TODO: some error handling
        }
    }

    func checkYear(displayedMonthAndYear: DateComponents) async {
        guard let displayedYear = displayedMonthAndYear.year else { return }
        guard loadedYear != displayedYear else { return }

        if let date = calendar.date(from: displayedMonthAndYear) {
            await loadShiftsForYear(dateContainingYear: date)
        }
    }

    func loadShiftsForMonth(dateContainingMonth: Date) async {
        do {
            let shifts = try await repo.getShifts(for: dateContainingMonth)
            await MainActor.run {
                displayedMonthShifts = shifts
            }
        } catch {
            // TODO: some error handling
            await MainActor.run {
                displayedMonthShifts = []
            }
        }
    }

    /// Loads the open-day count backing the statistics' month coefficient.
    /// On failure we clear it rather than keep a stale month's value — the statistics
    /// then fall back to the calendar day count.
    func loadOpenDaysForMonth(dateContainingMonth: Date, forceRefresh: Bool = false) async {
        let key = OpenDaysService.monthString(from: dateContainingMonth)
        do {
            let openDays = try await openDaysRepo.getOpenDays(for: dateContainingMonth, forceRefresh: forceRefresh)
            await MainActor.run {
                displayedMonthOpenDays = openDays
            }
        } catch {
            Log.openDays.error("[CalendarVM] \(key, privacy: .public) open days unavailable, statistics fall back to calendar days: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                displayedMonthOpenDays = nil
            }
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
    
    // MARK: - Calendar export
    
    @State private var exportSheetIsPresented: Bool = false
    
    private var displayedMonthDate: Date? {
        calendar.date(from: displayedMonth)
    }
    
    private var currentMonthLabel: String {
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
                        dataDependency: (selectedDate, vm.plannedDays, vm.offeredDays, vm.actualDays),
                        proxy: proxy
                    )
                    .dayOfWeekHeaders { month, index in
                        Text(dayOfWeekName(index: index).uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.cpForegroundMuted)
                    }
                    .days { day in
                        let date = calendar.date(from: day.components)!
                        let isToday = calendar.isDateInToday(date)
                        let backgroundOpacity: Double = getBackgroundOpacity(date: date)

                        let dayKey = calendar.startOfDay(for: date)
                        let hasPlannedShift = vm.plannedDays.contains(dayKey)
                        let hasOfferedShift = vm.offeredDays.contains(dayKey)
                        let hasActualShift = vm.actualDays.contains(dayKey)

                        CalendarDayCell(
                            dayNumber: day.day,
                            isToday: isToday,
                            hasPlannedShift: hasPlannedShift,
                            hasOfferedShift: hasOfferedShift,
                            hasActualShift: hasActualShift,
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
                            Task { await vm.loadShiftsForMonth(dateContainingMonth: dateContainingMonth) }
                            Task { await vm.loadOpenDaysForMonth(dateContainingMonth: dateContainingMonth) }
                        }
                        let month = displayedMonth
                        Task { await vm.checkYear(displayedMonthAndYear: month) }
                    }
                    .backgroundColor(.cpBackgroundPrimary)
                    .disabled(isRefreshingMonth)
                    .onAppear {
                        let today = Date()
                        selectedDate = today
                        scrollToMonthAndUpdateState(dateContainingMonth: today, animated: false)
                        Task { await vm.loadShiftsForYear(dateContainingYear: today) }
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
                        Button {
                            offerShiftSheetIsPresented = true
                        } label: {
                            Text("offer shifts")
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                        
                        Button {
                            exportSheetIsPresented = true
                        } label: {
                            Text("upload to calendar")
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.cpBackgroundPrimary)
                    .tint(.cpForegroundPrimary)
                    .sheet(isPresented: $offerShiftSheetIsPresented) {
                        if let displayedMonthDate = calendar.date(from: displayedMonth) {
                            ShiftMultiOfferView(
                                displayedMonth: displayedMonthDate,
                                onToast: handleMultiOfferFinished(success:message:)
                            )
                        }
                    }
                    .sheet(isPresented: $exportSheetIsPresented) {
                        CalendarExportSheetView(
                            monthLabel: currentMonthLabel,
                            monthDate: displayedMonthDate,
                            onDone: { success, message in
                                exportSheetIsPresented = false
                                Task { @MainActor in
                                    UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
                                    await presentToast(success: success, message: message)
                                }
                            }
                        )
                        .presentationDetents([.large])
                    }
                    .aspectRatio(7, contentMode: .fit)
                    
                    if let displayedMonthDate = displayedMonthDate {
                        ShiftStatisticsView(
                            shifts: vm.displayedMonthShifts,
                            displayedMonth: displayedMonthDate,
                            openDays: vm.displayedMonthOpenDays
                        )
                        .padding(.top, 8)
                    }
                    
                    FreeShiftsListView()
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 24)
            }
            .background {
                Color.cpBackgroundPrimary.ignoresSafeArea()
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
            // force-refresh the displayed month cache
            _ = try await vm.repo.getShifts(for: date, forceRefresh: true)

            // force-refresh the open-day count backing the statistics coefficient.
            // Swallows its own errors so this secondary endpoint can't fail the refresh.
            await vm.loadOpenDaysForMonth(dateContainingMonth: date, forceRefresh: true)

            // then recompute day dots across the year (keeps current behavior consistent)
            await vm.loadShiftsForYear(dateContainingYear: date)

            // refresh the statistics
            await vm.loadShiftsForMonth(dateContainingMonth: date)
            
            // minimum spinner duration (slow network won't be slowed further)
            let elapsed = startedAt.duration(to: clock.now)
            let remaining = minRefreshSpinnerDuration - elapsed
            if remaining > .zero {
                try await clock.sleep(for: remaining)
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        
        } catch {
            // minimum spinner duration even on error (consistent UX)
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
                await vm.loadShiftsForYear(dateContainingYear: selectedDate)
                await vm.loadShiftsForMonth(dateContainingMonth: selectedDate)
            } catch {
             // same as handleMultiOfferFinished()
            }
        }
    }
    
    func handleMultiOfferFinished(success: Bool, message: String) {
        // cancel any hide-show sequence in progress and start a fresh one.
        toastPresentationTask?.cancel()
        toastPresentationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000) // wait for sheet to be closed in the UI

            await presentToast(success: success, message: message)
            guard let monthDate = calendar.date(from: displayedMonth) else { return }
            do {
                try await vm.repo.refresh(for: monthDate)
                await vm.loadShiftsForYear(dateContainingYear: monthDate)
                await vm.loadShiftsForMonth(dateContainingMonth: monthDate)
            } catch {
                // there used to be a toast for refresh error, now deliberately silent: toasting here would replace the offer result the
                // user is currently reading.
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

    /// How long a toast stays up: a base reading time plus a bit per extra line, capped so a
    /// long batch report can't sit on screen indefinitely.
    ///
    /// Counts explicit newlines only — soft wrapping isn't known until layout, so a single long
    /// line that wraps gets the base duration. Good enough: the multi-line cases we build are
    /// all `\n`-joined.
    func toastVisibleDuration(for message: String) -> TimeInterval {
        let base: TimeInterval = 2
        let perExtraLine: TimeInterval = 1.2
        let maxDuration: TimeInterval = 8

        let extraLines = max(0, message.split(separator: "\n", omittingEmptySubsequences: false).count - 1)
        return min(base + Double(extraLines) * perExtraLine, maxDuration)
    }

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
        let visibleDuration = toastVisibleDuration(for: message)
        toastHideTask = Task { @MainActor in // schedule hiding
            try? await Task.sleep(nanoseconds: UInt64(visibleDuration * 1_000_000_000))
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
        let month = displayedMonth
        // Separate tasks on purpose: the year preload is up to 12 fetches and must not
        // hold up the displayed month's shifts or open-day count.
        Task { await vm.checkYear(displayedMonthAndYear: month) }
        Task { await vm.loadShiftsForMonth(dateContainingMonth: dateContainingMonth) }
        Task { await vm.loadOpenDaysForMonth(dateContainingMonth: dateContainingMonth) }
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
    /// Upper bound on toast height. Messages are expected to be pre-truncated to this
    /// many lines by the caller (see `CalendarView.toastLineCount`); this is a backstop.
    static let maxLines = 8

    let message: String
    let isSuccess: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(isSuccess ? .green : .red)
            Text(message)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(ToastBanner.maxLines)
                .fixedSize(horizontal: false, vertical: true)
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
    let hasActualShift: Bool
    let backgroundOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .padding(2)
                    .foregroundStyle(.cpForegroundPrimary.opacity(backgroundOpacity))

                VStack(spacing: 5) {
                    Text(verbatim: "\(dayNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(isToday ? Color.cpBackgroundPrimary : Color.cpForegroundPrimary)

                    HStack {
                        Circle()
                            .frame(width: 5, height: 5)
                            .opacity((hasPlannedShift || hasOfferedShift || hasActualShift) ? 1 : 0)
                            .opacity((hasPlannedShift || hasActualShift) ? 1 : 0.3)
                            .foregroundStyle(.cpForegroundSecondary)
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

    func actualDaySet(using calendar: Calendar) -> Set<Date> {
        Set(self.filter { $0.kind == .actual }.map { calendar.startOfDay(for: $0.start) })
    }
}

#Preview {
    CalendarView()
}

