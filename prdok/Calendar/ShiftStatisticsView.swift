//
//  ShiftStatisticsView.swift
//  prdok
//
//  Created by David Horňák on 02.03.2026.
//

import SwiftUI

// TODO: get the amount of closing shifts from the API (open days now come from `otevrene_dny`)
struct ShiftStatisticsView: View {
    let shifts: [Shift]
    let displayedMonth: Date
    /// Days the provoz is actually open this month, from the `otevrene_dny` akce.
    /// `nil` while loading or if the endpoint failed — we then fall back to the
    /// calendar's day count, which is what this view used before the API existed.
    var openDays: Int? = nil

    private var offeredShifts: [Shift] {
        shifts.filter { $0.kind == .offered }
    }
    
    private var actualShifts: [Shift] {
        shifts.filter { $0.kind == .actual }
    }
    
    private var plannedShifts: [Shift] {
        shifts.filter { $0.kind == .planned }
    }
    
    private var monthCoefficient: Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)
        let days = openDays ?? range?.count ?? 30
        return Double(days) / 30.0
    }
    
    private var totalOfferedHours: Int {
        offeredShifts.reduce(0) { total, shift in
            let duration = shift.end.timeIntervalSince(shift.start)
            let hours = Int(duration / 3600)
            return total + hours
        }
    }
    
    private var totalActualHours: Int {
        actualShifts.reduce(0) { total, shift in
            let duration = shift.end.timeIntervalSince(shift.start)
            let hours = Int(duration / 3600)
            return total + hours
        }
    }
    
    private var weekendOfferedHours: Int {
        let calendar = Calendar.current
        return offeredShifts.reduce(0) { total, shift in
            let weekday = calendar.component(.weekday, from: shift.start)
            // weekday: 1 = Sunday, 7 = Saturday
            let isWeekend = weekday == 1 || weekday == 7
            
            if isWeekend {
                let duration = shift.end.timeIntervalSince(shift.start)
                let hours = Int(duration / 3600)
                return total + hours
            }
            return total
        }
    }
    
    private var offeredClosingShiftsCount: Int {
        offeredShifts.filter { isClosingShift($0) }.count
    }
    
    private var actualClosingShiftsCount: Int {
        actualShifts.filter { isClosingShift($0) }.count
    }
    
    private var plannedClosingShiftsCount: Int {
        plannedShifts.filter { isClosingShift($0) }.count
    }
    
    private var actualShiftsCount: Int {
        actualShifts.count
    }
    
    // MARK: - Requirements
    
    private var requirementClosingShifts: (offered: (current: Int, required: Int, met: Bool), actual: (current: Int, required: Int, met: Bool)) {
        let offeredRequired = Int(round(monthCoefficient * 12))
        let actualRequired = Int(round(monthCoefficient * 4))
        
        let offered = (offeredClosingShiftsCount, offeredRequired, offeredClosingShiftsCount >= offeredRequired)
        let actual = (actualClosingShiftsCount, actualRequired, actualClosingShiftsCount >= actualRequired)
        
        return (offered, actual)
    }
    
    private var requirementWeekendOfferedHours: (current: Int, required: Int, met: Bool) {
        let required = Int(round(monthCoefficient * 18))
        return (weekendOfferedHours, required, weekendOfferedHours >= required)
    }
    
    private var requirementTotalHours: (offered: (current: Int, required: Int, met: Bool), actual: (current: Int, required: Int, met: Bool)) {
        let offeredRequired = Int(round(monthCoefficient * 100))
        let actualRequired = Int(round(monthCoefficient * 72))
        
        let offered = (totalOfferedHours, offeredRequired, totalOfferedHours >= offeredRequired)
        let actual = (totalActualHours, actualRequired, totalActualHours >= actualRequired)
        
        return (offered, actual)
    }
    
    private func isClosingShift(_ shift: Shift) -> Bool {
        let calendar = Calendar.current
        let endHour = calendar.component(.hour, from: shift.end)
        let startWeekday = calendar.component(.weekday, from: shift.start)
        
        // weekday: 1 = Sunday, 7 = Saturday
        let isWeekendShift = startWeekday == 1 || startWeekday == 7
        
        if isWeekendShift {
            // Weekend: closing if ends at 23:00 or later (23, 0 for midnight/past midnight)
            return endHour >= 23 || endHour < 6 // includes midnight-6am as "late night"
        } else {
            // Weekday: closing if ends at 1:00 or later (but typically before morning)
            return endHour >= 1 && endHour < 6 // 1am-5am range
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Weekend hours requirement (single)
            RequirementRow(
                label: "Weekend hours",
                requirement: requirementWeekendOfferedHours
            )
            
            // Closing shifts requirement (OR)
            OrRequirementRow(
                label: "Closing shifts",
                offered: requirementClosingShifts.offered,
                actual: requirementClosingShifts.actual,
                plannedCount: plannedClosingShiftsCount
            )
            
            // Total hours requirement (OR)
            OrRequirementRow(
                label: "Total",
                offered: requirementTotalHours.offered,
                actual: requirementTotalHours.actual
            )
        }
        .padding(.vertical, 16)
    }
}

