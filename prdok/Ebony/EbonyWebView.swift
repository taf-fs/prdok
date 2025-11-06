//
//  EbonyWebView.swift
//  prdok
//
//  Created by David Horňák on 05.11.2025.
//

import SwiftUI
import WebKit

struct EbonyWebView: UIViewRepresentable {
    @AppStorage("skladnik") private var skladnik: String?
    
    func getURL() -> URL {
        if let params = skladnik {
            return URL(string: "https://streva.prostoru.cz/brana/ebony2.php?\(params)")!
        } else {
            return URL(string: "about:blank")!
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: getURL()))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Reload only if the URL changed
        let currentURL = getURL()
        if webView.url != currentURL {
            webView.load(URLRequest(url: getURL()))
        }
    }
}
#Preview {
    EbonyWebView()
}
