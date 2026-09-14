//
//  ShiftIndicatorView.swift
//  prdok
//
//  Created by David Horňák on 25.11.2025.
//

import SwiftUI


struct ShiftTimelineLayout {
    let calendar: Calendar
    let startHour: Double   // normally 7
    let endHour: Double     // 25 == 1:00 next day
    
    init(calendar: Calendar = Calendar(identifier: .gregorian),
         startHour: Double = 7,
         endHour: Double = 25) {
        self.calendar = calendar
        self.startHour = startHour
        self.endHour = endHour
    }
    
    private var totalHours: Double { endHour - startHour }

    /// Hours since midnight of `start`'s day. Times past midnight keep counting up
    /// (1:00 the next day == 25), the same way the portal writes them ("do":"25:00:00").
    private func hours(of date: Date, sinceDayOf start: Date) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: start)) / 3600
    }

    /// Clamp to [startHour, endHour] so early starts stay flush left and
    /// anything beyond 1:00 (25h) stays flush right.
    private func normalized(_ hour: Double) -> CGFloat {
        let clamped = min(max(hour, startHour), endHour)
        return CGFloat((clamped - startHour) / totalHours)
    }

    /// Positions both ends of one interval on the same timeline.
    ///
    /// Both ends are measured from the same midnight, so the pill keeps its real
    /// length instead of each end being placed from its wall-clock hour alone.
    /// An interval that also *ends* before `startHour` is a post-midnight one
    /// (the portal's 24:00 – 25:00), so it moves to the far end of the timeline.
    func normalizedRange(start: Date, end: Date) -> (start: CGFloat, end: CGFloat) {
        var startH = hours(of: start, sinceDayOf: start)
        var endH = max(hours(of: end, sinceDayOf: start), startH)

        if endH < startHour {
            startH += 24
            endH += 24
        }

        return (normalized(startH), normalized(endH))
    }

    /// Spreads `ranges` over as few lanes as possible, with no two ranges in a lane overlapping.
    ///
    /// Taken in order of start, each range joins the first lane whose last range has already
    /// ended; only when every lane is still busy does a new one open. Because the earliest start
    /// always goes first, a new lane opens only when that many ranges really run at the same
    /// moment, so the lane count is the smallest possible. Ranges that merely touch share a lane.
    ///
    /// Takes anything that has a range, so the lanes can carry more than positions.
    static func lanes<Item>(_ items: [Item], range: (Item) -> (start: CGFloat, end: CGFloat)) -> [[Item]] {
        var lanes: [[Item]] = []
        let sorted = items.sorted { (range($0).start, range($0).end) < (range($1).start, range($1).end) }
        for item in sorted {
            if let free = lanes.firstIndex(where: { range($0.last!).end <= range(item).start }) {
                lanes[free].append(item)
            } else {
                lanes.append([item])
            }
        }
        return lanes
    }
}

/// A lightweight time interval the indicator can draw. Both `Shift` and `FreeShift`
/// map onto this, so `ShiftIndicatorView` isn't tied to one model.
struct ShiftInterval: Identifiable, Hashable {
    let id: Int
    let start: Date
    let end: Date

    var timeRangeString: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return "\(df.string(from: start)) - \(df.string(from: end))"
    }
}

struct ShiftIndicatorView: View {
    let intervals: [ShiftInterval]
    let color: Color

    /// Overall height of the bar. Defaults to the original 40; pass something small
    /// (e.g. 6) for a thin indicator.
    var height: CGFloat = 40
    /// Whether each pill shows its time range. Turn off for a bare bar.
    var showsTimeLabel: Bool = true
    /// Corner radius of the background track.
    var cornerRadius: CGFloat = 16
    /// Whether to render a "–" placeholder when there are no intervals.
    var showsEmptyPlaceholder: Bool = true

    private let layout = ShiftTimelineLayout()

    /// Convenience for the existing `[Shift]` call sites.
    init(shifts: [Shift],
         color: Color,
         height: CGFloat = 40,
         showsTimeLabel: Bool = true,
         cornerRadius: CGFloat = 16,
         showsEmptyPlaceholder: Bool = true) {
        self.init(intervals: shifts.map { ShiftInterval(id: $0.id, start: $0.start, end: $0.end) },
                  color: color,
                  height: height,
                  showsTimeLabel: showsTimeLabel,
                  cornerRadius: cornerRadius,
                  showsEmptyPlaceholder: showsEmptyPlaceholder)
    }