private struct RequirementRow: View {
    let label: LocalizedStringKey
    let requirement: (current: Int, required: Int, met: Bool)
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(label)
                .font(.system(.body, design: .serif))
                .foregroundStyle(requirement.met ? Color.green : Color.cpForegroundSecondary)
            
            
            Spacer()
            
            Text(verbatim: "\(requirement.current)/\(requirement.required)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.regular)
                .foregroundStyle(requirement.met ? Color.green : Color.cpForegroundPrimary)
            Text("off.")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.regular)
                .foregroundStyle(Color.cpForegroundPrimary)
        }
    }
}

private struct OrRequirementRow: View {
    let label: LocalizedStringKey
    let offered: (current: Int, required: Int, met: Bool)
    let actual: (current: Int, required: Int, met: Bool)
    var plannedCount: Int? = nil
    
    private var isRequirementMet: Bool {
        offered.met || actual.met
    }
    
    var body: some View {
        HStack {
            HStack(alignment: .bottom, spacing: 4) {
                Text(label)
                    .minimumScaleFactor(0.5)  // allows text to scale down to 50% of font size
                    .lineLimit(1)
                    .font(.system(.body, design: .serif))
                    .fontWeight(.regular)
                    .foregroundStyle(isRequirementMet ? Color.green : Color.cpForegroundSecondary)
                
                if let plannedCount {
                    Text("(\(plannedCount) planned)")
                        .minimumScaleFactor(0.5)  // allows text to scale down to 50% of font size
                        .lineLimit(1)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.regular)
                        .foregroundStyle(Color.cpForegroundSecondary)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(verbatim: "\(actual.current)/\(actual.required)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(actual.met ? Color.green : Color.cpForegroundPrimary)
                
                Text("done")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundPrimary)
                
                Text("or")
                    .font(.system(.caption, design: .serif))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundSecondary)
                
                Text(verbatim: "\(offered.current)/\(offered.required)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(offered.met ? Color.green : Color.cpForegroundPrimary)
                
                Text("off.")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundPrimary)
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let displayedMonth = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))! // April = 30 days, coef = 1.0
    
    // Create some sample shifts for preview
    let sampleShifts = [
        // Regular offered shift (weekday, ends at 1 AM - closing shift)
        Shift(
            id: 1,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 1))!
        ),
        // Weekend offered shift (Saturday, ends at 16:00 - NOT closing)
        Shift(
            id: 2,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 8))!, // Saturday
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 16))!
        ),
        // Weekend offered shift (Sunday, ends at 23:00 - closing shift)
        Shift(
            id: 3,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 16))!, // Sunday
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 23))!
        ),
        // Actual shift (weekday, ends at 2 AM - closing shift)
        Shift(
            id: 4,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: 2))!
        ),
        // Actual shift (weekday, ends at 12 PM - NOT closing)
        Shift(
            id: 5,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 8))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 12))!
        ),
        // More actual shifts to meet requirements
        Shift(
            id: 6,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 8))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 16))!
        ),
        Shift(
            id: 7,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 16, hour: 8))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 16, hour: 16))!
        )
    ]
    
    return ShiftStatisticsView(shifts: sampleShifts, displayedMonth: displayedMonth)
        .padding(.horizontal, 12)
}
