//
//  BonusRepository.swift
//  prdok
//
//  Created by David Horňák on 20.09.2026.
//


import Foundation
import os

struct BonusRepository {
    let maxCacheAge: TimeInterval

    /// Months (relative to "now") that are allowed to refresh if stale.
    /// Default: previous (-1), current (0), next (+1) — the window payroll is still
    /// working in, plus the month ahead, whose offered numbers change daily.
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
        return cal.dateComponents([.month], from: startOfMonth(base), to: startOfMonth(target)).month ?? 0
    }

    // MARK: - Core loading with policy

    /// Returns the pay structure for the month containing `date`.
    ///
    /// Set `forceRefresh` to bypass the policy and always fetch (used by the calendar's
    /// refresh button, so the conditions can't show a stale verdict next to fresh shifts).
    func getBonus(for date: Date, forceRefresh: Bool = false) async throws -> MonthBonus {
        let y = year(from: date)
        let m = month(from: date)
        let key = Log.month(y, m)
        let offset = monthOffset(from: Date(), to: date)

        if forceRefresh {
            Log.bonus.notice("[BonusRepo] \(key, privacy: .public) FORCE — bypassing cache")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }

        if refreshableMonthOffsets.contains(offset) {
            Log.bonus.debug("[BonusRepo] \(key, privacy: .public) policy: refreshable (offset \(offset), max age \(Log.age(self.maxCacheAge), privacy: .public))")

            guard let cached = try BonusCache.load(year: y, month: m) else {
                Log.bonus.info("[BonusRepo] \(key, privacy: .public) cache MISS — fetching")
                return try await fetchAndCache(date: date, year: y, month: m, key: key)
            }

            let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
            guard !BonusCache.isStale(cached, maxAge: maxCacheAge) else {
                Log.bonus.info("[BonusRepo] \(key, privacy: .public) cache STALE (age \(Log.age(cacheAge), privacy: .public) > \(Log.age(self.maxCacheAge), privacy: .public)) — fetching")
                return try await fetchAndCache(date: date, year: y, month: m, key: key)
            }

            Log.bonus.info("[BonusRepo] \(key, privacy: .public) cache HIT — \(cached.bonus.score)/\(cached.bonus.maxScore), age \(Log.age(cacheAge), privacy: .public)")
            return cached.bonus
        } else {
            // Payroll has long since closed these months: the verdict can't change.
            Log.bonus.debug("[BonusRepo] \(key, privacy: .public) policy: settled (offset \(offset))")

            if let cached = try BonusCache.load(year: y, month: m) {
                let cacheAge = Date().timeIntervalSince(cached.fetchedAt)
                Log.bonus.info("[BonusRepo] \(key, privacy: .public) cache HIT (settled) — \(cached.bonus.score)/\(cached.bonus.maxScore), age \(Log.age(cacheAge), privacy: .public)")
                return cached.bonus
            }

            Log.bonus.notice("[BonusRepo] \(key, privacy: .public) cache MISS (settled) — one-time fetch to seed")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }
    }

    /// Fetches a month's pay structure and writes it to the cache. A cache-write failure
    /// is logged but not fatal — the caller still gets the fetched structure.
    private func fetchAndCache(date: Date, year y: Int, month m: Int, key: String) async throws -> MonthBonus {
        let bonus = try await BonusService.fetchBonus(for: date)
        do {
            try BonusCache.save(bonus: bonus, year: y, month: m)
            Log.bonus.info("[BonusRepo] \(key, privacy: .public) SAVE — cached \(bonus.score)/\(bonus.maxScore)")
        } catch {
            Log.bonus.error("[BonusRepo] \(key, privacy: .public) SAVE failed: \(error.localizedDescription, privacy: .public)")
        }
        return bonus
    }

    // MARK: - Cache management

    func clearCache(for date: Date) throws {
        let y = year(from: date)
        let m = month(from: date)
        try BonusCache.purge(year: y, month: m)
        Log.bonus.notice("[BonusRepo] \(Log.month(y, m), privacy: .public) cache CLEARED")
    }

    func clearAllCache() throws {
        try BonusCache.purgeAll()
        Log.bonus.notice("[BonusRepo] all bonus caches CLEARED")
    }
}
