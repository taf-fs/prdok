//
//  FreeShiftService.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  Fetches the employee portal page and scrapes the free shifts ("Handlování směn").
//  There is no JSON API for these, so we request the HTML and parse it.
//
//  Auth: the PHP session is bootstrapped/refreshed purely from the `ids`+`id` query
//  parameters, so every request is self-sufficient. `URLSession` manages the
//  `PHPSESSID` cookie on its own — we deliberately don't touch cookies here.
//

import Foundation
import os

enum FreeShiftService {

    /// Fetches the list of free shifts from `zamestnanci.php`.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"id"`,`"ids"` or `"provoz"` are absent from `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be built.
    ///   - `URLError(.badServerResponse)` if the HTTP status is not 2xx.
    static func fetchFreeShifts() async throws -> [FreeShift] {
        guard
            let id = UserDefaults.standard.string(forKey: "id"),
            let ids = UserDefaults.standard.string(forKey: "ids"),
            let provoz = UserDefaults.standard.string(forKey: "provoz")
        else {
            throw PairingManager.PairingError.missingCredentials
        }

        var components = URLComponents(string: "\(AppConfig.apiBaseURL)/nasi/zamestnanci.php")
        // Send ids+id on every request so the session is always (re)established.
        components?.queryItems = [
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "provoz", value: provoz)
        ]
        guard let url = components?.url else {
            throw PairingManager.PairingError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let html = decodeHTML(data)
        return FreeShiftParser.parse(html: html)
    }

    /// Decodes the response body to a `String`. The portal declares `charset=UTF-8`;
    /// if a stray byte makes strict UTF-8 decoding fail, fall back to ISO Latin 1
    /// (which never fails) so one bad byte can't wipe out the whole page.
    private static func decodeHTML(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        Log.shifts.notice("FreeShiftService: response was not valid UTF-8; falling back to isoLatin1.")
        return String(data: data, encoding: .isoLatin1) ?? ""
    }
}
