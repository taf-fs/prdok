//
//  FreeShiftsListView.swift
//  prdok
//
//  Created by David Horňák on 17.07.2026.
//
//  "Handlování směn": the open shifts anyone can pick up, under the statistics in CalendarView.
//  One row per day on a shared time axis; tapping a day opens who is on shift then.
//  Data comes from the `smeny_handl` API akce via `FreeShiftService`. Read-only; refreshed
//  by the calendar's refresh button, never on its own.
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

    /// Loads free shifts once per view lifetime. Free shifts change over time, so the
    /// calendar's refresh button (`force: true`) re-fetches.
    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        isLoading = true
        error = nil
        do {
            shifts = try await FreeShiftService.fetchFreeShifts()
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
            Log.freeShifts.error("[FreeShiftsVM] load failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

struct FreeShiftsListView: View {
    @ObservedObject var vm: FreeShiftsViewModel
    /// Called with the tapped day's date; the parent opens who is on shift that day.
    var onOpenDay: (Date) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("today.freeShifts.title")
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await vm.load() }
    }

    @ViewBuilder
    private var content : some View {
        if vm.isLoading && vm.shifts.isEmpty {
            centered { ProgressView() }
        } else if vm.shifts.isEmpty, vm.error != nil {
            centered { note("today.freeShifts.error") }
        } else if vm.shifts.isEmpty {
            centered { note("today.freeShifts.empty") }
        } else {
            FreeShiftsTimeline(shifts: vm.shifts, onOpenDay: onOpenDay)
        }
    }

    private func centered<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func note(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(Color.cpForegroundSecondary)
    }
}

// MARK: - Timeline

/// The axis is `ShiftTimelineLayout`'s 07:00 to 01:00, where every shift falls; a tick interval
/// dividing its 18 hours labels both ends.
private enum TimelineMetrics {
    static let axisStartHour = 7
    static let axisEndHour = 25
    static let axisTickHours = 9

    static let dateColumnWidth: CGFloat = 60
    static let columnGap: CGFloat = 8

    /// Tall enough to fit the role letter inside.
    static let barHeight: CGFloat = 14
    static let laneGap: CGFloat = 3
    static let trackLineHeight: CGFloat = 2
    static let minBarWidth: CGFloat = barHeight
    static let roleLetterSize: CGFloat = 10
    /// Each bar gives up this much of its length, so two shifts touching in one lane stay two bars.
    static let barEndGap: CGFloat = 2

    /// Same green the calendar uses for planned shifts.
    static let barColor = Color(red: 76/255, green: 196/255, blue: 23/255, opacity: 0.5)
}

/// One shift's bar: where it sits on the track, and the role letter drawn inside it.
private struct FreeShiftBar {
    let range: (start: CGFloat, end: CGFloat)
    let letter: String?
}

/// One day of the timeline: its shifts, and the same shifts as bars spread over lanes.
private struct FreeShiftDay: Identifiable {
    let date: Date
    let shifts: [FreeShift]
    let lanes: [[FreeShiftBar]]

    var id: Date { date }

    static func group(_ shifts: [FreeShift], calendar: Calendar = .current) -> [FreeShiftDay] {
        let layout = ShiftTimelineLayout(calendar: calendar)
        return Dictionary(grouping: shifts) { calendar.startOfDay(for: $0.start) }
            .sorted { $0.key < $1.key }
            .map { date, shifts in
                let bars = shifts.map {
                    FreeShiftBar(range: layout.normalizedRange(start: $0.start, end: $0.end), letter: $0.role.letter)
                }
                return FreeShiftDay(date: date, shifts: shifts, lanes: ShiftTimelineLayout.lanes(bars) { $0.range })
            }
    }
}

private struct FreeShiftsTimeline: View {
    let shifts: [FreeShift]
    let onOpenDay: (Date) -> Void

    var body: some View {
        let days = FreeShiftDay.group(shifts)
        VStack(spacing: 0) {
            HStack(spacing: TimelineMetrics.columnGap) {
                Color.clear.frame(width: TimelineMetrics.dateColumnWidth, height: 0)
                AxisLabels()
            }
            ForEach(days) { day in
                Divider()
                FreeShiftDayRow(day: day) { onOpenDay(day.date) }
            }
        }
    }
}

/// Hour labels centred on their ticks. The first may hang half outside into the empty date
/// column; the last is pulled back so its right edge ends flush with the rows below.
private struct AxisLabels: View {
    private var hours: [Int] {
        Array(stride(from: TimelineMetrics.axisStartHour,
                     through: TimelineMetrics.axisEndHour,
                     by: TimelineMetrics.axisTickHours))
    }

    var body: some View {
        AxisLabelsLayout(hours: hours) {
            ForEach(hours, id: \.self) { hour in
                Text(verbatim: String(format: "%02d", hour % 24))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.cpForegroundSecondary)
            }
        }
        .accessibilityHidden(true)
    }
}

/// An HStack can only put children one after another; a custom `Layout` places each label
/// wherever it likes - here at its hour's fraction of the width.
private struct AxisLabelsLayout: Layout {
    let hours: [Int]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let span = CGFloat(TimelineMetrics.axisEndHour - TimelineMetrics.axisStartHour)
        for (index, label) in subviews.enumerated() where hours.indices.contains(index) {
            let size = label.sizeThatFits(.unspecified)
            let fraction = CGFloat(hours[index] - TimelineMetrics.axisStartHour) / span
            let centredX = bounds.minX + bounds.width * fraction - size.width / 2
            label.place(
                at: CGPoint(x: min(centredX, bounds.maxX - size.width), y: bounds.minY),
                proposal: ProposedViewSize(size)
            )
        }
    }
}

