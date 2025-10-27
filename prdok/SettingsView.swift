//
//  SettingsView.swift
//  prdok
//
//  Created by David Horňák on 25.10.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isUnpairingInProgress = false
    
    var body: some View {
        ZStack {
            VStack {
                Text("settings")
                List {
                    Button {
                        Task {
                            isUnpairingInProgress = true
                            defer { isUnpairingInProgress = false }
                            do {
                                try await PairingManager.shared.unpairDevice()
                                UserDefaults.standard.set(false, forKey: "setupCompleted")
                            } catch {
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    } label: {
                        Text("settings.unpair")
                    }
                    
//                    Button {
//                        UserDefaults.standard.set(false, forKey: "setupCompleted")
//                    } label: {
//                        Text("go back to setup")
//                    }
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            if isUnpairingInProgress {
                LoadingScreenView()
            }

        }
    }
}

#Preview {
    SettingsView()
}
