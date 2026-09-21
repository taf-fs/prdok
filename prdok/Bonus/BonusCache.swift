//
//  BonusCache.swift
//  prdok
//
//  Created by David Horňák on 20.09.2026.
//

import Foundation
import UniformTypeIdentifiers

struct BonusCacheFile: Codable {
    let fetchedAt: Date
    let bonus: MonthBonus
}

enum BonusCache {
    private static let fm = FileManager.default

    private static var directoryURL: URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Prdok", isDirectory: true)
            .appendingPathComponent("BonusCache", isDirectory: true)
    }

    private static func ensureDir() throws {
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private static func fileURL(forYear year: Int, forMonth month: Int) -> URL {
        let mm = String(format: "%02d", month)
        return directoryURL.appendingPathComponent("bonus-\(year)-\(mm).json", conformingTo: .json)
    }

    static func save(bonus: MonthBonus, year: Int, month: Int, now: Date = Date()) throws {
        try ensureDir()
        let cacheFile = BonusCacheFile(fetchedAt: now, bonus: bonus)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cacheFile)
        try data.write(to: fileURL(forYear: year, forMonth: month), options: [.atomic])
    }

    static func load(year: Int, month: Int) throws -> BonusCacheFile? {
        let url = fileURL(forYear: year, forMonth: month)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BonusCacheFile.self, from: data)
    }

    static func isStale(_ cache: BonusCacheFile, maxAge: TimeInterval) -> Bool {
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
