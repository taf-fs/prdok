//
//  ShiftCalendarPlan.swift
//  prdok
//
//  Created by David Horňák on 01.03.2026.
//

import Foundation
import EventKit

struct ShiftCalendarPlan: Equatable {
    let month: Date
    let plannedShiftsCount: Int
    let existingExportedEventsCount: Int
    let shouldOfferSync: Bool
}

struct ShiftCalendarSyncSummary: Equatable {
    let plannedShiftsCount: Int
    let created: Int
    let updated: Int
    let deleted: Int
    let skipped: Int
}

enum ShiftCalendarServiceError: Error, LocalizedError {
    case accessDenied
    case calendarNotWritable
    case invalidMonthDate

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return NSLocalizedString("calendarExport.error.accessDenied", comment: "Calendar access denied.")
        case .calendarNotWritable:
            return NSLocalizedString("calendarExport.error.calendarNotWritable", comment: "Selected calendar is not writable.")
        case .invalidMonthDate:
            return NSLocalizedString("calendarExport.error.invalidMonthDate", comment: "Invalid month date.")
        }
    }
}

/// EventKit-backed service that can:
/// - list writable calendars
/// - detect whether the month already contains exported shifts
/// - add-only export
/// - sync export (add missing + update changed + delete orphaned)
final class ShiftCalendarSyncService {
    private let store: EKEventStore
    private let repo: ShiftRepository

    /// Marker placed into EKEvent.notes so we can find and manage only our events.
    /// We keep it very simple and stable.
    private let notesKey = "prdokShiftId"
    private var notesPrefix: String { "\(notesKey)=" }

    init(store: EKEventStore = EKEventStore(), repo: ShiftRepository = ShiftRepository()) {
        self.store = store
        self.repo = repo
    }

    // MARK: Permissions

