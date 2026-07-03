//
//  LinksView.swift
//  prdok
//
//  Created by David Horňák on 05.11.2025.
//

import SwiftUI

enum LinkKind: Identifiable { // .sheet(item:) requires Identifiable
    case contacts
    case waiter
    case meetingMinutes
    case forum
    case collaborate
    case employee
    
    var id: Int {
        switch self {
        case .contacts: return 0
        case .waiter: return 1
        case .meetingMinutes: return 2
        case .forum: return 3
        case .collaborate: return 4
        case .employee: return 5
        }
    }
}

struct LinksView: View {
    @State private var activeSheet: LinkKind?
    
    @AppStorage("id") private var id: String?
    @AppStorage("ids") private var ids: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                Text("links.title")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                
                LinkButton("link.contacts") {
                    activeSheet = .contacts
                }
                LinkButton("link.waiter") {
                    activeSheet = .waiter
                }
                LinkButton("link.meetingMinutes") {
                    activeSheet = .meetingMinutes
                }
                LinkButton("link.forum") {
                    activeSheet = .forum
                }
                //                LinkButton("link.collaborate") {
                //                    activeSheet = .collaborate
                //                }
                LinkButton("link.employeeWeb") {
                    activeSheet = .employee
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 12)
        }
        .background { (Color.cpBackgroundPrimary).ignoresSafeArea() }
        .sheet(item: $activeSheet, onDismiss: dismissSheet) { sheet in
            switch sheet {
            case .contacts:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/kontakty.php")!)
//            case .waiter:
            case .meetingMinutes:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/zapisyzporad.php")!)
            case .forum:
                LinkWebView(url: URL(string: "\(AppConfig.employeePortalURL)/")!)
            case .employee:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/zamestnanci.php")!)
            default:
                Text("link.notImplementedYet")
            }
        }
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
}

struct LinkButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    
    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .underline()
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.cpForegroundPrimary)
        }
    }
}

#Preview {
    LinksView()
}
