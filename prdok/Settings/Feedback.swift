//
//  Feedback.swift
//  prdok
//
//  Created by David Horňák on 25.09.2026.
//

import UIKit

/// Feedback goes by email: the user's own mail app opens on a draft to the developer, with a block
/// of build and device details under a space for the user's own words.
enum Feedback {

    static let address = "taf.fs.dev@gmail.com"

    /// A mailto link with the subject and body filled in. Opened through `openURL`, it goes to
    /// whichever mail app the user has set as default, not only Apple Mail.
    static var mailURL: URL? {
        let body = String(localized: "settings.feedback.prompt") + "\n\n\n\n" + diagnostics
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Prdok feedback \(appVersion)"),
            // The mailto standard (RFC 6068) wants line breaks in the body as CRLF; Gmail throws
            // away the bare LF that Swift strings use, leaving the whole body on one line.
            URLQueryItem(name: "body", value: body.replacingOccurrences(of: "\n", with: "\r\n")),
        ]
        return components.url
    }

    /// What a bug report needs to be reproduced: which build, which iOS, which phone, which language.
    /// Deliberately nothing about the account; the pairing identifiers stay out of email. English
    /// whatever the app language, since the developer reads it.
    private static var diagnostics: String {
        #if DEBUG
        let buildType = " debug"
        #else
        let buildType = ""
        #endif
        return """
        -- app install information --
        App: \(appVersion) (\(buildNumber))\(buildType)
        iOS: \(UIDevice.current.systemVersion)
        Device: \(deviceModel)
        Language: \(Bundle.main.preferredLocalizations.first ?? "?")
        """
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// The hardware identifier, e.g. "iPhone15,2"; `UIDevice.model` only ever says "iPhone".
    /// The simulator reports the Mac's CPU there, so it reads the model being simulated instead.
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (Simulator)"
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
