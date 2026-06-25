//
//  AppConfig.swift
//  prdok
//

import Foundation

enum AppConfig {
    private static let config: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String]
        else { fatalError("Config.plist missing — copy Config.example.plist and fill in real values") }
        return dict
    }()

    static let apiBaseURL: String = config["apiBaseURL"]!
    static let employeePortalURL: String = config["employeePortalURL"]!
    static let pairingInitKey: String = config["pairingInitKey"]!
}
