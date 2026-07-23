//
//  FreeShiftService.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  Fetches the free shifts ("Handlování směn") via the `smeny_handl` API akce.
//  Same endpoint/credentials as `ShiftService.fetchShifts` (`klic` + `provoz`).
//

import Foundation
import os

enum FreeShiftService {

    /// Fetches the list of free shifts from `hello.php` via the `smeny_handl` akce.
    ///
    /// The server returns at most 200 shifts, and an empty array when there are none.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` or `"provoz"` are absent from `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be built.
    ///   - `URLError(.badServerResponse)` if the HTTP status is not 2xx.
    ///   - Any error thrown by `FreeShiftParser.decode(from:)` (JSON decoding / parsing failures).
    static func fetchFreeShifts() async throws -> [FreeShift] {
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
            "akce": "smeny_handl",
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try FreeShiftParser.decode(from: data)
    }
}
