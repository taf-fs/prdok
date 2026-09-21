//
//  BootstrapCover.swift
//  prdok
//
//  Created by David Horňák on 09.11.2025.
//

import SwiftUI

struct BootstrapCover: View {
    @Binding var isPresented: Bool
    var body: some View {
        ZStack {
            BootstrapWebView() { _ in
                // gets dismiss as soon as it’s done
                isPresented = false
            }

            Color.cpBackgroundElevated.ignoresSafeArea()

            VStack(spacing: 16) {
                DripLoadingAnimation()
                    .frame(width: 95, height: 101)
                Text("bootstrap.loading")
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
        }
    }
}
