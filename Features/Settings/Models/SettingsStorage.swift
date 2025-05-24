//
//  SettingsStorage.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation
import SwiftUI
import Combine

/// A property wrapper for type-safe settings storage with error handling and validation
@propertyWrapper
public struct SettingsStorage<T: Codable> where T: Codable {
    // MARK: - Types
    public enum StorageError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case invalidValue
        case storageAccessFailed
        
        public var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode settings value"
            case .decodingFailed: return "Failed to decode settings value"
            case .invalidValue: return "Invalid settings value"
            case .storageAccessFailed: return "Failed to access storage"
            }
        }
    }
    
    // MARK: - Properties
    private let key: String
    private let defaultValue: T
    private let storage: UserDefaults
    private let validator: ((T) -> Bool)?
    private let transformer: ((T) -> T)?
    
    // Publisher for value changes
    private let publisher = PassthroughSubject<T, Never>()
    
    // MARK: - Initialization
    /// Initialize settings storage
    /// - Parameters:
    ///   - wrappedValue: Default value
    ///   - key: Storage key
    ///   - storage: UserDefaults instance
    ///   - validator: Optional validation closure
    ///   - transformer: Optional value transformer
    public init(
        wrappedValue defaultValue: T,
        key: String,
        storage: UserDefaults = .standard,
        validator: ((T) -> Bool)? = nil,
        transformer: ((T) -> T)? = nil
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
        self.validator = validator
        self.transformer = transformer
    }
    
    // MARK: - Property Wrapper
    public var wrappedValue: T {
        get {
            do {
                return try getValue()
            } catch {
                print("Failed to get settings value: \(error.localizedDescription)")
                return defaultValue
            }
        }
        set {
            do {
                try setValue(newValue)
                publisher.send(newValue)
            } catch {
                print("Failed to set settings value: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Projected Value
    public var projectedValue: SettingsStorageProjection<T> {
        SettingsStorageProjection<T>(storage: self)
    }
    
    // MARK: - Private Methods
    private func getValue() throws -> T {
        guard let data = storage.data(forKey: key) else {
            return defaultValue
        }
        
        do {
            let decoder = JSONDecoder()
            let value = try decoder.decode(T.self, from: data)
            if let transformer = transformer {
                return transformer(value)
            }
            return value
        } catch {
            throw StorageError.decodingFailed
        }
    }
    
    private func setValue(_ newValue: T) throws {
        if let validator = validator, !validator(newValue) {
            throw StorageError.invalidValue
        }
        
        let valueToStore = transformer?(newValue) ?? newValue
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(valueToStore)
            storage.set(data, forKey: key)
        } catch {
            throw StorageError.encodingFailed
        }
    }
}

// MARK: - Settings Storage Projection
public struct SettingsStorageProjection<T> {
    private let storage: SettingsStorage<T>
    
    init(storage: SettingsStorage<T>) {
        self.storage = storage
    }
    
    /// Publisher for value changes
    public var publisher: AnyPublisher<T, Never> {
        storage.publisher.eraseToAnyPublisher()
    }
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    /// Settings keys namespace
    public enum Keys {
        public static let userName = "userName"
        public static let defaultCurrency = "defaultCurrency"
        public static let isDarkMode = "isDarkMode"
        public static let primaryColor = "primaryColor"
        public static let notificationsAllowed = "notificationsAllowed"
        public static let purchaseNotificationsEnabled = "purchaseNotificationsEnabled"
        public static let purchaseNotificationFrequency = "purchaseNotificationFrequency"
        public static let budgetTotalNotificationsEnabled = "budgetTotalNotificationsEnabled"
        public static let budgetTotalNotificationFrequency = "budgetTotalNotificationFrequency"
        public static let isFirstLaunch = "isFirstLaunch"
        
        // Constants for key prefixes
        public static let prefix = "com.brandonsbudget.settings."
        
        /// Generate prefixed key
        /// - Parameter key: Base key
        /// - Returns: Prefixed key
        public static func prefixed(_ key: String) -> String {
            prefix + key
        }
    }
    
    /// Check if key exists
    /// - Parameter key: Key to check
    /// - Returns: Whether key exists
    func contains(key: String) -> Bool {
        object(forKey: key) != nil
    }
    
    /// Remove all app settings
    func removeAllSettings() {
        let prefix = Keys.prefix
        let allKeys = dictionaryRepresentation().keys
        let settingsKeys = allKeys.filter { $0.hasPrefix(prefix) }
        settingsKeys.forEach { removeObject(forKey: $0) }
    }
}

// MARK: - Testing Support
#if DEBUG
extension UserDefaults {
    /// Create test storage
    /// - Parameter suiteName: Suite name for test storage
    /// - Returns: Test UserDefaults instance
    static func createTestStorage(suiteName: String) -> UserDefaults? {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removeAllSettings()
        return defaults
    }
}

extension SettingsStorage {
    /// Create test storage
    /// - Parameters:
    ///   - defaultValue: Default value
    ///   - key: Storage key
    /// - Returns: Test settings storage
    static func createTestStorage(
        defaultValue: T,
        key: String
    ) -> SettingsStorage<T> {
        let testDefaults = UserDefaults.createTestStorage(suiteName: "test_settings")!
        return SettingsStorage(
            wrappedValue: defaultValue,
            key: key,
            storage: testDefaults
        )
    }
}
#endif
