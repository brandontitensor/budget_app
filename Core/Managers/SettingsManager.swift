//
//  SettingsManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation
import Combine
import UserNotifications
import UIKit


/// Manages the app's user settings and preferences with proper state management, validation, and error handling
@MainActor
public final class SettingsManager: ObservableObject {
    // MARK: - Types
    public enum PurchaseNotificationFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        public var displayName: String { rawValue }
        
        public var systemImageName: String {
            switch self {
            case .daily: return "bell.badge"
            case .weekly: return "bell.badge.circle"
            case .monthly: return "bell.badge.fill"
            }
        }
        
        public var description: String {
            switch self {
            case .daily: return "Daily reminders to log purchases"
            case .weekly: return "Weekly reminders to log purchases"
            case .monthly: return "Monthly reminders to log purchases"
            }
        }
    }
    
    public enum BudgetTotalNotificationFrequency: String, Codable, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        public var displayName: String { rawValue }
        
        public var systemImageName: String {
            switch self {
            case .monthly: return "calendar.circle"
            case .yearly: return "calendar.badge.plus"
            }
        }
        
        public var description: String {
            switch self {
            case .monthly: return "Monthly budget review reminders"
            case .yearly: return "Yearly budget planning reminders"
            }
        }
    }
    
    public enum DataExportFormat: String, Codable, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        
        public var displayName: String { rawValue }
        public var fileExtension: String { rawValue.lowercased() }
        public var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .json: return "application/json"
            }
        }
    }
    
    public enum BackupFrequency: String, Codable, CaseIterable {
        case never = "Never"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        public var displayName: String { rawValue }
        
        public var systemImageName: String {
            switch self {
            case .never: return "xmark.icloud"
            case .daily: return "icloud.and.arrow.up"
            case .weekly: return "icloud.and.arrow.up.fill"
            case .monthly: return "icloud.circle"
            }
        }
        
        public var intervalInSeconds: TimeInterval? {
            switch self {
            case .never: return nil
            case .daily: return 86400 // 24 hours
            case .weekly: return 604800 // 7 days
            case .monthly: return 2592000 // 30 days
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published public var userName: String {
        didSet {
            saveUserName(userName)
            validateAndHandleError(userName, validation: validateUserName)
        }
    }
    
    @Published public var defaultCurrency: String {
        didSet {
            saveDefaultCurrency(defaultCurrency)
            validateAndHandleError(defaultCurrency, validation: validateCurrency)
        }
    }
    
    @Published public var notificationsAllowed: Bool {
        didSet {
            saveNotificationsAllowed(notificationsAllowed)
            notificationStateChanged()
        }
    }
    
    @Published public var purchaseNotificationsEnabled: Bool {
        didSet {
            savePurchaseNotificationsEnabled(purchaseNotificationsEnabled)
            notificationStateChanged()
        }
    }
    
    @Published public var purchaseNotificationFrequency: PurchaseNotificationFrequency {
        didSet {
            savePurchaseNotificationFrequency(purchaseNotificationFrequency)
            notificationStateChanged()
        }
    }
    
    @Published public var budgetTotalNotificationsEnabled: Bool {
        didSet {
            saveBudgetTotalNotificationsEnabled(budgetTotalNotificationsEnabled)
            notificationStateChanged()
        }
    }
    
    @Published public var budgetTotalNotificationFrequency: BudgetTotalNotificationFrequency {
        didSet {
            saveBudgetTotalNotificationFrequency(budgetTotalNotificationFrequency)
            notificationStateChanged()
        }
    }
    
    @Published public var isFirstLaunch: Bool {
        didSet { saveIsFirstLaunch(isFirstLaunch) }
    }
    
    // MARK: - Additional Settings
    @Published public var enableHapticFeedback: Bool {
        didSet { saveEnableHapticFeedback(enableHapticFeedback) }
    }
    
    @Published public var enableDataBackup: Bool {
        didSet {
            saveEnableDataBackup(enableDataBackup)
            if enableDataBackup {
                scheduleNextBackup()
            } else {
                cancelScheduledBackup()
            }
        }
    }
    
    @Published public var backupFrequency: BackupFrequency {
        didSet {
            saveBackupFrequency(backupFrequency)
            if enableDataBackup {
                scheduleNextBackup()
            }
        }
    }
    
    @Published public var lastBackupDate: Date? {
        didSet { saveLastBackupDate(lastBackupDate) }
    }
    
    @Published public var privacyMode: Bool {
        didSet { savePrivacyMode(privacyMode) }
    }
    
    @Published public var biometricAuthEnabled: Bool {
        didSet { saveBiometricAuthEnabled(biometricAuthEnabled) }
    }
    
    @Published public var defaultExportFormat: DataExportFormat {
        didSet { saveDefaultExportFormat(defaultExportFormat) }
    }
    
    @Published public var showDecimalPlaces: Bool {
        didSet { saveShowDecimalPlaces(showDecimalPlaces) }
    }
    
    @Published public var roundToNearestCent: Bool {
        didSet { saveRoundToNearestCent(roundToNearestCent) }
    }
    
    @Published public var enableAdvancedFeatures: Bool {
        didSet { saveEnableAdvancedFeatures(enableAdvancedFeatures) }
    }
    
    // MARK: - Private Properties
    private enum Keys: String, CaseIterable {
        case userName
        case defaultCurrency
        case notificationsAllowed
        case purchaseNotificationsEnabled
        case purchaseNotificationFrequency
        case budgetTotalNotificationsEnabled
        case budgetTotalNotificationFrequency
        case isFirstLaunch
        case enableHapticFeedback
        case enableDataBackup
        case backupFrequency
        case lastBackupDate
        case privacyMode
        case biometricAuthEnabled
        case defaultExportFormat
        case showDecimalPlaces
        case roundToNearestCent
        case enableAdvancedFeatures
        case settingsVersion
        case lastMigrationDate
        
        var key: String { AppConstants.Storage.userDefaultsKeyPrefix + rawValue }
    }
    
    private let userDefaults: UserDefaults
    private let errorHandler: ErrorHandler
    private var cancellables = Set<AnyCancellable>()
    private let settingsQueue = DispatchQueue(label: "com.brandonsbudget.settings", qos: .utility)
    
    // MARK: - Version Management
    private let currentSettingsVersion = 3
    private var hasPerformedMigration = false
    
    // MARK: - Validation Rules
    private struct ValidationRules {
        static let maxUserNameLength = 50
        static let minUserNameLength = 1
        static let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "SEK", "NOK", "DKK"]
        static let maxBackupRetentionDays = 30
        static let reservedUserNames = ["admin", "system", "user", "test", "guest"]
    }
    
    // MARK: - Notification State
    @Published public private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var lastNotificationUpdate: Date?
    
    // MARK: - Backup State
    private var backupTimer: Timer?
    @Published public private(set) var isBackupInProgress = false
    @Published public private(set) var nextScheduledBackup: Date?
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.settings.metrics", qos: .utility)
    
    // MARK: - Initialization
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.errorHandler = ErrorHandler.shared
        
        // Initialize properties with safe defaults
        self.userName = ""
        self.defaultCurrency = "USD"
        self.notificationsAllowed = false
        self.purchaseNotificationsEnabled = false
        self.purchaseNotificationFrequency = .daily
        self.budgetTotalNotificationsEnabled = false
        self.budgetTotalNotificationFrequency = .monthly
        self.isFirstLaunch = true
        self.enableHapticFeedback = true
        self.enableDataBackup = false
        self.backupFrequency = .weekly
        self.lastBackupDate = nil
        self.privacyMode = false
        self.biometricAuthEnabled = false
        self.defaultExportFormat = .csv
        self.showDecimalPlaces = true
        self.roundToNearestCent = true
        self.enableAdvancedFeatures = false
        
        // Load existing settings
        loadAllSettings()
        
        // Setup migration if needed
        performMigrationIfNeeded()
        
        // Setup notification state observation
        setupNotificationStateObservation()
        
        // Setup automatic backup
        setupAutomaticBackup()
        
        // Monitor performance
        setupPerformanceMonitoring()
        
        print("✅ SettingsManager: Initialized with version \(currentSettingsVersion)")
    }
    
    // MARK: - Public Methods
    
    /// Update user name with comprehensive validation
    public func updateUserName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateUserName(trimmedName)
        userName = trimmedName
    }
    
    /// Update default currency with validation
    public func updateDefaultCurrency(_ currency: String) throws {
        try validateCurrency(currency)
        defaultCurrency = currency
    }
    
    /// Update notification settings with comprehensive validation
    public func updateNotificationSettings(
        allowed: Bool,
        purchaseEnabled: Bool,
        purchaseFrequency: PurchaseNotificationFrequency,
        budgetEnabled: Bool,
        budgetFrequency: BudgetTotalNotificationFrequency
    ) async throws {
        // Validate notification permissions
        if purchaseEnabled || budgetEnabled {
            guard allowed else {
                throw AppError.validation(message: "Cannot enable specific notifications without general permission")
            }
        }
        
        // Check system notification authorization if enabling notifications
        if allowed && (purchaseEnabled || budgetEnabled) {
            let authStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if authStatus == .denied {
                throw AppError.permission(type: .notifications)
            }
        }
        
        // Update all settings atomically
        notificationsAllowed = allowed
        purchaseNotificationsEnabled = purchaseEnabled
        purchaseNotificationFrequency = purchaseFrequency
        budgetTotalNotificationsEnabled = budgetEnabled
        budgetTotalNotificationFrequency = budgetFrequency
        
        lastNotificationUpdate = Date()
    }
    
    /// Reset all settings to their default values
    public func resetToDefaults() async throws {
        let startTime = Date()
        
        do {
            // Clear all settings from UserDefaults
            for key in Keys.allCases {
                userDefaults.removeObject(forKey: key.key)
            }
            
            // Reset published properties to defaults
            await MainActor.run {
                userName = ""
                defaultCurrency = "USD"
                notificationsAllowed = false
                purchaseNotificationsEnabled = false
                purchaseNotificationFrequency = .daily
                budgetTotalNotificationsEnabled = false
                budgetTotalNotificationFrequency = .monthly
                isFirstLaunch = true
                enableHapticFeedback = true
                enableDataBackup = false
                backupFrequency = .weekly
                lastBackupDate = nil
                privacyMode = false
                biometricAuthEnabled = false
                defaultExportFormat = .csv
                showDecimalPlaces = true
                roundToNearestCent = true
                enableAdvancedFeatures = false
                lastNotificationUpdate = nil
                nextScheduledBackup = nil
            }
            
            // Cancel all notifications
            await NotificationManager.shared.cancelAllNotifications()
            
            // Cancel scheduled backups
            cancelScheduledBackup()
            
            recordMetric("resetToDefaults", duration: Date().timeIntervalSince(startTime))
            print("✅ SettingsManager: Reset to defaults completed")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Resetting settings to defaults")
            throw appError
        }
    }
    
    /// Export settings to a dictionary for backup purposes
    public func exportSettings() async throws -> [String: Any] {
        let startTime = Date()
        
        do {
            let settings: [String: Any] = [
                Keys.userName.key: userName,
                Keys.defaultCurrency.key: defaultCurrency,
                Keys.notificationsAllowed.key: notificationsAllowed,
                Keys.purchaseNotificationsEnabled.key: purchaseNotificationsEnabled,
                Keys.purchaseNotificationFrequency.key: purchaseNotificationFrequency.rawValue,
                Keys.budgetTotalNotificationsEnabled.key: budgetTotalNotificationsEnabled,
                Keys.budgetTotalNotificationFrequency.key: budgetTotalNotificationFrequency.rawValue,
                Keys.isFirstLaunch.key: isFirstLaunch,
                Keys.enableHapticFeedback.key: enableHapticFeedback,
                Keys.enableDataBackup.key: enableDataBackup,
                Keys.backupFrequency.key: backupFrequency.rawValue,
                Keys.lastBackupDate.key: lastBackupDate?.timeIntervalSince1970 ?? 0,
                Keys.privacyMode.key: privacyMode,
                Keys.biometricAuthEnabled.key: biometricAuthEnabled,
                Keys.defaultExportFormat.key: defaultExportFormat.rawValue,
                Keys.showDecimalPlaces.key: showDecimalPlaces,
                Keys.roundToNearestCent.key: roundToNearestCent,
                Keys.enableAdvancedFeatures.key: enableAdvancedFeatures,
                Keys.settingsVersion.key: currentSettingsVersion,
                "exportDate": Date().timeIntervalSince1970,
                "exportVersion": "3.0",
                "deviceInfo": [
                    "model": UIDevice.current.model,
                    "systemVersion": UIDevice.current.systemVersion,
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                ]
            ]
            
            recordMetric("exportSettings", duration: Date().timeIntervalSince(startTime))
            return settings
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Exporting settings")
            throw appError
        }
    }
    
    /// Import settings from a backup dictionary
    public func importSettings(_ settings: [String: Any]) async throws {
        let startTime = Date()
        
        do {
            // Validate import data structure
            guard let userName = settings[Keys.userName.key] as? String,
                  let defaultCurrency = settings[Keys.defaultCurrency.key] as? String,
                  let notificationsAllowed = settings[Keys.notificationsAllowed.key] as? Bool,
                  let purchaseNotificationsEnabled = settings[Keys.purchaseNotificationsEnabled.key] as? Bool,
                  let purchaseFrequencyString = settings[Keys.purchaseNotificationFrequency.key] as? String,
                  let purchaseFrequency = PurchaseNotificationFrequency(rawValue: purchaseFrequencyString),
                  let budgetNotificationsEnabled = settings[Keys.budgetTotalNotificationsEnabled.key] as? Bool,
                  let budgetFrequencyString = settings[Keys.budgetTotalNotificationFrequency.key] as? String,
                  let budgetFrequency = BudgetTotalNotificationFrequency(rawValue: budgetFrequencyString) else {
                throw AppError.csvImport(underlying: NSError(
                    domain: "SettingsManager",
                    code: 4001,
                    userInfo: [NSLocalizedDescriptionKey: "Missing required settings fields"]
                ))
            }
            
            // Validate imported data
            try validateImportedData(
                userName: userName,
                currency: defaultCurrency,
                notificationsAllowed: notificationsAllowed,
                purchaseEnabled: purchaseNotificationsEnabled,
                budgetEnabled: budgetNotificationsEnabled
            )
            
            // Import core settings
            await MainActor.run {
                self.userName = userName
                self.defaultCurrency = defaultCurrency
                self.notificationsAllowed = notificationsAllowed
                self.purchaseNotificationsEnabled = purchaseNotificationsEnabled
                self.purchaseNotificationFrequency = purchaseFrequency
                self.budgetTotalNotificationsEnabled = budgetNotificationsEnabled
                self.budgetTotalNotificationFrequency = budgetFrequency
            }
            
            // Import optional settings with fallbacks
            await importOptionalSettings(settings)
            
            recordMetric("importSettings", duration: Date().timeIntervalSince(startTime))
            print("✅ SettingsManager: Settings imported successfully")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Importing settings")
            throw appError
        }
    }
    
    /// Create comprehensive settings backup
    public func createBackup() async throws -> URL {
        let startTime = Date()
        isBackupInProgress = true
        defer { isBackupInProgress = false }
        
        do {
            let settings = try await exportSettings()
            let backupData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let backupDirectory = documentsPath.appendingPathComponent("Settings Backups")
            
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            
            let timestamp = DateFormatter.backupTimestamp.string(from: Date())
            let backupURL = backupDirectory.appendingPathComponent("settings_backup_\(timestamp).json")
            
            try backupData.write(to: backupURL)
            
            // Update backup state
            await MainActor.run {
                lastBackupDate = Date()
                scheduleNextBackup()
            }
            
            // Clean up old backups
            await cleanupOldBackups()
            
            recordMetric("createBackup", duration: Date().timeIntervalSince(startTime))
            print("✅ SettingsManager: Backup created at \(backupURL.lastPathComponent)")
            return backupURL
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Creating settings backup")
            throw appError
        }
    }
    
    /// Restore settings from backup file
    public func restoreFromBackup(_ url: URL) async throws {
        let startTime = Date()
        
        do {
            let backupData = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: backupData) as? [String: Any]
            
            guard let settings = settings else {
                throw AppError.fileAccess(underlying: NSError(
                    domain: "SettingsManager",
                    code: 4002,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid backup file format"]
                ))
            }
            
            // Validate backup version compatibility
            if let backupVersion = settings["exportVersion"] as? String,
               let version = Double(backupVersion),
               version > 3.0 {
                throw AppError.validation(message: "Backup file is from a newer version and cannot be imported")
            }
            
            try await importSettings(settings)
            
            recordMetric("restoreFromBackup", duration: Date().timeIntervalSince(startTime))
            print("✅ SettingsManager: Settings restored from backup")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Restoring settings from backup")
            throw appError
        }
    }
    
    /// Get comprehensive settings summary for debugging
    public func getSettingsSummary() -> [String: Any] {
        return [
            "Core Settings": [
                "userName": userName.isEmpty ? "<empty>" : userName,
                "defaultCurrency": defaultCurrency,
                "isFirstLaunch": isFirstLaunch,
                "settingsVersion": currentSettingsVersion
            ],
            "Notifications": [
                "notificationsAllowed": notificationsAllowed,
                "purchaseNotificationsEnabled": purchaseNotificationsEnabled,
                "purchaseNotificationFrequency": purchaseNotificationFrequency.rawValue,
                "budgetTotalNotificationsEnabled": budgetTotalNotificationsEnabled,
                "budgetTotalNotificationFrequency": budgetTotalNotificationFrequency.rawValue,
                "lastNotificationUpdate": lastNotificationUpdate?.description ?? "<none>",
                "authorizationStatus": notificationAuthorizationStatus.rawValue
            ],
            "Backup & Privacy": [
                "enableDataBackup": enableDataBackup,
                "backupFrequency": backupFrequency.rawValue,
                "lastBackupDate": lastBackupDate?.description ?? "<none>",
                "nextScheduledBackup": nextScheduledBackup?.description ?? "<none>",
                "privacyMode": privacyMode,
                "biometricAuthEnabled": biometricAuthEnabled
            ],
            "User Interface": [
                "enableHapticFeedback": enableHapticFeedback,
                "defaultExportFormat": defaultExportFormat.rawValue,
                "showDecimalPlaces": showDecimalPlaces,
                "roundToNearestCent": roundToNearestCent,
                "enableAdvancedFeatures": enableAdvancedFeatures
            ],
            "System Info": [
                "isValid": validateCurrentSettings(),
                "hasPerformedMigration": hasPerformedMigration,
                "isBackupInProgress": isBackupInProgress
            ]
        ]
    }
    
    /// Get backup status information
    public func getBackupStatus() -> (enabled: Bool, lastBackup: Date?, nextBackup: Date?, isInProgress: Bool) {
        return (
            enabled: enableDataBackup,
            lastBackup: lastBackupDate,
            nextBackup: nextScheduledBackup,
            isInProgress: isBackupInProgress
        )
    }
    
    /// Check if notification permissions are properly configured
    public func checkNotificationConfiguration() async -> (hasPermission: Bool, needsSetup: Bool, recommendations: [String]) {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let hasPermission = settings.authorizationStatus == .authorized
        let needsSetup = (purchaseNotificationsEnabled || budgetTotalNotificationsEnabled) && !hasPermission
        
        var recommendations: [String] = []
        
        if needsSetup {
            recommendations.append("Enable notification permissions in Settings")
        }
        
        if hasPermission && !notificationsAllowed {
            recommendations.append("Enable notifications in app settings")
        }
        
        if settings.authorizationStatus == .provisional {
            recommendations.append("Consider upgrading to full notification permissions")
        }
        
        return (hasPermission: hasPermission, needsSetup: needsSetup, recommendations: recommendations)
    }
    
    // MARK: - Private Save Methods
    
    private func saveUserName(_ value: String) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.userName.key)
        }
    }
    
    private func saveDefaultCurrency(_ value: String) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.defaultCurrency.key)
        }
    }
    
    private func saveNotificationsAllowed(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.notificationsAllowed.key)
        }
    }
    
    private func savePurchaseNotificationsEnabled(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.purchaseNotificationsEnabled.key)
        }
    }
    
    private func savePurchaseNotificationFrequency(_ value: PurchaseNotificationFrequency) {
        settingsQueue.async {
            self.userDefaults.set(value.rawValue, forKey: Keys.purchaseNotificationFrequency.key)
        }
    }
    
    private func saveBudgetTotalNotificationsEnabled(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.budgetTotalNotificationsEnabled.key)
        }
    }
    
    private func saveBudgetTotalNotificationFrequency(_ value: BudgetTotalNotificationFrequency) {
        settingsQueue.async {
            self.userDefaults.set(value.rawValue, forKey: Keys.budgetTotalNotificationFrequency.key)
        }
    }
    
    private func saveIsFirstLaunch(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.isFirstLaunch.key)
        }
    }
    
    private func saveEnableHapticFeedback(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.enableHapticFeedback.key)
        }
    }
    
    private func saveEnableDataBackup(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.enableDataBackup.key)
        }
    }
    
    private func saveBackupFrequency(_ value: BackupFrequency) {
        settingsQueue.async {
            self.userDefaults.set(value.rawValue, forKey: Keys.backupFrequency.key)
        }
    }
    
    private func saveLastBackupDate(_ value: Date?) {
        settingsQueue.async {
            if let date = value {
                self.userDefaults.set(date.timeIntervalSince1970, forKey: Keys.lastBackupDate.key)
            } else {
                self.userDefaults.removeObject(forKey: Keys.lastBackupDate.key)
            }
        }
    }
    
    private func savePrivacyMode(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.privacyMode.key)
        }
    }
    
    private func saveBiometricAuthEnabled(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.biometricAuthEnabled.key)
        }
    }
    
    private func saveDefaultExportFormat(_ value: DataExportFormat) {
        settingsQueue.async {
            self.userDefaults.set(value.rawValue, forKey: Keys.defaultExportFormat.key)
        }
    }
    
    private func saveShowDecimalPlaces(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.showDecimalPlaces.key)
        }
    }
    
    private func saveRoundToNearestCent(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.roundToNearestCent.key)
        }
    }
    
    private func saveEnableAdvancedFeatures(_ value: Bool) {
        settingsQueue.async {
            self.userDefaults.set(value, forKey: Keys.enableAdvancedFeatures.key)
        }
    }
    
    // MARK: - Private Load Methods
    
    private func loadAllSettings() {
        userName = userDefaults.string(forKey: Keys.userName.key) ?? ""
        defaultCurrency = userDefaults.string(forKey: Keys.defaultCurrency.key) ?? "USD"
        notificationsAllowed = userDefaults.bool(forKey: Keys.notificationsAllowed.key)
        purchaseNotificationsEnabled = userDefaults.bool(forKey: Keys.purchaseNotificationsEnabled.key)
        budgetTotalNotificationsEnabled = userDefaults.bool(forKey: Keys.budgetTotalNotificationsEnabled.key)
        enableHapticFeedback = userDefaults.object(forKey: Keys.enableHapticFeedback.key) as? Bool ?? true
        enableDataBackup = userDefaults.bool(forKey: Keys.enableDataBackup.key)
        privacyMode = userDefaults.bool(forKey: Keys.privacyMode.key)
        biometricAuthEnabled = userDefaults.bool(forKey: Keys.biometricAuthEnabled.key)
        showDecimalPlaces = userDefaults.object(forKey: Keys.showDecimalPlaces.key) as? Bool ?? true
        roundToNearestCent = userDefaults.object(forKey: Keys.roundToNearestCent.key) as? Bool ?? true
        enableAdvancedFeatures = userDefaults.bool(forKey: Keys.enableAdvancedFeatures.key)
        
        // Load enumeration values
        if let frequencyString = userDefaults.string(forKey: Keys.purchaseNotificationFrequency.key),
           let frequency = PurchaseNotificationFrequency(rawValue: frequencyString) {
            purchaseNotificationFrequency = frequency
        }
        
        if let frequencyString = userDefaults.string(forKey: Keys.budgetTotalNotificationFrequency.key),
           let frequency = BudgetTotalNotificationFrequency(rawValue: frequencyString) {
            budgetTotalNotificationFrequency = frequency
        }
        
        if let frequencyString = userDefaults.string(forKey: Keys.backupFrequency.key),
           let frequency = BackupFrequency(rawValue: frequencyString) {
            backupFrequency = frequency
        }
        
        if let formatString = userDefaults.string(forKey: Keys.defaultExportFormat.key),
           let format = DataExportFormat(rawValue: formatString) {
            defaultExportFormat = format
        }
        
        // Load backup date
        let backupTimestamp = userDefaults.double(forKey: Keys.lastBackupDate.key)
        if backupTimestamp > 0 {
            lastBackupDate = Date(timeIntervalSince1970: backupTimestamp)
        }
        
        // Handle first launch detection
        if !userDefaults.bool(forKey: Keys.isFirstLaunch.key + "_set") {
            isFirstLaunch = true
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key)
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key + "_set")
        } else {
            isFirstLaunch = userDefaults.bool(forKey: Keys.isFirstLaunch.key)
        }
        
        // Schedule next backup if needed
        if enableDataBackup {
            scheduleNextBackup()
        }
    }
    
    private func importOptionalSettings(_ settings: [String: Any]) async {
        await MainActor.run {
            if let enableHapticFeedback = settings[Keys.enableHapticFeedback.key] as? Bool {
                self.enableHapticFeedback = enableHapticFeedback
            }
            
            if let enableDataBackup = settings[Keys.enableDataBackup.key] as? Bool {
                self.enableDataBackup = enableDataBackup
            }
            
            if let frequencyString = settings[Keys.backupFrequency.key] as? String,
               let frequency = BackupFrequency(rawValue: frequencyString) {
                self.backupFrequency = frequency
            }
            
            if let lastBackupTimestamp = settings[Keys.lastBackupDate.key] as? TimeInterval,
               lastBackupTimestamp > 0 {
                self.lastBackupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
            }
            
            if let privacyMode = settings[Keys.privacyMode.key] as? Bool {
                self.privacyMode = privacyMode
            }
            
            if let biometricAuthEnabled = settings[Keys.biometricAuthEnabled.key] as? Bool {
                self.biometricAuthEnabled = biometricAuthEnabled
            }
            
            if let formatString = settings[Keys.defaultExportFormat.key] as? String,
               let format = DataExportFormat(rawValue: formatString) {
                self.defaultExportFormat = format
            }
            
            if let showDecimalPlaces = settings[Keys.showDecimalPlaces.key] as? Bool {
                self.showDecimalPlaces = showDecimalPlaces
            }
            
            if let roundToNearestCent = settings[Keys.roundToNearestCent.key] as? Bool {
                self.roundToNearestCent = roundToNearestCent
            }
            
            if let enableAdvancedFeatures = settings[Keys.enableAdvancedFeatures.key] as? Bool {
                self.enableAdvancedFeatures = enableAdvancedFeatures
            }
        }
    }
    
    // MARK: - Migration
    
    private func performMigrationIfNeeded() {
        let savedVersion = userDefaults.integer(forKey: Keys.settingsVersion.key)
        
        if savedVersion < currentSettingsVersion && !hasPerformedMigration {
            do {
                try migrateSettings(from: savedVersion, to: currentSettingsVersion)
                userDefaults.set(currentSettingsVersion, forKey: Keys.settingsVersion.key)
                userDefaults.set(Date().timeIntervalSince1970, forKey: Keys.lastMigrationDate.key)
                hasPerformedMigration = true
                print("✅ SettingsManager: Migrated settings from version \(savedVersion) to \(currentSettingsVersion)")
            } catch {
                errorHandler.handle(AppError.from(error), context: "Migrating settings")
            }
        }
    }
    
    private func migrateSettings(from oldVersion: Int, to newVersion: Int) throws {
        print("🔄 SettingsManager: Starting migration from version \(oldVersion) to \(newVersion)")
        
        // Version 1 migration: Add haptic feedback setting
        if oldVersion < 1 {
            if userDefaults.object(forKey: Keys.enableHapticFeedback.key) == nil {
                userDefaults.set(true, forKey: Keys.enableHapticFeedback.key)
            }
        }
        
        // Version 2 migration: Add privacy mode and backup settings
        if oldVersion < 2 {
            if userDefaults.object(forKey: Keys.privacyMode.key) == nil {
                userDefaults.set(false, forKey: Keys.privacyMode.key)
            }
            if userDefaults.object(forKey: Keys.enableDataBackup.key) == nil {
                userDefaults.set(false, forKey: Keys.enableDataBackup.key)
            }
            if userDefaults.object(forKey: Keys.backupFrequency.key) == nil {
                userDefaults.set(BackupFrequency.weekly.rawValue, forKey: Keys.backupFrequency.key)
            }
        }
        
        // Version 3 migration: Add new UI and advanced features
        if oldVersion < 3 {
            if userDefaults.object(forKey: Keys.biometricAuthEnabled.key) == nil {
                userDefaults.set(false, forKey: Keys.biometricAuthEnabled.key)
            }
            if userDefaults.object(forKey: Keys.defaultExportFormat.key) == nil {
                userDefaults.set(DataExportFormat.csv.rawValue, forKey: Keys.defaultExportFormat.key)
            }
            if userDefaults.object(forKey: Keys.showDecimalPlaces.key) == nil {
                userDefaults.set(true, forKey: Keys.showDecimalPlaces.key)
            }
            if userDefaults.object(forKey: Keys.roundToNearestCent.key) == nil {
                userDefaults.set(true, forKey: Keys.roundToNearestCent.key)
            }
            if userDefaults.object(forKey: Keys.enableAdvancedFeatures.key) == nil {
                userDefaults.set(false, forKey: Keys.enableAdvancedFeatures.key)
            }
        }
        
        print("✅ SettingsManager: Migration completed successfully")
    }
    
    // MARK: - Validation
    
    private func validateUserName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedName.isEmpty {
            guard trimmedName.count >= ValidationRules.minUserNameLength else {
                throw AppError.validation(message: "User name is too short")
            }
            
            guard trimmedName.count <= ValidationRules.maxUserNameLength else {
                throw AppError.validation(message: "User name is too long (max \(ValidationRules.maxUserNameLength) characters)")
            }
            
            // Check for reserved names
            let lowercaseName = trimmedName.lowercased()
            guard !ValidationRules.reservedUserNames.contains(lowercaseName) else {
                throw AppError.validation(message: "This user name is reserved and cannot be used")
            }
            
            // Check for inappropriate characters
            let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
            guard trimmedName.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
                throw AppError.validation(message: "User name contains invalid characters")
            }
        }
    }
    
    private func validateCurrency(_ currency: String) throws {
        guard ValidationRules.supportedCurrencies.contains(currency) else {
            throw AppError.validation(message: "Unsupported currency: \(currency). Supported currencies: \(ValidationRules.supportedCurrencies.joined(separator: ", "))")
        }
    }
    
    private func validateImportedData(
        userName: String,
        currency: String,
        notificationsAllowed: Bool,
        purchaseEnabled: Bool,
        budgetEnabled: Bool
    ) throws {
        // Validate user name
        try validateUserName(userName)
        
        // Validate currency
        try validateCurrency(currency)
        
        // Validate notification logic
        if (purchaseEnabled || budgetEnabled) && !notificationsAllowed {
            throw AppError.validation(message: "Cannot enable notifications without general permission")
        }
    }
    
    private func validateCurrentSettings() -> Bool {
        do {
            try validateUserName(userName)
            try validateCurrency(defaultCurrency)
            try validateImportedData(
                userName: userName,
                currency: defaultCurrency,
                notificationsAllowed: notificationsAllowed,
                purchaseEnabled: purchaseNotificationsEnabled,
                budgetEnabled: budgetTotalNotificationsEnabled
            )
            return true
        } catch {
            return false
        }
    }
    
    private func validateAndHandleError<T>(_ value: T, validation: (T) throws -> Void) {
        do {
            try validation(value)
        } catch {
            errorHandler.handle(AppError.from(error), context: "Validating settings")
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationStateObservation() {
        // Monitor notification authorization changes
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
           Task<Void, Never>{ [weak self] in
                await self?.updateNotificationAuthorizationStatus()
            }
        }
        
        // Initial check
       Task<Void, Never>{
            await updateNotificationAuthorizationStatus()
        }
    }
    
    private func setupAutomaticBackup() {
        if enableDataBackup {
            scheduleNextBackup()
        }
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func notificationStateChanged() {
       Task<Void, Never>{
            await NotificationManager.shared.updateNotificationSchedule(settings: self)
            lastNotificationUpdate = Date()
        }
    }
    
    private func updateNotificationAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationAuthorizationStatus = settings.authorizationStatus
        }
    }
    
    // MARK: - Backup Management
    
    private func scheduleNextBackup() {
        guard enableDataBackup,
              let interval = backupFrequency.intervalInSeconds else {
            nextScheduledBackup = nil
            return
        }
        
        let nextBackup: Date
        if let lastBackup = lastBackupDate {
            nextBackup = lastBackup.addingTimeInterval(interval)
        } else {
            nextBackup = Date().addingTimeInterval(interval)
        }
        
        nextScheduledBackup = nextBackup
        
        // Schedule backup timer
        backupTimer?.invalidate()
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
           Task<Void, Never>{ [weak self] in
                await self?.performAutomaticBackupIfNeeded()
            }
        }
    }
    
    private func cancelScheduledBackup() {
        backupTimer?.invalidate()
        backupTimer = nil
        nextScheduledBackup = nil
    }
    
    private func performAutomaticBackupIfNeeded() async {
        guard enableDataBackup,
              !isBackupInProgress else { return }
        
        let shouldBackup: Bool
        if let lastBackup = lastBackupDate,
           let interval = backupFrequency.intervalInSeconds {
            shouldBackup = Date().timeIntervalSince(lastBackup) >= interval
        } else {
            shouldBackup = true
        }
        
        if shouldBackup {
            do {
                let _ = try await createBackup()
                print("✅ SettingsManager: Automatic backup completed")
            } catch {
                print("⚠️ SettingsManager: Automatic backup failed - \(error.localizedDescription)")
            }
        }
    }
    
    private func cleanupOldBackups() async {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let backupDirectory = documentsPath.appendingPathComponent("Settings Backups")
            
            guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return }
            
            let files = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(ValidationRules.maxBackupRetentionDays * 24 * 60 * 60))
            var cleanedCount = 0
            
            for fileURL in files {
                if fileURL.pathExtension == "json" && fileURL.lastPathComponent.contains("settings_backup") {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let creationDate = attributes[.creationDate] as? Date, creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: fileURL)
                        cleanedCount += 1
                    }
                }
            }
            
            if cleanedCount > 0 {
                print("🧹 SettingsManager: Cleaned up \(cleanedCount) old backup files")
            }
            
        } catch {
            print("⚠️ SettingsManager: Failed to cleanup old backups - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ SettingsManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 SettingsManager Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            // Clear metrics after logging
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        backupTimer?.invalidate()
        cancellables.removeAll()
        print("🧹 SettingsManager: Cleaned up resources")
    }
}

