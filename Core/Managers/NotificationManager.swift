//
//  NotificationManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//

import UserNotifications
import Combine
import Foundation
import SwiftUI

/// Manages all notification-related functionality for the app with proper error handling and state management
@MainActor
public final class NotificationManager: NSObject, ObservableObject {
    // MARK: - Types
    public enum NotificationCategory: String, CaseIterable {
        case purchase = "purchase"
        case budget = "budget"
        case reminder = "reminder"
        case achievement = "achievement"
        case warning = "warning"
        
        public var displayName: String {
            switch self {
            case .purchase: return "Purchase Reminders"
            case .budget: return "Budget Updates"
            case .reminder: return "General Reminders"
            case .achievement: return "Achievements"
            case .warning: return "Warnings"
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .purchase: return "cart.fill"
            case .budget: return "dollarsign.circle"
            case .reminder: return "bell"
            case .achievement: return "trophy.fill"
            case .warning: return "exclamationmark.triangle"
            }
        }
    }
    
    public enum NotificationPriority: String, CaseIterable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case critical = "critical"
        
        public var interruptionLevel: UNNotificationInterruptionLevel {
            switch self {
            case .low: return .passive
            case .normal: return .active
            case .high: return .timeSensitive
            case .critical: return .critical
            }
        }
        
