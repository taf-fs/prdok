//
//  LinksView.swift
//  prdok
//
//  Created by David Horňák on 05.11.2025.
//

import SwiftUI

enum LinkKind {
    case contacts
    case waiter
    case forum
    case meetingMinutes
    case collaborate
}

struct LinksView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("links.title")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                Spacer()
                    .frame(height: 32)
                LinkButton("link.contacts") {
                    // logic
                }
                
            }
            .padding(.top, 24)
            .padding(.horizontal, 12)
            
        }
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
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    LinksView()
}
