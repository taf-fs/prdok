//
//  ShiftService.swift
//  prdok
//
//  Created by David Horňák on 28.10.2025.
//

import Foundation

struct ShiftService {
    /// Fetches shifts for the month containing the provided date.
    ///
    /// This calls the `/zapp/hello.php` endpoint using a form URL-encoded `POST` with:
    /// - `akce=mojesmeny`
    /// - `kdy` = year-month formatted as `"yyyy-MM"` (see `formatDateToYearAndMonthString(date:)`)
    /// - `klic` loaded from `UserDefaults` under the `"klic"` key
    ///
    /// The backend accepts multiple formats for `kdy` (`"yyyy"`, `"yyyy-MM"`, `"yyyy-MM-dd"`), but this client
    /// currently always requests a month worth of data by sending `"yyyy-MM"`.
    ///
    /// The response is decoded via `ShiftParser.decodeShifts(from:)` into normalized `Shift` values:
    /// planned (`.planned`), actual (`.actual`), and offered (`.offered`).
    ///
    /// - Parameter date: Any date within the month to fetch shifts for.
    ///
    /// - Returns: A combined array of shifts (planned, actual, and offered) returned by the backend.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` is not present in `UserDefaults`.
    ///   - `FetchShiftError.invalidDate` if the date cannot be formatted into the `"yyyy-MM"` form used by the API.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be constructed.
    ///   - `URLError(.badServerResponse)` if the HTTP response is not in the 2xx range.
    ///   - Any error thrown by `ShiftParser.decodeShifts(from:)` (e.g. JSON decoding / parsing failures).
    static func fetchShifts(date: Date) async throws -> [Shift] {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let when = formatDateToYearAndMonthString(date: date) else {
            throw FetchShiftError.invalidDate(date)
        }
        guard let provoz = UserDefaults.standard.string(forKey: "provoz") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "klic": key,
            "akce": "mojesmeny",
            "kdy": when,
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try ShiftParser.decodeShifts(from: data)
    }
    
    /// Offers (publishes) a shift availability (“možnost”) to the backend for a given day and time range.
    ///
    /// This calls the `/zapp/hello.php` endpoint using a form URL-encoded `POST` with:
    /// - `akce=pridatmoznost`
    /// - `kdy` = shift day formatted as `"yyyy-MM-dd"`
    /// - `od` / `do` = start/end times formatted as `"HH:00:00"`
    /// - `klic` loaded from `UserDefaults` under the `"klic"` key
    ///
    /// The server currently reports success/failure via a message contained in the JSON
    /// field `err` (see `ServerResponse`). This method maps known messages to `OfferShiftResult`:
    ///
    /// - Parameters:
    ///   - when: Day of the offered shift. Only the calendar date is used (sent as `"yyyy-MM-dd"`).
    ///   - start: Start hour in 24-hour format. Must be in `7...24`.
    ///   - end: End hour in 24-hour format. Must be in `8...25`.
    ///
    /// - Returns: An `OfferShiftResult` describing whether the offer was saved, rejected by the server,
    ///   or returned an unrecognized response.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` is not present in `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be constructed.
    ///   - `ShiftConversionError.invalidStartHour` / `ShiftConversionError.invalidEndHour` if `start`/`end`
    ///     are outside allowed ranges.
    ///   - `URLError(.badServerResponse)` if the HTTP response is not in the 2xx range.
    ///   - Any decoding error if the response cannot be decoded as `ServerResponse`.
    static func offerShift(when: Date, start: Int, end: Int) async throws -> OfferShiftResult {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let provoz = UserDefaults.standard.string(forKey: "provoz") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        let (shiftDayOfYear, startHour, endHour) = try convertOfferedShiftToParams(when: when, start: start, end: end)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "klic": key,
            "akce": "pridatmoznost",
            "kdy": shiftDayOfYear,   // yyyy-mm-dd
            "od": startHour,         // hh:mm:ss
            "do": endHour,           // hh:mm:ss
            "parametr": "",
            "provoz": provoz
        ]

