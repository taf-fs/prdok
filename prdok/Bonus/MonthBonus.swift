//
//  MonthBonus.swift
//  prdok
//
//  Created by David Horňák on 20.09.2026.
//

import Foundation

/// One side of a condition row, or a whole yes/no condition, as the server scored it.
struct BonusCondition: Codable, Equatable {
    let met: Bool
    /// What the employee has. `nil` when the server states the condition as a plain yes/no.
    var value: Int? = nil
    /// What it takes. `nil` when the server doesn't express the condition as a threshold.
    var required: Int? = nil
}

/// A condition the server scores once but states on two sides: what was offered and
/// what was actually worked. Either side can carry it, hence the single `met` on top —
/// the two sides are numbers to show, not a verdict to recompute.
struct BonusEither: Codable, Equatable {
    let met: Bool
    let offered: BonusCondition
    let worked: BonusCondition
}

struct MonthBonus: Codable, Equatable {
    /// Conditions actually met, out of `maxScore` (6 in every month seen so far).
    let score: Int
    let maxScore: Int
    /// Jokers the employee holds.
    let jokers: Int
    /// Jokers this month cost. 0 when the bonus wasn't earned — the server omits the key then.
    let jokersUsed: Int
    /// Whether the bonus was earned, i.e. `score + jokers >= maxScore`.
    let earned: Bool
    /// What every hour of this month is worth on top, in Kč.
    let bonusCzkPerHour: Int
    /// 1 = finished month, 2 = the current one, 3 = still ahead.
    let monthState: Int

    let weekendHours: BonusCondition
    let closingShifts: BonusEither
    let hours: BonusEither
    let meeting: BonusCondition
    /// Why no meeting was held, when the server explains it (holidays). Empty normally.
    let meetingNote: String
    /// Availability entered before the announced deadline, against what it takes.
    let earlyOffers: BonusCondition
    let earlyOffersDeadline: Date?
    /// Competencies held. No threshold: the server scores this one on its own.
    let competencies: BonusCondition
    /// Competency gained in this month, `nil` when none.
    let competencyGained: String?

    /// True once the month is over and its score can no longer change.
    var isMonthFinished: Bool { monthState == 1 }
}
