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
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: 1)
                }
                .offset(y: -toolbarOffset)
                
                Spacer()
                
//                Button("complete setup") { UserDefaults.standard.set(true, forKey: "setupCompleted") }
                
                Button {
                    Task {
                        isTextFieldFocused = false
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            // TODO: consider putting a second or something of delay here, ProgressView flashes so fast maybe it's bad ux
                            try await PairingManager.shared.connectAccountUsingLink(employeeLink)
                            UserDefaults.standard.set(true, forKey: "setupCompleted")
                            UserDefaults.standard.set(true, forKey: "needsToBootstrap")
                        } catch {
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                } label: {
                    Text("connect.link.button.connect")
                        .bold()
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.background)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.primary)
                                .tint(.primary)
                        }
                        .overlay {
                            if !isURL {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.8))
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
}

#Preview {
    PairWithLinkView()
}

