//
//  ScanQRView.swift
//  prdok
//
//  Created by David Horňák on 14.10.2025.
//

import SwiftUI
import CodeScanner
import AVFoundation

struct ScanQRView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var gradientColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.8)
        }
        return Color.white.opacity(0.8)
    }
    
    private let boxSize: CGFloat = 320
    private let boxRadius: CGFloat = 22
    private let lineWidth: CGFloat = 6
    private let toolbarOffset: CGFloat = 60
    
    var body: some View {
        NavigationView {
            ZStack {
                CodeScannerView(
                    codeTypes: [.qr],
                    scanMode: .oncePerCode
                ) { response in
                    switch response {
                    case .success(let result):
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                try await PairingManager.shared.connectAccountUsingQR(result.string)
                                UserDefaults.standard.set(true, forKey: "setupCompleted")
                                UserDefaults.standard.set(true, forKey: "needsToBootstrap")
                            } catch {
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    case .failure(let error):
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
                .ignoresSafeArea()
                
                // blur
                ZStack {
                    Rectangle()
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                    RadialGradient(
                        gradient: Gradient(colors: [.clear, gradientColor]),
                        center: .center,
                        startRadius: 100,
                        endRadius: 600
                    )
                    .ignoresSafeArea()
                }
                .overlay {
                    RoundedRectangle(cornerRadius: boxRadius, style: .continuous)
                        .frame(width: boxSize, height: boxSize)
                        .offset(y: -toolbarOffset / 2)
                        .blendMode(.destinationOut) // punch a hole
                }
                .compositingGroup() // required for destinationOut
                
                
                ScannerCorners(cornerRadius: boxRadius,
                               cornerLength: 42,
                               insetForStroke: 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: boxSize, height: boxSize)
                .offset(y: -toolbarOffset / 2)

                
                VStack {
                    Text("connect.qr.instructions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .offset(y: -(boxSize/2 + toolbarOffset))
                }
                .ignoresSafeArea()

                if isLoading {
                    LoadingScreenView(text: "loading.connecting")
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("connect.qr.toolbar.title")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .tint(.primary)
                    }
                    
                }
            }
        }
    }
}

#Preview {
    ScanQRView()
}
