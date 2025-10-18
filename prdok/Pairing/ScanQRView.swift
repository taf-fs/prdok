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
    @State private var scanResult: String? = nil
    
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
                        scanResult = result.string
                    case .failure(let error):
                        print("Scan error:", error.localizedDescription)
                    }
                }
                .ignoresSafeArea()
                
                // blur
                ZStack {
                    Rectangle()
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                    RadialGradient(
                        gradient: Gradient(colors: [.clear, Color.black.opacity(0.8)]),
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
                .stroke(Color.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: boxSize, height: boxSize)
                .offset(y: -toolbarOffset / 2)

                
                VStack {
                    Text("Namiř fotoaparát na QR kód na zaměstnaneckém webu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .offset(y: -(boxSize/2 + toolbarOffset))
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                if let scanResult {
                    Text(scanResult)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Propojit přes QR kód")
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

