//
//  PauseTimerView.swift
//  prdok
//
//  Created by David Horňák on 13.01.2026.
//

import SwiftUI
import UserNotifications

struct SimplePauseTimerView: View {
    // UI-driving state (keeps transitions smooth)
    @State private var activeTimerId: Int? = nil

    // persisted active timer id (0 => none, 1/2 for each timer)
    @AppStorage("simplePause.activeTimerId") private var storedActiveTimerId: Int = 0

    private var persistedActiveTimerId: Int? {
        storedActiveTimerId == 0 ? nil : storedActiveTimerId
    }

    var body: some View {
        HStack(spacing: 8) {
            if activeTimerId == nil || activeTimerId == 1 {
                TimerButton(id: 1, length: 15, activeId: $activeTimerId)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            if activeTimerId == nil || activeTimerId == 2 {
                TimerButton(id: 2, length: 30, activeId: $activeTimerId)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .aspectRatio(7, contentMode: .fit)
        .onAppear {
            // restore ui
            activeTimerId = persistedActiveTimerId
        }
        .onChange(of: activeTimerId) { newValue in
            // persist any UI change
            storedActiveTimerId = newValue ?? 0
        }
    }
}

// TODO: make timer persist through app kills and launches
private struct TimerButton: View {
    let id: Int
    let length: Int // minutes
    @Binding var activeId: Int? // controls the parent HStack

    // UI-only state
    @State private var isNotificationTimeTextShown: Bool = false

    // Persisted per-timer state
    @AppStorage("simplePause.timer1.endDate") private var timer1EndDateTimestamp: Double = 0
    @AppStorage("simplePause.timer2.endDate") private var timer2EndDateTimestamp: Double = 0
    @AppStorage("simplePause.timer1.notificationID") private var timer1NotificationID: String = ""
    @AppStorage("simplePause.timer2.notificationID") private var timer2NotificationID: String = ""

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false

    private var durationSeconds: Int { length * 60 }

    // MARK: - Persisted accessors

    private func getStoredEndDate() -> Date? {
        let ts = (id == 1) ? timer1EndDateTimestamp : timer2EndDateTimestamp
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private func setStoredEndDate(_ date: Date?) {
        let ts = date?.timeIntervalSince1970 ?? 0
        if id == 1 { timer1EndDateTimestamp = ts }
        else { timer2EndDateTimestamp = ts }
    }

    private func getStoredNotificationID() -> String? {
        let raw = (id == 1) ? timer1NotificationID : timer2NotificationID
        return raw.isEmpty ? nil : raw
    }

    private func setStoredNotificationID(_ value: String?) {
        let raw = value ?? ""
        if id == 1 { timer1NotificationID = raw }
        else { timer2NotificationID = raw }
    }

    private var isActivated: Bool {
        activeId == id && getStoredEndDate() != nil
    }

    var body: some View {
        ZStack {
            Color.blue.opacity(0.2)

            if isActivated {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = remainingSeconds(now: context.date)

                    HStack(spacing: 0) {
                        if let endDate = getStoredEndDate() {
                            if isNotificationTimeTextShown {
                                HStack {
                                    Image(systemName: "bell")
                                    Text("simplePause.notification.endTime \(endDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.headline)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("simplePause.notification.set \(length)")
                                        .font(.headline)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .frame(maxWidth: .infinity)
                            }
                        }

                        Button {
                            cancelTimer()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .opacity(0.5)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .onChange(of: remaining) { newValue in
                        guard isActivated else { return }
                        if newValue <= 0 {
                            finishTimer()
                        }
                    }
                }
            } else {
                Button {
                    startTimer()
                    toggleNotification(duration: length)
                } label: {
                    HStack {
                        Image(systemName: "bell")
                            .font(.headline)
                        Text("\(length) min")
                            .font(.system(.subheadline))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .cornerRadius(15)
        .onAppear {
            restoreStateIfNeeded()
        }
        .onChange(of: activeId) { _ in
            if activeId != id {
                isNotificationTimeTextShown = false
            }
        }
    }

    // MARK: - Restore

    private func restoreStateIfNeeded() {
        // if this timer has a stored end date, decide whether it's still active.
        if let endDate = getStoredEndDate() {
            if endDate <= Date() {
                clearPersistedState()
                return
            }

            // ensure the parent knows this is the active timer (single-active invariant).
            if activeId != id {
                // no animation requested on restore
                activeId = id
            }

            // same UX as normal timer set
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    if isActivated {
                        isNotificationTimeTextShown = true
                    }
                }
            }

            // If we think there's a notification scheduled, verify it still exists.
            if let notiID = getStoredNotificationID() {
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let stillPending = requests.contains(where: { $0.identifier == notiID })
                    if !stillPending {
                        DispatchQueue.main.async {
                            setStoredNotificationID(nil)
                        }
                    }
                }
            }
        } else {
            // no stored end date -> nothing active for this timer
            // defensively clear any stored notificationID
            if getStoredNotificationID() != nil {
                setStoredNotificationID(nil)
            }
        }
    }

    // MARK: - Logic

    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                if isActivated {
                    isNotificationTimeTextShown = true
                }
            }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = id
            setStoredEndDate(Date().addingTimeInterval(TimeInterval(durationSeconds)))
        }

        // If user had enabled a notification previously and restarts, clear it.
        cancelScheduledNotification()
    }

    private func cancelTimer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = nil
            setStoredEndDate(nil)
            isNotificationTimeTextShown = false
        }
        cancelScheduledNotification()
    }

    private func finishTimer() {
        cancelTimer()
    }

    private func remainingSeconds(now: Date = Date()) -> Int {
        guard isActivated else { return durationSeconds }

        if let endDate = getStoredEndDate() {
            return max(0, Int(endDate.timeIntervalSince(now)))
        } else {
            return durationSeconds
        }
    }

    private func clearPersistedState() {
        if activeId == id {
            activeId = nil
        }
        setStoredEndDate(nil)
        setStoredNotificationID(nil)
        isNotificationTimeTextShown = false
    }

    // MARK: - Notification Handling

    private func toggleNotification(duration: Int) {
        if getStoredNotificationID() != nil {
            cancelScheduledNotification()
        } else {
            NotificationManager.shared.requestAuthorization { granted in
                notificationsEnabled = granted

                NotificationManager.shared.getAuthorizationStatus { status in
                    if status == .authorized && notificationsEnabled == true {
                        scheduleNotification(duration)
                    }
                }
            }
        }
    }

    private func scheduleNotification(_ duration: Int) {
        guard isActivated, let endDate = getStoredEndDate() else { return }

        if let id = getStoredNotificationID() {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("simplePause.notification.finish.title", comment: "Pause timer finish notification title")

        let bodyFormat = NSLocalizedString(
            "simplePause.notification.finish.body",
            comment: "Pause timer finish notification body. Use %d for duration (is in minutes)"
        )
        content.body = String(format: bodyFormat, duration)
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let newID = UUID().uuidString
        let request = UNNotificationRequest(identifier: newID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
                return
            }
            DispatchQueue.main.async {
                setStoredNotificationID(newID)
            }
        }
    }

    private func cancelScheduledNotification() {
        if let id = getStoredNotificationID() {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
        setStoredNotificationID(nil)
    }
}

#Preview {
    SimplePauseTimerView()
        .padding(.horizontal, 16)
}
