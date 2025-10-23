//
//  PairingManager.swift
//  prdok
//
//  Created by David Horňák on 22.10.2025.
//

import Foundation



class PairingManager {
    static let shared = PairingManager()
    
    private var id: String = ""
    private var ids: String = ""
    
    enum pairingType {
        case qr
        case link
    }
    
    /// validateQR() checks whether the parameter scanned from the QR code on the employee link conforms to the format specified on the
    /// backend: `zapp|klic|cp_zamestnanci|44|77yGdor8El|cp`
    func validateQR(_ codeContent: String) -> Bool {
        let parameters = codeContent.split(separator: "|")
        if parameters.count == 6 {
            return true
        }
        return false
    }
    
    /// validateLink checks whether the link provided by the user is a valid URL, and contains the parameters id, ids, provoz.
    /// example URL: `https://lorem.ipsum.com/lorem/ipsum.php?ids=SECRET123&id=123&provoz=asd`
    func validateLink(_ link: String) -> Bool {
        guard
            let url = URL(string: link),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            // not a valid url or no query items
            return false
        }
        
        let includedParameters = Set(queryItems.map { $0.name })
        let requiredParameters: Set<String> = ["id", "ids", "provoz"]
        
        return requiredParameters.isSubset(of: includedParameters)
    }
    
    // TODO: find a way to save the key and also how to get id and ids from the link or the QR code
    // probably define some private vars that a function will assign values to
    
    func getInfoFromLink(_ link: String) {
        guard
            let components = URLComponents(string: link),
            let items = components.queryItems,
            let parsedId = items.first(where: { $0.name == "id" })?.value,
            let parsedIds = items.first(where: { $0.name == "ids" })?.value,
            !id.isEmpty, !ids.isEmpty
        else {
            // Optionally log a warning here
            return
        }

        self.id = parsedId
        self.ids = parsedIds
    }

    
    func getInfoFromQR(_ codeContent: String) {
        let parameters = codeContent.split(separator: "|")
        self.id = String(parameters[3])
        self.ids = String(parameters[4])
    }
    
    
    private func requestAndSaveKey() {
        let url = URL(string: "https://server.com/hello.php")! // hardcoding this for now
        
        let bodyString = [
            "klic=nemamklic123", // backend returns the key in the JSON response if key doesn't exist
            "akce=init",
            "parametr=",
            "provoz=cp" // also hardcoded for now
        ].joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        // TODO: perform the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Request failed:", error ?? "Unknown error")
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ulozsi = json["ulozsi"] as? [String: Any],
               let klic = ulozsi["klic"] as? String {
                
                UserDefaults.standard.setValue(klic, forKey: "klic")
                print("Persisted klic: \(klic)")
            } else {
                print("Failed to parse JSON or find klic")
            }
        }
    }
    
    private func connectKeyToAccount(url: URL, bodyData: Data?) {
        let url = URL(string: "https://server.com/hello.php")! // hardcoding this for now
        let key = UserDefaults.standard.string(forKey: "klic")! // assuming that klic was already obtained
        
        // TODO: check whether we have the required key, id, ids
        let bodyString = [
            "klic=\(key)",
            "akce=propojit_klicem",
            "parametr=zapp|\(key)|cp_zamestnanci|\(id)|\(ids)|cp", // akce=propojit_klicem is the only case where parametr is used
            "provoz=cp" // also hardcoded for now
        ].joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        // TODO: the request
    }
}
