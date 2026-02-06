//
//  SettingsView.swift
//  prdok
//
//  Created by David Horňák on 25.10.2025.
//

import SwiftUI

struct SettingsView: View {
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @State private var showNotisDeniedAlert = false
    @State private var showUnpairErrorAlert = false
    @State private var alertMessage = ""
    @State private var isUnpairingInProgress = false
    
    var body: some View {
        ZStack {
            VStack {
                Text("settings")
                List {
                    Section(header: Text("settings.sectionHeader.notifications")) {
                        Toggle("settings.notifications.toggle", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { newToggleValue in
                                if newToggleValue == true {
                                    // check for denied status to show denied alert to prompt the user to turn on notis in the settings
                                    NotificationManager.shared.getAuthorizationStatus { setting in
                                        if setting == .denied {
                                            notificationsEnabled = false
                                            showNotisDeniedAlert = true
                                        } else {
                                            // turn on notis if granted (will ask for access if access not determined)
                                            NotificationManager.shared.requestAuthorization { granted in
                                                notificationsEnabled = granted
                                            }
                                        }
                                    }
                                } else {
                                    // could clear all notis
                                }
                            }
                            .alert("settings.alert.notisDenied.title", isPresented: $showNotisDeniedAlert) {
                                Button("settings.alert.notisDenied.button.cancel", role: .cancel) { }
                                Button("settings.alert.notisDenied.button.openSettings") {
                                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(appSettings)
                                    }
                                }
                            } message: {
                             Text("settings.alert.notisDenied.message")
                            }
                    }
                    
                    Button {
                        Task {
                            isUnpairingInProgress = true
                            defer { isUnpairingInProgress = false }
                            do {
                                try await PairingManager.shared.unpairDevice()
                                UserDefaults.standard.set(false, forKey: "setupCompleted")
                            } catch {
                                alertMessage = error.localizedDescription
                                showUnpairErrorAlert = true
                            }
                        }
                    } label: {
                        Text("settings.unpair")
                            .foregroundStyle(.red)
                    }
                    
//                    Button {
//                        UserDefaults.standard.set(false, forKey: "setupCompleted")
//                    } label: {
//                        Text("go back to setup")
//                    }
                }
            }
            .alert(alertMessage, isPresented: $showUnpairErrorAlert) {
                Button("OK", role: .cancel) { }
            }
            if isUnpairingInProgress {
                LoadingScreenView()
            }

        }
        .onAppear {
            NotificationManager.shared.getAuthorizationStatus { setting in
                if (setting == .denied || setting == .notDetermined) { notificationsEnabled = false }
            }
        }
    }
}

#Preview {
    SettingsView()
}
