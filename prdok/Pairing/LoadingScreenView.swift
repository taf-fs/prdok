//
//  LoadingScreenView.swift
//  prdok
//
//  Created by David Horňák on 25.10.2025.
//

import SwiftUI

struct LoadingScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var text: String?
    var isDarkMode: Bool { return colorScheme == .dark }

    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .white : .black))
                    .controlSize(.large)
                if let loadingText = text {
                    Text(loadingText)
                }
            }
            .padding(30)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

#Preview {
    LoadingScreenView()
}
