//
//  ShiftRepository.swift
//  prdok
//
//  Created by David Horňák on 29.10.2025.
//

import Foundation
import os

struct ShiftRepository {
    let maxCacheAge: TimeInterval

    /// Months (relative to "now") that are allowed to refresh if stale.
    /// Default: previous (-1), current (0), next (+1).
    let refreshableMonthOffsets: Set<Int>

    init(
        maxCacheAge: TimeInterval = 60 * 60 * 24,
        refreshableMonthOffsets: Set<Int> = [-1, 0, 1]
    ) {
        self.maxCacheAge = maxCacheAge
        self.refreshableMonthOffsets = refreshableMonthOffsets
    }

    
    private func year(from date: Date) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: date)
    }
    private func month(from date: Date) -> Int {
        Calendar(identifier: .gregorian).component(.month, from: date)
    }
    
    private func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps)!
    }

    private func monthOffset(from base: Date, to target: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let a = startOfMonth(base)
        let b = startOfMonth(target)
        return cal.dateComponents([.month], from: a, to: b).month ?? 0
    }
    
    // MARK: - Core loading with policy

    /// Loads shifts for a given month `date`, honoring the policy window:
    /// - Months within `refreshableMonthOffsets` (relative to now): refresh if stale (based on `maxCacheAge`).
    /// - Other months: never refresh; use cache if present; if missing, fetch once and cache.
    ///
    /// Set `forceRefresh` to true to bypass the policy and always fetch.
    func getShifts(for date: Date, forceRefresh: Bool = false) async throws -> [Shift] {
        let y = year(from: date)
        let m = month(from: date)
        let mm = String(format: "%02d", m)
        let offset = monthOffset(from: Date(), to: date)

        if forceRefresh {
            Log.shifts.notice("Force refresh: ignoring cache for \(y)-\(mm)")
            let shifts = try await ShiftService.fetchShifts(date: date)
            Log.shifts.info("Fetched \(shifts.count) shifts for \(y)-\(mm); saving cache")
            do {
                try ShiftCache.save(shifts: shifts, year: y, month: m)
                Log.shifts.debug("Saved cache for \(y)-\(mm)")
            } catch {
                Log.shifts.error("Failed to save cache for \(y)-\(mm): \(error.localizedDescription, privacy: .public)")
            }
            return shifts
        }

        // Policy: is this month allowed to refresh if stale?
        if refreshableMonthOffsets.contains(offset) {
            Log.shifts.debug("Policy: \(y)-\(mm) is in refreshable window (offset \(offset)).")
            if let cached = try ShiftCache.load(year: y, month: m),
               !ShiftCache.isStale(cached, maxAge: maxCacheAge) {
                Log.shifts.debug("Cache fresh for \(y)-\(mm); returning cached (\(cached.shifts.count))")
                return cached.shifts
            } else {
                Log.shifts.debug("Cache missing/stale for \(y)-\(mm); fetching from network")
                let shifts = try await ShiftService.fetchShifts(date: date)
                Log.shifts.info("Fetched \(shifts.count) shifts for \(y)-\(mm); saving cache")
                do {
                    try ShiftCache.save(shifts: shifts, year: y, month: m)
                    Log.shifts.debug("Saved cache for \(y)-\(mm)")
                } catch {
                    Log.shifts.error("Failed to save cache for \(y)-\(mm): \(error.localizedDescription, privacy: .public)")
                }
                return shifts
            }
        } else {
            Log.shifts.debug("Policy: \(y)-\(mm) is outside refreshable window (offset \(offset)).")
            // Immutable months: never refresh. Use cache if any; seed once if missing.
            if let cached = try ShiftCache.load(year: y, month: m) {
                Log.shifts.debug("Cache exists for \(y)-\(mm); returning cached (\(cached.shifts.count))")
                return cached.shifts
            } else {
                Log.shifts.debug("Cache missing for \(y)-\(mm); one-time fetch to seed cache")
                let shifts = try await ShiftService.fetchShifts(date: date)
                do {
                    try ShiftCache.save(shifts: shifts, year: y, month: m)
                    Log.shifts.debug("Saved cache for \(y)-\(mm)")
                } catch {
                    Log.shifts.error("Failed to save cache for \(y)-\(mm): \(error.localizedDescription, privacy: .public)")
                }
                return shifts
            }
        }
    }

    
    func refresh(for date: Date) async throws {
        _ = try await getShifts(for: date, forceRefresh: true)
    }

    // MARK: - Cache management
    func clearCache(for date: Date) throws {
        let y = year(from: date)
        let m = month(from: date)
        let mm = String(format: "%02d", m)
        try ShiftCache.purge(year: y, month: m)
        Log.shifts.notice("Cleared cache for \(y)-\(mm)")
    }

    func clearAllCache() throws {
        try ShiftCache.purgeAll()
        Log.shifts.notice("Cleared all cache.")
    }
    // MARK: - Year helpers

    /// Preloads a full year using the policy:
    /// - Mutable window months (prev/current/next relative to now) refresh if stale.
    /// - Other months are fetched only if missing, then cached; otherwise left untouched.
    /// Returns all shifts sorted by start time.
    func preloadYear(_ year: Int) async throws -> [Shift] {
        var all: [Shift] = []
        let cal = Calendar(identifier: .gregorian)

        for month in 1...12 {
            guard let monthDate = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { continue }
            let monthShifts = try await getShifts(for: monthDate)
            all.append(contentsOf: monthShifts)
        }

        return all.sorted(by: { $0.start < $1.start })
    }

    /// Reads whatever is currently cached for the year, no network calls.
    func loadYearFromCache(_ year: Int) throws -> [Shift] {
        var all: [Shift] = []
        for m in 1...12 {
            if let cached = try ShiftCache.load(year: year, month: m) {
                all.append(contentsOf: cached.shifts)
            }
        }
        return all.sorted(by: { $0.start < $1.start })
    }
}
