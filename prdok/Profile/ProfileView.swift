//
//  ProfileView.swift
//  prdok
//
//  The signed-in employee's profile: short name, start date and the seven
//  competencies with the month each was gained. Pushed from `TodayView`'s
//  person icon. Data comes from the `mojedata` akce via `ProfileService`.
//

import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published var error: String?
    @Published var isLoading = false

    func load() {
        error = nil
        isLoading = true
        Task {
            do {
                let profile = try await ProfileService.fetchProfile()
                self.profile = profile
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme

    /// Themed café logo asset.
    private var logoName: String {
        colorScheme == .dark ? "cpLogoDark" : "cpLogo"
    }

    var body: some View {
        ZStack {
            Color.cpBackgroundPrimary.ignoresSafeArea()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm.profile == nil { vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let profile = vm.profile {
            loaded(profile)
        } else if vm.isLoading {
            ProgressView("profile.loading")
        } else {
            errorState
        }
    }

    private func loaded(_ profile: Profile) -> some View {
        VStack {
            header(profile)

            List {
                Section(header: Text("profile.competencies.title")
                    .font(.system(.body, design: .monospaced, weight: .bold))) {
                    ForEach(profile.competencies) { status in
                        competencyRow(status)
                    }
                }
                .listRowBackground(Color.cpBackgroundSecondary)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func header(_ profile: Profile) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                (Text("profile.memberSince") + Text(verbatim: " ") + Text(Self.startDateString(profile.startDate)))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
            
            Spacer(minLength: 0)
            
            Image(logoName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func competencyRow(_ status: CompetencyStatus) -> some View {
        HStack {
            Text(status.competency.titleKey)
                .foregroundStyle(Color.cpForegroundPrimary)
            Spacer(minLength: 8)
            if let gained = status.gained {
                Text(Self.gainedMonthString(gained))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.cpForegroundSecondary)
            } else {
                Text(verbatim: "–")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.cpForegroundMuted)
            }
        }
    }

    private var errorState: some View {
        VStack(spacing: 16) {
            Text("profile.error")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.cpForegroundSecondary)
                .multilineTextAlignment(.center)
            Button("profile.retry") { vm.load() }
                .foregroundStyle(Color.cpForegroundPrimary)
        }
        .padding()
    }

    // MARK: - Formatting

    /// Localized full start date, e.g. "30. srpna 2024".
    private static func startDateString(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    /// Localized month + year the competency was gained, e.g. "září 2024".
    private static func gainedMonthString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
