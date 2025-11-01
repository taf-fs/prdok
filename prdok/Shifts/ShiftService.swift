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
}

enum FetchShiftError: Error, LocalizedError {
    case invalidDate(Date)

    var errorDescription: String? {
        switch self {
        case .invalidDate(let d): return "Invalid date: \(d)"
        }
    }
}
