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

struct TimerButton: View {
    let id: Int
    let length: Int // minutes
    @Binding var activeId: Int? // controls the parent HStack

    @State private var isActivated = false
    @State private var isRunning = false

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

                    HStack(spacing: 50) {
                        Text(timeString(time: remaining))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        Rectangle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 1, height: 20)

                        HStack(spacing: 25) {
                            Button {
                                togglePauseResume(now: context.date)
                            } label: {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .animation(nil)
                                    .font(.title3)
                            }

                            Button {
                                cancelTimer()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.primary)
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
    }

    private func togglePauseResume(now: Date) {
        if isRunning {
            // pause
            let remaining = remainingSeconds(now: now) // snaps how many secs left before pausing the timer
            pausedRemainingSeconds = remaining
            timerEndDate = nil
            isRunning = false
        } else {
            // resume: add remaining seconds to current Date for new timerEndDate
            let remaining = pausedRemainingSeconds ?? durationSeconds
            timerEndDate = now.addingTimeInterval(TimeInterval(remaining))
            pausedRemainingSeconds = nil
            isRunning = true
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
    
    private func finishTimer() {
        cancelTimer()
        // make sound perhaps
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

    // TODO: implement this, make sure noti access granted, and give option of choice if noti for timer end should be sent
    private func scheduleNotification() {}

    private func cancelScheduledNotification() {}
}

#Preview {
    PauseTimerView()
        .padding(.horizontal, 16)
}
