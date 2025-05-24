//
//  NotificationManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//


import UserNotifications
import Combine

/// Manages all notification-related functionality for the app with proper error handling and state management
public final class NotificationManager {
    // MARK: - Types
    public enum NotificationError: LocalizedError {
        case authorizationDenied
        case invalidNotificationContent
        case schedulingError(Error)
        case notificationNotFound
        
        public var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Notification permissions were denied"
            case .invalidNotificationContent:
                return "Invalid notification content"
            case .schedulingError(let error):
                return "Failed to schedule notification: \(error.localizedDescription)"
            case .notificationNotFound:
                return "Notification not found"
            }
        }
    }
    
    // MARK: - Properties
    public static let shared = NotificationManager()
    
    private let notificationCenter: UNUserNotificationCenter
    private let scheduler: NotificationScheduler
    private var cancellables = Set<AnyCancellable>()
    
    // State publisher
    private let authorizationStateSubject = CurrentValueSubject<Bool, Never>(false)
    public var authorizationStatePublisher: AnyPublisher<Bool, Never> {
        authorizationStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Constants
    private enum NotificationIdentifiers {
        static let purchase = "purchaseNotification"
        static let budgetTotal = "budgetTotalNotification"
        static let prefix = "com.brandonsbudget.notification."
    }
    
    // MARK: - Initialization
    private init(
        notificationCenter: UNUserNotificationCenter = .current(),
        scheduler: NotificationScheduler = DefaultNotificationScheduler()
    ) {
        self.notificationCenter = notificationCenter
        self.scheduler = scheduler
        
        // Check initial authorization state
        Task {
            await checkInitialAuthorizationState()
        }
    }
    
    // MARK: - Authorization Methods
    /// Request notification authorization from the user
    /// - Returns: Boolean indicating if authorization was granted
    public func requestAuthorization() async throws -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await updateAuthorizationState(granted)
            return granted
        } catch {
            throw NotificationError.authorizationDenied
        }
    }
    
    /// Check the current notification authorization status
    /// - Returns: Boolean indicating if notifications are authorized
    public func checkNotificationStatus() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
        await updateAuthorizationState(isAuthorized)
        return isAuthorized
    }
    
    // MARK: - Scheduling Methods
    /// Schedule purchase reminder notifications
    /// - Parameter frequency: How often the reminder should be shown
    internal func schedulePurchaseNotifications(
        frequency: SettingsManager.PurchaseNotificationFrequency
    ) async throws {
        // Remove existing notifications first
        await cancelNotifications(withIdentifier: NotificationIdentifiers.purchase)
        
        guard await checkNotificationStatus() else {
            throw NotificationError.authorizationDenied
        }
        
        var dateComponents = DateComponents()
        
        switch frequency {
        case .daily:
            dateComponents.hour = 20 // 8 PM
        case .weekly:
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 20
        case .monthly:
            dateComponents.day = 1
            dateComponents.hour = 20
        }
        
        try await scheduleNotification(
            identifier: NotificationIdentifiers.purchase,
            title: "Enter Purchases Reminder",
            body: "Don't forget to log your recent purchases!",
            dateComponents: dateComponents,
            repeats: true
        )
    }
    
    /// Schedule budget total notifications
    /// - Parameter frequency: How often the notification should be shown
    public func scheduleBudgetTotalNotifications(
        frequency: SettingsManager.BudgetTotalNotificationFrequency
    ) async throws {
        await cancelNotifications(withIdentifier: NotificationIdentifiers.budgetTotal)
        
        guard await checkNotificationStatus() else {
            throw NotificationError.authorizationDenied
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9 // 9 AM
        
        switch frequency {
        case .monthly:
            dateComponents.day = 1
        case .yearly:
            dateComponents.day = 1
            dateComponents.month = 1
        }
        
        try await scheduleNotification(
            identifier: NotificationIdentifiers.budgetTotal,
            title: "Budget Update",
            body: "Time to review and update your budget!",
            dateComponents: dateComponents,
            repeats: true
        )
    }
    
    /// Update all notification schedules based on current settings
    /// - Parameter settings: The app's settings manager
    public func updateNotificationSchedule(settings: SettingsManager) async {
        do {
            if await settings.purchaseNotificationsEnabled {
                try await schedulePurchaseNotifications(
                    frequency: settings.purchaseNotificationFrequency
                )
            } else {
                await cancelNotifications(withIdentifier: NotificationIdentifiers.purchase)
            }
            
            if await settings.budgetTotalNotificationsEnabled {
                try await scheduleBudgetTotalNotifications(
                    frequency: settings.budgetTotalNotificationFrequency
                )
            } else {
                await cancelNotifications(withIdentifier: NotificationIdentifiers.budgetTotal)
            }
        } catch {
            // Log error but don't propagate it to avoid crashing the app
            print("Failed to update notification schedule: \(error.localizedDescription)")
        }
    }
    
    /// Cancel specific notifications
    /// - Parameter identifier: The identifier of notifications to cancel
    public func cancelNotifications(withIdentifier identifier: String) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }
    
    /// Cancel all pending notifications
    public func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Private Methods
    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool = false
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: repeats
        )
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.prefix + identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationError.schedulingError(error)
        }
    }
    
    private func checkInitialAuthorizationState() async {
        let isAuthorized = await checkNotificationStatus()
        await updateAuthorizationState(isAuthorized)
    }
    
    @MainActor
    private func updateAuthorizationState(_ authorized: Bool) {
        authorizationStateSubject.send(authorized)
    }
}

// MARK: - Notification Scheduler Protocol
protocol NotificationScheduler {
    func schedule(request: UNNotificationRequest) async throws
    func cancel(withIdentifier identifier: String)
    func cancelAll()
}

// MARK: - Default Notification Scheduler
struct DefaultNotificationScheduler: NotificationScheduler {
    private let notificationCenter = UNUserNotificationCenter.current()
    
    func schedule(request: UNNotificationRequest) async throws {
        try await notificationCenter.add(request)
    }
    
    func cancel(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAll() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
}

// MARK: - Testing Support
#if DEBUG
public final class MockNotificationScheduler: NotificationScheduler {
    public var scheduledNotifications: [UNNotificationRequest] = []
    public var cancelledIdentifiers: Set<String> = []
    public var didCancelAll = false
    
    public func schedule(request: UNNotificationRequest) async throws {
        scheduledNotifications.append(request)
    }
    
    public func cancel(withIdentifier identifier: String) {
        cancelledIdentifiers.insert(identifier)
    }
    
    public func cancelAll() {
        didCancelAll = true
    }
}
#endif
