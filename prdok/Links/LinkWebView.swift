//
//  LinkWebView.swift
//  prdok
//
//  Created by David Horňák on 08.11.2025.
//

import SwiftUI
import SafariServices

struct LinkWebView: UIViewControllerRepresentable {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = false

        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
