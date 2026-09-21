//
//  LoadingScreenView.swift
//  prdok
//
//  Created by David Horňák on 25.10.2025.
//

import SwiftUI

struct LoadingScreenView: View {
    @State var text: LocalizedStringKey?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                DripLoadingAnimation()
                    .frame(width: 95, height: 101)
                if let loadingText = text {
                    Text(loadingText)
                        .foregroundStyle(Color.cpForegroundSecondary)
                }
            }
            .padding(30)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(Color.cpBackgroundElevated)
            }
        }
    }
}

#Preview {
    LoadingScreenView()
}