private struct FreeShiftDayRow: View {
    let day: FreeShiftDay
    let onTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d.M."
        return df
    }()

    /// "PO", "ÚT" / "MO", "TU", the same two letters as the calendar's weekday header.
    private var weekdayLabel: String {
        let index = Calendar.current.component(.weekday, from: day.date) - 1
        let names = DateFormatter().weekdaySymbols ?? []
        guard names.indices.contains(index) else { return "" }
        return String(names[index].prefix(2)).uppercased()
    }

    /// The bars show no times and only a role letter, so a screen reader gets the day, times and roles spelled out instead.
    private var accessibilityText: String {
        let shifts = day.shifts
            .sorted { $0.start < $1.start }
            .map { shift in
                [shift.timeRangeString, shift.role.label].compactMap { $0 }.joined(separator: " ")
            }
            .joined(separator: ", ")
        return "\(UpcomingShiftRow.dayLabel(day.date)): \(shifts)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TimelineMetrics.columnGap) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.dateFormatter.string(from: day.date))
                        .font(.system(.body, design: .serif))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(weekdayLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.cpForegroundSecondary)
                }
                .frame(width: TimelineMetrics.dateColumnWidth, alignment: .leading)

                DayTrack(lanes: day.lanes)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.cpForegroundPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }
}

/// A thin track line with the day's lanes stacked over it; the row grows by a lane when it needs one.
private struct DayTrack: View {
    let lanes: [[FreeShiftBar]]

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.cpForegroundSecondary.opacity(0.2))
                .frame(height: TimelineMetrics.trackLineHeight)

            VStack(spacing: TimelineMetrics.laneGap) {
                ForEach(lanes.indices, id: \.self) { index in
                    Lane(bars: lanes[index])
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Lane: View {
    let bars: [FreeShiftBar]

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            ForEach(bars.indices, id: \.self) { index in
                let bar = bars[index]
                let range = bar.range
                let barWidth = min(max(trackWidth * (range.end - range.start) - TimelineMetrics.barEndGap,
                                       TimelineMetrics.minBarWidth),
                                   trackWidth)
                // Keep the bar inside the track when the minimum width pushes it past an edge.
                let barX = min(max(trackWidth * range.start + TimelineMetrics.barEndGap / 2, 0),
                               max(trackWidth - barWidth, 0))
                // The bar colour is see-through, which would let the track line show through the
                // bars lying on it, so it sits on the page background to come out opaque.
                Capsule()
                    .fill(Color.cpBackgroundPrimary)
                    .overlay(Capsule().fill(TimelineMetrics.barColor))
                    .overlay {
                        if let letter = bar.letter {
                            Text(verbatim: letter)
                                .font(.system(size: TimelineMetrics.roleLetterSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.cpForegroundPrimary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .frame(width: barWidth, height: geo.size.height)
                    .offset(x: barX)
            }
        }
        .frame(height: TimelineMetrics.barHeight)
    }
}

private extension FreeShiftRole {
    /// The portal's own `typ` marker, shown inside the bar. The screen reader gets `label` instead.
    var letter: String? {
        switch self {
        case .regular: return nil
        case .manager: return "v"
        case .barista: return "b"
        }
    }

    /// Localized label for the screen reader. Regular shifts get none.
    var label: String? {
        switch self {
        case .regular: return nil
        case .manager: return String(localized: "freeShifts.role.manager")
        case .barista: return String(localized: "freeShifts.role.barista")
        }
    }
}

// MARK: - Previews

private func previewShift(_ id: Int, day: Int, from: Int, to: Int, role: FreeShiftRole = .regular) -> FreeShift {
    let cal = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: from))!
    let end = to > from
        ? cal.date(bySettingHour: to, minute: 0, second: 0, of: start)!
        : cal.date(from: DateComponents(year: 2026, month: 9, day: day + 1, hour: to))!
    return FreeShift(id: id, start: start, end: end, role: role)
}

#Preview {
    ScrollView {
        FreeShiftsTimeline(
            shifts: [
                previewShift(1, day: 11, from: 9, to: 13),
                // Two pairs overlapping: two lanes.
                previewShift(2, day: 17, from: 7, to: 8),
                previewShift(3, day: 17, from: 7, to: 11, role: .barista),
                previewShift(4, day: 17, from: 16, to: 0),
                previewShift(5, day: 17, from: 17, to: 0),
                previewShift(6, day: 20, from: 8, to: 11, role: .manager),
                // Three at once between 13 and 14: the row grows a third lane.
                previewShift(7, day: 21, from: 10, to: 17),
                previewShift(8, day: 21, from: 11, to: 14),
                previewShift(9, day: 21, from: 13, to: 14),
                // Touching in one lane, then the portal's 24:00-25:00.
                previewShift(10, day: 25, from: 10, to: 16),
                previewShift(11, day: 25, from: 16, to: 18),
                previewShift(12, day: 25, from: 0, to: 1),
            ],
            onOpenDay: { _ in }
        )
        .padding()
    }
    .background(Color.cpBackgroundPrimary)
}
