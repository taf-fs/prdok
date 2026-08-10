//
//  PairWithCredentialsView.swift
//  prdok
//
//  Created by David Horňák on 09.08.2026.
//

import SwiftUI

struct PairWithCredentialsView: View {
    @Environment(\.colorScheme) var colorScheme

    private enum Field {
        case id, ids, provoz
    }

    @State private var id: String = ""
    @State private var ids: String = ""
    @State private var provoz: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isLinkViewActive = false // navigates to PairWithLinkView
    @FocusState private var focusedField: Field?

    var hasCredentials: Bool { PairingManager.shared.validateCredentials(id: id, ids: ids, provoz: provoz) }
    var isDarkMode: Bool { colorScheme == .dark }

    private let toolbarOffset: CGFloat = 60
    private let fieldSpacing: CGFloat = 12
    private let fieldCornerRadius: CGFloat = 12
    private let minSpinnerDuration: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            VStack {
                Spacer()

                Group {
                    Text("connect.credentials.prompt")
                        .font(.system(.title))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)

                    VStack(spacing: fieldSpacing) {
                        credentialField("connect.credentials.field.id", text: $id, field: .id)
                        credentialField("connect.credentials.field.ids", text: $ids, field: .ids, isSecure: true)
                        credentialField("connect.credentials.field.provoz", text: $provoz, field: .provoz)
                    }

                    Button {
                        focusedField = nil
                        isLinkViewActive = true
                    } label: {
                        Text("setup.connect.link")
                            .font(.subheadline)
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.cpForegroundSecondary)
                            .tint(Color.cpForegroundPrimary)
                    }
                }
                .offset(y: -toolbarOffset)

                Spacer()

                Button {
                    Task {
                        focusedField = nil
                        isLoading = true
                        defer { isLoading = false }

                        let startedAt = ContinuousClock.now

                        do {
                            try await PairingManager.shared.connectAccountUsingCredentials(id: id, ids: ids, provoz: provoz)
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
                    Text("connect.credentials.button.connect")
                        .bold()
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.cpBackgroundPrimary)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cpForegroundPrimary)
                        }
                        .overlay {
                            if !hasCredentials {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.background.opacity(0.75))
                            }
                        }
                }
                .disabled(!hasCredentials || isLoading)
            }
            .padding()
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .navigationDestination(isPresented: $isLinkViewActive) {
                PairWithLinkView()
            }
            if isLoading {
                LoadingScreenView(text: "loading.connecting")
            }
        }
    }

    /// A single credential field: a rounded box holding the label above the text the user types.
    /// `isSecure` masks what the user types, for credentials that shouldn't be shown on screen.
    private func credentialField(_ label: LocalizedStringKey, text: Binding<String>, field: Field, isSecure: Bool = false) -> some View {
        let isFocused = focusedField == field

        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.cpForegroundMuted)

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .foregroundStyle(Color.cpForegroundPrimary)
            .focused($focusedField, equals: field)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(field == .provoz ? .done : .next)
            .onSubmit {
                switch field {
                case .id: focusedField = .ids
                case .ids: focusedField = .provoz
                case .provoz: focusedField = nil
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: fieldCornerRadius)
                .fill(Color.cpBackgroundSecondary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: fieldCornerRadius)
                .stroke(isFocused ? Color.cpForegroundPrimary : Color.cpForegroundMuted, lineWidth: isFocused ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: fieldCornerRadius))
        .onTapGesture { focusedField = field }
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
    NavigationStack {
        PairWithCredentialsView()
    }
}
