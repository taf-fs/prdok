//
//  AboutView.swift
//  prdok
//
//  Created by David Horňák on 25.09.2026.
//

import SwiftUI

/// About the app: logo, platform label and installed version, who made it, and links to the
/// privacy policy and the support page. Pushed from `SettingsView`.
struct AboutView: View {

    private static let privacyPolicyURL = URL(string: "https://taf-fs.github.io/prdok/")!
    /// The support page, which lists the common problems and their fixes.
    private static let commonProblemsURL = URL(string: "https://taf-fs.github.io/prdok/support.html")!

    @Environment(\.colorScheme) private var colorScheme

    private var logoName: String {
        colorScheme == .dark ? "cpLogoDark" : "cpLogo"
    }

    // A ScrollView of hand-drawn cards rather than a List: a List resizes its rows outside of
    // SwiftUI's animations, so the credits card couldn't grow smoothly when the secret opens.
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                CreditsCard()
                VStack(spacing: 0) {
                    linkRow("about.privacyPolicy", url: Self.privacyPolicyURL)
                    Divider()
                        .padding(.horizontal, 16)
                    linkRow("about.commonProblems", url: Self.commonProblemsURL)
                }
                .background(Color.cpBackgroundSecondary, in: aboutCardShape)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color.cpBackgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(logoName)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .padding(.bottom, 12)
            Text("about.platform")
                .font(.body)
            Text("about.version \(Feedback.appVersion) \(Feedback.buildNumber)")
                .font(.subheadline)
                .foregroundStyle(Color.cpForegroundSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// A row that leaves the app for a web page, with an arrow that says so.
    private func linkRow(_ title: LocalizedStringKey, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .foregroundStyle(Color.cpForegroundPrimary)
    }
}

/// The rounded card behind each group, drawn to match the grouped lists in Settings.
private let aboutCardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)


private struct CreditsCard: View {

    private static let specialThanks = [
        "Ali",
        "Andrei",
        "Aneška",
        "Antonina",
        "Arča",
        "Eliška H.",
        "Jarda",
        "Karla",
        "Kačka J.",
        "Kryštof Pše.",
        "Káťa R.",
        "Martin M.",
        "Natálie K.",
        "Polina",
        "Vítek",
        "Zuza E.",
    ]

    private static let secretTaps = 10

    @State private var taps = 0

    private var revealed: Bool { taps >= Self.secretTaps }

    var body: some View {
        VStack(spacing: 0) {
            Text("about.credits")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.cpForegroundSecondary)

            // The names slide down out from under the text above them: the clipped box grows
            // with the card while the names move in from its top edge.
            VStack {
                if revealed {
                    VStack(spacing: 4) {
                        Text("about.specialThanks")
                            .font(.subheadline.bold())
                            .multilineTextAlignment(.center)
                        ForEach(Self.specialThanks, id: \.self) { name in
                            Text(verbatim: name)
                                .font(.subheadline)
                                .foregroundStyle(Color.cpForegroundSecondary)
                        }
                    }
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.cpBackgroundSecondary, in: aboutCardShape)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !revealed else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                taps += 1
            }
            if revealed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
