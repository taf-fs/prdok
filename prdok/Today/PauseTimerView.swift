//
//  PauseTimerView.swift
//  prdok
//
//  Created by David Horňák on 13.01.2026.
//

import SwiftUI
import UserNotifications

struct PauseTimerView: View {
    @State private var activeTimerId: Int? = nil

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
    }
}


// deprecating this fow now
private struct TimerButton: View {
    let id: Int
    let length: Int // minutes
    @Binding var activeId: Int? // controls the parent HStack

    @State private var isActivated = false
    @State private var isRunning = false
    @State private var notificationID: String?   // identifier of scheduled notification
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false

    // for active timer:
    @State private var timerEndDate: Date? = nil // point of reference for isRunning = true
    @State private var pausedRemainingSeconds: Int? = nil // point of reference for isRunning = false

    private var durationSeconds: Int { length * 60 }

    var body: some View {
        ZStack {
            Color.blue.opacity(0.2)

            if isActivated {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = remainingSeconds(now: context.date)

                    HStack(spacing: 0) {
                        // countdown
                        HStack {
                            Text(timeString(time: remaining))
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            
                            if let endDate = timerEndDate {
                                Text("(\(endDate.formatted(date: .omitted, time: .shortened)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                            
                        Rectangle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 1, height: 20)

                        HStack(spacing: 0) {
                            Spacer()
                            Button {
                                toggleNotification()
                            } label: {
                                Image(systemName: notificationID == nil ? "bell.slash" : "bell.fill")
                                    .opacity(notificationID == nil ? 0.5 : 1.0)
                            }
                            
                            Spacer()
                            Button {
                                togglePauseResume(now: context.date)
                            } label: {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .animation(nil)
                                    .font(.title3)
                            }
                            Spacer()
                            Button {
                                cancelTimer()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: remaining) { newValue in
                        // timer finish check
                        guard isActivated, isRunning else { return }
                        if newValue <= 0 {
                            finishTimer()
                        }
                    }
                }
            } else {
                Button {
                    startTimer()
                    toggleNotification()
                } label: {
                    HStack {
                        Image(systemName: "stopwatch")
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
    }

    // MARK: - Logic
    
    private func startTimer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = id
            isActivated = true
            isRunning = true
            pausedRemainingSeconds = nil
            timerEndDate = Date().addingTimeInterval(TimeInterval(durationSeconds))
        }
        // If user had enabled a notification previously and restarts, clear it.
        cancelScheduledNotification()
    }

    private func togglePauseResume(now: Date) {
        if isRunning {
            // pause
            let remaining = remainingSeconds(now: now) // snaps how many secs left before pausing the timer
            pausedRemainingSeconds = remaining
            timerEndDate = nil
            isRunning = false
            
            // If notification is enabled, cancel the current one, and let the resume action schedule a new one
            if notificationID != nil {
                if let id = notificationID {
                    print("cancelling notification with the id \(String(describing: notificationID))")
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                }
            }
        } else {
            // resume: add remaining seconds to current Date for new timerEndDate
            let remaining = pausedRemainingSeconds ?? durationSeconds
            timerEndDate = now.addingTimeInterval(TimeInterval(remaining))
            pausedRemainingSeconds = nil
            isRunning = true

            // If notification is enabled, reschedule to new end date
            if notificationID != nil {
                scheduleNotification()
            }
        }
    }

    private func cancelTimer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = nil
            isActivated = false
            isRunning = false
            timerEndDate = nil
            pausedRemainingSeconds = nil
        }
        cancelScheduledNotification()
    }
    
    // only gets called when the timer finishes without naturally
    private func finishTimer() {
        cancelTimer()
        // haptic or sound or something in the future if needed
    }

    private func remainingSeconds(now: Date = Date()) -> Int {
        guard isActivated else { return durationSeconds }

        if isRunning, let timerEndDate { // how many secs until timerEndDate (assuming timer is running)
            return max(0, Int(timerEndDate.timeIntervalSince(now)))
        } else if let pausedRemainingSeconds { // how many secs until timer end (assuming timer is paused)
            return max(0, pausedRemainingSeconds)
        } else { // edge case fallback
            return durationSeconds
        }
    }

    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Notification Handling

    /// Bell button: toggle notifications on/off for this timer.
    private func toggleNotification() {
        if notificationID != nil {
            // Turn off: cancel pending notification
            cancelScheduledNotification()
        } else {
            // Turn on: request permission then schedule
            NotificationManager.shared.requestAuthorization { granted in
                notificationsEnabled = granted
                
                NotificationManager.shared.getAuthorizationStatus { status in
                    if (status == .authorized && notificationsEnabled == true) { // this is for the edge case, where the user grants access but then manually denies it
                        scheduleNotification()
                    }
                }
            }
        }
    }

    /// Schedule or reschedule the notification to fire at current timerEndDate.
    ///
    /// If the timer is paused (no end date), we skip scheduling – it will be scheduled again on resume. The pause action will also cancel the scheduled notification.
    private func scheduleNotification() {
        guard isActivated else { return }
        guard isRunning, let endDate = timerEndDate else {
            // If paused, don't schedule; keep notificationID but no pending request.
            return
        }

        // cancel previous one if any
        if let id = notificationID {
            print("cancelling notification with the id \(String(describing: notificationID))")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.pause.finish.title", comment: "Pause timer finish notification title")
        content.body = NSLocalizedString("notification.pause.finish.body", comment: "Pause timer finish notification body")
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                          from: endDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let newID = UUID().uuidString
        let request = UNNotificationRequest(identifier: newID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
                return
            }
            DispatchQueue.main.async {
                notificationID = newID
                print("scheduling notification with the id \(newID)")
            }
        }
    }

    /// Cancel any pending notification for this timer and clear the flag.
    private func cancelScheduledNotification() {
        if let id = notificationID {
            print("cancelling notification with the id \(String(describing: notificationID))")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        }
        notificationID = nil
    }
}

#Preview {
    PauseTimerView()
        .padding(.horizontal, 16)
}
