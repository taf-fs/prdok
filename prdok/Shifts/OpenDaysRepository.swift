//
//  OpenDaysRepository.swift
//  prdok
//
//  Created by David Horňák on 24.07.2026.
//
//  Cache policy for open-day counts. A month's count stops being able to change once
//  the month is over, so a cache entry written after the month ended is final and is
//  never re-fetched. Everything else (the current month, future months, and entries
//  captured mid-month before the count settled) falls back to a staleness window.
//

import Foundation
import os

struct OpenDaysRepository {
    let maxCacheAge: TimeInterval

    init(maxCacheAge: TimeInterval = 60 * 60 * 24) {
        self.maxCacheAge = maxCacheAge
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

    /// Start of the month *after* the one containing `date` — the instant that month's
    /// open-day count becomes final.
    private func monthEnd(_ date: Date) -> Date {
        let cal = Calendar(identifier: .gregorian)
        return cal.date(byAdding: .month, value: 1, to: startOfMonth(date)) ?? date
    }

    // MARK: - Core loading with policy

    /// Returns the number of days the provoz is open in the month containing `date`.
    ///
    /// Set `forceRefresh` to bypass the policy and always fetch (used by the calendar's
    /// refresh button).
    func getOpenDays(for date: Date, forceRefresh: Bool = false) async throws -> Int {
        let y = year(from: date)
        let m = month(from: date)
        let key = Log.month(y, m)

        if forceRefresh {
            Log.openDays.notice("[OpenDaysRepo] \(key, privacy: .public) FORCE — bypassing cache")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }

        guard let cached = try OpenDaysCache.load(year: y, month: m) else {
            Log.openDays.info("[OpenDaysRepo] \(key, privacy: .public) cache MISS — fetching")
            return try await fetchAndCache(date: date, year: y, month: m, key: key)
        }

        let cacheAge = Date().timeIntervalSince(cached.fetchedAt)

        // A finished month's count can no longer change, so an entry written after the
        // month ended is final — serve it forever, however old it gets. (`fetchedAt` is
        // never in the future, so this also implies the month is in the past.)
        if cached.fetchedAt >= monthEnd(date) {
            Log.openDays.info("[OpenDaysRepo] \(key, privacy: .public) cache HIT (final) — \(cached.openDays) open day(s), age \(Log.age(cacheAge), privacy: .public)")
            return cached.openDays
        }

        // Still editable — or captured mid-month, before the count settled.
        guard OpenDaysCache.isStale(cached, maxAge: maxCacheAge) else {
            Log.openDays.info("[OpenDaysRepo] \(key, privacy: .public) cache HIT — \(cached.openDays) open day(s), age \(Log.age(cacheAge), privacy: .public)")
            return cached.openDays
        }

        Log.openDays.info("[OpenDaysRepo] \(key, privacy: .public) cache STALE (age \(Log.age(cacheAge), privacy: .public) > \(Log.age(self.maxCacheAge), privacy: .public)) — fetching")
        return try await fetchAndCache(date: date, year: y, month: m, key: key)
    }

    /// Fetches a month's count and writes it to the cache. A cache-write failure is
    /// logged but not fatal — the caller still gets the fetched count.
    private func fetchAndCache(date: Date, year y: Int, month m: Int, key: String) async throws -> Int {
        let openDays = try await OpenDaysService.fetchOpenDays(for: date)
        do {
            try OpenDaysCache.save(openDays: openDays, year: y, month: m)
            Log.openDays.info("[OpenDaysRepo] \(key, privacy: .public) SAVE — cached \(openDays) open day(s)")
        } catch {
            Log.openDays.error("[OpenDaysRepo] \(key, privacy: .public) SAVE failed: \(error.localizedDescription, privacy: .public)")
        }
        return openDays
    }

    // MARK: - Cache management

    func clearCache(for date: Date) throws {
        let y = year(from: date)
        let m = month(from: date)
        try OpenDaysCache.purge(year: y, month: m)
        Log.openDays.notice("[OpenDaysRepo] \(Log.month(y, m), privacy: .public) cache CLEARED")
    }

    func clearAllCache() throws {
        try OpenDaysCache.purgeAll()
        Log.openDays.notice("[OpenDaysRepo] all open-days caches CLEARED")
    }
}
