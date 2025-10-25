//
//  TodayView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

struct TodayView: View {
    @AppStorage("id") private var id: String?
    
    var body: some View {
        Text("Your id: \(id ?? "not set")")
    }
}

#Preview {
    TodayView()
}
