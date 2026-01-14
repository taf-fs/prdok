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
    let id: Int
    let kind: ShiftKind
    let start: Date
    let end: Date
    
    init(id: Int, kind: ShiftKind, start: Date, end: Date) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
    }
    
    var dayStart: Date {
        Calendar(identifier: .gregorian).startOfDay(for: start)
    }
    
    var timeRangeString: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let startHour = df.string(from: start)
        let endHour = df.string(from: end)
        return "\(startHour) - \(endHour)"
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
    let id: String    // ID of the shift received from the server
    let kdy: String   // "yyyy-MM-dd"
    let od: String    // "HH:mm:ss"
    let doTime: String

    enum CodingKeys: String, CodingKey {
        case id
        case kdy
        case od
        case doTime = "do" // "do" is a reserved word in Swift, so map it
    }
}


// example server response:
//
//{
//    "smeny":{
//        "dochazka":[
//            {
//                "id":"73084",
//                "kdy":"2025-10-04",
//                "od":"16:01:00",
//                "do":"24:58:00"
//            }
//        ],
//        "plan":[
//            {
//                "id":"73085",
//                "kdy":"2025-10-04",
//                "od":"16:00:00",
//                "do":"25:00:00"
//            }
//        ],
//        "moznosti":[
//            {
//                "id":"73086",
//                "kdy":"2025-10-04",
//                "od":"16:00:00",
//                "do":"25:00:00"
//            }
//        ]
//    }
//}
