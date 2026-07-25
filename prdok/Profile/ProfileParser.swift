//
//  ProfileParser.swift
//  prdok
//
//  Decodes the employee profile out of the `mojedata` API response. Parses the
//  `datum_nastup` start date and the seven `kompetenceN` month markers ("yyyyMM",
//  or "0" when the competency hasn't been gained yet).
//

import Foundation
import os

enum ProfileParseError: Error, LocalizedError {
    case couldNotParseStartDate(String)

    var errorDescription: String? {
        switch self {
        case .couldNotParseStartDate(let value):
            return "Could not parse start date '\(value)'."
        }
    }
}

enum ProfileParser {

    /// Decodes a `Profile` from a `mojedata` API response.
    ///
    /// - Throws:
    ///   - Any error from `JSONDecoder` if the envelope is malformed.
    ///   - `ProfileParseError.couldNotParseStartDate` if `datum_nastup` isn't `yyyy-MM-dd`.
    static func decode(
        from data: Data,
        timeZone: TimeZone = TimeZone(identifier: "Europe/Prague") ?? .current
    ) throws -> Profile {
        let envelope = try JSONDecoder().decode(ProfileEnvelope.self, from: data)
        let raw = envelope.data

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let startDate = parseDay(raw.datumNastup, calendar: calendar) else {
            throw ProfileParseError.couldNotParseStartDate(raw.datumNastup)
        }

        let competencies = zip(Competency.allCases, raw.competenceRawValues).map { competency, value in
            CompetencyStatus(competency: competency, gained: parseMonth(value, calendar: calendar))
        }

        let gainedCount = competencies.filter { $0.gained != nil }.count
        Log.profile.debug("[ProfileParser] decoded profile — \(gainedCount)/\(Competency.allCases.count) competencies gained")
        return Profile(name: raw.jmeno, startDate: startDate, competencies: competencies)
    }

    /// Parses a `"yyyy-MM-dd"` day into a `Date` at the start of that day.
    private static func parseDay(_ string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Parses a `"yyyyMM"` competency marker into the first day of that month.
    /// Returns `nil` for `"0"` (not gained) or anything unparseable.
    private static func parseMonth(_ string: String, calendar: Calendar) -> Date? {
        guard string.count == 6,
              let year = Int(string.prefix(4)), let month = Int(string.suffix(2)),
              (1...12).contains(month)
        else { return nil }

        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }
}
