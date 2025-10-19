//
//  PairWithLinkView.swift
//  prdok
//
//  Created by David Horňák on 19.10.2025.
//

import SwiftUI

struct PairWithLinkView: View {
    @State private var employeeLink: String = ""
    @FocusState private var textFieldIsFocused: Bool
    
    var isURL: Bool {
        if let url = URL(string: employeeLink) {
            return url.scheme == "http" || url.scheme == "https"
        }
        return false
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("tvůj zaměstnanecký odkaz?")
                .font(.system(.title))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom)
            TextField("https://...", text: $employeeLink)
                .focused($textFieldIsFocused)
                .onSubmit {
                    validate(employeeLink)
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.URL)
                .keyboardType(.URL)
            Rectangle()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: 1)
            
            Spacer()
            
            Button {
                validate(employeeLink)
            } label: {
                Text("Propojit")
                    .bold()
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.background)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.primary)
                            .tint(.primary)
                    }
                    .overlay {
                        if (!isURL) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.8))
                        }
                    }
            }
            .disabled(!isURL)
        }
        .padding()
    }
}

func validate(_ link: String) {
    
}

#Preview {
    PairWithLinkView()
}
