//
//  FreeShiftParser.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  Decodes the "Handlování směn" (free shifts) out of the `smeny_handl` API response.
//  Mirrors `ShiftParser.decodeShifts`: reuses `ShiftParser.parseShift` for the
//  Europe/Prague date math (including the end < start → next-day rollover).
//

import Foundation
import os

enum FreeShiftParser {

    /// Decodes free shifts from a `smeny_handl` API response.
    ///
    /// - Throws:
    ///   - Any error from `JSONDecoder` if the envelope is malformed.
    ///   - `ShiftParseError` if a row's date/time can't be parsed or its id isn't an `Int`.
    static func decode(
        from data: Data,
        timeZone: TimeZone = TimeZone(identifier: "Europe/Prague") ?? .current
    ) throws -> [FreeShift] {
        let envelope = try JSONDecoder().decode(FreeShiftEnvelope.self, from: data)

        let shifts = try envelope.shifts.map { raw -> FreeShift in
            let (start, end) = try ShiftParser.parseShift(
                dayString: raw.kdy,
                startString: raw.od,
                endString: raw.doTime,
                timeZone: timeZone
            )

            guard let id = Int(raw.id) else {
                throw ShiftParseError.couldNotParseID(id: raw.id)
            }

            return FreeShift(
                id: id,
                start: start,
                end: end,
                role: ShiftRole(marker: raw.typ)
            )
        }

        // The service logs the count; here we break it down by role, which it can't see.
        let byRole = Dictionary(grouping: shifts, by: \.role)
        Log.freeShifts.debug("[FreeShiftParser] decoded \(shifts.count) — regular \(byRole[.regular]?.count ?? 0), vedoucí \(byRole[.manager]?.count ?? 0), barista \(byRole[.barista]?.count ?? 0)")
        return shifts
    }
}
