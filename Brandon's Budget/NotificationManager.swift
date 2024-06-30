//
//  NotificationManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//
//
//  NotificationManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//

import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification authorization granted")
                    completion(true)
                } else {
                    print("Notification authorization denied")
                    if let error = error {
                        print("Authorization error: \(error.localizedDescription)")
                    }
                    completion(false)
                }
            }
        }
    }
    
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isAuthorized = settings.authorizationStatus == .authorized
                completion(isAuthorized)
            }
        }
    }
    
    func schedulePurchaseNotifications(frequency: SettingsManager.PurchaseNotificationFrequency) {
        // Remove existing purchase notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["purchaseNotification"])
        
        var dateComponents = DateComponents()
        
        switch frequency {
        case .daily:
            dateComponents.hour = 20 // 8 PM
        case .weekly:
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 20 // 8 PM
        case .monthly:
            dateComponents.day = 1 // First day of the month
            dateComponents.hour = 20 // 8 PM
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Enter Purchases Reminder"
        content.body = "Don't forget to log your recent purchases!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "purchaseNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling purchase notification: \(error.localizedDescription)")
            } else {
                print("Purchase notification scheduled successfully")
            }
        }
    }
    
    func scheduleBudgetTotalNotifications(frequency: SettingsManager.BudgetTotalNotificationFrequency) {
        // Remove existing budget total notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["budgetTotalNotification"])
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9 // 9 AM
        
        switch frequency {
        case .monthly:
            dateComponents.day = 1 // First day of the month
        case .yearly:
            dateComponents.day = 1 // First day of the year
            dateComponents.month = 1 // January
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Enter Budget Update"
        content.body = "Enter your budget for the new period!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "budgetTotalNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling budget total notification: \(error.localizedDescription)")
            } else {
                print("Budget total notification scheduled successfully")
            }
        }
    }
    
    func updateNotificationSchedule(settingsManager: SettingsManager) {
        if settingsManager.purchaseNotificationsEnabled {
            schedulePurchaseNotifications(frequency: settingsManager.purchaseNotificationFrequency)
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["purchaseNotification"])
        }
        
        if settingsManager.budgetTotalNotificationsEnabled {
            scheduleBudgetTotalNotifications(frequency: settingsManager.budgetTotalNotificationFrequency)
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["budgetTotalNotification"])
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
