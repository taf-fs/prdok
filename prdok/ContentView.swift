//
//  ContentView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("setupCompleted") private var setupCompleted = false
    @State private var selectedTab = 0
    private let brandColor = Color("cpCream")

    var body: some View {
        ZStack {
            if !setupCompleted {
                SetupView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                TabView(selection: $selectedTab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "clock") }
                        .tag(0)

                    CalendarView()
                        .tabItem { Label("Kalendář", systemImage: "calendar") }
                        .tag(1)

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gear") }
                }
                .tabTint(brandColor)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: setupCompleted)
    }
}

#Preview {
    ContentView()
}

private extension View {
    @ViewBuilder
    func tabTint(_ color: Color) -> some View {
        if #available(iOS 16, *) {
            self.tint(color)
        } else {
            // iOS 15: TabView ignores `.tint`; use `.accentColor`.
            self.accentColor(color)
        }
    }
}
