//
//  FreeShiftsListView.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  "Handlování směn": the open shifts anyone can pick up, under the statistics in CalendarView.
//  One row per day on a shared time axis; tapping a day opens who is on shift then.
//  Data comes from`FreeShiftService`. Read-only; refreshed by the calendar's refresh button, never on its own.
//

import SwiftUI
import Combine
import os

@MainActor
final class FreeShiftsViewModel: ObservableObject {
    @Published var shifts: [FreeShift] = []
    @Published var isLoading = false
    @Published var error: String?

    private var hasLoaded = false

    /// Loads free shifts once per view lifetime. Free shifts change over time, so the
    /// calendar's refresh button (`force: true`) re-fetches.
    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        isLoading = true
        error = nil
        do {
            shifts = try await FreeShiftService.fetchFreeShifts()
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
            Log.freeShifts.error("[FreeShiftsVM] load failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

struct FreeShiftsListView: View {
    @ObservedObject var vm: FreeShiftsViewModel
    /// Called with the tapped day's date; the parent opens who is on shift that day.
    var onOpenDay: (Date) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.freeShifts.title")
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await vm.load() }
    }

    @ViewBuilder
    private var content : some View {
        if vm.isLoading && vm.shifts.isEmpty {
            centered { ProgressView() }
        } else if vm.shifts.isEmpty, vm.error != nil {
            centered { note("today.freeShifts.error") }
        } else if vm.shifts.isEmpty {
            centered { note("today.freeShifts.empty") }
        } else {
            ShiftDayTimeline(entries: vm.shifts.map(\.timelineEntry), background: .cpBackgroundSecondary, onOpenDay: onOpenDay)
        }
    }

    private func centered<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func note(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(Color.cpForegroundSecondary)
    }
}

private extension FreeShift {
    var timelineEntry: ShiftTimelineEntry {
        ShiftTimelineEntry(start: start, end: end, role: role, timeRangeString: timeRangeString)
    }
}

// MARK: - Previews

private func previewShift(_ id: Int, day: Int, from: Int, to: Int, role: ShiftRole = .regular) -> FreeShift {
    let cal = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: from))!
    let end = to > from
        ? cal.date(bySettingHour: to, minute: 0, second: 0, of: start)!
        : cal.date(from: DateComponents(year: 2026, month: 9, day: day + 1, hour: to))!
    return FreeShift(id: id, start: start, end: end, role: role)
}

#Preview {
    ScrollView {
        ShiftDayTimeline(
            entries: [
                previewShift(1, day: 11, from: 9, to: 13),
                // Two pairs overlapping: two lanes.
                previewShift(2, day: 17, from: 7, to: 8),
                previewShift(3, day: 17, from: 7, to: 11, role: .barista),
                previewShift(4, day: 17, from: 16, to: 0),
                previewShift(5, day: 17, from: 17, to: 0),
                previewShift(6, day: 20, from: 8, to: 11, role: .manager),
                // Three at once between 13 and 14: the row grows a third lane.
                previewShift(7, day: 21, from: 10, to: 17),
                previewShift(8, day: 21, from: 11, to: 14),
                previewShift(9, day: 21, from: 13, to: 14),
                // Touching in one lane, then the portal's 24:00-25:00.
                previewShift(10, day: 25, from: 10, to: 16),
                previewShift(11, day: 25, from: 16, to: 18),
                previewShift(12, day: 25, from: 0, to: 1),
            ].map(\.timelineEntry),
            background: .cpBackgroundSecondary,
            onOpenDay: { _ in }
        )
        .padding()
    }
    .background(Color.cpBackgroundSecondary)
}
