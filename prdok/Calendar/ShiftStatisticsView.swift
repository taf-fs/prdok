//
//  ShiftStatisticsView.swift
//  prdok
//
//  Created by David Horňák on 02.03.2026.
//
//

import SwiftUI

struct ShiftStatisticsView: View {
    let shifts: [Shift]
    let displayedMonth: Date
    /// Open days this month, from `otevrene_dny`. Only scales anything when `bonus` is
    /// nil; `nil` itself falls back again, to the calendar's day count.
    var openDays: Int? = nil
    /// The server's scoring of the six conditions, from `mzdastruktura`. `nil` while
    /// loading or when the fetch failed.
    var bonus: MonthBonus? = nil

    /// Starts closed: the header answers the only question most months raise, and the
    /// calendar keeps the screen.
    @State private var isExpanded = false

    /// False while loading, so the card only turns green once the bonus is known earned.
    private var earned: Bool { bonus?.earned ?? false }

    private var offeredShifts: [Shift] {
        shifts.filter { $0.kind == .offered }
    }

    private var plannedShifts: [Shift] {
        shifts.filter { $0.kind == .planned }
    }

    /// Scales a requirement stated for a 30-day month down to the days the provoz is
    /// open. Reverse-engineered, and only ever reached when `bonus` is nil — the payload
    /// states the very same limits, `round(openDays / 30 × base)`.
    private var monthCoefficient: Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)
        let days = openDays ?? range?.count ?? 30
        return Double(days) / 30.0
    }

    /// Sums the durations first and only rounds the total. Rounding each shift
    /// down on its own lost up to an hour per shift — attendance is punched at
    /// times like 16:01–24:58, so a 9 hour shift used to count as 8.
    private func totalHours(of shifts: [Shift]) -> Int {
        let duration = shifts.reduce(0.0) { total, shift in
            total + shift.end.timeIntervalSince(shift.start)
        }
        return Int((duration / 3600).rounded())
    }

    private var totalOfferedHours: Int {
        totalHours(of: offeredShifts)
    }

    private var weekendOfferedHours: Int {
        let calendar = Calendar.current
        return offeredShifts.reduce(0) { total, shift in
            let weekday = calendar.component(.weekday, from: shift.start)
            // weekday: 1 = Sunday, 7 = Saturday
            guard weekday == 1 || weekday == 7 else { return total }

            // Only the 9:00–23:00 part of the shift counts; a shift running past
            // midnight is clamped to 23:00 like any other late end.
            let endsNextDay = !calendar.isDate(shift.start, inSameDayAs: shift.end)
            let startHour = max(calendar.component(.hour, from: shift.start), 9)
            let endHour = endsNextDay ? 23 : min(calendar.component(.hour, from: shift.end), 23)

            return total + max(0, endHour - startHour)
        }
    }

    private var offeredClosingShiftsCount: Int {
        offeredShifts.filter { isClosingShift($0) }.count
    }

    private var plannedClosingShiftsCount: Int {
        plannedShifts.filter { isClosingShift($0) }.count
    }

    // MARK: - Conditions
    //
    // Each row takes its numbers, its limit and its colour from one source at a time:
    // the payload, or the local math when there is none. The worked sides have no local
    // version on purpose — a confident `0` where payroll counted 2 is worse than a dash.

    private var requirementWeekendOfferedHours: ConditionSide {
        if let weekend = bonus?.weekendHours {
            return ConditionSide(weekend)
        }
        let required = Int(round(monthCoefficient * 18))
        return ConditionSide(current: weekendOfferedHours, required: required, met: weekendOfferedHours >= required)
    }

    private var requirementClosingShifts: (offered: ConditionSide, worked: ConditionSide?, met: Bool) {
        if let closing = bonus?.closingShifts {
            return (ConditionSide(closing.offered), ConditionSide(closing.worked), closing.met)
        }
        let required = Int(round(monthCoefficient * 12))
        let offered = ConditionSide(current: offeredClosingShiftsCount, required: required, met: offeredClosingShiftsCount >= required)
        return (offered, nil, offered.met)
    }

    private var requirementTotalHours: (offered: ConditionSide, worked: ConditionSide?, met: Bool) {
        if let hours = bonus?.hours {
            return (ConditionSide(hours.offered), ConditionSide(hours.worked), hours.met)
        }
        let required = Int(round(monthCoefficient * 100))
        let offered = ConditionSide(current: totalOfferedHours, required: required, met: totalOfferedHours >= required)
        return (offered, nil, offered.met)
    }

    /// `(do 16. 2.)` — the day availability had to be entered by.
    private var deadlineNote: LocalizedStringKey? {
        guard let deadline = bonus?.earlyOffersDeadline else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        // Let the locale order the parts: "16 Feb" in English, "16. úno" in Czech.
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "dMMM", options: 0, locale: .current)
        return LocalizedStringKey("shiftStats.deadlineInline\(formatter.string(from: deadline))")
    }

    /// `(+barman)` — the only month-specific thing the server says about competencies.
    private var competencyNote: LocalizedStringKey? {
        guard let gained = bonus?.competencyGained else { return nil }
        return LocalizedStringKey("shiftStats.newCompetencyInline\(gained)")
    }

    /// A shift that closes the provoz: from 23:00 on a weekend, from 01:00 on a weekday.
    private func isClosingShift(_ shift: Shift) -> Bool {
        let calendar = Calendar.current
        let endHour = calendar.component(.hour, from: shift.end)
        let startWeekday = calendar.component(.weekday, from: shift.start)

        // weekday: 1 = Sunday, 7 = Saturday
        let isWeekendShift = startWeekday == 1 || startWeekday == 7

        if isWeekendShift {
            return endHour >= 23 || endHour < 6
        } else {
            return endHour >= 1 && endHour < 6
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            BonusHeader(bonus: bonus, isExpanded: $isExpanded)

            if isExpanded {
                conditions
            }
        }
        // The tint sits on top of the elevated colour rather than replacing it, which
        // keeps the card readable in both themes.
        .padding(16)
        .background(earned ? Color.green.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
        .background(Color.cpBackgroundElevated, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var conditions: some View {
        Group {
            ConditionRow(
                label: "shiftStats.weekendHours",
                value: .fraction(requirementWeekendOfferedHours),
                suffix: "shiftStats.suffix.offered",
                met: requirementWeekendOfferedHours.met
            )

            EitherConditionRow(
                label: "shiftStats.closingShifts",
                offered: requirementClosingShifts.offered,
                worked: requirementClosingShifts.worked,
                met: requirementClosingShifts.met,
                plannedCount: plannedClosingShiftsCount
            )

            EitherConditionRow(
                label: "shiftStats.totalHours",
                offered: requirementTotalHours.offered,
                worked: requirementTotalHours.worked,
                met: requirementTotalHours.met
            )

            // A yes/no, granted automatically in months with no meeting — `note` says why.
            ConditionRow(
                label: "shiftStats.meeting",
                note: bonus?.meetingNote,
                value: bonus.map { .mark($0.meeting.met) } ?? .unknown,
                met: bonus?.meeting.met ?? false
            )

            ConditionRow(
                label: "shiftStats.earlyOffers",
                inlineNote: deadlineNote,
                value: bonus.map { .fraction(ConditionSide($0.earlyOffers)) } ?? .unknown,
                suffix: "shiftStats.suffix.hours",
                met: bonus?.earlyOffers.met ?? false
            )

            // A count, not a fraction: the payload carries no threshold for this one.
            ConditionRow(
                label: "shiftStats.competencies",
                inlineNote: competencyNote,
                value: bonus?.competencies.value.map { .count($0) } ?? .unknown,
                suffix: "shiftStats.suffix.competencies",
                met: bonus?.competencies.met ?? false
            )
        }
        // As one block, not row by row: the calendar above is already moving.
        .transition(.opacity)
    }
}

// MARK: - Row parts

/// Shown instead of a number the server didn't send. One glyph, one place.
private let unknownValue = "-"

/// One side of a condition: what the employee has, what it takes, and whether that side
/// carries the condition on its own.
struct ConditionSide: Equatable {
    let current: Int
    let required: Int
    let met: Bool

    init(current: Int, required: Int, met: Bool) {
        self.current = current
        self.required = required
        self.met = met
    }

    /// A side as the server stated it. Its `met` only colours this number — the row's
    /// verdict is the condition's own flag, which can differ.
    init(_ condition: BonusCondition) {
        self.current = condition.value ?? 0
        self.required = condition.required ?? 0
        self.met = condition.met
    }
}

/// What a condition prints on its right-hand side.
private enum ConditionValue {
    /// `28/19` — what the employee has against what it takes.
    case fraction(ConditionSide)
    /// `6` — a number the server scores without telling us the threshold.
    case count(Int)
    /// A condition with no numbers at all: the employee meeting.
    case mark(Bool)
    /// Nothing to show, and nothing worth guessing.
    case unknown
}

/// A condition on one line: its name on the left, its number on the right.
private struct ConditionRow: View {
    let label: LocalizedStringKey
    /// A short note on the label line — the deadline, the competency gained this month.
    var inlineNote: LocalizedStringKey? = nil
    /// The server's own explanation, on a line of its own: it is a full sentence, and
    /// the label line is one line that scales itself down.
    var note: String? = nil
    let value: ConditionValue
    var suffix: LocalizedStringKey? = nil
    /// The condition's verdict, as the server scored it.
    let met: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 4) {
                ConditionLabel(label: label, inlineNote: inlineNote, met: met)

                Spacer()

                HStack(alignment: .bottom, spacing: 4) {
                    ConditionValueText(value: value, met: met)

                    if let suffix {
                        Text(suffix)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.regular)
                            .foregroundStyle(Color.cpForegroundPrimary)
                    }
                }
                // The numbers keep their width; the label is what gives way.
                .layoutPriority(1)
            }

            if let note, !note.isEmpty {
                Text(verbatim: note)
                    .font(.system(.caption, design: .serif))
                    .lineLimit(2)
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
        }
    }
}

