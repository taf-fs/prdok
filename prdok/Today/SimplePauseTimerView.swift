//
//  PauseTimerView.swift
//  prdok
//
//  Created by David Horňák on 13.01.2026.
//

import SwiftUI
import UserNotifications

struct SimplePauseTimerView: View {
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

private struct TimerButton: View {
    let id: Int
    let length: Int // minutes
    @Binding var activeId: Int? // controls the parent HStack

    @State private var isActivated = false
    @State private var notificationID: String?   // identifier of scheduled notification
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false

    // for active timer:
    @State private var timerEndDate: Date? = nil // point of reference for isRunning = true
    @State private var isNotificationTimeTextShown: Bool = false

    private var durationSeconds: Int { length * 60 }

    var body: some View {
        ZStack {
            Color.blue.opacity(0.2)

            if isActivated {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = remainingSeconds(now: context.date)

                    HStack(spacing: 0) {
                        // note: scrap the countdown idea, just use a simple notification
                        if let endDate = timerEndDate {
                            if isNotificationTimeTextShown {
                                HStack {
                                    Image(systemName: "bell")
                                    Text("Oznámení nastaveno na \(endDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.headline)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Oznámení se pošle za \(length) min")
                                        .font(.headline)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        HStack(spacing: 0) {
                            Button {
                                cancelTimer()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .opacity(0.5)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .onChange(of: remaining) { newValue in
                        // timer finish check
                        guard isActivated else { return }
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
    }

    // MARK: - Logic
    
    private func startTimer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = id
            isActivated = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isNotificationTimeTextShown = true
                }
            }
            timerEndDate = Date().addingTimeInterval(TimeInterval(durationSeconds))
        }
        // If user had enabled a notification previously and restarts, clear it.
        cancelScheduledNotification()
    }

    private func cancelTimer() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            activeId = nil
            isActivated = false
            timerEndDate = nil
            
            isNotificationTimeTextShown = false
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

        if let timerEndDate { // how many secs until timerEndDate
            return max(0, Int(timerEndDate.timeIntervalSince(now)))
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
        guard isActivated, let endDate = timerEndDate else { return }


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
    SimplePauseTimerView()
        .padding(.horizontal, 16)
}
