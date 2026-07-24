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
}

struct ContentView: View {
    @AppStorage("setupCompleted") private var setupCompleted = false // false only when value doesn't exist
    @AppStorage("needsToBootstrap") private var needsToBootstrap = false
    @AppStorage("colorTheme") private var colorTheme: Theme = .system
    @State private var selectedTab: ContentTab = .today
    private let brandColor = Color("cpCream")

    var body: some View {
        ZStack {
            if !setupCompleted {
                SetupView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                ZStack {
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

                        //                    TempShiftView()
                        //                        .tabItem { Label("shifts", systemImage: "calendar") }
                    }
                    .tint(Color.cpForegroundMuted)
                    .preferredColorScheme(selectedTab == ContentTab.ebony ? .light : colorTheme.colorScheme)
                    //                .tabTint(brandColor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .fullScreenCover(isPresented: $needsToBootstrap) {
                        BootstrapCover(isPresented: $needsToBootstrap)
                    }
                    if needsToBootstrap {
                        Color.cpBackgroundPrimary
                            .ignoresSafeArea()
                    }
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