/// A condition the server scores once but states twice: what was offered, and what was
/// actually worked. Either side can carry it, so the label's colour comes from the
/// condition itself rather than from the two numbers.
private struct EitherConditionRow: View {
    let label: LocalizedStringKey
    let offered: ConditionSide
    /// `nil` without the payload — worked numbers are payroll's count, and the shift
    /// list is not a usable substitute.
    let worked: ConditionSide?
    let met: Bool
    var plannedCount: Int? = nil

    var body: some View {
        HStack {
            ConditionLabel(
                label: label,
                inlineNote: plannedCount.map { LocalizedStringKey("shiftStats.plannedInline\($0)") },
                met: met
            )

            Spacer()

            HStack(alignment: .bottom, spacing: 4) {
                ConditionValueText(value: worked.map { .fraction($0) } ?? .unknown, met: worked?.met ?? false)

                Text("shiftStats.suffix.actual")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundPrimary)

                Text("shiftStats.or")
                    .font(.system(.caption2, design: .serif))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundSecondary)

                ConditionValueText(value: .fraction(offered), met: offered.met)

                Text("shiftStats.suffix.offered")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundPrimary)
            }
            // Two fractions and three units — the widest thing in the block, and it
            // never truncates. The label scales down around it.
            .layoutPriority(1)
        }
    }
}

