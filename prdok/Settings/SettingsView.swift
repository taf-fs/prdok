//
//  SettingsView.swift
//  prdok
//
//  Created by David Horňák on 25.10.2025.
//

import SwiftUI

struct SettingsView: View {
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("colorTheme") private var colorTheme: Theme = .system
    @State private var showNotisDeniedAlert = false
    @State private var showUnpairErrorAlert = false
    @State private var showUnpairConfirmAlert = false
    @State private var alertMessage = ""
    @State private var isUnpairingInProgress = false
    @State private var showThemeSheet = false
    
    var body: some View {
        ZStack {
            VStack {
                Text("settings.title")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                
                    .padding(.horizontal, 12)
                    .padding(.top, 24)
                List {
                    Section {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("settings.language")
                        }
                        .foregroundStyle(Color.cpForegroundPrimary)
                        Button {
                            showThemeSheet = true
                        } label: {
                            Text("settings.colorTheme")
                        }
                        .foregroundStyle(Color.cpForegroundPrimary)
                    }
                    .listRowBackground(Color.cpBackgroundSecondary)
                    
                    Section(header: Text("settings.sectionHeader.notifications").font(.system(.body, design: .monospaced, weight: .bold))) {
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
                    .listRowBackground(Color.cpBackgroundSecondary)
                    

                    
                    Section(header: Text("settings.sectionHeader.developer").font(.system(.body, design: .monospaced, weight: .bold))) {
                        NavigationLink {
                            DeveloperSettingsView()
                        } label: {
                            Text("settings.developer.userdefaults")
                        }
                    }
                    .listRowBackground(Color.cpBackgroundSecondary)

                    Button {
                        showUnpairConfirmAlert = true
                    } label: {
                        Text("settings.unpair")
                            .foregroundStyle(.red)
                    }
                    .listRowBackground(Color.cpBackgroundSecondary)
                    
//                    Button {
//                        UserDefaults.standard.set(false, forKey: "setupCompleted")
//                    } label: {
//                        Text("go back to setup")
//                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color.cpBackgroundPrimary)
            .alert(alertMessage, isPresented: $showUnpairErrorAlert) {
                Button("OK", role: .cancel) { }
            }
            .alert("settings.alert.unpairConfirm.title", isPresented: $showUnpairConfirmAlert) {
                Button("settings.alert.unpairConfirm.button.cancel", role: .cancel) { }
                Button("settings.alert.unpairConfirm.button.unpair", role: .destructive) {
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
                }
            } message: {
                Text("settings.alert.unpairConfirm.message")
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
        .sheet(isPresented: $showThemeSheet) {
            NavigationStack {
                ThemeSelectorView(theme: $colorTheme)
                    .padding()
                    .navigationTitle("settings.colorTheme.sheetTitle")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button { showThemeSheet = false } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
