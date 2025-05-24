//
//  SettingsManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation
import Combine

/// Manages the app's user settings and preferences with proper state management and data consistency
@MainActor
public final class SettingsManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = SettingsManager()
    
    // MARK: - Types
    public enum PurchaseNotificationFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }
    
    public enum BudgetTotalNotificationFrequency: String, Codable, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
    
    public enum SettingsError: LocalizedError {
        case invalidData
        case saveFailed
        case importFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid settings data"
            case .saveFailed: return "Failed to save settings"
            case .importFailed: return "Failed to import settings"
            }
        }
    }
    
    // MARK: - Published Properties
    @Published public var userName: String {
        didSet { save(userName, for: .userName) }
    }
    
    @Published public var defaultCurrency: String {
        didSet { save(defaultCurrency, for: .defaultCurrency) }
    }
    
    @Published public var notificationsAllowed: Bool {
        didSet {
            save(notificationsAllowed, for: .notificationsAllowed)
            notificationStateChanged()
        }
    }
    
    @Published public var purchaseNotificationsEnabled: Bool {
        didSet {
            save(purchaseNotificationsEnabled, for: .purchaseNotificationsEnabled)
            notificationStateChanged()
        }
    }
    
    @Published public var purchaseNotificationFrequency: PurchaseNotificationFrequency {
        didSet {
            save(purchaseNotificationFrequency, for: .purchaseNotificationFrequency)
            notificationStateChanged()
        }
    }
    
    @Published public var budgetTotalNotificationsEnabled: Bool {
        didSet {
            save(budgetTotalNotificationsEnabled, for: .budgetTotalNotificationsEnabled)
            notificationStateChanged()
        }
    }
    
    @Published public var budgetTotalNotificationFrequency: BudgetTotalNotificationFrequency {
        didSet {
            save(budgetTotalNotificationFrequency, for: .budgetTotalNotificationFrequency)
            notificationStateChanged()
        }
    }
    
    @Published public var isFirstLaunch: Bool {
        didSet { save(isFirstLaunch, for: .isFirstLaunch) }
    }
    
    // MARK: - Private Properties
    private enum Keys: String {
        case userName
        case defaultCurrency
        case notificationsAllowed
        case purchaseNotificationsEnabled
        case purchaseNotificationFrequency
        case budgetTotalNotificationsEnabled
        case budgetTotalNotificationFrequency
        case isFirstLaunch
        
        var key: String { "com.brandonsbudget.settings." + rawValue }
    }
    
    private let userDefaults: UserDefaults
    private let notificationManager: NotificationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Properties
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    // MARK: - Initialization
    private init(
        userDefaults: UserDefaults = .standard,
        notificationManager: NotificationManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.notificationManager = notificationManager
        
        // Initialize properties with stored values
        self.userName = userDefaults.string(forKey: Keys.userName.key) ?? ""
        self.defaultCurrency = userDefaults.string(forKey: Keys.defaultCurrency.key) ?? "USD"
        self.notificationsAllowed = userDefaults.bool(forKey: Keys.notificationsAllowed.key)
        self.purchaseNotificationsEnabled = userDefaults.bool(forKey: Keys.purchaseNotificationsEnabled.key)
        self.purchaseNotificationFrequency = PurchaseNotificationFrequency(
            rawValue: userDefaults.string(forKey: Keys.purchaseNotificationFrequency.key) ?? "daily"
        ) ?? .daily
        self.budgetTotalNotificationsEnabled = userDefaults.bool(forKey: Keys.budgetTotalNotificationsEnabled.key)
        self.budgetTotalNotificationFrequency = BudgetTotalNotificationFrequency(
            rawValue: userDefaults.string(forKey: Keys.budgetTotalNotificationFrequency.key) ?? "monthly"
        ) ?? .monthly
        
        // Handle first launch
        if !userDefaults.bool(forKey: Keys.isFirstLaunch.key + "_set") {
            self.isFirstLaunch = true
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key)
            userDefaults.set(true, forKey: Keys.isFirstLaunch.key + "_set")
        } else {
            self.isFirstLaunch = userDefaults.bool(forKey: Keys.isFirstLaunch.key)
        }
        
        // Setup notification state observation
        setupNotificationStateObservation()
    }
    
    // MARK: - Public Methods
    
    /// Update user name
    public func updateUserName(_ name: String) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Update default currency
    public func updateDefaultCurrency(_ currency: String) {
        guard !currency.isEmpty else { return }
        defaultCurrency = currency
    }
    
    /// Update notification settings
    public func updateNotificationSettings(
        allowed: Bool,
        purchaseEnabled: Bool,
        purchaseFrequency: PurchaseNotificationFrequency,
        budgetEnabled: Bool,
        budgetFrequency: BudgetTotalNotificationFrequency
    ) {
        notificationsAllowed = allowed
        purchaseNotificationsEnabled = purchaseEnabled
        purchaseNotificationFrequency = purchaseFrequency
        budgetTotalNotificationsEnabled = budgetEnabled
        budgetTotalNotificationFrequency = budgetFrequency
    }
    
    /// Reset all settings to their default values
    public func resetToDefaults() {
        userName = ""
        defaultCurrency = "USD"
        notificationsAllowed = false
        purchaseNotificationsEnabled = false
        purchaseNotificationFrequency = .daily
        budgetTotalNotificationsEnabled = false
        budgetTotalNotificationFrequency = .monthly
        isFirstLaunch = true
        
        Task {
            await notificationManager.cancelAllNotifications()
        }
    }
    
    /// Export settings to a dictionary for backup purposes
    public func exportSettings() -> [String: Any] {
        [
            Keys.userName.key: userName,
            Keys.defaultCurrency.key: defaultCurrency,
            Keys.notificationsAllowed.key: notificationsAllowed,
            Keys.purchaseNotificationsEnabled.key: purchaseNotificationsEnabled,
            Keys.purchaseNotificationFrequency.key: purchaseNotificationFrequency.rawValue,
            Keys.budgetTotalNotificationsEnabled.key: budgetTotalNotificationsEnabled,
            Keys.budgetTotalNotificationFrequency.key: budgetTotalNotificationFrequency.rawValue,
            Keys.isFirstLaunch.key: isFirstLaunch
        ]
    }
    
    /// Import settings from a backup dictionary
    public func importSettings(_ settings: [String: Any]) throws {
        guard let userName = settings[Keys.userName.key] as? String,
              let defaultCurrency = settings[Keys.defaultCurrency.key] as? String,
              let notificationsAllowed = settings[Keys.notificationsAllowed.key] as? Bool,
              let purchaseNotificationsEnabled = settings[Keys.purchaseNotificationsEnabled.key] as? Bool,
              let purchaseFrequencyString = settings[Keys.purchaseNotificationFrequency.key] as? String,
              let purchaseFrequency = PurchaseNotificationFrequency(rawValue: purchaseFrequencyString),
              let budgetNotificationsEnabled = settings[Keys.budgetTotalNotificationsEnabled.key] as? Bool,
              let budgetFrequencyString = settings[Keys.budgetTotalNotificationFrequency.key] as? String,
              let budgetFrequency = BudgetTotalNotificationFrequency(rawValue: budgetFrequencyString) else {
            throw SettingsError.invalidData
        }
        
        self.userName = userName
        self.defaultCurrency = defaultCurrency
        self.notificationsAllowed = notificationsAllowed
        self.purchaseNotificationsEnabled = purchaseNotificationsEnabled
        self.purchaseNotificationFrequency = purchaseFrequency
        self.budgetTotalNotificationsEnabled = budgetNotificationsEnabled
        self.budgetTotalNotificationFrequency = budgetFrequency
    }
    
    // MARK: - Private Methods
    private func save<T: Encodable>(_ value: T, for key: Keys) {
        if let stringValue = value as? String {
            userDefaults.set(stringValue, forKey: key.key)
        } else if let boolValue = value as? Bool {
            userDefaults.set(boolValue, forKey: key.key)
        } else if let data = try? JSONEncoder().encode(value) {
            userDefaults.set(data, forKey: key.key)
        }
        objectWillChange.send()
    }
    
    private func setupNotificationStateObservation() {
        notificationManager.authorizationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authorized in
                self?.notificationsAllowed = authorized
            }
            .store(in: &cancellables)
    }
    
    private func notificationStateChanged() {
        Task {
            await notificationManager.updateNotificationSchedule(settings: self)
        }
    }
}

// MARK: - Testing Support
#if DEBUG
extension SettingsManager {
    static func createMock() -> SettingsManager {
        return SettingsManager()
    }
}
#endif
