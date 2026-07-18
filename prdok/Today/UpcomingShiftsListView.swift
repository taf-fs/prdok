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
                            title: Self.dayLabel(shift.start),
                            timeText: shift.timeRangeString,
                            interval: ShiftInterval(id: shift.id, start: shift.start, end: shift.end),
                            color: barColor
                        )
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    /// `Shift` has no server-provided day label, so format one (e.g. "pondělí 20.7.").
    private static func dayLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEE d.M."
        return df.string(from: date)
    }
}

struct UpcomingShiftRow: View {
    let title: String
    let timeText: String
    let interval: ShiftInterval
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.subheadline, design: .serif))
                    .fontWeight(.semibold)
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
