//
//  FreeShift.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  A "volná směna" (free shift) from the "Handlování směn" section of the employee
//  portal. Fetched via the `smeny_handl` API akce and decoded by `FreeShiftParser`.
//

import Foundation

struct FreeShift: Identifiable, Hashable {
    let id: Int
    let start: Date
    let end: Date
    let role: ShiftRole

    var timeRangeString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm"
        return "\(df.string(from: start)) – \(df.string(from: end))"
    }

    /// Lightweight time interval for `ShiftIndicatorView`.
    var indicatorInterval: ShiftInterval {
        ShiftInterval(id: id, start: start, end: end)
    }
}

// MARK: - Incoming JSON DTOs

/// The `smeny_handl` akce returns the free shifts alongside the usual session
/// envelope; we only care about the `smeny_handl` array (empty when there are none,
/// capped at 200 by the server).
struct FreeShiftEnvelope: Decodable {
    let shifts: [RawFreeShift]

    enum CodingKeys: String, CodingKey {
        case shifts = "smeny_handl"
    }
}

struct RawFreeShift: Decodable {
    let id: String    // ID of the free shift received from the server
    let kdy: String   // "yyyy-MM-dd"
    let od: String    // "HH:mm:ss"
    let doTime: String
    let typ: String   // role marker: "-" regular, "v" vedoucí, "b" barista

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
//    "smeny_handl":[
//        {
//            "id":"48674",
//            "kdoi":"0",
//            "kdoj":"Volná směna",
//            "kdy":"2026-07-25",
//            "od":"08:00:00",
//            "do":"12:00:00",
//            "doba":"4",
//            "typ":"-",
//            "radek":"6",
//            "vlastnost":"1",
//            "poznamka":"",
//            "ts":"2026-06-18 13:14:31"
//        }
//    ]
//    // ... plus session envelope fields (ulozsi, pak, err, ...) we ignore
//}