        request.httpBody = params.formURLEncodedData()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(ServerResponse.self, from: data)
        let message = decoded.err?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch message {
        case "ukládám možnost.":
            return .saved
        case let msg? where msg.localizedCaseInsensitiveContains("odmítám zapsat"):
            return .rejected(message: msg)
        default:
            return .unexpected(message: message)
        }
    }
    
    /// Removes a previously offered shift availability (“možnost”) from the backend.
    ///
    /// This calls the `/zapp/hello.php` endpoint using a form URL-encoded `POST` with:
    /// - `akce=smazatmoznost`
    /// - `smenaid` = `shift.id`
    /// - `klic` loaded from `UserDefaults` under the `"klic"` key
    ///
    /// The server currently reports success/failure via a message contained in the JSON
    /// field `err` (see `ServerResponse`). This method maps known messages to `RemoveShiftResult`:
    ///
    /// - Parameter shift: The shift to remove. The request uses `shift.id` as `smenaid`.
    ///
    /// - Returns: A `RemoveShiftResult` indicating whether the shift was removed, not found on the server,
    ///   or an unrecognized server message was returned.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` is not present in `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be constructed.
    ///   - `URLError(.badServerResponse)` if the HTTP response is not in the 2xx range.
    ///   - Any decoding error if the response cannot be decoded as `ServerResponse`.
    static func removeShift(shift: Shift) async throws -> RemoveShiftResult {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let provoz = UserDefaults.standard.string(forKey: "provoz") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "klic": key,
            "akce": "smazatmoznost",
            "smenaid": String(shift.id),
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Decode JSON and decide
        let decoded = try JSONDecoder().decode(ServerResponse.self, from: data)
        
        let message = decoded.err?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch message {
        case "mažu možnost.":
            return .removed
        case "nevidím možnost ke smazání.":
            return .notFound
        default:
            return .unexpected(message: message)
        }
    }
    
    /// Formats a `Date` into the year-month string required by the backend `kdy` parameter when requesting
    /// a month worth of shifts.
    ///
    /// - Parameter date: Any date within the desired month.
    /// - Returns: A string in the `"yyyy-MM"` format (e.g. `"2026-02"`).
    static private func formatDateToYearAndMonthString(date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    
    /// convertOfferedShiftToParams converts a shift's date and integer start/end hours into string parameters
    /// expected by the backend API.
    ///
    /// - Validates that the start hour is in the range 7...24 and the end hour is in the
    ///   range 8...25. If the values are outside these ranges, it throws `ShiftConversionError`.
    /// - Formats the given `when` `Date` into a `"yyyy-MM-dd"` string suitable for the
    ///   `kdy` parameter in the request.
    /// - Converts the integer `start` and `end` hour values into zero‑padded `"HH:00:00"`
    ///   strings suitable for the `od` and `do` parameters in the request.
    ///
    /// - Parameters:
    ///   - when: The date of the shift.
    ///   - start: The starting hour of the shift (24‑hour format, 7...24).
    ///   - end: The ending hour of the shift (24‑hour format, 8...25).
    ///
    /// - Returns: A tuple containing:
    ///   - `shiftDayOfYear`: The shift date formatted as `"yyyy-MM-dd"`.
    ///   - `startHour`: The start time formatted as `"HH:00:00"`.
    ///   - `endHour`: The end time formatted as `"HH:00:00"`.
    ///
    /// - Throws: `ShiftConversionError.invalidStartHour` or
    ///   `ShiftConversionError.invalidEndHour` if the provided hours are out of range.
    static private func convertOfferedShiftToParams(when: Date, start: Int, end: Int) throws -> (shiftDayOfYear: String, startHour: String, endHour: String) {
        // Validate ranges
        guard (7...24).contains(start) else {
            throw ShiftConversionError.invalidStartHour(start)
        }
        guard (8...25).contains(end) else {
            throw ShiftConversionError.invalidEndHour(end)
        }
        
        // Date formatter for yyyy-MM-dd
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = Calendar.current.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let shiftDayOfYear = dateFormatter.string(from: when)
        
        // Helper to convert an hour Int to "HH:00:00" string, zero-padded
        func hourString(from hour: Int) -> String {
            String(format: "%02d:00:00", hour)
        }
        
        let startHour = hourString(from: start)
        let endHour = hourString(from: end)
        
        return (shiftDayOfYear, startHour, endHour)
    }
}

/// encoder that turns [​String: ​String] into application/x-www-form-urlencoded body data
private extension Dictionary where Key == String, Value == String {
    func formURLEncodedData() -> Data? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._* ") // adding space manually so we can swap it later
        
        let body = self
            .sorted(by: { $0.key < $1.key }) // Sorting is good for deterministic output
            .map { key, value -> String in
                let escapedKey = key
                    .addingPercentEncoding(withAllowedCharacters: allowed)?
                    .replacingOccurrences(of: " ", with: "+")
                    ?? ""
                
                let escapedValue = value
                    .addingPercentEncoding(withAllowedCharacters: allowed)?
                    .replacingOccurrences(of: " ", with: "+")
                    ?? ""
                
                return "\(escapedKey)=\(escapedValue)"
            }
            .joined(separator: "&")
        
        return body.data(using: .utf8)
    }
}

/// For now, the server has the responses for (un)successful shift offers and removals in the `err` field of the JSON response.
private struct ServerResponse: Decodable {
    let err: String?
}

enum OfferShiftResult: Equatable {
    case saved
    case rejected(message: String)        // in case of freeze
    case unexpected(message: String?)     // unrecognized server response
}

enum RemoveShiftResult: Equatable {
    case removed
    case notFound
    case unexpected(message: String?)
}


enum FetchShiftError: Error, LocalizedError {
    case invalidDate(Date)

    var errorDescription: String? {
        switch self {
        case .invalidDate(let d): return "Invalid date: \(d)"
        }
    }
}

enum ShiftConversionError: Error {
    case invalidStartHour(Int)
    case invalidEndHour(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidStartHour(let h): return "Invalid starting hour: \(h)"
        case .invalidEndHour(let h): return "Invalid ending hour: \(h)"
        }
    }
}