        public var sound: UNNotificationSound? {
            switch self {
            case .low: return nil
            case .normal: return .default
            case .high: return .defaultCritical
            case .critical: return .defaultCritical
            }
        }
    }
    
    public enum NotificationError: LocalizedError {
        case authorizationDenied
        case schedulingFailed(String)
        case invalidTemplate
        case categoryNotFound
        case tooManyNotifications
        case systemUnavailable
        
        public var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "Notification permission denied"
            case .schedulingFailed(let reason):
                return "Failed to schedule notification: \(reason)"
            case .invalidTemplate:
                return "Invalid notification template"
            case .categoryNotFound:
                return "Notification category not found"
            case .tooManyNotifications:
                return "Too many notifications scheduled"
            case .systemUnavailable:
                return "Notification system is unavailable"
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .authorizationDenied:
                return "Enable notifications in Settings to receive reminders"
            case .schedulingFailed:
                return "Check notification settings and try again"
            case .invalidTemplate:
                return "Contact support if this issue persists"
            case .categoryNotFound:
                return "Restart the app to refresh notification categories"
            case .tooManyNotifications:
                return "Clear some existing notifications and try again"
            case .systemUnavailable:
                return "Restart your device if notifications aren't working"
            }
        }
    }
    
    public struct NotificationTemplate {
        let title: String
        let body: String
        let category: NotificationCategory
        let priority: NotificationPriority
        let actions: [UNNotificationAction]
        let userInfo: [String: Any]
        
        public init(
            title: String,
            body: String,
            category: NotificationCategory,
            priority: NotificationPriority = .normal,
            actions: [UNNotificationAction] = [],
            userInfo: [String: Any] = [:]
        ) {
            self.title = title
            self.body = body
            self.category = category
            self.priority = priority
            self.actions = actions
            self.userInfo = userInfo
        }
        
        /// Validate template before scheduling
        public func validate() throws {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NotificationError.invalidTemplate
            }
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NotificationError.invalidTemplate
            }
            guard title.count <= 100 else {
                throw NotificationError.invalidTemplate
            }
            guard body.count <= 500 else {
                throw NotificationError.invalidTemplate
            }
        }
    }
    
    public struct NotificationSchedule {
        let identifier: String
        let template: NotificationTemplate
        let trigger: UNNotificationTrigger
        let repeats: Bool
        
        public init(
            identifier: String,
            template: NotificationTemplate,
            trigger: UNNotificationTrigger,
            repeats: Bool = false
        ) {
            self.identifier = identifier
            self.template = template
            self.trigger = trigger
            self.repeats = repeats
        }
        
        /// Validate schedule before processing
        public func validate() throws {
            try template.validate()
            guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NotificationError.invalidTemplate
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var isEnabled = false
    @Published public private(set) var pendingNotifications: [UNNotificationRequest] = []
    @Published public private(set) var deliveredNotifications: [UNNotification] = []
    @Published public private(set) var scheduledNotificationCount = 0
    @Published public private(set) var lastSuccessfulSchedule: Date?
    @Published public private(set) var lastError: AppError?
    @Published public private(set) var isProcessing = false
    
    // MARK: - Private Properties
    private let notificationCenter: UNUserNotificationCenter
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = DispatchQueue(label: "com.brandonsbudget.notifications", qos: .userInitiated)
    
    // MARK: - Notification Identifiers
    private enum NotificationIdentifiers {
        static let purchase = "purchaseNotification"
        static let budgetTotal = "budgetTotalNotification"
        static let budgetWarning = "budgetWarningNotification"
        static let monthlyReview = "monthlyReviewNotification"
        static let achievementUnlocked = "achievementNotification"
        static let dataBackup = "dataBackupNotification"
        static let prefix = "com.brandonsbudget.notification."
        
        static func prefixed(_ identifier: String) -> String {
            return prefix + identifier
        }
    }
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.notifications.metrics", qos: .utility)
    
    // MARK: - Constants
    private let maxPendingNotifications = 64 // iOS limit
    private let maxNotificationAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - State Publishers
    public var authorizationStatePublisher: AnyPublisher<Bool, Never> {
        $authorizationStatus
            .map { $0 == .authorized }
            .eraseToAnyPublisher()
    }
    
    public var notificationEnabledPublisher: AnyPublisher<Bool, Never> {
        $isEnabled.eraseToAnyPublisher()
    }
    
    public var errorPublisher: AnyPublisher<AppError?, Never> {
        $lastError.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private override init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        
        super.init()
        
        // Setup notification center delegate
        notificationCenter.delegate = self
        
        // Setup notification categories
        setupNotificationCategories()
        
        // Check initial authorization state
       Task<Void, Never>{
            await checkInitialAuthorizationState()
            await refreshNotificationLists()
        }
        
        // Setup periodic status checks
        setupPeriodicStatusChecks()
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
        
        print("✅ NotificationManager: Initialized successfully")
    }
    
    // MARK: - Authorization Methods
    
    /// Request notification authorization from the user with enhanced options
    public func requestAuthorization(
        options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]
    ) async throws -> Bool {
        let startTime = Date()
        
        return try await performOperation(context: "Requesting notification authorization") {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await updateAuthorizationState()
            
            if granted {
                // Setup notification categories after authorization
                setupNotificationCategories()
                lastSuccessfulSchedule = Date()
                print("✅ NotificationManager: Authorization granted")
            } else {
                print("❌ NotificationManager: Authorization denied")
                throw NotificationError.authorizationDenied
            }
            
            recordMetric("requestAuthorization", duration: Date().timeIntervalSince(startTime))
            return granted
        }
    }
    
    /// Check the current notification authorization status
    public func checkNotificationStatus() async -> Bool {
        await updateAuthorizationState()
        return authorizationStatus == .authorized
    }
    
    /// Open app notification settings
    public func openNotificationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Scheduling Methods
    
    /// Schedule purchase reminder notifications
    public func schedulePurchaseNotifications(
        frequency: SettingsManager.PurchaseNotificationFrequency
    ) async throws {
        let startTime = Date()
        
        try await performOperation(context: "Scheduling purchase notifications") {
            // Remove existing purchase notifications
            await cancelNotifications(withCategory: .purchase)
            
            guard await checkNotificationStatus() else {
                throw NotificationError.authorizationDenied
            }
            
            // Check notification limits
            try await validateNotificationLimits()
            
            let template = createPurchaseReminderTemplate()
            let trigger = createTrigger(for: frequency)
            
            let schedule = NotificationSchedule(
                identifier: NotificationIdentifiers.purchase,
                template: template,
                trigger: trigger,
                repeats: true
            )
            
            try await scheduleNotification(schedule)
            
            recordMetric("schedulePurchaseNotifications", duration: Date().timeIntervalSince(startTime))
            print("✅ NotificationManager: Scheduled purchase notifications (\(frequency.rawValue))")
        }
    }
    
    /// Schedule budget total notifications
    public func scheduleBudgetTotalNotifications(
        frequency: SettingsManager.BudgetTotalNotificationFrequency
    ) async throws {
        let startTime = Date()
        
        try await performOperation(context: "Scheduling budget notifications") {
            await cancelNotifications(withCategory: .budget)
            
            guard await checkNotificationStatus() else {
                throw NotificationError.authorizationDenied
            }
            
            try await validateNotificationLimits()
            
            let template = createBudgetUpdateTemplate()
            let trigger = createTrigger(for: frequency)
            
            let schedule = NotificationSchedule(
                identifier: NotificationIdentifiers.budgetTotal,
                template: template,
                trigger: trigger,
                repeats: true
            )
            
            try await scheduleNotification(schedule)
            
            recordMetric("scheduleBudgetTotalNotifications", duration: Date().timeIntervalSince(startTime))
            print("✅ NotificationManager: Scheduled budget notifications (\(frequency.rawValue))")
        }
    }
    
    /// Schedule budget warning notification when over budget
    public func scheduleBudgetWarning(
        category: String,
        currentSpent: Double,
        budgetLimit: Double,
        delay: TimeInterval = 0
    ) async throws {
        let startTime = Date()
        
        try await performOperation(context: "Scheduling budget warning") {
            guard await checkNotificationStatus() else {
                throw NotificationError.authorizationDenied
            }
            
            try await validateNotificationLimits()
            
            let percentageOver = ((currentSpent - budgetLimit) / budgetLimit) * 100
            let template = createBudgetWarningTemplate(
                category: category,
                currentSpent: currentSpent,
                budgetLimit: budgetLimit,
                percentageOver: percentageOver
            )
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
            let identifier = NotificationIdentifiers.budgetWarning + "_\(category)_\(UUID().uuidString)"
            
            let schedule = NotificationSchedule(
                identifier: identifier,
                template: template,
                trigger: trigger,
                repeats: false
            )
            
            try await scheduleNotification(schedule)
            
            recordMetric("scheduleBudgetWarning", duration: Date().timeIntervalSince(startTime))
            print("⚠️ NotificationManager: Scheduled budget warning for \(category)")
        }
    }
    
    /// Schedule achievement notification
    public func scheduleAchievementNotification(
        title: String,
        message: String,
        delay: TimeInterval = 2.0
    ) async throws {
        let startTime = Date()
        
        do {
            try await performOperation(context: "Scheduling achievement notification") {
                guard await checkNotificationStatus() else {
                    return // Don't throw error for achievements if notifications disabled
                }
                
                let template = NotificationTemplate(
                    title: title,
                    body: message,
                    category: .achievement,
                    priority: .high,
                    userInfo: ["type": "achievement", "timestamp": Date().timeIntervalSince1970]
                )
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let identifier = NotificationIdentifiers.achievementUnlocked + "_\(UUID().uuidString)"
                
                let schedule = NotificationSchedule(
                    identifier: identifier,
                    template: template,
                    trigger: trigger,
                    repeats: false
                )
                
                try await scheduleNotification(schedule)
                
                recordMetric("scheduleAchievementNotification", duration: Date().timeIntervalSince(startTime))
                print("🏆 NotificationManager: Scheduled achievement notification")
            }
        } catch {
            // Log but don't propagate achievement notification errors
            print("⚠️ NotificationManager: Failed to schedule achievement notification - \(error.localizedDescription)")
        }
    }
    
    /// Update all notification schedules based on current settings
    public func updateNotificationSchedule(settings: SettingsManager) async {
        let startTime = Date()
        
        do {
            // Clear any previous errors
            lastError = nil
            
            if settings.notificationsAllowed && await checkNotificationStatus() {
                // Schedule purchase notifications
                if settings.purchaseNotificationsEnabled {
                    try await schedulePurchaseNotifications(
                        frequency: settings.purchaseNotificationFrequency
                    )
                } else {
                    await cancelNotifications(withCategory: .purchase)
                }
                
                // Schedule budget notifications
                if settings.budgetTotalNotificationsEnabled {
                    try await scheduleBudgetTotalNotifications(
                        frequency: settings.budgetTotalNotificationFrequency
                    )
                } else {
                    await cancelNotifications(withCategory: .budget)
                }
                
                lastSuccessfulSchedule = Date()
            } else {
                // Cancel all notifications if disabled
                await cancelAllNotifications()
            }
            
            // Refresh notification lists
            await refreshNotificationLists()
            
            recordMetric("updateNotificationSchedule", duration: Date().timeIntervalSince(startTime))
            print("✅ NotificationManager: Updated notification schedule")
            
        } catch {
            await handleError(AppError.from(error), context: "Updating notification schedule")
        }
    }
    
    // MARK: - Cancellation Methods
    
    /// Cancel notifications by category
    public func cancelNotifications(withCategory category: NotificationCategory) async {
        let startTime = Date()
        
        let identifiersToRemove = pendingNotifications
            .filter { request in
                guard let categoryString = request.content.userInfo["category"] as? String else { return false }
                return categoryString == category.rawValue
            }
            .map { $0.identifier }
        
        if !identifiersToRemove.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            await refreshNotificationLists()
            
            recordMetric("cancelNotificationsByCategory", duration: Date().timeIntervalSince(startTime))
            print("🧹 NotificationManager: Cancelled \(identifiersToRemove.count) \(category.rawValue) notifications")
        }
    }
    
    /// Cancel specific notifications by identifier
    public func cancelNotifications(withIdentifiers identifiers: [String]) async {
        let startTime = Date()
        
        let prefixedIdentifiers = identifiers.map { NotificationIdentifiers.prefixed($0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: prefixedIdentifiers)
        
        await refreshNotificationLists()
        
        recordMetric("cancelNotificationsByIdentifier", duration: Date().timeIntervalSince(startTime))
        print("🧹 NotificationManager: Cancelled \(identifiers.count) specific notifications")
    }
    
    /// Cancel all pending notifications
    public func cancelAllNotifications() async {
        let startTime = Date()
        
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        await refreshNotificationLists()
        
        recordMetric("cancelAllNotifications", duration: Date().timeIntervalSince(startTime))
        print("🧹 NotificationManager: Cancelled all notifications")
    }
    
    /// Clean up old delivered notifications
    public func cleanupOldNotifications() async {
        let startTime = Date()
        
        let cutoffDate = Date().addingTimeInterval(-maxNotificationAge)
        let oldNotifications = deliveredNotifications.filter { notification in
            notification.date < cutoffDate
        }
        
        if !oldNotifications.isEmpty {
            let identifiers = oldNotifications.map { $0.request.identifier }
            notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
            await refreshNotificationLists()
            
            recordMetric("cleanupOldNotifications", duration: Date().timeIntervalSince(startTime))
            print("🧹 NotificationManager: Cleaned up \(oldNotifications.count) old notifications")
        }
    }
    
    // MARK: - Notification Management
    
    /// Get detailed notification statistics
    public func getNotificationStatistics() async -> NotificationStatistics {
        await refreshNotificationLists()
        
        let categoryBreakdown = Dictionary(grouping: pendingNotifications) { request in
            request.content.userInfo["category"] as? String ?? "unknown"
        }.mapValues { $0.count }
        
        let nextScheduledDate = pendingNotifications
            .compactMap { request in
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    return trigger.nextTriggerDate()
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    return Date().addingTimeInterval(trigger.timeInterval)
                }
                return nil
            }
            .sorted()
            .first
        
        return NotificationStatistics(
            totalPending: pendingNotifications.count,
            totalDelivered: deliveredNotifications.count,
            authorizationStatus: authorizationStatus,
            categoryBreakdown: categoryBreakdown,
            nextScheduledDate: nextScheduledDate,
            lastError: lastError,
            lastSuccessfulSchedule: lastSuccessfulSchedule
        )
    }
    
    /// Clear delivered notifications
    public func clearDeliveredNotifications() async {
        notificationCenter.removeAllDeliveredNotifications()
        await refreshNotificationLists()
        print("🧹 NotificationManager: Cleared delivered notifications")
    }
    
    /// Validate notification system health
    public func validateSystemHealth() async throws {
        // Check authorization
        guard await checkNotificationStatus() else {
            throw NotificationError.authorizationDenied
        }
        
        // Check system availability
        let settings = await notificationCenter.notificationSettings()
        guard settings.notificationCenterSetting == .enabled else {
            throw NotificationError.systemUnavailable
        }
        
        // Check notification limits
        try await validateNotificationLimits()
        
        print("✅ NotificationManager: System health validated")
    }
    
    // MARK: - Private Implementation
    
    private func performOperation<T>(
        context: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let result = try await operation()
            // Clear any previous errors on success
            lastError = nil
            return result
        } catch {
            await handleError(AppError.from(error), context: context)
            throw error
        }
    }
    
    private func handleError(_ error: AppError, context: String) async {
        lastError = error
        ErrorHandler.shared.handle(error, context: context)
    }
    
    private func validateNotificationLimits() async throws {
        await refreshNotificationLists()
        
        guard pendingNotifications.count < maxPendingNotifications else {
            throw NotificationError.tooManyNotifications
        }
    }
    
    private func scheduleNotification(_ schedule: NotificationSchedule) async throws {
        // Validate schedule
        try schedule.validate()
        
        let content = UNMutableNotificationContent()
        content.title = schedule.template.title
        content.body = schedule.template.body
        content.categoryIdentifier = schedule.template.category.rawValue
        content.sound = schedule.template.priority.sound
        content.interruptionLevel = schedule.template.priority.interruptionLevel
        
        // Add metadata
        var userInfo = schedule.template.userInfo
        userInfo["category"] = schedule.template.category.rawValue
        userInfo["priority"] = schedule.template.priority.rawValue
        userInfo["scheduledDate"] = Date().timeIntervalSince1970
        userInfo["identifier"] = schedule.identifier
        content.userInfo = userInfo
        
        // Add badge count for important notifications
        if schedule.template.priority == .high || schedule.template.priority == .critical {
            content.badge = NSNumber(value: (await getNotificationStatistics()).totalPending + 1)
        }
        
        let identifier = NotificationIdentifiers.prefixed(schedule.identifier)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: schedule.trigger
        )
        
        do {
            try await notificationCenter.add(request)
            await refreshNotificationLists()
            lastSuccessfulSchedule = Date()
            print("📅 NotificationManager: Scheduled notification '\(schedule.identifier)'")
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }
    
    private func setupNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // Purchase category with quick actions
        let purchaseActions = [
            UNNotificationAction(
                identifier: "ADD_PURCHASE",
                title: "Add Purchase",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "REMIND_LATER",
                title: "Remind Later",
                options: []
            )
        ]
        let purchaseCategory = UNNotificationCategory(
            identifier: NotificationCategory.purchase.rawValue,
            actions: purchaseActions,
            intentIdentifiers: [],
            options: []
        )
        categories.insert(purchaseCategory)
        
        // Budget category with quick actions
        let budgetActions = [
            UNNotificationAction(
                identifier: "VIEW_BUDGET",
                title: "View Budget",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "UPDATE_BUDGET",
                title: "Update Budget",
                options: [.foreground]
            )
        ]
        let budgetCategory = UNNotificationCategory(
            identifier: NotificationCategory.budget.rawValue,
            actions: budgetActions,
            intentIdentifiers: [],
            options: []
        )
        categories.insert(budgetCategory)
        
        // Warning category with urgent actions
        let warningActions = [
            UNNotificationAction(
                identifier: "VIEW_SPENDING",
                title: "View Spending",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "ADJUST_BUDGET",
                title: "Adjust Budget",
                options: [.foreground]
            )
        ]
        let warningCategory = UNNotificationCategory(
            identifier: NotificationCategory.warning.rawValue,
            actions: warningActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(warningCategory)
        
        // Achievement category
        let achievementActions = [
            UNNotificationAction(
                identifier: "VIEW_ACHIEVEMENTS",
                title: "View Achievements",
                options: [.foreground]
            )
        ]
        let achievementCategory = UNNotificationCategory(
            identifier: NotificationCategory.achievement.rawValue,
            actions: achievementActions,
            intentIdentifiers: [],
            options: []
        )
        categories.insert(achievementCategory)
        
        // Reminder category
        let reminderActions = [
            UNNotificationAction(
                identifier: "OPEN_APP",
                title: "Open App",
                options: [.foreground]
            )
        ]
        let reminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.reminder.rawValue,
            actions: reminderActions,
            intentIdentifiers: [],
            options: []
        )
        categories.insert(reminderCategory)
        
        notificationCenter.setNotificationCategories(categories)
        print("✅ NotificationManager: Setup \(categories.count) notification categories")
    }
    
    private func createPurchaseReminderTemplate() -> NotificationTemplate {
        let messages = [
            "Don't forget to log your recent purchases! 🛒",
            "Time to update your spending records 📝",
            "Keep your budget on track - add your purchases 💰",
            "Quick reminder: Log your recent transactions 📊"
        ]
        
        let randomMessage = messages.randomElement() ?? messages[0]
        
        return NotificationTemplate(
            title: "Purchase Reminder",
            body: randomMessage,
            category: .purchase,
            priority: .normal,
            userInfo: ["type": "purchase_reminder"]
        )
    }
    
    private func createBudgetUpdateTemplate() -> NotificationTemplate {
        let messages = [
            "Time to review and update your budget! 📈",
            "Monthly budget check-in time 📋",
            "Keep your financial goals on track 🎯",
            "Time for your budget planning session 💡"
        ]
        
        let randomMessage = messages.randomElement() ?? messages[0]
        
        return NotificationTemplate(
            title: "Budget Update",
            body: randomMessage,
            category: .budget,
            priority: .normal,
            userInfo: ["type": "budget_update"]
        )
    }
    
    private func createBudgetWarningTemplate(
        category: String,
        currentSpent: Double,
        budgetLimit: Double,
        percentageOver: Double
    ) -> NotificationTemplate {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        
        let spentFormatted = formatter.string(from: NSNumber(value: currentSpent)) ?? "\(currentSpent)"
        let limitFormatted = formatter.string(from: NSNumber(value: budgetLimit)) ?? "\(budgetLimit)"
        
        let body = "You've spent \(spentFormatted) of your \(limitFormatted) \(category) budget (\(String(format: "%.0f", percentageOver))% over). Consider adjusting your spending or budget."
        
        return NotificationTemplate(
            title: "⚠️ Budget Alert: \(category)",
            body: body,
            category: .warning,
            priority: .high,
            userInfo: [
                "type": "budget_warning",
                "category": category,
                "currentSpent": currentSpent,
                "budgetLimit": budgetLimit,
                "percentageOver": percentageOver
            ]
        )
    }
    
    private func createTrigger(for frequency: SettingsManager.PurchaseNotificationFrequency) -> UNNotificationTrigger {
        var dateComponents = DateComponents()
        
        switch frequency {
        case .daily:
            dateComponents.hour = AppConstants.Time.defaultReminderHour
        case .weekly:
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = AppConstants.Time.defaultReminderHour
        case .monthly:
            dateComponents.day = AppConstants.Time.defaultBudgetUpdateDay
            dateComponents.hour = AppConstants.Time.defaultReminderHour
        }
        
        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    }
    
    private func createTrigger(for frequency: SettingsManager.BudgetTotalNotificationFrequency) -> UNNotificationTrigger {
        var dateComponents = DateComponents()
        dateComponents.hour = 9 // 9 AM
        
        switch frequency {
        case .monthly:
            dateComponents.day = AppConstants.Time.defaultBudgetUpdateDay
        case .yearly:
            dateComponents.day = 1
            dateComponents.month = 1
        }
        
        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    }
    
    private func updateAuthorizationState() async {
        let settings = await notificationCenter.notificationSettings()
        
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
            isEnabled = settings.authorizationStatus == .authorized
        }
    }
    
    private func checkInitialAuthorizationState() async {
        await updateAuthorizationState()
        print("📱 NotificationManager: Initial authorization status: \(authorizationStatus.rawValue)")
    }
    
    private func refreshNotificationLists() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        
        await MainActor.run {
            self.pendingNotifications = pendingRequests
            self.deliveredNotifications = deliveredNotifications
            self.scheduledNotificationCount = pendingRequests.count
        }
    }
    
    private func setupPeriodicStatusChecks() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
           Task<Void, Never>{ [weak self] in
                await self?.updateAuthorizationState()
                await self?.refreshNotificationLists()
                await self?.cleanupOldNotifications()
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 2.0 {
                print("⚠️ NotificationManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 NotificationManager Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is active
        completionHandler([.banner, .badge, .sound])
        
        print("📱 NotificationManager: Presenting notification in foreground")
    }
    
    /// Handle notification actions
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let notification = response.notification
        let userInfo = notification.request.content.userInfo
        
        print("📱 NotificationManager: Received action '\(actionIdentifier)' for notification")
        
       Task<Void, Never>{
            await handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo)
            completionHandler()
        }
    }
    
    private func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        switch actionIdentifier {
        case "ADD_PURCHASE":
            NotificationCenter.default.post(
                name: .openAddPurchase,
                object: nil,
                userInfo: userInfo
            )
            
        case "VIEW_BUDGET":
            NotificationCenter.default.post(
                name: .openBudgetView,
                object: nil,
                userInfo: userInfo
            )
            
        case "UPDATE_BUDGET":
            NotificationCenter.default.post(
                name: .openBudgetUpdate,
                object: nil,
                userInfo: userInfo
            )
            
        case "VIEW_SPENDING":
            NotificationCenter.default.post(
                name: .openSpendingView,
                object: nil,
                userInfo: userInfo
            )
            
        case "ADJUST_BUDGET":
            NotificationCenter.default.post(
                name: .openBudgetAdjustment,
                object: nil,
                userInfo: userInfo
            )
            
        case "VIEW_ACHIEVEMENTS":
            NotificationCenter.default.post(
                name: .openAchievements,
                object: nil,
                userInfo: userInfo
            )
            
        case "REMIND_LATER":
            try? await scheduleDelayedReminder(delay: 3600) // 1 hour
            
        case "OPEN_APP":
            NotificationCenter.default.post(
                name: .openAppFromNotification,
                object: nil,
                userInfo: userInfo
            )
            
        case UNNotificationDefaultActionIdentifier:
            NotificationCenter.default.post(
                name: .openAppFromNotification,
                object: nil,
                userInfo: userInfo
            )
            
        default:
            print("⚠️ NotificationManager: Unknown action identifier: \(actionIdentifier)")
        }
    }
    
    private func scheduleDelayedReminder(delay: TimeInterval) async throws {
        let template = createPurchaseReminderTemplate()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let identifier = "delayed_reminder_\(UUID().uuidString)"
        
        let schedule = NotificationSchedule(
            identifier: identifier,
            template: template,
            trigger: trigger,
            repeats: false
        )
        
        try await scheduleNotification(schedule)
        print("⏰ NotificationManager: Scheduled delayed reminder in \(delay/3600) hours")
    }
}

