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
    @State private var scanResult: String? = nil
    
    var body: some View {
        VStack {
            Text("please scan qr code text")
            
            CodeScannerView(codeTypes: [.qr]) { response in
                switch response {
                case .success(let result):
                    print("Found code: \(result.string)")
                    scanResult = result.string
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
            .frame(maxWidth: 300, maxHeight: 300)
            .border(Color.gray)
            
            if (scanResult != nil) {
                Text("\(String(describing: scanResult))")                
            }
        }
        
    }
}

#Preview {
    ContentView(selectedTab: 2)
}
