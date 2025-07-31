//
//  NotificationService.swift
//  Eckstein
//
//  Created by Eliad Shahar on 13/07/2025.
//

import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Weight Reminders
    
    func scheduleWeightReminder(at time: Date, frequency: String) async {
        // First check if authorized
        if !isAuthorized {
            let granted = await requestAuthorization()
            guard granted else { return }
        }
        
        // Cancel existing weight reminders
        await cancelWeightReminders()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "weight_reminder_title".localized
        content.body = "weight_reminder_body".localized
        content.sound = .default
        content.categoryIdentifier = "WEIGHT_REMINDER"
        
        // Create trigger based on frequency
        let trigger: UNNotificationTrigger
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        switch frequency {
        case "daily":
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case "3days":
            // For every 3 days, we'll schedule multiple notifications
            await scheduleRepeatingReminders(content: content, components: components, intervalDays: 3)
            return
        case "weekly":
            var weeklyComponents = components
            weeklyComponents.weekday = calendar.component(.weekday, from: Date())
            trigger = UNCalendarNotificationTrigger(dateMatching: weeklyComponents, repeats: true)
        default:
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "weight_reminder_\(frequency)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await notificationCenter.add(request)
            print("Weight reminder scheduled successfully")
        } catch {
            print("Error scheduling weight reminder: \(error)")
        }
    }
    
    private func scheduleRepeatingReminders(content: UNNotificationContent, components: DateComponents, intervalDays: Int) async {
        // Schedule notifications for the next 30 occurrences (90 days for 3-day intervals)
        for i in 0..<30 {
            var triggerDate = Date()
            if let hour = components.hour, let minute = components.minute {
                triggerDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: triggerDate) ?? triggerDate
            }
            triggerDate = Calendar.current.date(byAdding: .day, value: intervalDays * i, to: triggerDate) ?? triggerDate
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "weight_reminder_3days_\(i)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Error scheduling 3-day reminder \(i): \(error)")
            }
        }
    }
    
    func cancelWeightReminders() async {
        let identifiers = await notificationCenter.pendingNotificationRequests()
            .map { $0.identifier }
            .filter { $0.hasPrefix("weight_reminder_") }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Quick Actions
    
    func registerNotificationCategories() {
        let addWeightAction = UNNotificationAction(
            identifier: "ADD_WEIGHT",
            title: "add_weight".localized,
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "dismiss".localized,
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "WEIGHT_REMINDER",
            actions: [addWeightAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([category])
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "test_notification_title".localized
        content.body = "test_notification_body".localized
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("Test notification scheduled")
        } catch {
            print("Error scheduling test notification: \(error)")
        }
    }
}