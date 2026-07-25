//
//  ProfileService.swift
//  prdok
//
//  Fetches the signed-in employee's own profile via the `mojedata` API akce.
//  Same endpoint/credentials as `ShiftService.fetchShifts` (`klic` + `provoz`).
//

import Foundation
import os

enum ProfileService {

    /// Fetches the employee profile from `hello.php` via the `mojedata` akce.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` or `"provoz"` are absent from `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be built.
    ///   - `URLError(.badServerResponse)` if the HTTP status is not 2xx.
    ///   - Any error thrown by `ProfileParser.decode(from:)` (JSON decoding / parsing failures).
    static func fetchProfile() async throws -> Profile {
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
            "akce": "mojedata",
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let started = ContinuousClock.now
        Log.profile.info("[ProfileService] → akce=mojedata provoz=\(provoz, privacy: .public)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.profile.error("[ProfileService] ← mojedata HTTP \(status) — bad response")
            throw URLError(.badServerResponse)
        }

        do {
            let profile = try ProfileParser.decode(from: data)
            Log.profile.info("[ProfileService] ← mojedata HTTP \(http.statusCode), \(data.count) B, \(Log.ms(since: started)) ms")
            return profile
        } catch {
            Log.profile.error("[ProfileService] ← mojedata decode failed after \(data.count) B: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