// MARK: - Supporting Types

public struct NotificationStatistics {
    public let totalPending: Int
    public let totalDelivered: Int
    public let authorizationStatus: UNAuthorizationStatus
    public let categoryBreakdown: [String: Int]
    public let nextScheduledDate: Date?
    public let lastError: AppError?
    public let lastSuccessfulSchedule: Date?
    
    public var summary: String {
        return "Pending: \(totalPending), Delivered: \(totalDelivered), Status: \(authorizationStatus.rawValue)"
    }
    
    public var healthStatus: HealthStatus {
        if lastError != nil {
            return .error
        } else if authorizationStatus != .authorized {
            return .warning
        } else if totalPending > 0 {
            return .active
        } else {
            return .idle
        }
    }
    
    public enum HealthStatus: String, CaseIterable {
        case active = "Active"
        case idle = "Idle"
        case warning = "Warning"
        case error = "Error"
        
        public var color: Color {
            switch self {
            case .active: return .green
            case .idle: return .gray
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .active: return "bell.fill"
            case .idle: return "bell.slash"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
}

public struct NotificationInsights {
    public let statistics: NotificationStatistics
    public let recommendations: [String]
    public let overallHealth: NotificationStatistics.HealthStatus
    public let lastAnalysis: Date
    
    public var hasIssues: Bool {
        return !recommendations.isEmpty || overallHealth == .error || overallHealth == .warning
    }
    
    public var summary: String {
        let issueCount = recommendations.count
        if issueCount == 0 {
            return "All notification systems are working properly"
        } else {
            return "\(issueCount) notification \(issueCount == 1 ? "issue" : "issues") found"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let openAddPurchase = Notification.Name("openAddPurchase")
    static let openBudgetView = Notification.Name("openBudgetView")
    static let openBudgetUpdate = Notification.Name("openBudgetUpdate")
    static let openSpendingView = Notification.Name("openSpendingView")
    static let openBudgetAdjustment = Notification.Name("openBudgetAdjustment")
    static let openAchievements = Notification.Name("openAchievements")
    static let openAppFromNotification = Notification.Name("openAppFromNotification")
}

extension UNAuthorizationStatus {
    public var displayName: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    public var isAuthorized: Bool {
        return self == .authorized || self == .provisional
    }
}

// MARK: - Advanced Notification Features

extension NotificationManager {
    /// Schedule smart budget notifications based on spending patterns
    public func scheduleSmartBudgetNotifications(
        spendingData: [String: Double],
        budgetData: [String: Double]
    ) async throws {
        let startTime = Date()
        
        try await performOperation(context: "Scheduling smart budget notifications") {
            guard await checkNotificationStatus() else {
                throw NotificationError.authorizationDenied
            }
            
            try await validateNotificationLimits()
            
            for (category, spent) in spendingData {
                guard let budget = budgetData[category], budget > 0 else { continue }
                
                let percentage = (spent / budget) * 100
                
                // Schedule warning at 80% and 100% of budget
                if percentage >= 80 && percentage < 100 {
                    try await scheduleBudgetWarning(
                        category: category,
                        currentSpent: spent,
                        budgetLimit: budget,
                        delay: 0
                    )
                } else if percentage >= 100 {
                    try await scheduleBudgetWarning(
                        category: category,
                        currentSpent: spent,
                        budgetLimit: budget,
                        delay: 0
                    )
                }
            }
            
            recordMetric("scheduleSmartBudgetNotifications", duration: Date().timeIntervalSince(startTime))
            print("🧠 NotificationManager: Scheduled smart budget notifications")
        }
    }
    
    /// Schedule data backup reminder
    public func scheduleDataBackupReminder(delay: TimeInterval = 86400) async throws { // 24 hours default
        do {
            try await performOperation(context: "Scheduling backup reminder") {
                guard await checkNotificationStatus() else { return }
                
                let template = NotificationTemplate(
                    title: "Data Backup Reminder",
                    body: "Don't forget to backup your budget data to keep it safe! 💾",
                    category: .reminder,
                    priority: .normal,
                    userInfo: ["type": "backup_reminder"]
                )
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let identifier = NotificationIdentifiers.dataBackup
                
                let schedule = NotificationSchedule(
                    identifier: identifier,
                    template: template,
                    trigger: trigger,
                    repeats: false
                )
                
                try await scheduleNotification(schedule)
                print("💾 NotificationManager: Scheduled data backup reminder")
            }
        } catch {
            // Don't propagate backup reminder errors
            print("⚠️ NotificationManager: Failed to schedule backup reminder - \(error.localizedDescription)")
        }
    }
    
    /// Schedule monthly review notification
    public func scheduleMonthlyReview() async throws {
        try await performOperation(context: "Scheduling monthly review") {
            guard await checkNotificationStatus() else { return }
            
            let template = NotificationTemplate(
                title: "Monthly Budget Review",
                body: "Time to review your monthly spending and plan for next month! 📊",
                category: .budget,
                priority: .normal,
                userInfo: ["type": "monthly_review"]
            )
            
            // Schedule for the first day of next month at 10 AM
            var dateComponents = DateComponents()
            dateComponents.day = 1
            dateComponents.hour = 10
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = NotificationIdentifiers.monthlyReview
            
            let schedule = NotificationSchedule(
                identifier: identifier,
                template: template,
                trigger: trigger,
                repeats: true
            )
            
            try await scheduleNotification(schedule)
            print("📅 NotificationManager: Scheduled monthly review notifications")
        }
    }
    
    /// Get notification insights and recommendations
    public func getNotificationInsights() async -> NotificationInsights {
        let statistics = await getNotificationStatistics()
        
        var recommendations: [String] = []
        
        // Check authorization status
        if statistics.authorizationStatus != .authorized {
            recommendations.append("Enable notification permissions to receive budget reminders")
        }
        
        // Check if notifications are being scheduled
        if statistics.totalPending == 0 && statistics.authorizationStatus == .authorized {
            recommendations.append("No notifications are currently scheduled. Check your notification settings.")
        }
        
        // Check for delivery issues
        if statistics.totalDelivered == 0 && statistics.lastSuccessfulSchedule != nil {
            recommendations.append("Notifications are scheduled but none have been delivered. Check your device settings.")
        }
        
        // Check for errors
        if let error = statistics.lastError {
            recommendations.append("Recent error: \(error.errorDescription ?? "Unknown error")")
        }
        
        // Check for too many notifications
        if statistics.totalPending > 50 {
            recommendations.append("You have many pending notifications. Consider reducing notification frequency.")
        }
        
        return NotificationInsights(
            statistics: statistics,
            recommendations: recommendations,
            overallHealth: statistics.healthStatus,
            lastAnalysis: Date()
        )
    }
    
    /// Perform comprehensive notification system diagnostic
    public func performSystemDiagnostic() async -> SystemDiagnostic {
        let startTime = Date()
        var issues: [String] = []
        var warnings: [String] = []
        var successfulChecks: [String] = []
        
        // Check authorization
        await updateAuthorizationState()
        if authorizationStatus == .authorized {
            successfulChecks.append("Authorization granted")
        } else {
            issues.append("Missing notification authorization")
        }
        
        // Check system settings
        let settings = await notificationCenter.notificationSettings()
        if settings.notificationCenterSetting == .enabled {
            successfulChecks.append("Notification center enabled")
        } else {
            issues.append("Notification center disabled in system settings")
        }
        
        if settings.alertSetting == .enabled {
            successfulChecks.append("Alert notifications enabled")
        } else {
            warnings.append("Alert notifications are disabled")
        }
        
        if settings.badgeSetting == .enabled {
            successfulChecks.append("Badge notifications enabled")
        } else {
            warnings.append("Badge notifications are disabled")
        }
        
        if settings.soundSetting == .enabled {
            successfulChecks.append("Sound notifications enabled")
        } else {
            warnings.append("Sound notifications are disabled")
        }
        
        // Check pending notifications
        await refreshNotificationLists()
        if pendingNotifications.count < maxPendingNotifications {
            successfulChecks.append("Notification queue has capacity")
        } else {
            issues.append("Notification queue is full")
        }
        
        // Check for recent errors
        if lastError == nil {
            successfulChecks.append("No recent errors")
        } else {
            issues.append("Recent error detected: \(lastError?.errorDescription ?? "Unknown")")
        }
        
        // Check categories
        let categories = await notificationCenter.getNotificationCategories()
        if categories.count >= NotificationCategory.allCases.count {
            successfulChecks.append("All notification categories registered")
        } else {
            warnings.append("Some notification categories may be missing")
        }
        
        let diagnosticDuration = Date().timeIntervalSince(startTime)
        
        return SystemDiagnostic(
            timestamp: Date(),
            duration: diagnosticDuration,
            authorizationStatus: authorizationStatus,
            systemSettings: settings,
            pendingCount: pendingNotifications.count,
            deliveredCount: deliveredNotifications.count,
            issues: issues,
            warnings: warnings,
            successfulChecks: successfulChecks,
            overallHealth: determineOverallHealth(issues: issues, warnings: warnings)
        )
    }
    
    private func determineOverallHealth(issues: [String], warnings: [String]) -> SystemDiagnostic.HealthLevel {
        if !issues.isEmpty {
            return .critical
        } else if warnings.count > 2 {
            return .warning
        } else if warnings.count > 0 {
            return .caution
        } else {
            return .healthy
        }
    }
}

// MARK: - System Diagnostic

public struct SystemDiagnostic {
    public let timestamp: Date
    public let duration: TimeInterval
    public let authorizationStatus: UNAuthorizationStatus
    public let systemSettings: UNNotificationSettings
    public let pendingCount: Int
    public let deliveredCount: Int
    public let issues: [String]
    public let warnings: [String]
    public let successfulChecks: [String]
    public let overallHealth: HealthLevel
    
    public enum HealthLevel: String, CaseIterable {
        case healthy = "Healthy"
        case caution = "Caution"
        case warning = "Warning"
        case critical = "Critical"
        
        public var color: Color {
            switch self {
            case .healthy: return .green
            case .caution: return .yellow
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .caution: return "exclamationmark.circle"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
    
    public var summary: String {
        let totalIssues = issues.count + warnings.count
        if totalIssues == 0 {
            return "All systems operational"
        } else {
            return "\(totalIssues) \(totalIssues == 1 ? "issue" : "issues") detected"
        }
    }
    
    public var detailedReport: String {
        var report = "Notification System Diagnostic Report\n"
        report += "Generated: \(timestamp.formatted())\n"
        report += "Duration: \(String(format: "%.2f", duration * 1000))ms\n"
        report += "Overall Health: \(overallHealth.rawValue)\n\n"
        
        if !issues.isEmpty {
            report += "Issues (\(issues.count)):\n"
            for issue in issues {
                report += "• \(issue)\n"
            }
            report += "\n"
        }
        
        if !warnings.isEmpty {
            report += "Warnings (\(warnings.count)):\n"
            for warning in warnings {
                report += "• \(warning)\n"
            }
            report += "\n"
        }
        
        if !successfulChecks.isEmpty {
            report += "Successful Checks (\(successfulChecks.count)):\n"
            for check in successfulChecks {
                report += "• \(check)\n"
            }
        }
        
        return report
    }
}

// MARK: - Testing Support

#if DEBUG
extension NotificationManager {
    /// Create test notifications for development
    func createTestNotifications() async {
        do {
            // Test purchase reminder
            try await scheduleAchievementNotification(
                title: "Test Achievement",
                message: "This is a test achievement notification!",
                delay: 5
            )
            
            // Test budget warning
            try await scheduleBudgetWarning(
                category: "Groceries",
                currentSpent: 550,
                budgetLimit: 500,
                delay: 10
            )
            
            print("✅ NotificationManager: Created test notifications")
            
        } catch {
            print("❌ NotificationManager: Failed to create test notifications - \(error.localizedDescription)")
        }
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        scheduledCount: Int,
        deliveredCount: Int,
        authStatus: UNAuthorizationStatus,
        hasError: Bool,
        metricsCount: Int,
        isProcessing: Bool
    ) {
        return (
            scheduledCount: pendingNotifications.count,
            deliveredCount: deliveredNotifications.count,
            authStatus: authorizationStatus,
            hasError: lastError != nil,
            metricsCount: operationMetrics.count,
            isProcessing: isProcessing
        )
    }
    
    /// Force refresh notification lists for testing
    func forceRefreshForTesting() async {
        await refreshNotificationLists()
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Clear all metrics for testing
    func clearMetricsForTesting() {
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
    }
    
    /// Simulate notification authorization for testing
    func simulateAuthorizationForTesting(_ status: UNAuthorizationStatus) async {
        await MainActor.run {
            authorizationStatus = status
            isEnabled = status == .authorized
        }
    }
    
    /// Test error handling
    func triggerTestError() async {
        await handleError(
            AppError.permission(type: .notifications),
            context: "Testing error handling"
        )
    }
    
    /// Reset state for testing
    func resetStateForTesting() async {
        await MainActor.run {
            lastError = nil
            isProcessing = false
            lastSuccessfulSchedule = nil
        }
        
        await cancelAllNotifications()
        await refreshNotificationLists()
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
    }
}

// Mock notification center for testing
public class MockNotificationCenter: UNUserNotificationCenter {
    public var mockAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    public var mockPendingRequests: [UNNotificationRequest] = []
    public var mockDeliveredNotifications: [UNNotification] = []
    public var requestAuthorizationResult: (Bool, Error?) = (true, nil)
    public var shouldFailScheduling = false
    
    public override func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = requestAuthorizationResult.1 {
            throw error
        }
        mockAuthorizationStatus = requestAuthorizationResult.0 ? .authorized : .denied
        return requestAuthorizationResult.0
    }
    
    public func getNotificationSettings() async -> UNNotificationSettings {
        // Return mock settings - would need to create a proper mock UNNotificationSettings
        return await super.getNotificationSettings()
    }
    
    public override func add(_ request: UNNotificationRequest) async throws {
        if shouldFailScheduling {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock scheduling failure"])
        }
        mockPendingRequests.append(request)
    }
    
    public func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return mockPendingRequests
    }
    
    public func getDeliveredNotifications() async -> [UNNotification] {
        return mockDeliveredNotifications
    }
    
    public override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        mockPendingRequests.removeAll { identifiers.contains($0.identifier) }
    }
    
    public override func removeAllPendingNotificationRequests() {
        mockPendingRequests.removeAll()
    }
    
    public override func removeAllDeliveredNotifications() {
        mockDeliveredNotifications.removeAll()
    }
}
#endif
