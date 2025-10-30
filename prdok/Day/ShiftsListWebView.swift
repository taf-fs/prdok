//
//  ShiftsListWebView.swift
//  prdok
//
//  Created by David Horňák on 30.10.2025.
//

import SwiftUI
import SafariServices

struct ShiftsListWebView: UIViewControllerRepresentable {
    let date: Date
    
    init(date: Date) {
        self.date = date
    }
    
    func getUrlFromDate(date: Date) -> URL? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let formattedDate = df.string(from: date)
        let formattedString = "https://streva.prostoru.cz/nasi/dnes.php?den=\(formattedDate)"
        return URL(string: formattedString)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = false

        let url = getUrlFromDate(date: date) ?? URL(string: "https://streva.prostoru.cz/nasi/dnes.php")!
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
