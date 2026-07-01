//
//  Theme.swift
//  prdok
//
//  Created by David Horňák on 01.07.2026.
//

import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
