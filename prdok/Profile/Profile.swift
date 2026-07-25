//
//  Profile.swift
//  prdok
//
//  The signed-in employee's own profile ("moje data"), fetched via the `mojedata`
//  API akce and decoded by `ProfileParser`. We surface only a subset of the fields:
//  the short name, the start date and the seven competencies.
//

import SwiftUI

/// One of the seven competencies ("kompetence") an employee can gain. The raw case
/// values match the `kompetence1`…`kompetence7` suffixes in the API response.
enum Competency: Int, CaseIterable, Identifiable {
    case generalSkills = 1  // obecné dovednosti
    case placar             // placař
    case barman             // barman
    case vrchni             // vrchní
    case vycep              // výčep
    case barista            // barista
    case kuchar             // kuchař

    var id: Int { rawValue }

    /// Localized display name. Keys are defined in `Localizable.xcstrings`.
    var titleKey: LocalizedStringKey {
        switch self {
        case .generalSkills: return "profile.competency.generalSkills"
        case .placar:        return "profile.competency.placar"
        case .barman:        return "profile.competency.barman"
        case .vrchni:        return "profile.competency.vrchni"
        case .vycep:         return "profile.competency.vycep"
        case .barista:       return "profile.competency.barista"
        case .kuchar:        return "profile.competency.kuchar"
        }
    }
}

/// A competency together with when it was gained. `gained` is `nil` when the API
/// reports `"0"`, i.e. the competency hasn't been achieved yet.
struct CompetencyStatus: Identifiable {
    let competency: Competency
    /// First day of the month the competency was gained, or `nil` if not gained.
    let gained: Date?

    var id: Int { competency.id }
}

struct Profile {
    /// The short name (`jmeno`), e.g. "David H." — not the full `jmenocele`.
    let name: String
    /// Employment start date (`datum_nastup`).
    let startDate: Date
    /// All seven competencies, ordered, each with its gained month (or `nil`).
    let competencies: [CompetencyStatus]
}

// MARK: - Incoming JSON DTOs

/// The `mojedata` akce returns the profile alongside the usual session envelope; we
/// only care about the `mojedata` object.
struct ProfileEnvelope: Decodable {
    let data: RawProfile

    enum CodingKeys: String, CodingKey {
        case data = "mojedata"
    }
}

struct RawProfile: Decodable {
    let jmeno: String
    let datumNastup: String   // "yyyy-MM-dd"
    let kompetence1: String   // "yyyyMM" or "0"
    let kompetence2: String
    let kompetence3: String
    let kompetence4: String
    let kompetence5: String
    let kompetence6: String
    let kompetence7: String

    enum CodingKeys: String, CodingKey {
        case jmeno
        case datumNastup = "datum_nastup"
        case kompetence1, kompetence2, kompetence3, kompetence4
        case kompetence5, kompetence6, kompetence7
    }

    /// Competency raw values in `Competency` order, so the parser can zip them.
    var competenceRawValues: [String] {
        [kompetence1, kompetence2, kompetence3, kompetence4, kompetence5, kompetence6, kompetence7]
    }
}
