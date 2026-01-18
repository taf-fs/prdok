//
//  ShiftService.swift
//  prdok
//
//  Created by David Horňák on 28.10.2025.
//

import Foundation

struct ShiftService {
    static private func formatDateToYearAndMonthString(date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    /// fetchShifts(date:) calls the backend for the shift data specified by the `kdy` parameter, which can be either in the format "yyyy", "yyyy-MM" and "yyyy-MM-dd.
    /// **For now it's always requesting a month worth of shift data.**
    ///
    /// - Parameters:
    ///   - date: Date the function should fetch year/month/day worth of  shifts from.
    ///
    static func fetchShifts(date: Date) async throws -> [Shift] {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let when = formatDateToYearAndMonthString(date: date) else {
            throw FetchShiftError.invalidDate(date)
        }
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = [
            "klic=\(key)",
            "akce=mojesmeny",
            "kdy=\(when)",
            "parametr=",
            "provoz=cp" // also hardcode
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try ShiftParser.decodeShifts(from: data)
    }
    
    static func offerShift(when: Date, start: Int, end: Int) async throws -> Bool {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        let (shiftDayOfYear, startHour, endHour) = try convertOfferedShiftToParams(when: when, start: start, end: end)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = [
            "klic=\(key)",
            "akce=pridatmoznost",
            "kdy=\(shiftDayOfYear)", // yyyy-mm-dd
            "od=\(startHour)", // hh:mm:ss
            "do=\(endHour)",    // hh:mm:ss
            "parametr=",
            "provoz=cp" // also hardcode
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        
        // TODO: CHECK FOR RESPONSE, COMMUNICATE BACK TO THE APP WHETHER SUCCESS OR NOT
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return false // temp placement
    }
    
    static func removeShift(shift: Shift) async throws -> Bool {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = [
            "klic=\(key)",
            "akce=smazatmoznost",
            "smenaid=\(shift.id)", // server id of shift
            "parametr=",
            "provoz=cp" // also hardcode
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        
        // TODO: CHECK FOR RESPONSE, COMMUNICATE BACK TO THE APP WHETHER SUCCESS OR NOT
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return false // temp placement
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
    static func convertOfferedShiftToParams(when: Date, start: Int, end: Int) throws -> (shiftDayOfYear: String, startHour: String, endHour: String) {
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
