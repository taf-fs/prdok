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
