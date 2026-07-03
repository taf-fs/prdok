//
//  DeveloperSettingsView.swift
//  prdok
//
//  Created by David Horňák on 26.06.2026.
//

import SwiftUI

struct DeveloperSettingsView: View {

    private let keys: [String]
    @State private var copiedKey: String? = nil

    init() {
        if let path = Bundle.main.path(forResource: "DevCredentials", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            keys = dict.keys.sorted()
        } else {
            keys = []
        }
    }

    var body: some View {
        List {
            ForEach(keys, id: \.self) { key in
                let value = UserDefaults.standard.string(forKey: key) ?? "—"
                HStack {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        UIPasteboard.general.string = value
                        copiedKey = key
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedKey == key { copiedKey = nil }
                        }
                    } label: {
                        Image(systemName: copiedKey == key ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copiedKey == key ? Color.green : Color.cpForegroundSecondary)
                            .animation(.default, value: copiedKey)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(Text("settings.sectionHeader.developer"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
