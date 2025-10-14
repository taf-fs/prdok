//
//  ScanQRView.swift
//  prdok
//
//  Created by David Horňák on 14.10.2025.
//

import SwiftUI
import CodeScanner
import AVFoundation

struct ScanQRView: View {
    var body: some View {
        CodeScannerView(codeTypes: [.qr]) { response in
            switch response {
            case .success(let result):
                print("Found code: \(result.string)")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

#Preview {
    ScanQRView()
}
