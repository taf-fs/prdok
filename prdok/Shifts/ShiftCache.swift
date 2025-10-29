//
//  ShiftCache.swift
//  prdok
//
//  Created by David Horňák on 29.10.2025.
//

import Foundation
import UniformTypeIdentifiers

struct ShiftCacheFile: Codable {
    let fetchedAt: Date
    let shifts: [Shift]
}

enum ShiftCache {
    private static let fm = FileManager.default
    
    private static var directoryURL: URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Prdok", isDirectory: true)
            .appendingPathComponent("ShiftsCache", isDirectory: true)
    }
    
    private static func ensureDir() throws {
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
    
    private static func fileURL(forYear year: Int) ->  URL {
        directoryURL.appendingPathComponent("shifts-\(year).json", conformingTo: .json)
    }
    
    static func save(shifts: [Shift], year: Int, now: Date = Date()) throws {
        try ensureDir()
        let cacheFile = ShiftCacheFile(fetchedAt: now, shifts: shifts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cacheFile)
        try data.write(to: fileURL(forYear: year), options: [.atomic])
    }
    
    static func load(year: Int) throws -> ShiftCacheFile? {
        let url = fileURL(forYear: year)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShiftCacheFile.self, from: data)
    }
    
    static func isStale(_ cache: ShiftCacheFile, maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(cache.fetchedAt) > maxAge
    }
    
    static func purge(year: Int) throws {
        let url = fileURL(forYear: year)
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

