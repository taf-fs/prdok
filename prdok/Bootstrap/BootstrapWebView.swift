//
//  BootstrapWebView.swift
//  prdok
//
//  Created by David Horňák on 09.11.2025.
//

import SwiftUI
import SafariServices

struct BootstrapWebView: UIViewControllerRepresentable {
    @AppStorage("id") private var id: String?
    @AppStorage("ids") private var ids: String?
    
    func getURL() -> URL {
        if let id = id, let ids = ids {
            return URL(string: "https://streva.prostoru.cz/nasi/zamestnanci.php?ids=\(ids)&id=\(id)&provoz=cp")!
        } else {
            return URL(string: "https://streva.prostoru.cz/nasi/zamestnanci.php")! // temporary solution, but it should never get to this else block
        }
    }
    
    
    var onFinished: (Bool) -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: getURL())
        vc.delegate = context.coordinator
        vc.modalPresentationStyle = .fullScreen
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        
        let onFinished: (Bool) -> Void
        init(onFinished: @escaping (Bool) -> Void) { self.onFinished = onFinished }

        func safariViewController(_ controller: SFSafariViewController,
                                  didCompleteInitialLoad didLoadSuccessfully: Bool) {
            onFinished(didLoadSuccessfully)
        }
    }
}

#Preview {
    BootstrapWebView { _ in
        
    }
}
