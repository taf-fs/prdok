//
//  TodayView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine

final class TodayViewModel: ObservableObject {
    @Published var shifts: [Shift] = []
    @Published var error: String?
    @Published var showErrorAlert = false
    @Published var isLoading = false
    
    let repo = ShiftRepository()
    
    func fetch(date: Date) {
        error = nil
        isLoading = true
        Task {
            do {
                let currentMonthShifts = try await repo.getShifts(for: date)
                let nextMonthShifts = try await repo.getShifts(for: Calendar.current.date(byAdding: .month, value: 1, to: date)!)
                await MainActor.run {
                    self.shifts = currentMonthShifts + nextMonthShifts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showErrorAlert = true
                    self.isLoading = false
                }
            }
        }
    }
}

struct TodayView: View {
    @AppStorage("needsToBootstrap") private var needsToBootstrap = false
    @StateObject private var vm = TodayViewModel()
    @State var selectedDate: Date = Date()
    @State private var showWebView = false
    /// A day tapped in the upcoming shifts; separate from `showWebView`, which picks its own date.
    @State private var dayWebItem: ShiftsListWebItem?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 20) {
                    headerCard(height: proxy.size.height * 0.55)

                    SimplePauseTimerView()
                        .padding(.horizontal, 16)

                    UpcomingShiftsListView(shifts: vm.shifts, bottomInset: proxy.safeAreaInsets.bottom) { date in
                        dayWebItem = ShiftsListWebItem(date: date)
                    }
                    .padding(.horizontal, 16)
                }
                .background {
                    Color.cpBackgroundSecondary
                        .ignoresSafeArea(edges: .bottom)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .task {
                if !needsToBootstrap {
                    vm.fetch(date: Date())
                }
            }
            .onChange(of: needsToBootstrap) { isBootstrapping in
                if !isBootstrapping {
                    vm.fetch(date: Date())
                }
            }
            .sheet(item: $dayWebItem) { item in
                ShiftsListWebView(date: item.date)
            }
            .alert(vm.error ?? "", isPresented: $vm.showErrorAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func headerCard(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            TopDateBar()

            Spacer()

            VStack(spacing: 20) {
                countdownTimeline
                whoIsOnShiftButton
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(
            Color.cpBackgroundPrimary
                .ignoresSafeArea(edges: .top)
        )
        .sheet(isPresented: $showWebView) {
            webViewSheet
        }
    }

    private var countdownTimeline: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date

            if let current = vm.shifts.ongoingShift(at: now) {
                ShiftCountdownBlock(
                    isShiftUpcoming: false,
                    target: current.end,
                    rangeText: current.timeRangeString,
                    now: now)
            } else if let next = vm.shifts.nextPlannedShift(after: now) {
                ShiftCountdownBlock(
                    isShiftUpcoming: true,
                    target: next.start,
                    rangeText: next.timeRangeString,
                    now: now)
            } else if vm.isLoading {
                ProgressView("today.countdown.loading")
            } else {
                Text("today.noUpcomingShifts")
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
        }
    }

    private var whoIsOnShiftButton: some View {
        Button {
            showWebView = true
        } label: {
            Text("shiftsListWebView.presentView.button")
                .font(.system(.footnote))
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .padding(.horizontal, 40)
                .foregroundStyle(Color.cpBackgroundPrimary)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .tint(Color.cpForegroundPrimary)
                }
        }
    }

    @ViewBuilder
    private var webViewSheet: some View {
        if vm.shifts.ongoingShift() != nil {
            ShiftsListWebView(date: Date())
        } else if let nextPlannedShift = vm.shifts.nextPlannedShift() {
            ShiftsListWebView(date: nextPlannedShift.start)
        } else {
            ShiftsListWebView(date: Date())
        }
    }
}

private struct TopDateBar: View {
    var body: some View {
        HStack {
            NavigationLink {
                ProfileView()
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(.title))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(currentDayAndMonth())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gear")
                    .font(.system(.title))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ShiftCountdownBlock: View {
    let isShiftUpcoming: Bool
    let target: Date
    let rangeText: String
    let now: Date
    let testDate = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 12))!
    
    func isLaterThanTomorrow(target: Date) -> Bool {
        // Start of today
        let startOfToday = calendar.startOfDay(for: now)
        
        guard let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) else {
            return false
        }
        
        return target >= startOfDayAfterTomorrow
    }
    
    func isLaterThanToday(target: Date) -> Bool {
        let startOfToday = calendar.startOfDay(for: now)
        
        guard let startOfDayAfterToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return false
        }
        
        return target >= startOfDayAfterToday
    }
    
    var contextTitle: LocalizedStringKey {
        if isShiftUpcoming {
            if isLaterThanTomorrow(target: target) {
                return "today.countdown.shift.nextStart"
            } else { return "today.countdown.shift.nextStart.soon" }
        } else {
            return "today.countdown.shift.currentEnd"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(contextTitle)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.bold)
            
            if isShiftUpcoming && !isLaterThanTomorrow(target: target) {
                Text(isLaterThanToday(target: target) ? "today.countdown.tomorrow" : "today.countdown.today")
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
            } else {
                Text(timeRemainingString(until: target, from: isShiftUpcoming ? calendar.startOfDay(for: now) : now))
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.bold)
            }
            
            VStack(spacing: 4) {
                Text(rangeText)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                Text(targetDayAndMonth(target))
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }
}



private func currentDayAndMonth(_ now: Date = Date()) -> String {
    let df = DateFormatter()
    df.locale = Locale.current
    df.dateFormat = "d. MMMM"
    return df.string(from: now)
}

private func targetDayAndMonth(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale.current
    df.dateFormat = "dd.MM."
    return df.string(from: date)
}

/// Formats a remaining interval like "2 hours" or " 13 minutes".
private func timeRemainingString(until target: Date, from now: Date = Date()) -> String {
    let interval = max(0, target.timeIntervalSince(now))
    let oneHour: TimeInterval = 60 * 60
    let oneDay: TimeInterval = 24 * oneHour

    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.maximumUnitCount = 1 // ensure only a single unit is shown

    if interval >= oneDay {
        formatter.allowedUnits = [.day]
    } else if interval >= oneHour {
        formatter.allowedUnits = [.hour]
    } else {
        formatter.allowedUnits = [.minute]
    }

    return formatter.string(from: interval) ?? "0m"
}

extension Collection where Element == Shift {
    /// Returns an ongoing planned shift at `now` if any.
    func ongoingShift(at now: Date = Date()) -> Shift? {
        return self
            .filter { $0.kind == .planned && $0.start <= now && now < $0.end }
            .first
    }

    /// Returns the next planned shift strictly after `now`.
    func nextPlannedShift(after now: Date = Date()) -> Shift? {
        self
            .filter { $0.kind == .planned && $0.start > now }
            .min(by: { $0.start < $1.start })
    }
}

#Preview {
    ContentView()
}
