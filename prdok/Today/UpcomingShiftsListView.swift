//
//  UpcomingPlannedShiftsListView.swift
//  prdok
//
//  Personal upcoming *planned* shifts, shown under the timer in TodayView, in the same day
//  timeline as the free shifts in CalendarView. Unlike the free-shifts list this does no
//  networking of its own — it renders the planned shifts already loaded into `TodayViewModel`
//  (via `ShiftRepository`).
//

import SwiftUI

struct UpcomingShiftsListView: View {
    /// All shifts already loaded by the parent; filtered to upcoming planned ones here.
    let shifts: [Shift]

    /// Bottom safe-area inset (tab bar height) from the parent. The list extends behind the
    /// transparent tab bar, and this is added as bottom scroll padding so the last row can
    /// still be scrolled clear of the bar instead of being pinned behind it.
    var bottomInset: CGFloat = 0

    /// Called with the tapped day's date; the parent opens who is on shift that day.
    var onOpenDay: (Date) -> Void = { _ in }

    private var upcoming: [ShiftTimelineEntry] {
        let now = Date()
        return shifts
            .filter { $0.kind == .planned && $0.start > now }
            .map { ShiftTimelineEntry(start: $0.start, end: $0.end, role: $0.role, timeRangeString: $0.timeRangeString) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.plannedShifts.title")
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        let upcoming = upcoming
        if upcoming.isEmpty {
            Text("today.noUpcomingShifts")
                .font(.footnote)
                .foregroundStyle(Color.cpForegroundSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // The axis stays put while the days scroll under it.
            VStack(spacing: 0) {
                ShiftTimelineAxis()
                ScrollView {
                    ShiftDayTimelineRows(entries: upcoming, background: .cpBackgroundSecondary, onOpenDay: onOpenDay)
                        .padding(.bottom, 8 + bottomInset)
                }
            }
        }
    }
}

#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    func shift(_ id: Int, inDays days: Int, from: Int, hours: Int, role: ShiftRole = .regular) -> Shift {
        let start = cal.date(byAdding: .hour, value: days * 24 + from, to: today)!
        return Shift(id: id, kind: .planned, start: start, end: cal.date(byAdding: .hour, value: hours, to: start)!, role: role)
    }
    return UpcomingShiftsListView(shifts: [
        shift(1, inDays: 1, from: 8, hours: 8),
        shift(2, inDays: 3, from: 16, hours: 9, role: .manager),
        shift(3, inDays: 4, from: 7, hours: 4, role: .barista),
        shift(4, inDays: 4, from: 17, hours: 6),
    ])
    .padding()
    .background(Color.cpBackgroundSecondary)
}
