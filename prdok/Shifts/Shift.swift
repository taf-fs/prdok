//
//  Shift.swift
//  prdok
//
//  Created by David Horňák on 28.10.2025.
//

import Foundation

enum ShiftKind: String, Codable, Hashable {
    case offered
    case planned
    case actual
}

struct Shift: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: ShiftKind
    let start: Date
    let end: Date
    
    init(id: UUID = UUID(), kind: ShiftKind, start: Date, end: Date) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
    }
    
    var dayStart: Date {
        Calendar(identifier: .gregorian).startOfDay(for: start)
    }
}

// MARK: - Incoming JSON DTOs

struct APIEnvelope: Decodable {
    let smeny: SmenyGroups
}

struct SmenyGroups: Decodable {
    let dochazka: [RawShift]
    let plan: [RawShift]
    let moznosti: [RawShift]
}

struct RawShift: Decodable {
    let kdy: String   // "yyyy-MM-dd"
    let od: String    // "HH:mm:ss"
    let doTime: String

    enum CodingKeys: String, CodingKey {
        case kdy
        case od
        case doTime = "do" // "do" is a reserved word in Swift, so map it
    }
}
