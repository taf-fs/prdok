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
    
    init(maxCacheAge: TimeInterval = 60 * 60 * 24) {
        self.maxCacheAge = maxCacheAge
    }
    
    private func year(from date: Date) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: date)
    }
    
    func getShifts(for date: Date, forceRefresh: Bool = false) async throws -> [Shift] {
        let y = year(from: date)
        
        if forceRefresh {
            Log.shifts.notice("Force refresh: ignoring cache for year \(y)")
        } else {
            Log.shifts.debug("Checking cache for year \(y)")
        }

        if !forceRefresh, let cached = try ShiftCache.load(year: y), !ShiftCache.isStale(cached, maxAge: maxCacheAge) {
            Log.shifts.debug("Cache found for year \(y)")
            return cached.shifts
        } else {
            Log.shifts.debug("Cache missing/stale for year \(y); fetching from network")
        }
        

        let shifts = try await ShiftService.fetchShifts(date: date)
        Log.shifts.info("Fetched \(shifts.count) shifts for year \(y); saving cache")
        
        
        do {
            try ShiftCache.save(shifts: shifts, year: y)
            Log.shifts.debug("Saved cache for year \(y)")
        } catch {
            Log.shifts.error("Failed to save cache for year \(y): \(error.localizedDescription, privacy: .public)")
        }
         
        return shifts
    }
    
    func refresh(for date: Date) async throws -> [Shift] {
        let shifts = try await getShifts(for: date, forceRefresh: true)
        return shifts
    }

    func clearCache(for date: Date) throws {
        try ShiftCache.purge(year: year(from: date))
        Log.shifts.notice("Cleared cache for year \(year(from: date))")
    }

    func clearAllCache() throws {
        try ShiftCache.purgeAll()
        Log.shifts.notice("Cleared all cache.")
    }
}
