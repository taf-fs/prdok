//
//  ShiftDayTimeline.swift
//  prdok
//
//  Created by David Horňák on 15.09.2026.
//
//  One row per day on a shared 07:00 to 01:00 axis, with each shift as a bar and overlapping
//  shifts spread over lanes. Tapping a day hands its date back to the parent. Used by the
//  free shifts in CalendarView and the upcoming planned shifts in TodayView.
//

import SwiftUI

/// One shift as the timeline needs it: when, an optional letter inside the bar, and what
/// VoiceOver reads for it.
struct ShiftTimelineEntry {
    let start: Date
    let end: Date
    var letter: String? = nil
    /// The bars show no times, so VoiceOver gets them (and anything `letter` stands for) spelled out.
    let accessibilityText: String
}

extension ShiftTimelineEntry {
    /// A shift tagged with its role: the letter goes in the bar, the spelled-out role to VoiceOver.
    init(start: Date, end: Date, role: ShiftRole, timeRangeString: String) {
        self.init(
            start: start,
            end: end,
            letter: role.letter,
            accessibilityText: [timeRangeString, role.label].compactMap { $0 }.joined(separator: " ")
        )
    }
}

private extension ShiftRole {
    /// The portal's own `typ` marker, shown inside the bar. The screen reader gets `label` instead.
    var letter: String? {
        switch self {
        case .regular: return nil
        case .manager: return "v"
        case .barista: return "b"
        }
    }

    /// Localized label for the screen reader. Regular shifts get none.
    var label: String? {
        switch self {
        case .regular: return nil
        case .manager: return String(localized: "shift.role.manager")
        case .barista: return String(localized: "shift.role.barista")
        }
    }
}

/// Axis and day rows together, for a parent that scrolls the whole thing.
struct ShiftDayTimeline: View {
    let entries: [ShiftTimelineEntry]
    /// What the timeline sits on. The bars' see-through green is laid over it to come out opaque.
    var background: Color = .cpBackgroundPrimary
    let onOpenDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShiftTimelineAxis()
            ShiftDayTimelineRows(entries: entries, background: background, onOpenDay: onOpenDay)
        }
    }
}

// MARK: - Metrics

/// The axis is `ShiftTimelineLayout`'s 07:00 to 01:00, where every shift falls; a tick interval
/// dividing its 18 hours labels both ends.
private enum TimelineMetrics {
    static let axisStartHour = 7
    static let axisEndHour = 25
    static let axisTickHours = 9

    static let dateColumnWidth: CGFloat = 60
    static let columnGap: CGFloat = 8

    /// Tall enough to fit the role letter inside.
    static let barHeight: CGFloat = 14
    static let laneGap: CGFloat = 3
    static let trackLineHeight: CGFloat = 2
    static let minBarWidth: CGFloat = barHeight
    static let letterSize: CGFloat = 10
    /// Each bar gives up this much of its length, so two shifts touching in one lane stay two bars.
    static let barEndGap: CGFloat = 2

    /// Same green the calendar uses for planned shifts.
    static let barColor = Color(red: 76/255, green: 196/255, blue: 23/255, opacity: 0.5)
}

// MARK: - Grouping

/// One shift's bar: where it sits on the track, and the letter drawn inside it.
private struct TimelineBar {
    let range: (start: CGFloat, end: CGFloat)
    let letter: String?
}

/// One day of the timeline: its entries, and the same entries as bars spread over lanes.
private struct TimelineDay: Identifiable {
    let date: Date
    let entries: [ShiftTimelineEntry]
    let lanes: [[TimelineBar]]

    var id: Date { date }

    static func group(_ entries: [ShiftTimelineEntry], calendar: Calendar = .current) -> [TimelineDay] {
        let layout = ShiftTimelineLayout(calendar: calendar)
        return Dictionary(grouping: entries) { calendar.startOfDay(for: $0.start) }
            .sorted { $0.key < $1.key }
            .map { date, entries in
                let bars = entries.map {
                    TimelineBar(range: layout.normalizedRange(start: $0.start, end: $0.end), letter: $0.letter)
                }
                return TimelineDay(date: date, entries: entries, lanes: ShiftTimelineLayout.lanes(bars) { $0.range })
            }
    }
}

// MARK: - Axis

/// Hour labels over the tracks, indented past the date column. Separate from the rows so a parent
/// can keep it in place while the rows scroll.
struct ShiftTimelineAxis: View {
    private var hours: [Int] {
        Array(stride(from: TimelineMetrics.axisStartHour,
                     through: TimelineMetrics.axisEndHour,
                     by: TimelineMetrics.axisTickHours))
    }

