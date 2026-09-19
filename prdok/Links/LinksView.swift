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
    case files
    
    var id: Int {
        switch self {
        case .contacts: return 0
        case .waiter: return 1
        case .meetingMinutes: return 2
        case .forum: return 3
        case .collaborate: return 4
        case .employee: return 5
        case .files: return 6
        }
    }
}

struct LinksView: View {
    @State private var activeSheet: LinkKind?
    
    @AppStorage("id") private var id: String?
    @AppStorage("ids") private var ids: String?
    @AppStorage("provoz") private var provoz: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                Text("links.title")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                
                LinkButton("link.employeeWeb") {
                    activeSheet = .employee
                }
                LinkButton("link.contacts") {
                    activeSheet = .contacts
                }
//                LinkButton("link.waiter") {
//                    activeSheet = .waiter
//                }
                    LinkButton("link.meetingMinutes") {
                        activeSheet = .meetingMinutes
                    }
                    LinkButton("link.files") {
                        activeSheet = .files
                    }
                LinkButton("link.forum") {
                    activeSheet = .forum
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 12)
        }
        .background { (Color.cpBackgroundPrimary).ignoresSafeArea() }
        .sheet(item: $activeSheet, onDismiss: dismissSheet) { sheet in
            switch sheet {
            case .employee:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/zamestnanci.php?ids=\(ids ?? "")&id=\(id ?? "")&provoz=\(provoz ?? "")")!)
            case .contacts:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/kontakty.php")!)
//            case .waiter:
            case .meetingMinutes:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/zapisyzporad.php")!)
            case .files:
                LinkWebView(url: URL(string: "\(AppConfig.apiBaseURL)/nasi/soubory.php?provoz=\(provoz ?? "")&id=\(id ?? "")&ids=\(ids ?? "")")!)
            case .forum:
                LinkWebView(url: URL(string: "\(AppConfig.employeePortalURL)/")!)
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
