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
                let result = try await repo.getShifts(for: date)
                await MainActor.run {
                    self.shifts = result
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

func currentDayAndMonth(_ now: Date = Date()) -> String {
    let df = DateFormatter()
    df.locale = Locale.current
    df.dateFormat = "d. MMMM"
    return df.string(from: now)
}

/// Formats a remaining interval like "2 hours" or " 13 minutes".
func timeRemainingString(until target: Date, from now: Date = Date()) -> String {
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

struct TodayView: View {
    @StateObject private var vm = TodayViewModel()
    @State var selectedDate: Date = Date()
    @State private var showWebView = false
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 40) {
                    TopDateBar()

                    Spacer()
                    
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let now = context.date
                        
                        if let current = vm.shifts.ongoingShift(at: now) {
                            ShiftCountdownBlock(
                                contextKey: "today.countdown.shift.currentEnd",
                                target: current.end,
                                rangeText: current.timeRangeString,
                                now: now)
                        } else if let next = vm.shifts.nextPlannedShift(after: now) {
                            ShiftCountdownBlock(
                                contextKey: "today.countdown.shift.nextStart",
                                target: next.start,
                                rangeText: next.timeRangeString,
                                now: now)
                        } else if vm.isLoading {
                            ProgressView("Loading…")
                        } else {
                            Text("No upcoming planned shifts")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        showWebView = true
                    } label: {
                        Text("shiftsListWebView.presentView.button")
                            .font(.system(.caption))
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
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .frame(height: proxy.size.height * 0.6, alignment: .top)
                .frame(maxWidth: .infinity)
                .background(
                    Color.yellow.opacity(0.1)
                        .ignoresSafeArea(edges: .top)
                )
                .sheet(isPresented: $showWebView) {
                    ShiftsListWebView(date: selectedDate)
                }
                if let error = vm.error {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                }

            }
        }
        .task {
            vm.fetch(date: Date())
        }
    }
}

private struct TopDateBar: View {
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
                // go to calendarview
            } label: {
                Image(systemName: "calendar")
                    .font(.system(.title))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ShiftCountdownBlock: View {
    let contextKey: LocalizedStringKey
    let target: Date
    let rangeText: String
    let now: Date

    var body: some View {
        VStack(spacing: 16) {
            Text(contextKey)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
            // If `CountdownText` keeps LocalizedStringKey, keep the interpolation:
            Text("\(timeRemainingString(until: target, from: now))")
                .font(.system(.largeTitle, design: .serif))
                .fontWeight(.bold)
            Text(rangeText)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
        }
    }
}

#Preview {
    let now = Date()
    let weekAfterNow = Calendar.current.date(byAdding: .day, value: 90, to: now)!

    VStack(spacing: 12) {
        HStack {
            Text(currentDayAndMonth())
                .font(.system(.body, design: .monospaced))
        }
        
        ShiftCountdownBlock(
            contextKey: "Další směna je za",
            target: weekAfterNow,
            rangeText: "asdf - adsf ",
            now: now)
    }
    
}
