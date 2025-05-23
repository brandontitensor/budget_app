//
//  AppConstants.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation

/// Global configuration constants used throughout the app
public enum AppConstants {
    /// Feature flags for enabling/disabling functionality
    public enum Features {
        /// Whether widgets are enabled
        public static let enableWidgets = true
        
        /// Whether cloud sync is enabled
        public static let enableCloudSync = false
        
        /// Whether biometric authentication is enabled
        public static let enableBiometrics = true
        
        /// Whether data export functionality is enabled
        public static let enableDataExport = true
        
        /// Whether push notifications are enabled
        public static let enablePushNotifications = true
        
        /// Whether debug logging is enabled
        #if DEBUG
        public static let enableDebugLogging = true
        #else
        public static let enableDebugLogging = false
        #endif
    }
    
    /// UI-related constants
    public enum UI {
        /// Standard corner radius for UI elements
        public static let cornerRadius: CGFloat = 12
        
        /// Default padding for UI elements
        public static let defaultPadding: CGFloat = 16
        
        /// Default animation duration
        public static let defaultAnimationDuration: Double = 0.3
        
        /// Minimum height for interactive elements (accessibility)
        public static let minimumTouchHeight: CGFloat = 44
        
        /// Maximum width for buttons and controls
        public static let maximumButtonWidth: CGFloat = 280
        
        /// Standard spacing between elements
        public static let standardSpacing: CGFloat = 8
        
        /// Minimum width for content areas
        public static let minimumContentWidth: CGFloat = 320
        
        /// Maximum width for content areas
        public static let maximumContentWidth: CGFloat = 414
        
        /// Default shadow radius
        public static let defaultShadowRadius: CGFloat = 4
        
        /// Default shadow opacity
        public static let defaultShadowOpacity: Float = 0.1
    }
    
    /// Data-related constants
    public enum Data {
        /// Maximum number of budget categories allowed
        public static let maxBudgetCategories = 20
        
        /// Maximum length for transaction notes
        public static let maxTransactionNoteLength = 500
        
        /// Date format for CSV exports
        public static let csvExportDateFormat = "yyyy-MM-dd"
        
        /// Default currency code
        public static let defaultCurrency = "USD"
        
        /// Maximum file size for imports (10MB)
        public static let maxImportFileSize: Int64 = 10_485_760
        
        /// Supported file formats for import
        public static let supportedImportFormats = ["csv"]
        
        /// Maximum number of recent transactions to display
        public static let maxRecentTransactions = 5
        
        /// Number of months to keep in history
        public static let monthsToKeepInHistory = 24
    }
    
    /// Time-related constants
    public enum Time {
        /// Default reminder hour (8 PM)
        public static let defaultReminderHour = 20
        
        /// Default budget update day (1st of month)
        public static let defaultBudgetUpdateDay = 1
        
        /// Budget widget refresh interval (1 hour)
        public static let budgetWidgetRefreshInterval: TimeInterval = 3600
        
        /// Minimum time between notifications
        public static let minimumNotificationInterval: TimeInterval = 300
        
        /// Cache expiration time (24 hours)
        public static let cacheExpirationInterval: TimeInterval = 86400
    }
    
    /// Storage-related constants
    public enum Storage {
        /// App group identifier for shared data
        public static let appGroupIdentifier = "group.com.brandontitensor.BrandonsBudget"
        
        /// Key prefix for user defaults
        public static let userDefaultsKeyPrefix = "com.brandontitensor.BrandonsBudget."
        
        /// Key prefix for keychain items
        public static let keychainKeyPrefix = "com.brandontitensor.BrandonsBudget."
        
        /// Database filename
        public static let databaseFilename = "BudgetModel.sqlite"
    }
    
    /// URLs and endpoints
    public enum URLs {
        /// Base URL for the API
        public static let apiBaseURL = URL(string: "https://api.example.com")!
        
        /// Privacy policy URL
        public static let privacyPolicy = URL(string: "https://www.example.com/privacy")!
        
        /// Terms of service URL
        public static let termsOfService = URL(string: "https://www.example.com/terms")!
        
        /// Support URL
        public static let support = URL(string: "https://www.example.com/support")!
        
        /// App Store URL
        public static let appStore = URL(string: "https://apps.apple.com/app/id123456789")!
    }
    
    /// Validation constants
    public enum Validation {
        /// Minimum transaction amount
        public static let minimumTransactionAmount: Double = 0.01
        
        /// Maximum transaction amount
        public static let maximumTransactionAmount: Double = 999999.99
        
        /// Maximum category name length
        public static let maxCategoryNameLength = 30
        
        /// Password minimum length
        public static let minimumPasswordLength = 8
        
        /// Maximum failed login attempts
        public static let maxLoginAttempts = 3
    }
    
    /// Error messages
    public enum ErrorMessages {
        /// Generic error message
        public static let genericError = NSLocalizedString(
            "An unexpected error occurred. Please try again.",
            comment: "Generic error message"
        )
        
        /// Network error message
        public static let networkError = NSLocalizedString(
            "Unable to connect. Please check your internet connection.",
            comment: "Network error message"
        )
        
        /// Import error message
        public static let importError = NSLocalizedString(
            "Unable to import data. Please check the file format.",
            comment: "Import error message"
        )
        
        /// Export error message
        public static let exportError = NSLocalizedString(
            "Unable to export data. Please try again.",
            comment: "Export error message"
        )
        
        /// Invalid amount error message
        public static let invalidAmount = NSLocalizedString(
            "Please enter a valid amount.",
            comment: "Invalid amount error message"
        )
        
        /// Invalid category error message
        public static let invalidCategory = NSLocalizedString(
            "Please select a valid category.",
            comment: "Invalid category error message"
        )
        
        /// Maximum categories reached error message
        public static let maxCategoriesReached = NSLocalizedString(
            "Maximum number of categories reached.",
            comment: "Max categories error message"
        )
    }
    
    /// Default categories
    public enum DefaultCategories {
        /// All available default categories
        public static let all: [String] = [
            "Housing",
            "Transportation",
            "Food",
            "Utilities",
            "Insurance",
            "Healthcare",
            "Savings",
            "Entertainment",
            "Personal Care",
            "Education"
        ]
        
        /// Required categories that cannot be deleted
        public static let required: [String] = [
            "Uncategorized",
            "Housing",
            "Food",
            "Utilities"
        ]
    }
    
    /// Analytics event names
    public enum AnalyticsEvents {
        /// Add transaction event
        public static let addTransaction = "add_transaction"
        
        /// Update budget event
        public static let updateBudget = "update_budget"
        
        /// Export data event
        public static let exportData = "export_data"
        
        /// Import data event
        public static let importData = "import_data"
        
        /// View report event
        public static let viewReport = "view_report"
    }
}
