//
//  FreeShiftParser.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  Parses the "Handlování směn" table out of the employee portal HTML.
//  The backend has no JSON API for these, so we scrape the page.
//
//  Expected shape (first `<table>` after the "Handlování směn:" anchor):
//
//    <table style="border: 5px dotted red; margin: 3px;">
//      <tr valign="top">
//        <td><button onclick='okynko("smenahandl","cp/48523/0/445")'>…</button></td>
//        <td>pondělí 20.7. </td>
//        <td>20:00-21:00 <b>-</b> Volná směna</td>
//        <td></td>
//      </tr>
//      …
//    </table>
//
//  Parsing is deliberately defensive: a row that doesn't match the expected
//  shape is skipped, never fatal.
//


import Foundation
import os
import SwiftSoup

enum FreeShiftParser {

    /// Parses free shifts out of a full `zamestnanci.php` HTML page.
    /// Never throws — on any structural problem it logs and returns what it could parse (possibly `[]`).
    static func parse(
        html: String,
        now: Date = Date(),
        timeZone: TimeZone = TimeZone(identifier: "Europe/Prague") ?? .current
    ) -> [FreeShift] {
        do {
            let doc = try SwiftSoup.parse(html)

            // The table has a distinctive red dotted border. `*=` matches on substring
            // so we're resilient to minor whitespace/style tweaks. It is also the first
            // table after the "Handlování směn:" text anchor, matching the spec.
            guard let table = try doc.select("table[style*='dotted red']").first() else {
                Log.shifts.notice("FreeShiftParser: 'Handlování směn' table not found.")
                return []
            }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone

            var result: [FreeShift] = []
            let rows = try table.select("tr")
            for row in rows {
                if let shift = parseRow(row, now: now, calendar: calendar, timeZone: timeZone) {
                    result.append(shift)
                }
            }

            Log.shifts.info("FreeShiftParser: parsed \(result.count) free shift(s).")
            return result
        } catch {
            Log.shifts.error("FreeShiftParser: parse failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Row parsing

    private static func parseRow(
        _ row: Element,
        now: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> FreeShift? {
        do {
            // ID: onclick='okynko("smenahandl","cp/48523/0/445")' -> 48523.
            // Read the raw attribute value (not row.html()): SwiftSoup re-serializes markup
            // and escapes the inner quotes as &quot;, which the pattern would not match.
            var id: Int?
            for element in try row.select("[onclick]").array() {
                let onclick = try element.attr("onclick")
                if let parsed = firstInt(in: onclick, pattern: #"smenahandl"\s*,\s*"[^/"]+/(\d+)/"#) {
                    id = parsed
                    break
                }
            }
            guard let id else { return nil }

            let cells = try row.select("td").array()
            guard !cells.isEmpty else { return nil }

            // Find the cells by content instead of by fixed index, so small template
            // changes (an extra/blank cell) don't break parsing.
            var dayCellText: String?
            var timeMatch: (od: String, doTime: String)?
            var role: FreeShiftRole = .regular
            for cell in cells {
                let text = try cell.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if dayCellText == nil, matches(text, pattern: #"\d{1,2}\.\s*\d{1,2}\."#) {
                    dayCellText = text
                }
                if timeMatch == nil, let t = parseTimeRange(text) {
                    timeMatch = t
                    // The role marker lives in a <b> tag within the same (time) cell,
                    // e.g. "20:00-21:00 <b>v</b> Volná směna". Read it from the element,
                    // not the collapsed text, where the tag boundary is already lost.
                    if let bold = try cell.select("b").first() {
                        role = FreeShiftRole(marker: try bold.text())
                    }
                }
            }

            guard let dayText = dayCellText,
                  let (day, month) = parseDayMonth(dayText),
                  let times = timeMatch
            else {
                return nil
            }

            let year = resolveYear(month: month, day: day, now: now, calendar: calendar)
            let dayString = String(format: "%04d-%02d-%02d", year, month, day)

            // Reuse the existing, tested time logic (Europe/Prague, end < start -> +1 day).
            let (start, end) = try ShiftParser.parseShift(
                dayString: dayString,
                startString: times.od,
                endString: times.doTime,
                timeZone: timeZone
            )

            return FreeShift(id: id, start: start, end: end, rawDayText: dayText, role: role)
        } catch {
            Log.shifts.debug("FreeShiftParser: skipping row: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Field parsing

    /// `"20:00-21:00 - Volná směna"` -> ("20:00:00", "21:00:00")
    private static func parseTimeRange(_ text: String) -> (od: String, doTime: String)? {
        guard let match = firstGroups(in: text, pattern: #"(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})"#),
              match.count == 4,
              let oh = Int(match[0]), let om = Int(match[1]),
              let dh = Int(match[2]), let dm = Int(match[3])
        else { return nil }
        return (String(format: "%02d:%02d:00", oh, om), String(format: "%02d:%02d:00", dh, dm))
    }

    /// `"pondělí 20.7."` -> (day: 20, month: 7)
    private static func parseDayMonth(_ text: String) -> (day: Int, month: Int)? {
        guard let match = firstGroups(in: text, pattern: #"(\d{1,2})\.\s*(\d{1,2})\."#),
              match.count == 2,
              let day = Int(match[0]), (1...31).contains(day),
              let month = Int(match[1]), (1...12).contains(month)
        else { return nil }
        return (day, month)
    }

    /// The portal omits the year. Pick the year (previous/current/next) whose resulting
    /// date is closest to `now`, which naturally handles the December→January rollover.
    private static func resolveYear(month: Int, day: Int, now: Date, calendar: Calendar) -> Int {
        let nowYear = calendar.component(.year, from: now)
        var best = nowYear
        var bestDistance = TimeInterval.greatestFiniteMagnitude
        for candidate in [nowYear - 1, nowYear, nowYear + 1] {
            guard let date = calendar.date(from: DateComponents(year: candidate, month: month, day: day)) else { continue }
            let distance = abs(date.timeIntervalSince(now))
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }

    // MARK: - Regex helpers

    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

    private static func firstInt(in string: String, pattern: String) -> Int? {
        guard let groups = firstGroups(in: string, pattern: pattern), let first = groups.first else { return nil }
        return Int(first)
    }

    /// Returns the captured groups (not the full match) of the first occurrence, or nil.
    private static func firstGroups(in string: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        var groups: [String] = []
        for i in 1..<match.numberOfRanges {
            guard let r = Range(match.range(at: i), in: string) else { return nil }
            groups.append(String(string[r]))
        }
        return groups
    }
}
