//
//  SetupView.swift
//  prdok
//
//  Created by David Horňák on 18.10.2025.
//

import SwiftUI

struct SetupView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isSheetPresented: Bool = false
    @State private var isActive: Bool = false // navigates to PairWithLinkView
    
    var isDarkMode: Bool {
        return colorScheme == .dark
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("setup.welcome.title")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
                
                Text("setup.app.name")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(isDarkMode ? "cpLogoDark" : "cpLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 150, maxHeight: 150)
                    .opacity(0.9)
                
                Spacer()
                
                Text("setup.access.instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 4) {
                    Button { // wrote it like this in case i want to add more logic
                        isActive = true
                    } label: {
                        Text("setup.connect.link")
                            .bold()
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.background)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.primary)
                                    .tint(.primary)
                            }
                    }
                    
                    Button {
                        isSheetPresented = true
                    } label: {
                        Text("setup.connect.qr")
                            .bold()
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                            .tint(.primary)
//                            .background {
//                                RoundedRectangle(cornerRadius: 16)
//                                    .stroke(.secondary, lineWidth: 1)
//                                    .tint(.primary)
//                            }
                        
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .padding(.top, 128)
            .sheet(isPresented: $isSheetPresented) {
                ScanQRView()
            }
            .navigationDestination(isPresented: $isActive) {
                PairWithLinkView()
            }
            .navigationBarHidden(true) // ios 15 shenanigans
        }
    }
}


#Preview {
    SetupView()
}
