//
//  PairWithLinkView.swift
//  prdok
//
//  Created by David Horňák on 19.10.2025.
//

import SwiftUI

struct PairWithLinkView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var employeeLink: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @FocusState private var isTextFieldFocused: Bool
    
    var isURL: Bool { PairingManager.shared.validateLink(employeeLink) }
    var isDarkMode: Bool { colorScheme == .dark }
    
    private let toolbarOffset: CGFloat = 60
    private let minSpinnerDuration: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                
                Group {
                    Text("connect.link.prompt")
                        .font(.system(.title))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                    TextField("https://...", text: $employeeLink)
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                    Rectangle()
                        .foregroundStyle(Color.cpForegroundSecondary)
                        .frame(maxWidth: .infinity, maxHeight: 1)
                }
                .offset(y: -toolbarOffset)
                
                Spacer()
                
                Button {
                    Task {
                        isTextFieldFocused = false
                        isLoading = true
                        defer { isLoading = false }

                        let startedAt = ContinuousClock.now

                        do {
                            try await PairingManager.shared.connectAccountUsingLink(employeeLink)
                            await holdSpinner(since: startedAt)
                            UserDefaults.standard.set(true, forKey: "setupCompleted")
                            UserDefaults.standard.set(true, forKey: "needsToBootstrap")
                        } catch {
                            await holdSpinner(since: startedAt)
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                } label: {
                    Text("connect.link.button.connect")
                        .bold()
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.cpBackgroundPrimary)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cpForegroundPrimary)
                        }
                        .overlay {
                            if !isURL {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.background.opacity(0.75))
                            }
                        }
                }
                .disabled(!isURL || isLoading)
            }
            .padding()
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            if isLoading {
                LoadingScreenView(text: "loading.connecting")
            }
        }
    }

    /// Keeps the loading screen up for at least `minSpinnerDuration` to avoid flashing.
    /// A slow connect won't be slowed further, only fast ones get padded.
    private func holdSpinner(since startedAt: ContinuousClock.Instant) async {
        let remaining = minSpinnerDuration - startedAt.duration(to: ContinuousClock.now)
        if remaining > .zero {
            try? await ContinuousClock().sleep(for: remaining)
        }
    }
}

#Preview {
    PairWithLinkView()
}

