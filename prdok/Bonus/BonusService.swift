//
//  BonusService.swift
//  prdok
//
//  Created by David Horňák on 20.09.2026.
//

//
//  The payload is loosely typed: the same field arrives as a JSON string in one month
//  and a number in the next, hours can be fractional, and two keys go missing entirely
//  in perfectly normal months. Everything below decodes leniently on purpose.
//

import Foundation
import os

enum BonusService {

    /// Fetches the pay structure for the month containing `date`.
    ///
    /// Sends `akce=mzdastruktura` with `rokmesic` as `"yyyy-MM"`. Future months answer
    /// normally (zeros, `historie = 3`), so no month needs special-casing.
    ///
    /// - Throws:
    ///   - `PairingManager.PairingError.missingCredentials` if `"klic"` or `"provoz"` are absent from `UserDefaults`.
    ///   - `PairingManager.PairingError.invalidURL` if the endpoint URL cannot be built.
    ///   - `URLError(.badServerResponse)` if the HTTP status is not 2xx.
    ///   - `BonusError.serverError` if the server reported a problem in `err`.
    ///   - `BonusError.unavailable` if the response carried no pay structure at all.
    static func fetchBonus(for date: Date) async throws -> MonthBonus {
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
            "akce": "mzdastruktura",
            "rokmesic": month,
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let started = ContinuousClock.now
        Log.bonus.info("[BonusService] → akce=mzdastruktura rokmesic=\(month, privacy: .public) provoz=\(provoz, privacy: .public)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.bonus.error("[BonusService] ← \(month, privacy: .public) HTTP \(status) — bad response")
            throw URLError(.badServerResponse)
        }

        let envelope: BonusEnvelope
        do {
            envelope = try JSONDecoder().decode(BonusEnvelope.self, from: data)
        } catch {
            Log.bonus.error("[BonusService] ← \(month, privacy: .public) decode failed after \(data.count) B: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        if let bonus = envelope.bonus {
            Log.bonus.info("[BonusService] ← \(month, privacy: .public) HTTP \(http.statusCode), \(data.count) B, \(Log.ms(since: started)) ms — \(bonus.score)/\(bonus.maxScore), bonus \(bonus.earned ? "earned" : "not earned")")
            return bonus
        }
        if let message = envelope.errors.first {
            Log.bonus.error("[BonusService] ← \(month, privacy: .public) server error: \(message, privacy: .public)")
            throw BonusError.serverError(message)
        }
        Log.bonus.error("[BonusService] ← \(month, privacy: .public) no mzdastruktura in response (\(data.count) B)")
        throw BonusError.unavailable(month: month)
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

/// The `mzdastruktura` response. The pay structure is absent whenever the request was
/// rejected (a missing or malformed `rokmesic`, an unrecognised device key), and the
/// reason is then in `err`.
struct BonusEnvelope: Decodable {
    let bonus: MonthBonus?
    let errors: [String]

    private enum CodingKeys: String, CodingKey {
        case structure = "mzdastruktura"
        case errors = "err"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bonus = (try? container.decode(RawBonus.self, forKey: .structure))?.model

        // `err` is an array of strings for most failures, but a bare string for the
        // "nerozpoznán zaměstnanec" gate — and an object for some other akce. A parser
        // that only tries `[String]` silently loses the message.
        if let lines = try? container.decode([String].self, forKey: .errors) {
            errors = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else if let line = try? container.decode(String.self, forKey: .errors) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            errors = trimmed.isEmpty ? [] : [trimmed]
        } else {
            errors = []
        }
    }
}

/// The wire shape of `mzdastruktura`, decoded leniently and mapped to `MonthBonus`.
///
/// Only the fields the statistics block shows are read. The response also carries the
/// employee's wage table (`zaklad`, `hodinovabezna`, …) and the competency name lists;
/// they are deliberately left in the response, never parsed, cached or logged.
private struct RawBonus: Decodable {
    let model: MonthBonus

    private enum CodingKeys: String, CodingKey {
        case historie
        case kompetence
        case priplatek
    }

    private enum CompetencyKeys: String, CodingKey {
        case macount
        case tenhlemesic
    }

    private enum BonusKeys: String, CodingKey {
        case skore, maxskore, zoliku, pouzilzoliku, maho, hodnota
        case vikendnabizi, vikendlimit, vikendsplnil
        case zavirackynabidl, zavirackynabidllimit
        case zavirackyodpracoval, zavirackyodpracovallimit
        case zavirackysplnil
        case nabidnutohodin, nabidnutolimit
        case odpracovanohodin, odpracovanolimit
        case hodinysplnil
        case ucastnaschuzi, ucastnaschuzitext
        case splnilkompetence
        case nabidlhodindolimitu, limitmusidathodinmoznostidolimitu
        case datumlimitzapsanimoznosti, splnilnabidkudolimitu
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        let p = try root.nestedContainer(keyedBy: BonusKeys.self, forKey: .priplatek)
        let k = try? root.nestedContainer(keyedBy: CompetencyKeys.self, forKey: .kompetence)

        let score = p.lenientInt(.skore) ?? 0
        let maxScore = p.lenientInt(.maxskore) ?? 0
        let gained = k?.lenientString(.tenhlemesic) ?? ""

        model = MonthBonus(
            score: score,
            maxScore: maxScore,
            jokers: p.lenientInt(.zoliku) ?? 0,
            // The key is missing entirely in months where the bonus wasn't earned.
            jokersUsed: p.lenientInt(.pouzilzoliku) ?? 0,
            earned: p.lenientFlag(.maho),
            bonusCzkPerHour: p.lenientInt(.hodnota) ?? 0,
            monthState: root.lenientInt(.historie) ?? 0,
            weekendHours: BonusCondition(
                met: p.lenientFlag(.vikendsplnil),
                value: p.lenientInt(.vikendnabizi),
                required: p.lenientInt(.vikendlimit)
            ),
            closingShifts: BonusEither(
                met: p.lenientFlag(.zavirackysplnil),
                offered: p.side(value: .zavirackynabidl, required: .zavirackynabidllimit),
                worked: p.side(value: .zavirackyodpracoval, required: .zavirackyodpracovallimit)
            ),
            hours: BonusEither(
                met: p.lenientFlag(.hodinysplnil),
                offered: p.side(value: .nabidnutohodin, required: .nabidnutolimit),
                // Arrives as a decimal with the unpaid breaks already deducted (42.4),
                // and is rounded once, here, so nothing downstream rounds it again.
                worked: p.side(value: .odpracovanohodin, required: .odpracovanolimit)
            ),
            meeting: BonusCondition(met: p.lenientFlag(.ucastnaschuzi)),
            meetingNote: p.lenientString(.ucastnaschuzitext),
            earlyOffers: BonusCondition(
                met: p.lenientFlag(.splnilnabidkudolimitu),
                // `null` here means nothing was entered in time — that is a 0, not an unknown.
                value: p.lenientInt(.nabidlhodindolimitu) ?? 0,
                required: p.lenientInt(.limitmusidathodinmoznostidolimitu)
            ),
            earlyOffersDeadline: RawBonus.day(from: p.lenientString(.datumlimitzapsanimoznosti)),
            competencies: BonusCondition(
                met: p.lenientFlag(.splnilkompetence),
                value: k?.lenientInt(.macount)
            ),
            competencyGained: gained.isEmpty ? nil : gained
        )
    }

    /// `"2026-02-16"` → a date in the current time zone, so formatting it back for the
    /// deadline note lands on the same day the portal announced.
    private static func day(from string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: string)
    }
}

// MARK: - Lenient reads

private extension KeyedDecodingContainer {
    /// Reads a number however this month happened to encode it: `12`, `"12"`, `42.4`
    /// or `null`. Fractions are rounded here and only here (`42.4 → 42`); every value
    /// in this payload is ≥ 0, where `rounded()` is the plain half-up rounding payroll
    /// uses. `nil` when the key is missing or holds something unreadable.
    func lenientInt(_ key: K) -> Int? {
        if let int = try? decode(Int.self, forKey: key) { return int }
        if let double = try? decode(Double.self, forKey: key) { return Int(double.rounded()) }
        guard let string = try? decode(String.self, forKey: key) else { return nil }
        if let int = Int(string) { return int }
        if let double = Double(string) { return Int(double.rounded()) }
        return nil
    }

    /// A 0/1 condition flag. A missing or unreadable flag counts as not met.
    func lenientFlag(_ key: K) -> Bool {
        (lenientInt(key) ?? 0) == 1
    }

    /// A trimmed string; `""` when the key is missing, null or not a string.
    func lenientString(_ key: K) -> String {
        guard let string = try? decode(String.self, forKey: key) else { return "" }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One side of a two-sided condition. Its `met` colours that side's number; the
    /// condition's own verdict always comes from the server's flag, never from here.
    func side(value: K, required: K) -> BonusCondition {
        let have = lenientInt(value) ?? 0
        let need = lenientInt(required) ?? 0
        return BonusCondition(met: have >= need, value: have, required: need)
    }
}

enum BonusError: Error, LocalizedError {
    case serverError(String)
    case unavailable(month: String)

    var errorDescription: String? {
        switch self {
        case .serverError(let message): return message
        case .unavailable(let month): return "No pay structure returned for \(month)"
        }
    }
}
