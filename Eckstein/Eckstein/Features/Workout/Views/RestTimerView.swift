//
//  RestTimerView.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import SwiftUI
import UserNotifications

struct RestTimerView: View {
    @State private var timeRemaining: TimeInterval
    @State private var isActive = false
    @State private var showingDurationPicker = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let onDurationChange: (TimeInterval) -> Void
    
    init(duration: TimeInterval, onDurationChange: @escaping (TimeInterval) -> Void) {
        self._timeRemaining = State(initialValue: duration)
        self.onDurationChange = onDurationChange
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // Timer Display
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green, Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    VStack(spacing: 8) {
                        Text(timeString)
                            .font(.system(size: 60, weight: .light, design: .rounded))
                            .monospacedDigit()
                        
                        Text("rest_time".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Control Buttons
                HStack(spacing: 40) {
                    // Skip Button
                    Button {
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                            Text("skip".localized)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background((themeManager.accentColor == .red ? Color.red : Color.red).opacity(0.1))
                        .foregroundColor(themeManager.accentColor == .red ? .red : .red)
                        .cornerRadius(20)
                    }
                    
                    // Play/Pause Button
                    Button {
                        isActive.toggle()
                        if isActive {
                            scheduleNotification()
                        } else {
                            cancelNotification()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: isActive ? "pause.fill" : "play.fill")
                                .font(.title)
                            Text(isActive ? "pause".localized : "start".localized)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    
                    // +30s Button
                    Button {
                        timeRemaining += 30
                        if isActive {
                            cancelNotification()
                            scheduleNotification()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                            Text("+30" + "sec".localized)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background(themeManager.accentColor.color.opacity(0.1))
                        .foregroundColor(themeManager.accentColor.color)
                        .cornerRadius(20)
                    }
                }
                
                Spacer()
                
                // Quick Duration Selection
                VStack(spacing: 16) {
                    Text("quick_select".localized)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        ForEach([60, 90, 120, 180], id: \.self) { seconds in
                            Button {
                                timeRemaining = TimeInterval(seconds)
                                onDurationChange(TimeInterval(seconds))
                                isActive = false
                                cancelNotification()
                            } label: {
                                Text("\(seconds/60)" + "min".localized)
                                    .frame(width: 60, height: 40)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("rest_timer".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        cancelNotification()
                        dismiss()
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            if isActive && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining <= 0 && isActive {
                // Timer finished
                isActive = false
                playCompletionSound()
                dismiss()
            }
        }
        .onDisappear {
            cancelNotification()
        }
    }
    
    private var progress: Double {
        let initialDuration = timeRemaining + (isActive ? 1 : 0)
        return timeRemaining / initialDuration
    }
    
    private var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func scheduleNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "rest_time_complete".localized
                content.body = "time_to_get_back".localized
                content.sound = .default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining, repeats: false)
                let request = UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimer"])
    }
    
    private func playCompletionSound() {
        // Play a completion sound
        // This would use AVFoundation in a real app
    }
}