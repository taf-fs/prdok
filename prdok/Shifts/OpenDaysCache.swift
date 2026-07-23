//
//  OpenDaysCache.swift
//  prdok
//
//  Created by David Horňák on 24.07.2026.
//
//  On-disk cache for the `otevrene_dny` open-day counts. One small file per month,
//  mirroring `ShiftCache` so the two caches behave (and can be purged) the same way.
//

import Foundation
import UniformTypeIdentifiers

struct OpenDaysCacheFile: Codable {
    let fetchedAt: Date
    let openDays: Int
}

enum OpenDaysCache {
    private static let fm = FileManager.default

    private static var directoryURL: URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Prdok", isDirectory: true)
            .appendingPathComponent("OpenDaysCache", isDirectory: true)
    }

    private static func ensureDir() throws {
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private static func fileURL(forYear year: Int, forMonth month: Int) -> URL {
        let mm = String(format: "%02d", month)
        return directoryURL.appendingPathComponent("open-days-\(year)-\(mm).json", conformingTo: .json)
    }

    static func save(openDays: Int, year: Int, month: Int, now: Date = Date()) throws {
        try ensureDir()
        let cacheFile = OpenDaysCacheFile(fetchedAt: now, openDays: openDays)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cacheFile)
        try data.write(to: fileURL(forYear: year, forMonth: month), options: [.atomic])
    }

    static func load(year: Int, month: Int) throws -> OpenDaysCacheFile? {
        let url = fileURL(forYear: year, forMonth: month)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OpenDaysCacheFile.self, from: data)
    }

    static func isStale(_ cache: OpenDaysCacheFile, maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(cache.fetchedAt) > maxAge
    }

    static func purge(year: Int, month: Int) throws {
        let url = fileURL(forYear: year, forMonth: month)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    static func purgeAll() throws {
        if fm.fileExists(atPath: directoryURL.path) {
            try fm.removeItem(at: directoryURL)
        }
    }
}