/// The condition's name, optionally trailed by a small note.
private struct ConditionLabel: View {
    let label: LocalizedStringKey
    var inlineNote: LocalizedStringKey? = nil
    let met: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(label)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.regular)
                .foregroundStyle(met ? Color.green : Color.cpForegroundSecondary)

            if let inlineNote {
                Text(inlineNote)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.regular)
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
        }
    }
}

/// The number side of every row. A dash is deliberately dimmer than a real value: it
/// says "not known", not "zero".
private struct ConditionValueText: View {
    let value: ConditionValue
    let met: Bool

    var body: some View {
        switch value {
        case .fraction(let side):
            styled(Text(verbatim: "\(side.current)/\(side.required)"), met: side.met)
        case .count(let count):
            styled(Text(verbatim: "\(count)"), met: met)
        case .mark(let isMet):
            styled(Text(isMet ? "shiftStats.mark.met" : "shiftStats.mark.unmet"), met: met)
        case .unknown:
            Text(verbatim: unknownValue)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.regular)
                .foregroundStyle(Color.cpForegroundSecondary)
        }
    }

    private func styled(_ text: Text, met: Bool) -> some View {
        text
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.regular)
            .foregroundStyle(met ? Color.green : Color.cpForegroundPrimary)
    }
}

// MARK: - Header

/// Did the bonus come out, and how close was it — the only part of the block most
/// months need. The whole line turns green exactly when the bonus was earned.
private struct BonusHeader: View {
    let bonus: MonthBonus?
    @Binding var isExpanded: Bool

