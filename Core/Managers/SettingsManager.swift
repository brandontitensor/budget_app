//
//  SettingsManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 5/30/25 - Enhanced with centralized error handling and improved validation
//

import Foundation
import Combine

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
    }
    
    public enum SettingsError: LocalizedError {
        case invalidData(String)
        case saveFailed(String)
        case importFailed(String)
        case validationFailed(String)
        case encryptionFailed
        case migrationFailed
        case backupFailed
        case restoreFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidData(let detail):
                return "Invalid settings data: \(detail)"
            case .saveFailed(let detail):
                return "Failed to save settings: \(detail)"
            case .importFailed(let detail):
                return "Failed to import settings: \(detail)"
            case .validationFailed(let detail):
                return "Settings validation failed: \(detail)"
            case .encryptionFailed:
                return "Failed to encrypt sensitive settings"
            case .migrationFailed:
                return "Failed to migrate settings to new version"
            case .backupFailed:
                return "Failed to backup settings"
            case .restoreFailed:
                return "Failed to restore settings from backup"
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published public var userName: String {
        didSet { saveUserName(userName) }
    }
    
    @Published public var defaultCurrency: String {
        didSet { saveDefaultCurrency(defaultCurrency) }
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
        didSet { saveEnableDataBackup(enableDataBackup) }
    }
    
    @Published public var lastBackupDate: Date? {
        didSet { saveLastBackupDate(lastBackupDate) }
    }
    
    @Published public var privacyMode: Bool {
        didSet { savePrivacyMode(privacyMode) }
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
        case lastBackupDate
        case privacyMode
        case settingsVersion
        
        var key: String { "com.brandonsbudget.settings." + rawValue }
    }
    
    private let userDefaults: UserDefaults
    private let notificationManager: NotificationManager
    private let errorHandler: ErrorHandler
    private var cancellables = Set<AnyCancellable>()
    private let settingsQueue = DispatchQueue(label: "com.brandonsbudget.settings", qos: .utility)
    
    // MARK: - Version Management
    private let currentSettingsVersion = 2
    private var hasPerformedMigration = false
    
    // MARK: - Validation Rules
    private struct ValidationRules {
        static let maxUserNameLength = 50
        static let minUserNameLength = 1
        static let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY"]
        static let maxBackupRetentionDays = 30
    }
    
    // MARK: - Initialization
    private init(
        userDefaults: UserDefaults = .standard,
        notificationManager: NotificationManager = .shared,
        errorHandler: ErrorHandler = .shared
    ) {
        self.userDefaults = userDefaults
        self.notificationManager = notificationManager
        self.errorHandler = errorHandler
        
        // Initialize properties with validation
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
        self.lastBackupDate = nil
        self.privacyMode = false
        
        // Load existing settings
        loadAllSettings()
        
        // Setup migration if needed
        performMigrationIfNeeded()
        
        // Setup notification state observation
        setupNotificationStateObservation()
        
        // Setup automatic backup
        setupAutomaticBackup()
    }
    
    // MARK: - Public Methods
    
    /// Update user name with validation
    public func updateUserName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedName.count >= ValidationRules.minUserNameLength else {
            throw AppError.validation(message: "User name cannot be empty")
        }
        
        guard trimmedName.count <= ValidationRules.maxUserNameLength else {
            throw AppError.validation(message: "User name is too long (max \(ValidationRules.maxUserNameLength) characters)")
        }
        
        userName = trimmedName
    }
    
    /// Update default currency with validation
    public func updateDefaultCurrency(_ currency: String) throws {
        guard ValidationRules.supportedCurrencies.contains(currency) else {
            throw AppError.validation(message: "Unsupported currency: \(currency)")
        }
        
        defaultCurrency = currency
    }
    
    /// Update notification settings with validation
    public func updateNotificationSettings(
        allowed: Bool,
        purchaseEnabled: Bool,
        purchaseFrequency: PurchaseNotificationFrequency,
        budgetEnabled: Bool,
        budgetFrequency: BudgetTotalNotificationFrequency
    ) throws {
        // Validate notification permissions
        if purchaseEnabled || budgetEnabled {
            guard allowed else {
                throw AppError.validation(message: "Cannot enable specific notifications without general permission")
            }
        }
        
        // Update all settings atomically
        notificationsAllowed = allowed
        purchaseNotificationsEnabled = purchaseEnabled
        purchaseNotificationFrequency = purchaseFrequency
        budgetTotalNotificationsEnabled = budgetEnabled
        budgetTotalNotificationFrequency = budgetFrequency
    }
    
    /// Reset all settings to their default values
    public func resetToDefaults() throws {
        do {
            // Clear all settings from UserDefaults
            for key in Keys.allCases {
                userDefaults.removeObject(forKey: key.key)
            }
            
            // Reset published properties
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
            lastBackupDate = nil
            privacyMode = false
            
            // Cancel all notifications
            Task {
                await notificationManager.cancelAllNotifications()
            }
            
            print("✅ SettingsManager: Reset to defaults completed")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Resetting settings to defaults")
            throw appError
        }
    }
    
    /// Export settings to a dictionary for backup purposes
    public func exportSettings() throws -> [String: Any] {
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
                Keys.lastBackupDate.key: lastBackupDate?.timeIntervalSince1970 ?? 0,
                Keys.privacyMode.key: privacyMode,
                Keys.settingsVersion.key: currentSettingsVersion,
                "exportDate": Date().timeIntervalSince1970
            ]
            
            return settings
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Exporting settings")
            throw appError
        }
    }
    
    /// Import settings from a backup dictionary
    public func importSettings(_ settings: [String: Any]) throws {
        do {
            // Validate required fields
            guard let userName = settings[Keys.userName.key] as? String,
                  let defaultCurrency = settings[Keys.defaultCurrency.key] as? String,
                  let notificationsAllowed = settings[Keys.notificationsAllowed.key] as? Bool,
                  let purchaseNotificationsEnabled = settings[Keys.purchaseNotificationsEnabled.key] as? Bool,
                  let purchaseFrequencyString = settings[Keys.purchaseNotificationFrequency.key] as? String,
                  let purchaseFrequency = PurchaseNotificationFrequency(rawValue: purchaseFrequencyString),
                  let budgetNotificationsEnabled = settings[Keys.budgetTotalNotificationsEnabled.key] as? Bool,
                  let budgetFrequencyString = settings[Keys.budgetTotalNotificationFrequency.key] as? String,
                  let budgetFrequency = BudgetTotalNotificationFrequency(rawValue: budgetFrequencyString) else {
                throw SettingsError.invalidData("Missing required settings fields")
            }
            
            // Validate imported data
            try validateImportedData(
                userName: userName,
                currency: defaultCurrency,
                notificationsAllowed: notificationsAllowed,
                purchaseEnabled: purchaseNotificationsEnabled,
                budgetEnabled: budgetNotificationsEnabled
            )
            
            // Import settings
            self.userName = userName
            self.defaultCurrency = defaultCurrency
            self.notificationsAllowed = notificationsAllowed
            self.purchaseNotificationsEnabled = purchaseNotificationsEnabled
            self.purchaseNotificationFrequency = purchaseFrequency
            self.budgetTotalNotificationsEnabled = budgetNotificationsEnabled
            self.budgetTotalNotificationFrequency = budgetFrequency
            
            // Import optional settings
            if let enableHapticFeedback = settings[Keys.enableHapticFeedback.key] as? Bool {
                self.enableHapticFeedback = enableHapticFeedback
            }
            
            if let enableDataBackup = settings[Keys.enableDataBackup.key] as? Bool {
                self.enableDataBackup = enableDataBackup
            }
            
            if let lastBackupTimestamp = settings[Keys.lastBackupDate.key] as? TimeInterval,
               lastBackupTimestamp > 0 {
                self.lastBackupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
            }
            
            if let privacyMode = settings[Keys.privacyMode.key] as? Bool {
                self.privacyMode = privacyMode
            }
            
            print("✅ SettingsManager: Settings imported successfully")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Importing settings")
            throw appError
        }
    }
    
    /// Create settings backup
    public func createBackup() async throws -> URL {
        do {
            let settings = try exportSettings()
            let backupData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let backupDirectory = documentsPath.appendingPathComponent("Settings Backups")
            
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            
            let timestamp = DateFormatter.backupTimestamp.string(from: Date())
            let backupURL = backupDirectory.appendingPathComponent("settings_backup_\(timestamp).json")
            
            try backupData.write(to: backupURL)
            
            // Update last backup date
            lastBackupDate = Date()
            
            // Clean up old backups
            await cleanupOldBackups()
            
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
        do {
            let backupData = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: backupData) as? [String: Any]
            
            guard let settings = settings else {
                throw SettingsError.invalidData("Invalid backup file format")
            }
            
            try importSettings(settings)
            print("✅ SettingsManager: Settings restored from backup")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Restoring settings from backup")
            throw appError
        }
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
        
        // Load notification frequencies
        if let frequencyString = userDefaults.string(forKey: Keys.purchaseNotificationFrequency.key),
           let frequency = PurchaseNotificationFrequency(rawValue: frequencyString) {
            purchaseNotificationFrequency = frequency
        }
        
        if let frequencyString = userDefaults.string(forKey: Keys.budgetTotalNotificationFrequency.key),
           let frequency = BudgetTotalNotificationFrequency(rawValue: frequencyString) {
            budgetTotalNotificationFrequency = frequency
        }
        
        // Load backup date
        let backupTimestamp = userDefaults.double(forKey: Keys.lastBackupDate.key)
        if backupTimestamp > 0 {
            lastBackupDate = Date(timeIntervalSince1970: backupTimestamp)
        }
        
        // Handle first launch
        if !userDefaults.bool(forKey: Keys.isFirstLaunch.key + "_set") {
            isFirstLaunch = true
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key)
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key + "_set")
        } else {
            isFirstLaunch = userDefaults.bool(forKey: Keys.isFirstLaunch.key)
        }
    }
    
    // MARK: - Migration
    
    private func performMigrationIfNeeded() {
        let savedVersion = userDefaults.integer(forKey: Keys.settingsVersion.key)
        
        if savedVersion < currentSettingsVersion && !hasPerformedMigration {
            do {
                try migrateSettings(from: savedVersion, to: currentSettingsVersion)
                userDefaults.set(currentSettingsVersion, forKey: Keys.settingsVersion.key)
                hasPerformedMigration = true
                print("✅ SettingsManager: Migrated settings from version \(savedVersion) to \(currentSettingsVersion)")
            } catch {
                errorHandler.handle(AppError.from(error), context: "Migrating settings")
            }
        }
    }
    
    private func migrateSettings(from oldVersion: Int, to newVersion: Int) throws {
        // Migration logic for different versions
        if oldVersion < 1 {
            // Version 1 migration: Add haptic feedback setting
            if userDefaults.object(forKey: Keys.enableHapticFeedback.key) == nil {
                userDefaults.set(true, forKey: Keys.enableHapticFeedback.key)
            }
        }
        
        if oldVersion < 2 {
            // Version 2 migration: Add privacy mode and backup settings
            if userDefaults.object(forKey: Keys.privacyMode.key) == nil {
                userDefaults.set(false, forKey: Keys.privacyMode.key)
            }
            if userDefaults.object(forKey: Keys.enableDataBackup.key) == nil {
                userDefaults.set(false, forKey: Keys.enableDataBackup.key)
            }
        }
    }
    
    // MARK: - Validation
    
    private func validateImportedData(
        userName: String,
        currency: String,
        notificationsAllowed: Bool,
        purchaseEnabled: Bool,
        budgetEnabled: Bool
    ) throws {
        // Validate user name
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        private func validateImportedData(
            userName: String,
            currency: String,
            notificationsAllowed: Bool,
            purchaseEnabled: Bool,
            budgetEnabled: Bool
        ) throws {
            // Validate user name
            let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty && trimmedName.count > ValidationRules.maxUserNameLength {
                throw SettingsError.validationFailed("User name exceeds maximum length")
            }
            
            // Validate currency
            if !ValidationRules.supportedCurrencies.contains(currency) {
                throw SettingsError.validationFailed("Unsupported currency: \(currency)")
            }
            
            // Validate notification logic
            if (purchaseEnabled || budgetEnabled) && !notificationsAllowed {
                throw SettingsError.validationFailed("Cannot enable notifications without general permission")
            }
        }
        
        // MARK: - Setup Methods
        
        private func setupNotificationStateObservation() {
            notificationManager.authorizationStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] authorized in
                    if !authorized {
                        self?.notificationsAllowed = false
                    }
                }
                .store(in: &cancellables)
        }
        
        private func setupAutomaticBackup() {
            // Setup daily backup check if backup is enabled
            Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
                Task { [weak self] in
                    await self?.performAutomaticBackupIfNeeded()
                }
            }
        }
        
        private func notificationStateChanged() {
            Task {
                await notificationManager.updateNotificationSchedule(settings: self)
            }
        }
        
        private func performAutomaticBackupIfNeeded() async {
            guard enableDataBackup else { return }
            
            let shouldBackup: Bool
            if let lastBackup = lastBackupDate {
                shouldBackup = Date().timeIntervalSince(lastBackup) > 86400 // 24 hours
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
        
        // MARK: - Utility Methods
        
        /// Check if settings are valid
        public func validateCurrentSettings() -> Bool {
            do {
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
        
        /// Get settings summary for debugging
        public func getSettingsSummary() -> [String: Any] {
            return [
                "userName": userName.isEmpty ? "<empty>" : userName,
                "defaultCurrency": defaultCurrency,
                "notificationsAllowed": notificationsAllowed,
                "purchaseNotificationsEnabled": purchaseNotificationsEnabled,
                "purchaseNotificationFrequency": purchaseNotificationFrequency.rawValue,
                "budgetTotalNotificationsEnabled": budgetTotalNotificationsEnabled,
                "budgetTotalNotificationFrequency": budgetTotalNotificationFrequency.rawValue,
                "isFirstLaunch": isFirstLaunch,
                "enableHapticFeedback": enableHapticFeedback,
                "enableDataBackup": enableDataBackup,
                "lastBackupDate": lastBackupDate?.description ?? "<none>",
                "privacyMode": privacyMode,
                "settingsVersion": currentSettingsVersion,
                "isValid": validateCurrentSettings()
            ]
        }
        
        /// Get backup status information
        public func getBackupStatus() -> (enabled: Bool, lastBackup: Date?, nextBackup: Date?) {
            let nextBackup: Date?
            if enableDataBackup {
                if let lastBackup = lastBackupDate {
                    nextBackup = lastBackup.addingTimeInterval(86400) // 24 hours
                } else {
                    nextBackup = Date() // Immediate if never backed up
                }
            } else {
                nextBackup = nil
            }
            
            return (enabled: enableDataBackup, lastBackup: lastBackupDate, nextBackup: nextBackup)
        }
    }
    
    // MARK: - DateFormatter Extension
    
    private extension DateFormatter {
        static let backupTimestamp: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()
    }
    
    // MARK: - UserDefaults Extension
    
    extension UserDefaults {
        /// Remove all app settings
        func removeAllAppSettings() {
            let prefix = "com.brandonsbudget.settings."
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
            
            return SettingsManager(
                userDefaults: testDefaults,
                notificationManager: .shared,
                errorHandler: .shared
            )
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
            privacyMode = false
            
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
            savedVersion: Int
        ) {
            return (
                hasPerformedMigration: hasPerformedMigration,
                currentVersion: currentSettingsVersion,
                savedVersion: userDefaults.integer(forKey: Keys.settingsVersion.key)
            )
        }
    }
}