    init(intervals: [ShiftInterval],
         color: Color,
         height: CGFloat = 40,
         showsTimeLabel: Bool = true,
         cornerRadius: CGFloat = 16,
         showsEmptyPlaceholder: Bool = true) {
        self.intervals = intervals
        self.color = color
        self.height = height
        self.showsTimeLabel = showsTimeLabel
        self.cornerRadius = cornerRadius
        self.showsEmptyPlaceholder = showsEmptyPlaceholder
    }

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cpForegroundSecondary.opacity(0.2))

                if intervals.isEmpty {
                    if showsEmptyPlaceholder {
                        Text(verbatim: "–")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(Color.cpForegroundPrimary)
                    }
                } else {
                    // All pills share the same geometry / timeline
                    GeometryReader { geo in
                        ForEach(intervals) { interval in
                            ShiftIndicatorPillView(
                                interval: interval,
                                layout: layout,
                                color: color,
                                showsTimeLabel: showsTimeLabel,
                                cornerRadius: cornerRadius
                            )
                        }
                    }
                }
            }
            .frame(height: height)
        }
    }
}

struct ShiftIndicatorPillView: View {
    let interval: ShiftInterval
    let layout: ShiftTimelineLayout
    let color: Color
    var showsTimeLabel: Bool = true
    /// Corner radius of the track behind the pill. The pill fills the track's full
    /// height with no inset, so it has to match to sit flush in the rounded corners.
    var cornerRadius: CGFloat = 16

    /// Keeps short shifts wide enough to stay readable.
    private let minPillWidth: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            let range = layout.normalizedRange(start: interval.start, end: interval.end)

            let totalWidth = geo.size.width
            let pillWidth = min(max((range.end - range.start) * totalWidth, minPillWidth), totalWidth)
            // Keep the pill inside the track when the minimum width pushes it past an edge.
            let pillX = min(max(range.start * totalWidth, 0), max(totalWidth - pillWidth, 0))
            // Never round more than the pill's own half-extent, or the corners overlap.
            let pillRadius = min(cornerRadius, min(pillWidth, geo.size.height) / 2)

            RoundedRectangle(cornerRadius: pillRadius, style: .continuous)
                .fill(color)
                .frame(width: pillWidth, height: geo.size.height)
                .position(
                    x: pillX + pillWidth / 2,
                    y: geo.size.height / 2
                )

            if showsTimeLabel {
                Text(interval.timeRangeString)
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(width: pillWidth)
                    .position(
                        x: pillX + pillWidth / 2,
                        y: geo.size.height / 2
                    )
            }
        }
    }
}

struct ShiftIndicatorView_Previews: PreviewProvider {
    // Helper data for previews – defined outside the ViewBuilder
    private static let cal: Calendar = Calendar(identifier: .gregorian)
    private static let base: Date = cal.startOfDay(for: Date())
    
    private static func at(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: base)!
    }
    
    private static let exampleShifts0: [Shift] = [
        Shift(id: 1, kind: .offered, start: at(7), end: at(23))]
    
    private static let exampleShifts: [Shift] = [
        Shift(id: 2, kind: .offered, start: at(7),     end: at(11)),       // flush left
        Shift(id: 3, kind: .offered, start: at(16),    end: at(17,40)),    // middle
        Shift(id: 4, kind: .offered, start: at(17,59), end: at(18,40)),    // to 01:00
        Shift(id: 5, kind: .offered, start: at(20),    end: at(3))         // after 1:00, clamped
    ]

    /// 24:00 – 25:00 as the parser stores it: midnight to 1:00 of the shift's own day.
    private static let exampleShiftsAfterMidnight: [Shift] = [
        Shift(id: 6, kind: .offered, start: at(0), end: at(1))
    ]

    static var previews: some View {
        VStack(spacing: 24) {
            Text("Zadaná možnost")
            ShiftIndicatorView(
                shifts: exampleShifts0,
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
            Text("Více možností")
            ShiftIndicatorView(
                shifts: exampleShifts,
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
            Text("Po půlnoci (24:00 – 25:00)")
            ShiftIndicatorView(
                shifts: exampleShiftsAfterMidnight,
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
            Text("Bez směny")
            ShiftIndicatorView(
                shifts: [],
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
