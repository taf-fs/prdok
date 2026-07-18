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
    
    private func baseHour(for date: Date) -> Double {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    }
    
    /// Start ≤ 7:00 → pinned to 7:00 (flush left)
    func normalizedStartPosition(for date: Date) -> CGFloat {
        var h = baseHour(for: date)
        
        // Anything before or at startHour goes to startHour
        if h <= startHour {
            h = startHour
        }
        // no +24 trick here – we want "7 or earlier" all flush left
        
        // Clamp to [startHour, endHour]
        h = min(max(h, startHour), endHour)
        
        let t = (h - startHour) / totalHours
        return CGFloat(t)
    }
    
    /// End < 7:00 → treated as after midnight (h + 24)
    /// Anything beyond 1:00 (25h) is clamped to 25h (flush right)
    func normalizedEndPosition(for date: Date) -> CGFloat {
        var h = baseHour(for: date)
        
        // If time is before startHour, it's "after midnight" of next day
        if h < startHour {
            h += 24
        }
        
        // Clamp to [startHour, endHour] so >1:00 stays flush right
        h = min(max(h, startHour), endHour)
        
        let t = (h - startHour) / totalHours
        return CGFloat(t)
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
                                showsTimeLabel: showsTimeLabel
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

    var body: some View {
        GeometryReader { geo in
            let startNorm = layout.normalizedStartPosition(for: interval.start)
            let endNorm   = layout.normalizedEndPosition(for: interval.end)

            let totalWidth = geo.size.width
            let pillX = startNorm * totalWidth
            let pillWidth = max((endNorm - startNorm) * totalWidth, 40)
            // Keep the pill a capsule at small heights, but cap roundness on tall bars.
            let pillRadius = min(12, geo.size.height / 2)

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
