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
        case invalidLink
        case invalidQR
        case missingCredentials
    }
    
    /// validateQR() checks whether the parameter scanned from the QR code on the employee link conforms to the format specified on the
    /// backend: `zapp|klic|cp_zamestnanci|44|77yGdor8El|cp`
    func validateQR(_ codeContent: String) -> Bool {
        let parameters = codeContent.split(separator: "|")
        return parameters.count == 6
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
    /// parseLink(_:) extracts the "id" and "ids" query parameters from a link.
    ///
    /// - Parameter link: A full URL string expected to contain `id` and `ids` as query items.
    /// - Returns: A tuple `(id, ids)` if both parameters are present and non-empty; otherwise `nil`.
    /// - Note: Call `validateLink(_:)` before using this method to quickly rule out malformed links.
    private func parseLink(_ link: String) -> (id: String, ids: String)? {
        guard
            let components = URLComponents(string: link),
            let items = components.queryItems,
            let id = items.first(where: { $0.name == "id" })?.value,
            let ids = items.first(where: { $0.name == "ids" })?.value,
            !id.isEmpty, !ids.isEmpty
        else { return nil }
        return (id, ids)
    }

    /// parseQR(_:) parses the employee QR payload and extracts the `id` and `ids` fields.
    ///
    /// Expected format (6 pipe-separated parts): `zapp|klic|cp_zamestnanci|id|ids|cp`
    ///
    /// - Parameter content: The raw string scanned from the QR code.
    /// - Returns: A tuple `(id, ids)` if the content is valid; otherwise `nil`.
    /// - SeeAlso: `validateQR(_:)`
    private func parseQR(_ content: String) -> (id: String, ids: String)? {
        guard validateQR(content) else { return nil }
        let parts = content.split(separator: "|")
        // format: zapp|klic|cp_zamestnanci|id|ids|cp
        return (String(parts[3]), String(parts[4]))
    }
    
    // MARK: Networking (async)
    /// requestAndSaveKey() initializes and persists a pairing key by calling the backend.
    ///
    /// Performs a POST to the pairing endpoint with form URL-encoded parameters. On success, the response JSON
    /// is parsed for `ulozsi.klic`. The key is saved to `UserDefaults` under the key `"klic"` and also returned.
    ///
    /// - Returns: The pairing key string returned by the server.
    /// - Throws: `PairingError.invalidURL` if the endpoint URL is invalid; `PairingError.invalidResponse` for non-2xx responses;
    ///           `PairingError.missingKeyInResponse` if the expected key is absent from the JSON.
    private func requestAndSaveKey() async throws -> String {
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else { throw PairingError.invalidURL } // harcoded for now
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = [
            "klic=nemamklic123", // server returns the key to save when key doesn't exist in DB
            "akce=init",
            "parametr=",
            "provoz=cp" // also hardcode
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }

        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let ulozsi = obj?["ulozsi"] as? [String: Any]
        guard let key = ulozsi?["klic"] as? String, !key.isEmpty else {
            throw PairingError.missingKeyInResponse
        }

        UserDefaults.standard.setValue(key, forKey: "klic")
        print("Received and saving key: \(key) to UserDefaults")
        return key
    }
    
    /// connectKeyToAccount(id:ids:key:) links the previously obtained pairing key to a specific account on the backend.
    ///
    /// Builds and posts the expected `parametr` payload using the provided values and treats any 2xx HTTP status as success.
    /// The response body is not inspected.
    ///
    /// - Parameters:
    ///   - id: Employee identifier parsed from a link or QR.
    ///   - ids: Secret token or secondary identifier parsed from a link or QR.
    ///   - key: Pairing key previously obtained via `requestAndSaveKey()`.
    /// - Throws: `PairingError.invalidURL` if the endpoint URL is invalid; `PairingError.invalidResponse` for non-2xx responses.
    private func connectKeyToAccount(id: String, ids: String, key: String) async throws {
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else { throw PairingError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = [
            "klic=\(key)",
            "akce=propojit_klicem",
            "parametr=zapp|\(key)|cp_zamestnanci|\(id)|\(ids)|cp",
            "provoz=cp"
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        // for now, fact that the request succeeded at the HTTP level is good enough, no need to work with the response data
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }
        
        UserDefaults.standard.setValue(id, forKey: "id")
        UserDefaults.standard.setValue(ids, forKey: "ids")
        print("Connected device to account and set employee credentials to UserDefaults")
    }
    
    /// Unpairs the currently paired device from the employee account and clears local credentials.
    ///
    /// Sends a POST request with the `odparovat` action and the current `klic`, `id`, and `ids` values.
    /// On a successful 2xx  response, removes the corresponding keys from `UserDefaults`.
    ///
    /// - Throws: `PairingError.missingCredentials` if any of the required values are absent in `UserDefaults`;
    ///           `PairingError.invalidURL` if the endpoint URL is invalid;
    ///           `PairingError.invalidResponse` if the server responds with a non-2xx status code.
    private func unpairDeviceFromAccount() async throws {
        guard
            let key = UserDefaults.standard.string(forKey: "klic"),
            let id = UserDefaults.standard.string(forKey: "id"),
            let ids = UserDefaults.standard.string(forKey: "ids")
        else {
            throw PairingError.missingCredentials
        }
        
        guard let url = URL(string: "https://streva.prostoru.cz/zapp/hello.php") else { throw PairingError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = [
            "klic=\(key)",
            "akce=odparovat",
            "parametr=zapp|\(key)|cp_zamestnanci|\(id)|\(ids)|cp",
            "provoz=cp"
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PairingError.invalidResponse
        }
        
        UserDefaults.standard.removeObject(forKey: "klic")
        UserDefaults.standard.removeObject(forKey: "id")
        UserDefaults.standard.removeObject(forKey: "ids")
        print("Removed employee credentials and device key from account.")
    }
    
    // MARK: - "Public" API
    /// connectAccountUsingLink(_:) validates a link, requests/obtains a pairing key, and associates it with the account.
    ///
    /// - Parameter link: A URL string that includes `id`, `ids`, and `provoz` query parameters.
    /// - Throws: `PairingError.invalidLink` if validation or parsing fails; any error thrown by `requestAndSaveKey()`
    ///           or `connectKeyToAccount(id:ids:key:)`.
    func connectAccountUsingLink(_ link: String) async throws {
        guard validateLink(link), let parsed = parseLink(link) else {
            throw PairingError.invalidLink
        }
        let key = try await requestAndSaveKey()
        try await connectKeyToAccount(id: parsed.id, ids: parsed.ids, key: key)
    }
    
    /// connectAccountUsingQR(_:) validates a QR payload, requests/obtains a pairing key, and associates it with the account.
    ///
    /// - Parameter codeContent: The raw QR string `zapp|klic|cp_zamestnanci|id|ids|cp`.
    /// - Throws: `PairingError.invalidQR` if validation fails; any error thrown by `requestAndSaveKey()`
    ///           or `connectKeyToAccount(id:ids:key:)`.
    func connectAccountUsingQR(_ codeContent: String) async throws {
        guard let parsed = parseQR(codeContent) else {
            throw PairingError.invalidQR
        }
        let key = try await requestAndSaveKey()
        try await connectKeyToAccount(id: parsed.id, ids: parsed.ids, key: key)
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
            return NSLocalizedString("The URL provided is invalid.", comment: "Invalid URL error")
        case .invalidResponse:
            return NSLocalizedString("The server response was invalid.", comment: "Invalid response error")
        case .missingKeyInResponse:
            return NSLocalizedString("The server response is missing the expected key.", comment: "Missing key in response error")
        case .invalidLink:
            return NSLocalizedString("The employee link appears to be malformed.", comment: "Invalid link error")
        case .invalidQR:
            return NSLocalizedString("The QR code does not match the expected format.", comment: "Invalid QR error")
        case .missingCredentials:
            return NSLocalizedString("The credentials required to unpair device are missing", comment: "Missing Credentials")
        }
    }
}
