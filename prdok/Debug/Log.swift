//
//  Log.swift
//  prdok
//
//  Created by David Horňák on 29.10.2025.
//

import os
import Foundation

enum Log {
    static let shifts = Logger(subsystem: Bundle.main.bundleIdentifier ?? "io.tafdev.prdok", category: "Shifts")
}
