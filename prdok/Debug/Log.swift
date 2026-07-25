//
//  Log.swift
//  prdok
//
//  Created by David Horňák on 29.10.2025.
//
//  Logging conventions for the shift/open-days stack, so the console reads
//  consistently and can be filtered per area in Console.app:
//
//    Categories  — "Shifts", "FreeShifts", "OpenDays" (all under the app's subsystem).
//    Prefix      — every message starts with the layer, e.g. `[ShiftRepo]`.
//    Direction   — `→` a request leaving the app, `←` a response coming back.
//    Cache verbs — HIT / MISS / STALE / FORCE / SAVE, always with the month key.
//    Levels      — .notice for rare+significant (force refresh, cache cleared),
//                  .info for normal flow (requests, cache decisions, counts),
//                  .debug for detail, .error for failures.
//
//  Note: `Logger` redacts interpolated strings by default, so every string value we
//  actually want to read (month keys, akce names, errors) is marked `privacy: .public`.
//  None of it is sensitive — credentials are never logged.
//

import os
import Foundation

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "io.tafdev.prdok"

    static let shifts = Logger(subsystem: subsystem, category: "Shifts")
    static let freeShifts = Logger(subsystem: subsystem, category: "FreeShifts")
    static let openDays = Logger(subsystem: subsystem, category: "OpenDays")
    static let profile = Logger(subsystem: subsystem, category: "Profile")

    // MARK: - Formatting helpers

    /// Elapsed milliseconds since `start`. Returned as `Int` so it interpolates
    /// without needing an explicit privacy qualifier.
    static func ms(since start: ContinuousClock.Instant) -> Int {
        let components = start.duration(to: .now).components
        return Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }

    /// Compact cache age: `"42s"`, `"13m"`, `"3h 20m"`, `"2d 4h"`.
    static func age(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval.rounded()))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total % 60)s"
    }

    /// `"2026-07"` — the month key used throughout the cache logs.
    static func month(_ year: Int, _ month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }
}
