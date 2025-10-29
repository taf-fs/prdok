//
//  ShiftService.swift
//  prdok
//
//  Created by David Horňák on 28.10.2025.
//

import Foundation

struct ShiftService {
    static private func formatDateToYearString(date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    
    static func fetchShifts(date: Date) async throws -> [Shift] {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let when = formatDateToYearString(date: date) else {
            throw ParseError.invalidDate(date)
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


// TODO: get rid of this
enum ParseError: Error, LocalizedError {
    case invalidDate(Date)

    var errorDescription: String? {
        switch self {
        case .invalidDate(let d): return "Invalid date: \(d)"
        }
    }
}
