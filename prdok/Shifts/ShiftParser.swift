//
//  ShiftParser.swift
//  prdok
//
//  Created by David Horňák on 28.10.2025.
//

import Foundation

struct ShiftParser {
    
    /// Takes a string argument in the "hh:mm:ss" format and returns a tuple containing the hour, minute, and second.
    /// Supports hours 24, 25, 26.. and over and converts them into morning hours.
    private static func parseHMS(_ timeString: String) throws -> (h: Int, m: Int, s: Int) {
        let parts = timeString.split(separator: ":")
        guard parts.count == 3,
              let rawH = Int(parts[0]), rawH >= 0,
              let m = Int(parts[1]), (0...59).contains(m),
              let s = Int(parts[2]), (0...59).contains(s)
        else {
            throw ShiftParseError.invalidTime(timeString)
        }

        // 25:00:00 -> 01:00:00, 24:00:00 -> 00:00:00
        let h = rawH % 24
        return (h, m, s)
    }

    /// Takes a day the shift started in the "yyyy-MM-dd" format the hour of shift start, and the hour of shift end in the ""hh:mm:ss" format. Returns a tuple containing two dates, `start` is the start Date of the shift, `end` is the end Date of the shift.
    static func parseShift(dayString: String, startString: String, endString: String, timeZone: TimeZone = TimeZone(identifier: "Europe/Prague") ?? .current) throws -> (start: Date, end: Date) {

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayFormatter: DateFormatter = {
            let df = DateFormatter()
            df.calendar = calendar
            df.locale = Locale(identifier: "en_US_POSIX") // avoid user-locale issues
            df.timeZone = timeZone
            df.dateFormat = "yyyy-MM-dd"
            return df
        }()

        guard let day = dayFormatter.date(from: dayString) else {
            throw ShiftParseError.invalidDay(dayString)
        }

        let (sh, sm, ss) = try parseHMS(startString)
        let (eh, em, es) = try parseHMS(endString)

        guard let start = calendar.date(bySettingHour: sh, minute: sm, second: ss, of: day) else {
            throw ShiftParseError.couldNotComposeDate(day: dayString, time: startString)
        }

        guard var end = calendar.date(bySettingHour: eh, minute: em, second: es, of: day) else {
            throw ShiftParseError.couldNotComposeDate(day: dayString, time: endString)
        }

        if start > end {
            // End time is on the next day
            guard let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: end) else {
                throw ShiftParseError.couldNotComposeDate(day: dayString, time: endString)
            }
            end = nextDayEnd
        }
        
        return (start, end)
    }
    
    /// Decodes a list of shifts from the server response and normalizes their absolute dates.
    static func decodeShifts(from data: Data, serverTimeZone: TimeZone = TimeZone(identifier: "Europe/Prague") ?? .current) throws -> [Shift] {
        let envelope = try JSONDecoder().decode(APIEnvelope.self, from: data)
        
        func map(_ raw: RawShift, kind: ShiftKind) throws -> Shift {
            let (start, end) = try parseShift(
                dayString: raw.kdy,
                startString: raw.od,
                endString: raw.doTime,
                timeZone: serverTimeZone
            )
            
            guard let id = Int(raw.id) else {
                throw ShiftParseError.couldNotParseID(id: raw.id)
            }
            
            // Only roster rows carry a role in `typ`.
            let role = kind == .planned ? ShiftRole(marker: raw.typ) : .regular
            return Shift(id: id, kind: kind, start: start, end: end, role: role)
        }
        
        var shifts: [Shift] = []
        shifts += try envelope.smeny.dochazka.map { try map($0, kind: .actual) }
        shifts += try envelope.smeny.plan.map { try map($0, kind: .planned) }
        shifts += try envelope.smeny.moznosti.map { try map($0, kind: .offered) }
        return shifts
    }
}

enum ShiftParseError: Error, LocalizedError {
    case invalidDay(String)
    case invalidTime(String)
    case invalidDate(y: Int, m: Int, d: Int)
    case couldNotComposeDate(day: String, time: String)
    case couldNotParseID(id: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDay(let d): return "Invalid day format: \(d)"
        case .invalidTime(let t): return "Invalid time format: \(t)"
        case .invalidDate(let y, let m, let d): return "Invalid date: \(y)-\(m)-\(d)"
        case .couldNotComposeDate(let d, let t): return "Could not compose date from \(d) \(t)"
        case .couldNotParseID(let id): return "Could not parse id \(id)"
        }
    }
}
