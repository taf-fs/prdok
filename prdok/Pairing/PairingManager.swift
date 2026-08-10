//
//  PairingManager.swift
//  prdok
//
//  Created by David Horňák on 22.10.2025.
//

import Foundation



class PairingManager {
    static let shared = PairingManager()
    
    enum PairingError: Error {
        case invalidURL
        case invalidResponse
        case missingKeyInResponse
        case invalidQR
        case missingCredentials
        case missingSkladnik
        /// The server answered 200 but refused to connect the account (unknown id/ids, missing email, malformed key).
        /// `serverMessage` carries its `err` text, which is already user-readable.
        case pairingRejected(serverMessage: String?)
    }
    
    /// validateQR() checks whether the parameter scanned from the QR code on the employee link conforms to the format specified on the
    /// backend: `zapp|klic|cp_zamestnanci|44|77yGdor8El|kavarna`
    func validateQR(_ codeContent: String) -> Bool {
        let parameters = codeContent.split(separator: "|")
        return parameters.count == 6
    }
    
    /// validateCredentials checks whether the credentials typed in by the user are all present, ignoring surrounding whitespace.
    func validateCredentials(id: String, ids: String, provoz: String) -> Bool {
        [id, ids, provoz].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// validateLink checks whether the link provided by the user is a valid URL, and contains the parameters id, ids, provoz.
    /// example URL: `https://lorem.ipsum.com/lorem/ipsum.php?ids=SECRET123&id=123&provoz=asd`
    func validateLink(_ link: String) -> Bool {
        guard
            let url = URL(string: link),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else { return false }
        
        let includedParameters = Set(queryItems.map { $0.name })
        return ["id", "ids", "provoz"].allSatisfy(includedParameters.contains)
    }
        
    // MARK: - Parsing
    /// parseLink(_:) extracts the "id", "ids" and "provoz" query parameters from a link.
    ///
    /// - Parameter link: A full URL string expected to contain `id`, `ids` and `provoz` as query items.
    /// - Returns: A tuple `(id, ids, provoz)` if both parameters are present and non-empty; otherwise `nil`.
    /// - Note: Call `validateLink(_:)` before using this method to quickly rule out malformed links.
    private func parseLink(_ link: String) -> (id: String, ids: String, provoz: String)? {
        guard
            let components = URLComponents(string: link),
            let items = components.queryItems,
            let id = items.first(where: { $0.name == "id" })?.value,
            let ids = items.first(where: { $0.name == "ids" })?.value,
            let provoz = items.first(where: {$0.name == "provoz"})?.value,
            !id.isEmpty, !ids.isEmpty, !provoz.isEmpty
        else { return nil }
        return (id, ids, provoz)
    }

    /// parseQR(_:) parses the employee QR payload and extracts the `id`, `ids` and `provoz` fields.
    ///
    /// Expected format (6 pipe-separated parts): `zapp|klic|cp_zamestnanci|id|ids|provoz
    ///
    /// - Parameter content: The raw string scanned from the QR code.
    /// - Returns: A tuple `(id, ids, provoz)` if the content is valid; otherwise `nil`.
    /// - SeeAlso: `validateQR(_:)`
    private func parseQR(_ content: String) -> (id: String, ids: String, provoz: String)? {
        guard validateQR(content) else { return nil }
        let parts = content.split(separator: "|")
        // format: zapp|klic|cp_zamestnanci|id|ids|provoz
        return (String(parts[3]), String(parts[4]), String(parts[5]))
    }
    
    // MARK: - Response reading
    /// The server answers every outcome — success and failure alike — with HTTP 200, and reports failures in `err`.
    /// That field is a plain string in some branches and an array of strings in others, so both shapes are read here.
    private func serverMessage(from obj: [String: Any]?) -> String? {
        switch obj?["err"] {
        case let message as String:
            return message.isEmpty ? nil : message
        case let messages as [Any]:
            let joined = messages.compactMap { $0 as? String }.joined(separator: " ")
            return joined.isEmpty ? nil : joined
        default:
            return nil
        }
    }

    /// `ulozsi` is a JSON object when the server has something to hand back, but an empty JSON *array* when it doesn't,
    /// so a plain dictionary cast has to tolerate the array form.
    private func ulozsi(from obj: [String: Any]?) -> [String: Any] {
        obj?["ulozsi"] as? [String: Any] ?? [:]
    }

    // MARK: Networking (async)
    /// requestKey(provoz:) asks the backend for a pairing key.
    ///
    /// Performs a POST to the pairing endpoint with form URL-encoded parameters. On success, the response JSON
    /// is parsed for `ulozsi.klic`. Nothing is persisted here — the key is only stored once pairing as a whole
    /// succeeds, so a failed attempt leaves no half-paired state behind.
    ///
    /// - Parameter provoz: The facility identifier extracted from the link, QR code or credential fields.
    /// - Returns: The pairing key string returned by the server.
    /// - Throws: `PairingError.invalidURL` if the endpoint URL is invalid; `PairingError.invalidResponse` for non-2xx responses;
    ///           `PairingError.missingKeyInResponse` if the expected key is absent from the JSON.
    /// - Note: The `err` message in this response is not an error signal. A device that isn't paired yet is answered with
    ///         "nerozpoznán zaměstnanec.", which is the expected state at this point in the flow.
    private func requestKey(provoz: String) async throws -> String {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else { throw PairingError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "klic": AppConfig.pairingInitKey,
            "akce": "init",
            "parametr": "",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }

        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let key = ulozsi(from: obj)["klic"] as? String, !key.isEmpty else {
            throw PairingError.missingKeyInResponse
        }

        print("Received key: \(key)")
        return key
    }

    /// connectKeyToAccount(id:ids:key:provoz:) links the obtained pairing key to a specific account on the backend,
    /// and persists the whole credential set once the server confirms the account was found.
    ///
    /// A wrong `id`/`ids`/`provoz` combination still comes back as HTTP 200, with the reason in `err` and an empty
    /// `ulozsi` — so success is decided by the presence of `ulozsi.zamid` and `ulozsi.zamids`. Those are the values the
    /// server resolved for the account (via its email), and they are what gets stored, rather than what the user typed.
    /// Nothing is written to `UserDefaults` unless pairing actually went through.
    ///
    /// - Parameters:
    ///   - id: Employee identifier parsed from a link or QR, or typed in by the user.
    ///   - ids: Secret token or secondary identifier parsed from a link or QR, or typed in by the user.
    ///   - key: Pairing key previously obtained via `requestKey(provoz:)`.
    ///   - provoz: The facility identifier.
    /// - Throws: `PairingError.invalidURL` if the endpoint URL is invalid; `PairingError.invalidResponse` for non-2xx responses;
    ///           `PairingError.pairingRejected` if the server did not connect the account, carrying its `err` message.
    private func connectKeyToAccount(id: String, ids: String, key: String, provoz: String) async throws {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else { throw PairingError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "klic": key,
            "akce": "propojit_klicem",
            "parametr": "zapp|\(key)|\(provoz)_zamestnanci|\(id)|\(ids)|\(provoz)",
            "provoz": provoz
        ]
        request.httpBody = params.formURLEncodedData()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }

        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let ulozsi = ulozsi(from: obj)

        // The employee the server actually matched. Absent means it matched nobody, whatever the HTTP status says.
        guard
            let employeeID = ulozsi["zamid"] as? String, !employeeID.isEmpty,
            let employeeIDS = ulozsi["zamids"] as? String, !employeeIDS.isEmpty
        else {
            print("Pairing rejected by server: \(serverMessage(from: obj) ?? "no message")")
            throw PairingError.pairingRejected(serverMessage: serverMessage(from: obj))
        }

        let confirmedProvoz = (ulozsi["provoz"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? provoz

        UserDefaults.standard.setValue(key, forKey: "klic")
        UserDefaults.standard.setValue(employeeID, forKey: "id")
        UserDefaults.standard.setValue(employeeIDS, forKey: "ids")
        UserDefaults.standard.setValue(confirmedProvoz, forKey: "provoz")
        if let skladnik = ulozsi["lidauths"] as? String, !skladnik.isEmpty {
            UserDefaults.standard.setValue(skladnik, forKey: "skladnik")
        }
        print("Connected device to account and set employee credentials to UserDefaults")
    }

    /// Unpairs the currently paired device from the employee account and clears local credentials.
    ///
    /// Sends a POST request with the `odparovat` action and the current `klic`, `id`, `ids`, and `provoz` values.
    /// On a successful 2xx response, removes the corresponding keys from `UserDefaults`.
    ///
    /// - Throws: `PairingError.missingCredentials` if any of the required values are absent in `UserDefaults`;
    ///           `PairingError.invalidURL` if the endpoint URL is invalid;
    ///           `PairingError.invalidResponse` if the server responds with a non-2xx status code.
    private func unpairDeviceFromAccount() async throws {
        guard
            let key = UserDefaults.standard.string(forKey: "klic"),
            let provoz = UserDefaults.standard.string(forKey: "provoz")
        else {
            throw PairingError.missingCredentials
        }

        guard let url = URL(string: "\(AppConfig.apiBaseURL)/zapp/hello.php") else { throw PairingError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = [
            "klic=\(key)",
            "akce=odparovat",
            "parametr=",
            "provoz=\(provoz)"
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }

        UserDefaults.standard.removeObject(forKey: "klic")
        UserDefaults.standard.removeObject(forKey: "id")
        UserDefaults.standard.removeObject(forKey: "ids")
        UserDefaults.standard.removeObject(forKey: "provoz")
        print("Removed employee credentials and device key from account.")
    }
    
    // MARK: - "Public" API
    /// connectAccountUsingLink(_:) validates a link, requests/obtains a pairing key, and associates it with the account.
    ///
    /// - Parameter link: A URL string that includes `id`, `ids`, and `provoz` query parameters.
    /// - Throws: `PairingError.invalidURL` if validation or parsing fails; any error thrown by `requestKey(provoz:)`
    ///           or `connectKeyToAccount(id:ids:key:provoz:)`.
    func connectAccountUsingLink(_ link: String) async throws {
        guard validateLink(link), let parsed = parseLink(link) else {
            throw PairingError.invalidURL
        }
        let key = try await requestKey(provoz: parsed.provoz)
        try await connectKeyToAccount(id: parsed.id, ids: parsed.ids, key: key, provoz: parsed.provoz)
    }

    /// connectAccountUsingCredentials(id:ids:provoz:) requests/obtains a pairing key and associates it with the account,
    /// using the credentials the user typed in by hand instead of a link or QR code.
    ///
    /// - Parameters:
    ///   - id: Employee identifier.
    ///   - ids: Secret token or secondary identifier.
    ///   - provoz: The facility identifier.
    /// - Throws: `PairingError.missingCredentials` if any of the values is empty; any error thrown by `requestKey(provoz:)`
    ///           or `connectKeyToAccount(id:ids:key:provoz:)`.
    func connectAccountUsingCredentials(id: String, ids: String, provoz: String) async throws {
        guard validateCredentials(id: id, ids: ids, provoz: provoz) else {
            throw PairingError.missingCredentials
        }
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let ids = ids.trimmingCharacters(in: .whitespacesAndNewlines)
        let provoz = provoz.trimmingCharacters(in: .whitespacesAndNewlines)

        let key = try await requestKey(provoz: provoz)
        try await connectKeyToAccount(id: id, ids: ids, key: key, provoz: provoz)
    }

    /// connectAccountUsingQR(_:) validates a QR payload, requests/obtains a pairing key, and associates it with the account.
    ///
    /// - Parameter codeContent: The raw QR string `zapp|klic|cp_zamestnanci|id|ids|provoz`.
    /// - Throws: `PairingError.invalidQR` if validation fails; any error thrown by `requestKey(provoz:)`
    ///           or `connectKeyToAccount(id:ids:key:provoz:)`.
    func connectAccountUsingQR(_ codeContent: String) async throws {
        guard let parsed = parseQR(codeContent) else {
            throw PairingError.invalidQR
        }
        let key = try await requestKey(provoz: parsed.provoz)
        try await connectKeyToAccount(id: parsed.id, ids: parsed.ids, key: key, provoz: parsed.provoz)
    }
    
    /// Unpairs the device from the currently connected account.
    ///
    /// Convenience wrapper that invokes the internal unpairing routine and propagates any errors.
    ///
    /// - Throws: Any error thrown by `unpairDeviceFromAccount()`.
    func unpairDevice() async throws {
        try await unpairDeviceFromAccount()
    }
}

extension PairingManager.PairingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("pairingerror.invalidURL", comment: "Invalid URL error")
        case .invalidResponse:
            return NSLocalizedString("pairingerror.invalidResponse", comment: "Invalid response error")
        case .missingKeyInResponse:
            return NSLocalizedString("pairingerror.missingkey", comment: "Missing key in response error")
        case .invalidQR:
            return NSLocalizedString("pairingerror.invalidQR", comment: "Invalid QR error")
        case .missingCredentials:
            return NSLocalizedString("pairingerror.missingCredentials", comment: "Missing Credentials")
        case .missingSkladnik:
            return NSLocalizedString("pairingerror.missingSkladnik", comment: "Missing Skladnik")
        case .pairingRejected(let serverMessage):
            return serverMessage ?? NSLocalizedString("pairingerror.pairingRejected", comment: "Server refused to pair")
        }
    }
}
