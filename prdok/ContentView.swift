//
//  ContentView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 1
    private let brandColor = Color(red: 80/255, green: 40/255, blue: 12/255)

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Dnes", systemImage: "clock")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label("Kalendář", systemImage: "calendar")
                }
                .tag(1)
            
            ScanQRView()
                .tabItem {
                    Label("scan qr", systemImage: "square")
                }
                .tag(2)
        }
        .tabTint(brandColor)
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