    /// Keep this on MainActor since it may trigger a system prompt and is UI-adjacent.
    @MainActor
    func requestAccessIfNeeded() async throws {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }
        guard granted else { throw ShiftCalendarServiceError.accessDenied }
    }

    // MARK: Calendars

    /// Writable calendars only, as requested.
    func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
    }

    // MARK: Month helpers

    private func monthInterval(containing date: Date) -> DateInterval? {
        let cal = Calendar(identifier: .gregorian)
        return cal.dateInterval(of: .month, for: date)
    }

    private func plannedShifts(forMonthContaining month: Date) async throws -> [Shift] {
        let all = try await repo.getShifts(for: month)
        return all
            .filter { $0.kind == .planned }
            .sorted(by: { $0.start < $1.start })
    }

    // MARK: Event matching

    private func exportedShiftId(from event: EKEvent) -> Int? {
        guard let notes = event.notes else { return nil }
        guard let range = notes.range(of: notesPrefix) else { return nil }

        let tail = notes[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        return Int(digits)
    }

    private func makeNotes(for shiftId: Int) -> String {
        "\(notesPrefix)\(shiftId)"
    }

    private func fetchEvents(in calendar: EKCalendar, monthInterval: DateInterval) -> [EKEvent] {
        let predicate = store.predicateForEvents(
            withStart: monthInterval.start,
            end: monthInterval.end,
            calendars: [calendar]
        )
        return store.events(matching: predicate)
    }

    /// Returns only events that were created by us (contain our notes marker), plus mapping shiftId -> event
    private func exportedEventsByShiftId(in calendar: EKCalendar, monthInterval: DateInterval) -> [Int: EKEvent] {
        let events = fetchEvents(in: calendar, monthInterval: monthInterval)
        var result: [Int: EKEvent] = [:]
        for e in events {
            if let id = exportedShiftId(from: e) {
                result[id] = e
            }
        }
        return result
    }

    // MARK: Planning

    /// Used by the sheet to decide whether to show the Sync action.
    /// Not @MainActor: it can fetch EventKit events and do repository work without blocking the UI.
    func plan(forMonthContaining month: Date, calendar: EKCalendar) async throws -> ShiftCalendarPlan {
        // Note: caller should ensure permission has been requested already.
        guard calendar.allowsContentModifications else { throw ShiftCalendarServiceError.calendarNotWritable }
        guard let interval = monthInterval(containing: month) else { throw ShiftCalendarServiceError.invalidMonthDate }

        let planned = try await plannedShifts(forMonthContaining: month)
        let exported = exportedEventsByShiftId(in: calendar, monthInterval: interval)

        return ShiftCalendarPlan(
            month: month,
            plannedShiftsCount: planned.count,
            existingExportedEventsCount: exported.count,
            shouldOfferSync: !exported.isEmpty
        )
    }

    // MARK: Export operations

    private func normalizedEventTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Směna" : trimmed
    }

    /// Overwrites start/end/alarms unconditionally for events we manage.
    /// `alarmMinutesBefore == nil` means no alarm.
    private func applyShift(_ shift: Shift, to event: EKEvent, eventTitle: String, alarmMinutesBefore: Int?) {
        event.title = normalizedEventTitle(eventTitle)
        event.startDate = shift.start
        event.endDate = shift.end
        event.notes = makeNotes(for: shift.id)

        if let minutes = alarmMinutesBefore {
            let seconds = TimeInterval(minutes * 60)
            event.alarms = [EKAlarm(relativeOffset: -seconds)]
        } else {
            event.alarms = []
        }
    }

    /// Add-only: create events for shifts that are missing; do not update existing; do not delete orphaned.
    /// Not @MainActor: may do heavy EventKit work.
    func addOnly(
        forMonthContaining month: Date,
        calendar: EKCalendar,
        eventTitle: String,
        alarmMinutesBefore: Int?
    ) async throws -> ShiftCalendarSyncSummary {
        // Note: caller should ensure permission has been requested already.
        guard calendar.allowsContentModifications else { throw ShiftCalendarServiceError.calendarNotWritable }
        guard let interval = monthInterval(containing: month) else { throw ShiftCalendarServiceError.invalidMonthDate }

        let planned = try await plannedShifts(forMonthContaining: month)
        let exportedById = exportedEventsByShiftId(in: calendar, monthInterval: interval)

        var created = 0
        let updated = 0
        let deleted = 0
        var skipped = 0

        for shift in planned {
            if exportedById[shift.id] != nil {
                skipped += 1
                continue
            }

            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            applyShift(shift, to: event, eventTitle: eventTitle, alarmMinutesBefore: alarmMinutesBefore)
            try store.save(event, span: .thisEvent, commit: false)
            created += 1
        }

        try store.commit()

        return ShiftCalendarSyncSummary(
            plannedShiftsCount: planned.count,
            created: created,
            updated: updated,
            deleted: deleted,
            skipped: skipped
        )
    }

    /// Sync: create missing, update existing (overwrite), delete orphaned.
    /// Not @MainActor: may do heavy EventKit work.
    func sync(
        forMonthContaining month: Date,
        calendar: EKCalendar,
        eventTitle: String,
        alarmMinutesBefore: Int?
    ) async throws -> ShiftCalendarSyncSummary {
        // Note: caller should ensure permission has been requested already.
        guard calendar.allowsContentModifications else { throw ShiftCalendarServiceError.calendarNotWritable }
        guard let interval = monthInterval(containing: month) else { throw ShiftCalendarServiceError.invalidMonthDate }

        let planned = try await plannedShifts(forMonthContaining: month)
        let plannedById = Dictionary(uniqueKeysWithValues: planned.map { ($0.id, $0) })

        let exportedById = exportedEventsByShiftId(in: calendar, monthInterval: interval)

        var created = 0
        var updated = 0
        var deleted = 0
        var skipped = 0

        // Update existing + delete orphaned
        for (shiftId, event) in exportedById {
            if let shift = plannedById[shiftId] {
                // overwrite unconditionally
                applyShift(shift, to: event, eventTitle: eventTitle, alarmMinutesBefore: alarmMinutesBefore)
                try store.save(event, span: .thisEvent, commit: false)
                updated += 1
            } else {
                // orphaned: delete automatically
                try store.remove(event, span: .thisEvent, commit: false)
                deleted += 1
            }
        }

        // Create missing
        for shift in planned {
            if exportedById[shift.id] != nil {
                skipped += 1
                continue
            }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            applyShift(shift, to: event, eventTitle: eventTitle, alarmMinutesBefore: alarmMinutesBefore)
            try store.save(event, span: .thisEvent, commit: false)
            created += 1
        }

        try store.commit()

        return ShiftCalendarSyncSummary(
            plannedShiftsCount: planned.count,
            created: created,
            updated: updated,
            deleted: deleted,
            skipped: skipped
        )
    }
}
