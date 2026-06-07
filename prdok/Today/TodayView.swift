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
                    self.shifts.append(contentsOf: currentMonthShifts)
                    self.shifts.append(contentsOf: nextMonthShifts)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct TodayView: View {
    @StateObject private var vm = TodayViewModel()
    @State var selectedDate: Date = Date()
    @State private var showWebView = false
    @Binding var selectedTab: ContentTab
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 20) {
                ZStack {
                    VStack(spacing: 0) {
                        TopDateBar(selectedTab: $selectedTab)
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
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
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            
                            Button {
                                showWebView = true
                            } label: {
                                Text("shiftsListWebView.presentView.button")
                                    .font(.system(.footnote))
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 40)
                                    .foregroundStyle(.background)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.primary)
                                            .tint(.primary)
                                    }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .frame(height: proxy.size.height * 0.6, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.accentColor.opacity(0.1)
                            .ignoresSafeArea(edges: .top)
                    )
                    .sheet(isPresented: $showWebView) {
                        if vm.shifts.ongoingShift() != nil {
                            ShiftsListWebView(date: Date())
                        } else if let nextPlannedShift = vm.shifts.nextPlannedShift() {
                            ShiftsListWebView(date: nextPlannedShift.start)
                        } else {
                            ShiftsListWebView(date: Date())
                        }
                    }
                    if let error = vm.error {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                    }
                }
                
                SimplePauseTimerView()
                    .padding(.horizontal, 16)
                
//                Text("Tvoje další směny")
//                    .font(.system(.headline, design: .serif))
//                    .fontWeight(.semibold)
                
                Spacer()
            }
        }
        .task {
            vm.fetch(date: Date())
        }
    }
}

private struct TopDateBar: View {
    @Binding var selectedTab: ContentTab
    
    var body: some View {
        HStack {
            Button {
                // TODO: profileview
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
            
            Button {
                selectedTab = .calendar
            } label: {
                Image(systemName: "calendar")
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
