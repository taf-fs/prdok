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
        let key = Log.month(y, m)
        let offset = monthOffset(from: Date(), to: date)

        if forceRefresh {
            Log.shifts.notice("[ShiftRepo] \(key, privacy: .public) FORCE — bypassing cache")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }

        // Policy: is this month allowed to refresh if stale?
        if refreshableMonthOffsets.contains(offset) {
            Log.shifts.debug("[ShiftRepo] \(key, privacy: .public) policy: refreshable (offset \(offset), max age \(Log.age(self.maxCacheAge), privacy: .public))")

            let cached = try ShiftCache.load(year: y, month: m)
            guard let cached else {
                Log.shifts.info("[ShiftRepo] \(key, privacy: .public) cache MISS — fetching")
                return try await fetchAndCache(date: date, year: y, month: m, key: key)
            }

            let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
            guard !ShiftCache.isStale(cached, maxAge: maxCacheAge) else {
                Log.shifts.info("[ShiftRepo] \(key, privacy: .public) cache STALE (age \(Log.age(cacheAge), privacy: .public) > \(Log.age(self.maxCacheAge), privacy: .public)) — fetching")
                return try await fetchAndCache(date: date, year: y, month: m, key: key)
            }

            Log.shifts.info("[ShiftRepo] \(key, privacy: .public) cache HIT — \(cached.shifts.count) shift(s), age \(Log.age(cacheAge), privacy: .public)")
            return cached.shifts
        } else {
            // Immutable months: never refresh. Use cache if any; seed once if missing.
            Log.shifts.debug("[ShiftRepo] \(key, privacy: .public) policy: immutable (offset \(offset))")

            if let cached = try ShiftCache.load(year: y, month: m) {
                let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
                Log.shifts.info("[ShiftRepo] \(key, privacy: .public) cache HIT (immutable) — \(cached.shifts.count) shift(s), age \(Log.age(cacheAge), privacy: .public)")
                return cached.shifts
            }

            Log.shifts.notice("[ShiftRepo] \(key, privacy: .public) cache MISS (immutable) — one-time fetch to seed")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }
    }

    /// Fetches a month from the network and writes it to the cache. A cache-write
    /// failure is logged but not fatal — the caller still gets the fetched shifts.
    private func fetchAndCache(date: Date, year y: Int, month m: Int, key: String) async throws -> [Shift] {
        let shifts = try await ShiftService.fetchShifts(date: date)
        do {
            try ShiftCache.save(shifts: shifts, year: y, month: m)
            Log.shifts.info("[ShiftRepo] \(key, privacy: .public) SAVE — cached \(shifts.count) shift(s)")
        } catch {
            Log.shifts.error("[ShiftRepo] \(key, privacy: .public) SAVE failed: \(error.localizedDescription, privacy: .public)")
        }
        return shifts
    }

    
    func refresh(for date: Date) async throws {
        _ = try await getShifts(for: date, forceRefresh: true)
    }

    // MARK: - Cache management
    func clearCache(for date: Date) throws {
        let y = year(from: date)
        let m = month(from: date)
        try ShiftCache.purge(year: y, month: m)
        Log.shifts.notice("[ShiftRepo] \(Log.month(y, m), privacy: .public) cache CLEARED")
    }

    func clearAllCache() throws {
        try ShiftCache.purgeAll()
        Log.shifts.notice("[ShiftRepo] all shift caches CLEARED")
    }
    // MARK: - Year helpers

    /// Preloads a full year using the policy:
    /// - Mutable window months (prev/current/next relative to now) refresh if stale.
    /// - Other months are fetched only if missing, then cached; otherwise left untouched.
    /// Returns all shifts sorted by start time.
    func preloadYear(_ year: Int) async throws -> [Shift] {
        var all: [Shift] = []
        let cal = Calendar(identifier: .gregorian)
        let started = ContinuousClock.now

        Log.shifts.info("[ShiftRepo] preload \(year) — 12 months (each month logs its own cache decision below)")

        for month in 1...12 {
            guard let monthDate = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { continue }
            let monthShifts = try await getShifts(for: monthDate)
            all.append(contentsOf: monthShifts)
        }

        Log.shifts.info("[ShiftRepo] preload \(year) done — \(all.count) shift(s) in \(Log.ms(since: started)) ms")
        return all.sorted(by: { $0.start < $1.start })
    }

    /// Reads whatever is currently cached for the year, no network calls.
    func loadYearFromCache(_ year: Int) throws -> [Shift] {
        var all: [Shift] = []
        var cachedMonths = 0
        for m in 1...12 {
            if let cached = try ShiftCache.load(year: year, month: m) {
                all.append(contentsOf: cached.shifts)
                cachedMonths += 1
            }
        }
        Log.shifts.info("[ShiftRepo] \(year) cache-only read — \(all.count) shift(s) from \(cachedMonths)/12 cached month(s)")
        return all.sorted(by: { $0.start < $1.start })
    }
}
