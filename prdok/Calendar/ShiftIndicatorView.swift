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

struct ShiftIndicatorView: View {
    let title: LocalizedStringKey
    let shifts: [Shift]
    let color: Color
    
    private let layout = ShiftTimelineLayout()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                // "Změnit" button can go here later
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
                
                if shifts.isEmpty {
                    Text("–")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    // All pills share the same geometry / timeline
                    GeometryReader { geo in
                        ForEach(shifts) { shift in
                            ShiftIndicatorPillView(
                                shift: shift,
                                layout: layout,
                                color: color
                            )
                        }
                    }
                }
            }
            .frame(height: 52)
        }
    }
}

struct ShiftIndicatorPillView: View {
    let shift: Shift
    let layout: ShiftTimelineLayout
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let startNorm = layout.normalizedStartPosition(for: shift.start)
            let endNorm   = layout.normalizedEndPosition(for: shift.end)
            
            let totalWidth = geo.size.width
            let pillX = startNorm * totalWidth
            let pillWidth = max((endNorm - startNorm) * totalWidth, 40)
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                .frame(width: pillWidth, height: geo.size.height)
                .position(
                    x: pillX + pillWidth / 2,
                    y: geo.size.height / 2
                )
            
            Text(shift.timeRangeString)
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

struct ShiftIndicatorView_Previews: PreviewProvider {
    // Helper data for previews – defined outside the ViewBuilder
    private static let cal: Calendar = Calendar(identifier: .gregorian)
    private static let base: Date = cal.startOfDay(for: Date())
    
    private static func at(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: base)!
    }
    
    private static let exampleShifts0: [Shift] = [
        Shift(kind: .offered, start: at(7), end: at(23))]
    
    private static let exampleShifts: [Shift] = [
        Shift(kind: .offered, start: at(7), end: at(11)),        // flush left
        Shift(kind: .offered, start: at(16),    end: at(17,40)),    // middle
        Shift(kind: .offered, start: at(17,59),    end: at(18,40)),         // to 01:00
        Shift(kind: .offered, start: at(20),    end: at(3))          // after 1:00, clamped
    ]
    
    static var previews: some View {
        VStack(spacing: 24) {
            ShiftIndicatorView(
                title: "Zadaná možnost",
                shifts: exampleShifts0,
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
            ShiftIndicatorView(
                title: "Více možností",
                shifts: exampleShifts,
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
            ShiftIndicatorView(
                title: "Bez směny",
                shifts: [],
                color: Color(red: 102/255, green: 1, blue: 51/255)
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
