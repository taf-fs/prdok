//
//  UpcomingPlannedShiftsListView.swift
//  prdok
//
//  Personal upcoming *planned* shifts, shown under the timer in TodayView. Unlike the
//  free-shifts list this does no networking of its own — it renders the planned shifts
//  already loaded into `TodayViewModel` (via `ShiftRepository`).
//

import SwiftUI

struct UpcomingShiftsListView: View {
    /// All shifts already loaded by the parent; filtered to upcoming planned ones here.
    let shifts: [Shift]

    /// Bottom safe-area inset (tab bar height) from the parent. The list extends behind the
    /// transparent tab bar, and this is added as bottom scroll padding so the last row can
    /// still be scrolled clear of the bar instead of being pinned behind it.
    var bottomInset: CGFloat = 0

    private var upcoming: [Shift] {
        let now = Date()
        return shifts
            .filter { $0.kind == .planned && $0.start > now }
            .sorted { $0.start < $1.start }
    }

    /// Same green the calendar uses for planned shifts.
    private let barColor = Color(red: 76/255, green: 196/255, blue: 23/255, opacity: 0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.plannedShifts.title")
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)

            content
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cpBackgroundSecondary)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        if upcoming.isEmpty {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("today.noUpcomingShifts")
                        .font(.footnote)
                        .foregroundStyle(Color.cpForegroundSecondary)
                    Spacer()
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(upcoming) { shift in
                        UpcomingShiftRow(
                            title: UpcomingShiftRow.dayLabel(shift.start),
                            roleLabel: nil,
                            timeText: shift.timeRangeString,
                            interval: ShiftInterval(id: shift.id, start: shift.start, end: shift.end),
                            color: barColor
                        )
                    }
                }
                .padding(.bottom, 8 + bottomInset)
            }
        }
    }

}

struct UpcomingShiftRow: View {
    /// Neither `Shift` nor `FreeShift` carries a server-provided day label, so both
    /// lists format one here, using `.current`
    static func dayLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEE d.M."
        return df.string(from: date)
    }

    let title: String
    // TODO: resolve shift roles from the JSON response
    /// as of writing this, the upcoming planned shifts, i.e. shifts that are fetched from `ShiftRepository` don't have a role, since the docs for the JSON responses are sparse,
    /// so the `Shift` struct doesn't have a role property but the shifts scraped from the web for `FreeShift` do have a role.
    let roleLabel: LocalizedStringKey?
    let timeText: String
    let interval: ShiftInterval
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.subheadline, design: .serif))
                    .fontWeight(.semibold)

                if let roleLabel {
                    Text(roleLabel)
                        .font(.system(.caption2))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.cpForegroundSecondary)
                }

                Spacer(minLength: 8)

                Text(timeText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.cpForegroundPrimary)
            }

            ShiftIndicatorView(
                intervals: [interval],
                color: color,
                height: 6,
                showsTimeLabel: false,
                cornerRadius: 3,
                showsEmptyPlaceholder: false
            )
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cpBackgroundPrimary)
        }
    }
}
