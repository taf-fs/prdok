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
                rawDayText: dayLabel(for: start, timeZone: timeZone),
                role: FreeShiftRole(marker: raw.typ)
            )
        }

        Log.shifts.info("FreeShiftParser: decoded \(shifts.count) free shift(s).")
        return shifts
    }

    // MARK: - Day label

    /// The API returns only `kdy` (`"2026-07-25"`), so we build the Czech label the UI
    /// shows (e.g. `"sobota 25.7."`) ourselves, matching what the portal used to render.
    private static func dayLabel(for date: Date, timeZone: TimeZone) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "cs_CZ")
        df.timeZone = timeZone
        df.dateFormat = "EEEE d.M."
        return df.string(from: date)
    }
}
