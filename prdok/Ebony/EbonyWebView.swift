//
//  EbonyWebView.swift
//  prdok
//
//  Created by David Horňák on 05.11.2025.
//

import SwiftUI
import WebKit

struct EbonyWebScreen: View {
    @State var isPageLoaded: Bool = false
    
    var body: some View {
        ZStack {
            if #available(iOS 26, *) {
                Color(red: 255/255, green: 255/255, blue: 179/255)
                    .ignoresSafeArea(.container, edges: isPageLoaded ? .top : .all)
                EbonyWebView(isPageLoaded: $isPageLoaded)
                    .background(.clear)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                Color(red: 255/255, green: 255/255, blue: 179/255)
                    .ignoresSafeArea()
                EbonyWebView(isPageLoaded: $isPageLoaded)
                    .background(.clear)
            }
            
            ZStack {
                Color(red: 255/255, green: 255/255, blue: 179/255)
                    .ignoresSafeArea(.container, edges: .bottom)
                ProgressView()
                    .controlSize(.large)
            }
            .opacity(isPageLoaded ? 0 : 1)
            .animation(.easeOut(duration: 0.3), value: isPageLoaded)
            .allowsHitTesting(!isPageLoaded) // so the tap pass through
        }
    }
}

struct EbonyWebView: UIViewRepresentable {
    @Binding var isPageLoaded: Bool
    @AppStorage("skladnik") private var skladnik: String?
    @AppStorage("provoz") private var provoz: String?

    /// The "integrace" facility gets a stripped-down, read-only version of the page.
    var isIntegration: Bool { provoz == "integrace" }

    func getURL() -> URL {
        if let params = skladnik, params != "" {
            return URL(string: "\(AppConfig.apiBaseURL)/brana/ebony2.php?\(params)")!
        } else {
            return URL(string: "about:blank")!
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
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
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EbonyWebView
        
        init(_ parent: EbonyWebView) {
            self.parent = parent
        }
        
        // ✅ Called when the page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            var js = """
            document.querySelectorAll('a.linka[href="mopos.php"]').forEach(function(el) {
                el.style.display = 'none';
            });
            """
            if parent.isIntegration {
                // #ebonydiv is filled in later by kusebony2.php over AJAX and refilled on every
                // reloadebony(), so setting inline styles here would run before the panels exist
                // and be wiped afterwards. A stylesheet keeps matching whatever lands in the div.
                js += """

                (function() {
                    if (document.getElementById('nativeIntegraceStyle')) return;
                    var style = document.createElement('style');
                    style.id = 'nativeIntegraceStyle';
                    style.textContent =
                        '#ebonydiv > div:first-of-type { pointer-events: none !important; }' +
                        '#ebonydiv > div[style*="solid green"] { display: none !important; }';
                    document.head.appendChild(style);
                })();
                """
            }
            webView.evaluateJavaScript(js, completionHandler: nil)
            withAnimation {
                parent.isPageLoaded = true
            }
        }
    }
}
#Preview {
    EbonyWebScreen()
}
