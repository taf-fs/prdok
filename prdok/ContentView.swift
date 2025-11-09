//
//  ContentView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

enum ContentTab {
    case today
    case calendar
    case ebony
    case links
    case settings
}

struct ContentView: View {
    @AppStorage("setupCompleted") private var setupCompleted = false // false only when value doesn't exist
    @AppStorage("needsToBootstrap") private var needsToBootstrap = false
    @State private var selectedTab: ContentTab = .today
    private let brandColor = Color("cpCream")

    var body: some View {
        ZStack {
            if !setupCompleted {
                SetupView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                TabView(selection: $selectedTab) {
                    TodayView()
                        .tabItem { Label("tabitem.today", systemImage: "clock") }
                        .tag(ContentTab.today)

                    CalendarView()
                        .tabItem { Label("tabitem.calendar", systemImage: "calendar") }
                        .tag(ContentTab.calendar)

                    EbonyWebScreen()
                        .tabItem { Label("tabitem.ebony", systemImage: "list.bullet.rectangle") }
                        .tag(ContentTab.ebony)
                    
                    LinksView()
                        .tabItem { Label("tabitem.links", systemImage: "link")}
                        .tag(ContentTab.links)
                    
                    SettingsView()
                        .tabItem { Label("tabitem.settings", systemImage: "gear") }
                        .tag(ContentTab.settings)
                    
//                    TempShiftView()
//                        .tabItem { Label("shifts", systemImage: "calendar") }
                }
                .preferredColorScheme(selectedTab == ContentTab.ebony ? .light : nil)
//                .tabTint(brandColor)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .fullScreenCover(isPresented: $needsToBootstrap) {
                    BootstrapCover(isPresented: $needsToBootstrap)
                }
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
