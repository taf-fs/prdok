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

/// What kind of role a roster shift is for. In the API this is the `typ` field: a single
/// character (`"-"`, `"v"`, `"b"`). Planned and free shifts both come from the roster table,
/// so they share it; the other kinds have no role.
enum ShiftRole: String, Codable, Hashable {
    case regular   // "-"  — ordinary shift, needs no extra label
    case manager   // "v"  — vedoucí
    case barista   // "b"

    /// Maps the raw `typ` marker character to a role. Anything unexpected (including
    /// the dash) is treated as a regular shift.
    init(marker: String?) {
        switch marker?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "v": self = .manager
        case "b": self = .barista
        default:  self = .regular
        }
    }
}

struct Shift: Identifiable, Codable, Hashable {
    let id: Int
    let kind: ShiftKind
    let start: Date
    let end: Date
    /// Only planned shifts carry a real role; the rest are always `.regular`.
    let role: ShiftRole
    
    init(id: Int, kind: ShiftKind, start: Date, end: Date, role: ShiftRole = .regular) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, start, end, role
    }

    /// `role` was added later, so shifts cached before it decode as `.regular` until the
    /// month is fetched again.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        kind = try container.decode(ShiftKind.self, forKey: .kind)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        role = try container.decodeIfPresent(ShiftRole.self, forKey: .role) ?? .regular
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
    let typ: String?  // role marker on `plan` rows; on `dochazka` it is an attendance code ("1")

    enum CodingKeys: String, CodingKey {
        case id
        case kdy
        case od
        case doTime = "do" // "do" is a reserved word in Swift, so map it
        case typ
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
//                "do":"25:00:00",
//                "typ":"-"
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
