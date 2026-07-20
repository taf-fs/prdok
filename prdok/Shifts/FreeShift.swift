//
//  FreeShift.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  A "volná směna" (free shift) scraped from the "Handlování směn" section of
//  the employee portal HTML. Unlike `Shift`, this has no JSON API yet — it is parsed
//  out of the `zamestnanci.php` page (see `FreeShiftParser`).
//

import Foundation

/// What kind of role the free shift is for. On the portal this is a single character
/// inside a `<b>` tag in the time cell (e.g. `20:00-21:00 <b>-</b> Volná směna`).
enum FreeShiftRole: String, Hashable {
    case regular   // "-"  — ordinary shift, needs no extra label
    case manager   // "v"  — vedoucí
    case barista   // "b"

    /// Maps the raw `<b>` marker character to a role. Anything unexpected (including
    /// the dash) is treated as a regular shift.
    init(marker: String) {
        switch marker.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "v": self = .manager
        case "b": self = .barista
        default:  self = .regular
        }
    }
}

struct FreeShift: Identifiable, Hashable {
    let id: Int
    let start: Date
    let end: Date
    /// The raw day label as rendered by the server, e.g. `"pondělí 20.7."`.
    /// Kept verbatim so the UI can show exactly what the portal shows.
    let rawDayText: String
    let role: FreeShiftRole

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
