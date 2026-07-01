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
            ProgressView("bootstrap.loading")
        }
    }
}
