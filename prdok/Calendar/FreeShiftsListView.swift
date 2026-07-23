//
//  FreeShiftsListView.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  Native list of free shifts ("Handlování směn") shown under the timer in TodayView.
//  Data comes from the `smeny_handl` API akce via `FreeShiftService`. Read-only for now.
//

import SwiftUI
import Combine
import os

@MainActor
final class FreeShiftsViewModel: ObservableObject {
    @Published var shifts: [FreeShift] = []
    @Published var isLoading = false
    @Published var error: String?

    private var hasLoaded = false

    /// Loads free shifts once per view lifetime. Free shifts change over time, so a
    /// pull-to-refresh (`force: true`) re-fetches.
    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        isLoading = true
        error = nil
        do {
            shifts = try await FreeShiftService.fetchFreeShifts()
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
            Log.shifts.error("FreeShiftsViewModel: load failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

struct FreeShiftsListView: View {
    @StateObject private var vm = FreeShiftsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.freeShifts.title")
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)

            content
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cpBackgroundSecondary)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.shifts.isEmpty {
            centered { ProgressView() }
        } else if vm.shifts.isEmpty, vm.error != nil {
            centered {
                VStack {
                    Spacer()
                    Text("today.freeShifts.error")
                        .font(.footnote)
                        .foregroundStyle(Color.cpForegroundSecondary)
                    Spacer()
                }
            }
        } else if vm.shifts.isEmpty {
            centered {
                VStack {
                    Spacer()
                    Text("today.freeShifts.empty")
                        .font(.footnote)
                        .foregroundStyle(Color.cpForegroundSecondary)
                    Spacer()
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.shifts) { shift in
                        FreeShiftRow(shift: shift)
                    }
                }
                .padding(.bottom, 8)
            }
            .refreshable { await vm.load(force: true) }
        }
    }

    private func centered<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        HStack {
            Spacer()
            inner()
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

private struct FreeShiftRow: View {
    let shift: FreeShift

    /// Free shifts are "offered" availability — reuse the green used for offered shifts.
    private let barColor = Color(red: 76/255, green: 196/255, blue: 23/255, opacity: 0.5)

    var body: some View {
        UpcomingShiftRow(
            title: UpcomingShiftRow.dayLabel(shift.start),
            roleLabel: shift.role.labelKey,
            timeText: shift.timeRangeString,
            interval: shift.indicatorInterval,
            color: barColor
        )
    }
}

private extension FreeShiftRole {
    /// Localized label shown next to the date. Regular shifts show nothing.
    var labelKey: LocalizedStringKey? {
        switch self {
        case .regular: return nil
        case .manager: return "freeShifts.role.manager"
        case .barista: return "freeShifts.role.barista"
        }
    }
}

#Preview {
    FreeShiftsListView()
        .padding()
        .background(Color.cpBackgroundSecondary)
}