// MARK: - Extensions

extension SettingsManager {
    /// Get all supported currencies with their display names
    public var supportedCurrencies: [(code: String, name: String)] {
        return ValidationRules.supportedCurrencies.map { code in
            let locale = Locale(identifier: "en_US")
            let name = locale.localizedString(forCurrencyCode: code) ?? code
            return (code: code, name: name)
        }
    }
    
    /// Get formatted currency display
    public func formattedCurrency(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = defaultCurrency
        formatter.maximumFractionDigits = showDecimalPlaces ? 2 : 0
        
        let roundedAmount = roundToNearestCent ?
            (amount * 100).rounded(.toNearestOrAwayFromZero) / 100 :
            amount
            
        return formatter.string(from: NSNumber(value: roundedAmount)) ?? "\(amount)"
    }
    
    /// Check if biometric authentication is available
    public var isBiometricAuthAvailable: Bool {
        return false // Placeholder - would implement with LocalAuthentication framework
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let backupTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Remove all app settings
    func removeAllAppSettings() {
        let prefix = AppConstants.Storage.userDefaultsKeyPrefix
        let allKeys = dictionaryRepresentation().keys
        let settingsKeys = allKeys.filter { $0.hasPrefix(prefix) }
        settingsKeys.forEach { removeObject(forKey: $0) }
    }
}

// MARK: - Testing Support

#if DEBUG
extension SettingsManager {
    /// Create test settings manager with custom defaults
    static func createTestManager() -> SettingsManager {
        let testDefaults = UserDefaults(suiteName: "test_settings")!
        testDefaults.removeAllAppSettings()
        
        return SettingsManager(userDefaults: testDefaults)
    }
    