    var body: some View {
        HStack(spacing: TimelineMetrics.columnGap) {
            Color.clear.frame(width: TimelineMetrics.dateColumnWidth, height: 0)
            AxisLabelsLayout(hours: hours) {
                ForEach(hours, id: \.self) { hour in
                    Text(verbatim: String(format: "%02d", hour % 24))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Hour labels centred on their ticks. An HStack can only put children one after another; a custom
/// `Layout` places each label at its hour's fraction of the width. The first may hang half outside
/// into the empty date column; the last is pulled back so its right edge ends flush with the rows below.
private struct AxisLabelsLayout: Layout {
    let hours: [Int]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let span = CGFloat(TimelineMetrics.axisEndHour - TimelineMetrics.axisStartHour)
        for (index, label) in subviews.enumerated() where hours.indices.contains(index) {
            let size = label.sizeThatFits(.unspecified)
            let fraction = CGFloat(hours[index] - TimelineMetrics.axisStartHour) / span
            let centredX = bounds.minX + bounds.width * fraction - size.width / 2
            label.place(
                at: CGPoint(x: min(centredX, bounds.maxX - size.width), y: bounds.minY),
                proposal: ProposedViewSize(size)
            )
        }
    }
}

// MARK: - Rows

/// The day rows alone, each under a divider. Plain stacks rather than a List or LazyVStack:
/// the parent does the scrolling.
struct ShiftDayTimelineRows: View {
    let entries: [ShiftTimelineEntry]
    var background: Color = .cpBackgroundPrimary
    let onOpenDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(TimelineDay.group(entries)) { day in
                Divider()
                DayRow(day: day, background: background) { onOpenDay(day.date) }
            }
        }
    }
}

private struct DayRow: View {
    let day: TimelineDay
    let background: Color
    let onTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d.M."
        return df
    }()

    private static let spokenDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEE d.M."
        return df
    }()

    /// "PO", "ÚT" / "MO", "TU", the same two letters as the calendar's weekday header.
    private var weekdayLabel: String {
        let index = Calendar.current.component(.weekday, from: day.date) - 1
        let names = DateFormatter().weekdaySymbols ?? []
        guard names.indices.contains(index) else { return "" }
        return String(names[index].prefix(2)).uppercased()
    }

    private var accessibilityText: String {
        let entries = day.entries
            .sorted { $0.start < $1.start }
            .map(\.accessibilityText)
            .joined(separator: ", ")
        return "\(Self.spokenDateFormatter.string(from: day.date)): \(entries)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TimelineMetrics.columnGap) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.dateFormatter.string(from: day.date))
                        .font(.system(.body, design: .serif))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(weekdayLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundSecondary)
                }
                .frame(width: TimelineMetrics.dateColumnWidth, alignment: .leading)

                DayTrack(lanes: day.lanes, background: background)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.cpForegroundPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }
}

/// A thin track line with the day's lanes stacked over it; the row grows by a lane when it needs one.
private struct DayTrack: View {
    let lanes: [[TimelineBar]]
    let background: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.cpForegroundSecondary.opacity(0.2))
                .frame(height: TimelineMetrics.trackLineHeight)

            VStack(spacing: TimelineMetrics.laneGap) {
                ForEach(lanes.indices, id: \.self) { index in
                    Lane(bars: lanes[index], background: background)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Lane: View {
    let bars: [TimelineBar]
    let background: Color

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            ForEach(bars.indices, id: \.self) { index in
                let bar = bars[index]
                let range = bar.range
                let barWidth = min(max(trackWidth * (range.end - range.start) - TimelineMetrics.barEndGap,
                                       TimelineMetrics.minBarWidth),
                                   trackWidth)
                // Keep the bar inside the track when the minimum width pushes it past an edge.
                let barX = min(max(trackWidth * range.start + TimelineMetrics.barEndGap / 2, 0),
                               max(trackWidth - barWidth, 0))
                // The bar colour is see-through, which would let the track line show through the
                // bars lying on it, so it sits on the page background to come out opaque.
                Capsule()
                    .fill(background)
                    .overlay(Capsule().fill(TimelineMetrics.barColor))
                    .overlay {
                        if let letter = bar.letter {
                            Text(verbatim: letter)
                                .font(.system(size: TimelineMetrics.letterSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.cpForegroundPrimary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .frame(width: barWidth, height: geo.size.height)
                    .offset(x: barX)
            }
        }
        .frame(height: TimelineMetrics.barHeight)
    }
}
