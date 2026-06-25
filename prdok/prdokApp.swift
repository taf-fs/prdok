//
//  prdokApp.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

@main
struct prdokApp: App {
    init() {
        #if DEBUG
        loadDevCredentials()
        #endif

        if UserDefaults.standard.bool(forKey: "setupCompleted") == false {
            UserDefaults.standard.set(false, forKey: "needsToBootstrap")
        } else {
            UserDefaults.standard.set(true, forKey: "needsToBootstrap")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if DEBUG
private func loadDevCredentials() {
    guard let url = Bundle.main.url(forResource: "DevCredentials", withExtension: "plist"),
          let dict = NSDictionary(contentsOf: url) as? [String: String] else {
        fatalError("DevCredentials.plist missing. Create DevCredentials.plist and fill in your values.")
    }
    UserDefaults.standard.set(true, forKey: "setupCompleted")
    UserDefaults.standard.set(dict["klic"],     forKey: "klic")
    UserDefaults.standard.set(dict["id"],       forKey: "id")
    UserDefaults.standard.set(dict["ids"],      forKey: "ids")
    UserDefaults.standard.set(dict["provoz"],  forKey: "provoz")
    UserDefaults.standard.set(dict["skladnik"], forKey: "skladnik")
}
#endif