    private var earned: Bool { bonus?.earned ?? false }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("shiftStats.bonus.title")
                    .font(.system(.body, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(earned ? Color.green : Color.cpForegroundPrimary)

                Spacer()

                if let bonus {
                    Text(verbatim: "\(bonus.score)/\(bonus.maxScore)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(earned ? Color.green : Color.cpForegroundPrimary)
                } else {
                    Text(verbatim: unknownValue)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundSecondary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(.caption, design: .monospaced))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
            .contentShape(Rectangle())  // the whole line is the tap target
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

/// Shifts covering both closing-shift branches and both kinds a month is counted in.
private func previewShifts(in calendar: Calendar) -> [Shift] {
    [
        // offered, weekday, ends 01:00 — closing
        Shift(
            id: 1,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 1))!
        ),
        // offered, Saturday, ends 16:00 — not closing
        Shift(
            id: 2,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 8))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 16))!
        ),
        // offered, Sunday, ends 23:00 — closing
        Shift(
            id: 3,
            kind: .offered,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 23))!
        ),
        // actual, weekday, ends 02:00 — closing
        Shift(
            id: 4,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: 2))!
        ),
        // actual, weekday, ends 12:00 — not closing
        Shift(
            id: 5,
            kind: .actual,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 8))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 12))!
        ),
        // planned, weekday, ends 02:00 — the count in row 2's label note
        Shift(
            id: 6,
            kind: .planned,
            start: calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 16))!,
            end: calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 2))!
        )
    ]
}

/// March 2026 as the server scored it: the meeting was missed, a joker covered it.
private func previewEarnedBonus(in calendar: Calendar) -> MonthBonus {
    MonthBonus(
        score: 5,
        maxScore: 6,
        jokers: 1,
        jokersUsed: 1,
        earned: true,
        bonusCzkPerHour: 20,
        monthState: 1,
        weekendHours: BonusCondition(met: true, value: 28, required: 19),
        closingShifts: BonusEither(
            met: true,
            offered: BonusCondition(met: true, value: 12, required: 12),
            worked: BonusCondition(met: false, value: 2, required: 4)
        ),
        hours: BonusEither(
            met: true,
            offered: BonusCondition(met: true, value: 140, required: 103),
            worked: BonusCondition(met: false, value: 42, required: 74)
        ),
        meeting: BonusCondition(met: false),
        meetingNote: "",
        earlyOffers: BonusCondition(met: true, value: 104, required: 20),
        earlyOffersDeadline: calendar.date(from: DateComponents(year: 2026, month: 2, day: 16)),
        competencies: BonusCondition(met: true, value: 6),
        competencyGained: "barman"
    )
}

/// A month that ended without the bonus, with the holiday note under the meeting row.
private func previewMissedBonus(in calendar: Calendar) -> MonthBonus {
    MonthBonus(
        score: 4,
        maxScore: 6,
        jokers: 1,
        jokersUsed: 0,
        earned: false,
        bonusCzkPerHour: 20,
        monthState: 1,
        weekendHours: BonusCondition(met: false, value: 11, required: 19),
        closingShifts: BonusEither(
            met: false,
            offered: BonusCondition(met: false, value: 7, required: 12),
            worked: BonusCondition(met: true, value: 5, required: 4)
        ),
        hours: BonusEither(
            met: true,
            offered: BonusCondition(met: true, value: 126, required: 103),
            worked: BonusCondition(met: false, value: 44, required: 74)
        ),
        meeting: BonusCondition(met: true),
        meetingNote: "O prázdninách není zaměstnanecká schůze.",
        earlyOffers: BonusCondition(met: false, value: 0, required: 20),
        earlyOffersDeadline: calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)),
        competencies: BonusCondition(met: true, value: 6),
        competencyGained: nil
    )
}

#Preview("Bonus earned") {
    let calendar = Calendar.current
    let displayedMonth = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))! // April = 30 days, coef = 1.0

    return ShiftStatisticsView(
        shifts: previewShifts(in: calendar),
        displayedMonth: displayedMonth,
        bonus: previewEarnedBonus(in: calendar)
    )
    .padding(.horizontal, 12)
}

#Preview("Bonus missed") {
    let calendar = Calendar.current
    let displayedMonth = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

    return ShiftStatisticsView(
        shifts: previewShifts(in: calendar),
        displayedMonth: displayedMonth,
        bonus: previewMissedBonus(in: calendar)
    )
    .padding(.horizontal, 12)
}

#Preview("No pay structure") {
    let calendar = Calendar.current
    let displayedMonth = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

    return ShiftStatisticsView(
        shifts: previewShifts(in: calendar),
        displayedMonth: displayedMonth
    )
    .padding(.horizontal, 12)
}