    /// Load test data for development
    func loadTestData() {
        userName = "Test User"
        defaultCurrency = "USD"
        notificationsAllowed = true
        purchaseNotificationsEnabled = true
        purchaseNotificationFrequency = .weekly
        budgetTotalNotificationsEnabled = true
        budgetTotalNotificationFrequency = .monthly
        isFirstLaunch = false
        enableHapticFeedback = true
        enableDataBackup = true
        backupFrequency = .weekly
        privacyMode = false
        biometricAuthEnabled = false
        defaultExportFormat = .csv
        showDecimalPlaces = true
        roundToNearestCent = true
        enableAdvancedFeatures = true
        
        print("✅ SettingsManager: Loaded test data")
    }
    
    /// Force migration for testing
    func forceMigrationForTesting(fromVersion: Int) throws {
        hasPerformedMigration = false
        userDefaults.set(fromVersion, forKey: Keys.settingsVersion.key)
        try migrateSettings(from: fromVersion, to: currentSettingsVersion)
        userDefaults.set(currentSettingsVersion, forKey: Keys.settingsVersion.key)
        hasPerformedMigration = true
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        hasPerformedMigration: Bool,
        currentVersion: Int,
        savedVersion: Int,
        isBackupScheduled: Bool,
        metricsCount: Int
    ) {
        return (
            hasPerformedMigration: hasPerformedMigration,
            currentVersion: currentSettingsVersion,
            savedVersion: userDefaults.integer(forKey: Keys.settingsVersion.key),
            isBackupScheduled: backupTimer?.isValid ?? false,
            metricsCount: operationMetrics.count
        )
    }
    
    /// Create test errors for preview/testing
    func createTestErrors() {
        do {
            try updateUserName("") // Should trigger validation error
        } catch {
            // Error will be handled by error handler
        }
        
        do {
            try updateDefaultCurrency("INVALID") // Should trigger validation error
        } catch {
            // Error will be handled by error handler
        }
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
}
#endif
