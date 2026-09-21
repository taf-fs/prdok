//
//  OpenDaysService.swift
//  prdok
//
//  Created by David Horňák on 24.07.2026.
//
//  Fetches how many days the provoz is actually open in a given month via the
//  `otevrene_dny` API akce, which `ShiftStatisticsView` scales the monthly requirements
//  by instead of the raw calendar day count.
//
//  That scaling is now a fallback path. Since `mzdastruktura` landed, the statistics take
//  every limit straight from that payload, and the count fetched here is only consulted
//  when it is missing.
//

import Foundation
import os

enum OpenDaysService {

    /// Fetches the open-day count for the month containing `date`.
    ///
    /// Sends `akce=otevrene_dny` with `rokmesic` as `"yyyy-MM"`.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` or `"provoz"` are absent from `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be built.
    ///   - `URLError(.badServerResponse)` if the HTTP status is not 2xx.
    ///   - `OpenDaysError.serverError` if the server reported a problem in `err`.
    ///   - `OpenDaysError.unavailable` if the server returned no usable count.
    static func fetchOpenDays(for date: Date) async throws -> Int {
        guard let key = UserDefaults.standard.string(forKey: "klic") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let provoz = UserDefaults.standard.string(forKey: "provoz") else {
            throw PairingManager.PairingError.missingCredentials
        }
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else {
            throw PairingManager.PairingError.invalidURL
        }

        let month = monthString(from: date)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "klic": key,
            "akce": "otevrene_dny",
            "rokmesic": month,
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let started = ContinuousClock.now
        Log.openDays.info("[OpenDaysService] → akce=otevrene_dny rokmesic=\(month, privacy: .public) provoz=\(provoz, privacy: .public)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.openDays.error("[OpenDaysService] ← \(month, privacy: .public) HTTP \(status) — bad response")
            throw URLError(.badServerResponse)
        }

        let envelope: OpenDaysEnvelope
        do {
            envelope = try JSONDecoder().decode(OpenDaysEnvelope.self, from: data)
        } catch {
            Log.openDays.error("[OpenDaysService] ← \(month, privacy: .public) decode failed after \(data.count) B: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        if let openDays = envelope.openDays {
            Log.openDays.info("[OpenDaysService] ← \(month, privacy: .public) HTTP \(http.statusCode), \(data.count) B, \(Log.ms(since: started)) ms — \(openDays) open day(s)")
            return openDays
        }
        if let message = envelope.errors.first {
            Log.openDays.error("[OpenDaysService] ← \(month, privacy: .public) server error: \(message, privacy: .public)")
            throw OpenDaysError.serverError(message)
        }
        // `otevrenodnu` came back as `false`/unusable with no explanation in `err`.
        Log.openDays.error("[OpenDaysService] ← \(month, privacy: .public) no usable otevrenodnu in response (\(data.count) B)")
        throw OpenDaysError.unavailable(month: month)
    }

    /// `rokmesic` format expected by the backend (`^\d{4}-\d{2}$`).
    static func monthString(from date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM"
        return df.string(from: date)
    }
}

// MARK: - Incoming JSON DTO

/// The `otevrene_dny` response. `otevrenodnu` is inconsistently typed: it comes back
/// as a JSON string (`"30"`), a number (`31`), or `false` when the server could not
/// compute it — and it is absent entirely when `rokmesic` was rejected, in which case
/// the reason is in `err`.
struct OpenDaysEnvelope: Decodable {
    let openDays: Int?
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case openDays = "otevrenodnu"
        case errors = "err"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let number = try? container.decode(Int.self, forKey: .openDays) {
            openDays = number
        } else if let string = try? container.decode(String.self, forKey: .openDays) {
            openDays = Int(string)
        } else {
            openDays = nil
        }

        // `err` is `[]` when fine; other akce return it as an object, so stay lenient.
        errors = (try? container.decode([String].self, forKey: .errors)) ?? []
    }
}

enum OpenDaysError: Error, LocalizedError {
    case serverError(String)
    case unavailable(month: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        case .unavailable(let month): return "No open-day count returned for \(month)"
        }
    }
}
