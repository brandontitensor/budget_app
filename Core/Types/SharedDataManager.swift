//
//  SharedDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved data validation, and better widget integration
//

import Foundation
import Combine
import WidgetKit

/// Manages data sharing between the main app and widgets with proper validation and error handling
@MainActor
public final class SharedDataManager: ObservableObject {
    // MARK: - Types
    public enum SharedDataError: LocalizedError {
        case invalidData(String)
        case encodingFailed
        case decodingFailed
        case userDefaultsUnavailable
        case dataCorrupted
        case widgetUpdateFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidData(let details):
                return "Invalid shared data: \(details)"
            case .encodingFailed:
                return "Failed to encode shared data"
            case .decodingFailed:
                return "Failed to decode shared data"
            case .userDefaultsUnavailable:
                return "App Group UserDefaults unavailable"
            case .dataCorrupted:
                return "Shared data appears to be corrupted"
            case .widgetUpdateFailed:
                return "Failed to update widget data"
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .invalidData:
                return "Check the data values and try again"
            case .encodingFailed, .decodingFailed:
                return "Clear app data and restart the app"
            case .userDefaultsUnavailable:
                return "Check app group configuration"
            case .dataCorrupted:
                return "Reset widget data and restart the app"
            case .widgetUpdateFailed:
                return "Restart the app to refresh widget data"
            }
        }
    }
    
    public struct BudgetSummary: Codable, Equatable {
        public let monthlyBudget: Double
        public let totalSpent: Double
        public let remainingBudget: Double
        public let percentageUsed: Double
        public let percentageRemaining: Double
        public let isOverBudget: Bool
        public let categoryCount: Int
        public let transactionCount: Int
        public let lastUpdated: Date
        public let currentMonth: String
        
        public init(
            monthlyBudget: Double,
            totalSpent: Double,
            remainingBudget: Double,
            categoryCount: Int = 0,
            transactionCount: Int = 0,
            currentMonth: String? = nil
        ) {
            self.monthlyBudget = max(0, monthlyBudget)
            self.totalSpent = max(0, totalSpent)
            self.remainingBudget = remainingBudget
            self.percentageUsed = monthlyBudget > 0 ? (totalSpent / monthlyBudget) * 100 : 0
            self.percentageRemaining = monthlyBudget > 0 ? (remainingBudget / monthlyBudget) * 100 : 0
            self.isOverBudget = totalSpent > monthlyBudget
            self.categoryCount = max(0, categoryCount)
            self.transactionCount = max(0, transactionCount)
            self.lastUpdated = Date()
            
            if let month = currentMonth {
                self.currentMonth = month
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                self.currentMonth = formatter.string(from: Date())
            }
        }
        
        /// Validate the budget summary data
        public func validate() throws {
            guard monthlyBudget >= 0 else {
                throw SharedDataError.invalidData("Monthly budget cannot be negative")
            }
            guard totalSpent >= 0 else {
                throw SharedDataError.invalidData("Total spent cannot be negative")
            }
            guard categoryCount >= 0 else {
                throw SharedDataError.invalidData("Category count cannot be negative")
            }
            guard transactionCount >= 0 else {
                throw SharedDataError.invalidData("Transaction count cannot be negative")
            }
            guard !currentMonth.isEmpty else {
                throw SharedDataError.invalidData("Current month cannot be empty")
            }
        }
        
        /// Get formatted currency strings
        public func formattedMonthlyBudget() -> String {
            return NumberFormatter.formatCurrency(monthlyBudget)
        }
        
        public func formattedTotalSpent() -> String {
            return NumberFormatter.formatCurrency(totalSpent)
        }
        
        public func formattedRemainingBudget() -> String {
            return NumberFormatter.formatCurrency(remainingBudget)
        }
        
        /// Get status message for widget
        public var statusMessage: String {
            if isOverBudget {
                let overAmount = totalSpent - monthlyBudget
                return "Over budget by \(NumberFormatter.formatCurrency(overAmount))"
            } else if remainingBudget <= 0 {
                return "Budget fully used"
            } else {
                return "\(NumberFormatter.formatCurrency(remainingBudget)) remaining"
            }
        }
        
        /// Get color indicator for budget status
        public var statusColor: String {
            if isOverBudget {
                return "red"
            } else if percentageUsed > 90 {
                return "orange"
            } else if percentageUsed > 75 {
                return "yellow"
            } else {
                return "green"
            }
        }
    }
    
    public struct RecentTransaction: Codable, Identifiable, Equatable {
        public let id: UUID
        public let amount: Double
        public let category: String
        public let date: Date
        public let note: String?
        
        public init(id: UUID = UUID(), amount: Double, category: String, date: Date, note: String? = nil) {
            self.id = id
            self.amount = max(0, amount)
            self.category = category
            self.date = date
            self.note = note
        }
        
        public func formattedAmount() -> String {
            return NumberFormatter.formatCurrency(amount)
        }
        
        public func formattedDate() -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
        
        public func relativeDate() -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
    
    public struct WidgetData: Codable, Equatable {
        public let budgetSummary: BudgetSummary
        public let recentTransactions: [RecentTransaction]
        public let topCategories: [CategorySpending]
        public let lastUpdated: Date
        public let appVersion: String
        
        public init(
            budgetSummary: BudgetSummary,
            recentTransactions: [RecentTransaction] = [],
            topCategories: [CategorySpending] = [],
            appVersion: String? = nil
        ) {
            self.budgetSummary = budgetSummary
            self.recentTransactions = Array(recentTransactions.prefix(5)) // Limit to 5 transactions
            self.topCategories = Array(topCategories.prefix(5)) // Limit to top 5 categories
            self.lastUpdated = Date()
            self.appVersion = appVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }
        
        public func validate() throws {
            try budgetSummary.validate()
            
            for transaction in recentTransactions {
                guard transaction.amount >= 0 else {
                    throw SharedDataError.invalidData("Transaction amount cannot be negative")
                }
                guard !transaction.category.isEmpty else {
                    throw SharedDataError.invalidData("Transaction category cannot be empty")
                }
            }
            
            for category in topCategories {
                guard category.amount >= 0 else {
                    throw SharedDataError.invalidData("Category amount cannot be negative")
                }
                guard !category.name.isEmpty else {
                    throw SharedDataError.invalidData("Category name cannot be empty")
                }
            }
        }
    }
    
    public struct CategorySpending: Codable, Identifiable, Equatable {
        public let id = UUID()
        public let name: String
        public let amount: Double
        public let percentage: Double
        public let color: String
        
        public init(name: String, amount: Double, percentage: Double, color: String = "blue") {
            self.name = name
            self.amount = max(0, amount)
            self.percentage = max(0, min(100, percentage))
            self.color = color
        }
        
        public func formattedAmount() -> String {
            return NumberFormatter.formatCurrency(amount)
        }
        
        public func formattedPercentage() -> String {
            return String(format: "%.1f%%", percentage)
        }
    }
    
    // MARK: - Singleton
    public static let shared = SharedDataManager()
    
    // MARK: - Published Properties
    @Published public private(set) var currentBudgetSummary: BudgetSummary?
    @Published public private(set) var recentTransactions: [RecentTransaction] = []
    @Published public private(set) var topCategories: [CategorySpending] = []
    @Published public private(set) var lastSuccessfulUpdate: Date?
    @Published public private(set) var lastError: AppError?
    @Published public private(set) var isProcessing = false
    
    // MARK: - Private Properties
    private let sharedDefaults: UserDefaults?
    private let operationQueue = DispatchQueue(label: "com.brandonsbudget.shareddata", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private enum Keys {
        static let budgetSummary = "budgetSummary"
        static let recentTransactions = "recentTransactions"
        static let topCategories = "topCategories"
        static let widgetData = "widgetData"
        static let lastUpdate = "lastUpdate"
        static let dataVersion = "dataVersion"
        static let suiteName = "group.com.brandontitensor.BrandonsBudget"
    }
    
    private let currentDataVersion = 3
    private let maxRecentTransactions = 5
    private let maxTopCategories = 5
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.shareddata.metrics", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        self.sharedDefaults = UserDefaults(suiteName: Keys.suiteName)
        
        // Validate app group access
        if sharedDefaults == nil {
            print("⚠️ SharedDataManager: App Group UserDefaults unavailable")
        }
        
        // Load existing data
        loadExistingData()
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
        
        // Perform migration if needed
        performMigrationIfNeeded()
        
        print("✅ SharedDataManager: Initialized successfully")
    }
    
    // MARK: - Public Update Methods
    
    /// Update budget data with comprehensive validation
    public func updateBudgetData(
        monthlyBudget: Double,
        totalSpent: Double,
        remainingBudget: Double,
        categoryCount: Int = 0,
        transactionCount: Int = 0
    ) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let budgetSummary = BudgetSummary(
                monthlyBudget: monthlyBudget,
                totalSpent: totalSpent,
                remainingBudget: remainingBudget,
                categoryCount: categoryCount,
                transactionCount: transactionCount
            )
            
            // Validate the data
            try budgetSummary.validate()
            
            // Update internal state
            currentBudgetSummary = budgetSummary
            
            // Save to shared storage
            try await saveBudgetSummary(budgetSummary)
            
            // Update widget data
            try await updateCompleteWidgetData()
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadAllTimelines()
            
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            recordMetric("updateBudgetData", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated budget data - Budget: \(monthlyBudget.asCurrency), Spent: \(totalSpent.asCurrency)")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating shared budget data")
            throw appError
        }
    }
    
    /// Update recent transactions list
    public func updateRecentTransactions(_ transactions: [RecentTransaction]) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Validate transactions
            for transaction in transactions {
                guard transaction.amount >= 0 else {
                    throw SharedDataError.invalidData("Transaction amount cannot be negative")
                }
                guard !transaction.category.isEmpty else {
                    throw SharedDataError.invalidData("Transaction category cannot be empty")
                }
            }
            
            // Limit to recent transactions and sort by date
            let sortedTransactions = transactions
                .sorted { $0.date > $1.date }
                .prefix(maxRecentTransactions)
            
            recentTransactions = Array(sortedTransactions)
            
            // Save to shared storage
            try await saveRecentTransactions(recentTransactions)
            
            // Update complete widget data
            try await updateCompleteWidgetData()
            
            recordMetric("updateRecentTransactions", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated \(recentTransactions.count) recent transactions")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating recent transactions")
            throw appError
        }
    }
    
    /// Update top spending categories
    public func updateTopCategories(_ categories: [CategorySpending]) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Validate categories
            for category in categories {
                guard category.amount >= 0 else {
                    throw SharedDataError.invalidData("Category amount cannot be negative")
                }
                guard !category.name.isEmpty else {
                    throw SharedDataError.invalidData("Category name cannot be empty")
                }
            }
            
            // Limit to top categories and sort by amount
            let sortedCategories = categories
                .sorted { $0.amount > $1.amount }
                .prefix(maxTopCategories)
            
            topCategories = Array(sortedCategories)
            
            // Save to shared storage
            try await saveTopCategories(topCategories)
            
            // Update complete widget data
            try await updateCompleteWidgetData()
            
            recordMetric("updateTopCategories", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated \(topCategories.count) top categories")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating top categories")
            throw appError
        }
    }
    
    /// Update all widget data at once
    public func updateCompleteWidgetData(
        budgetSummary: BudgetSummary? = nil,
        transactions: [RecentTransaction]? = nil,
        categories: [CategorySpending]? = nil
    ) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Use provided data or current data
            let summary = budgetSummary ?? currentBudgetSummary ?? BudgetSummary(
                monthlyBudget: 0,
                totalSpent: 0,
                remainingBudget: 0
            )
            let recentTxns = transactions ?? recentTransactions
            let topCats = categories ?? topCategories
            
            let widgetData = WidgetData(
                budgetSummary: summary,
                recentTransactions: recentTxns,
                topCategories: topCats
            )
            
            // Validate complete widget data
            try widgetData.validate()
            
            // Save to shared storage
            try await saveWidgetData(widgetData)
            
            // Update internal state
            currentBudgetSummary = summary
            if transactions != nil { self.recentTransactions = recentTxns }
            if categories != nil { self.topCategories = topCats }
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadAllTimelines()
            
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            recordMetric("updateCompleteWidgetData", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated complete widget data")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating complete widget data")
            throw appError
        }
    }
    
    // MARK: - Public Read Methods
    
    /// Get current budget summary
    public func getBudgetSummary() -> BudgetSummary? {
        return currentBudgetSummary
    }
    
    /// Get monthly budget amount
    public func getMonthlyBudget() -> Double {
        return currentBudgetSummary?.monthlyBudget ?? 0.0
    }
    
    /// Get remaining budget amount
    public func getRemainingBudget() -> Double {
        return currentBudgetSummary?.remainingBudget ?? 0.0
    }
    
    /// Get total spent amount
    public func getTotalSpent() -> Double {
        return currentBudgetSummary?.totalSpent ?? 0.0
    }
    
    /// Get complete widget data
    public func getWidgetData() -> WidgetData? {
        guard let summary = currentBudgetSummary else { return nil }
        return WidgetData(
            budgetSummary: summary,
            recentTransactions: recentTransactions,
            topCategories: topCategories
        )
    }
    
    /// Get data health status
    public func getDataHealth() -> DataHealth {
        let hasValidBudget = currentBudgetSummary != nil
        let hasRecentUpdate = lastSuccessfulUpdate?.timeIntervalSinceNow ?? -Double.infinity > -3600 // Within 1 hour
        let hasError = lastError != nil
        let hasSharedDefaults = sharedDefaults != nil
        
        if !hasSharedDefaults {
            return DataHealth(
                status: .critical,
                message: "App Group unavailable",
                recommendation: "Check app configuration and restart"
            )
        } else if hasError {
            return DataHealth(
                status: .error,
                message: lastError?.errorDescription ?? "Unknown error",
                recommendation: lastError?.recoverySuggestion ?? "Try refreshing data"
            )
        } else if !hasValidBudget {
            return DataHealth(
                status: .warning,
                message: "No budget data available",
                recommendation: "Add budget data in the main app"
            )
        } else if !hasRecentUpdate {
            return DataHealth(
                status: .warning,
                message: "Data may be stale",
                recommendation: "Open the main app to refresh"
            )
        } else {
            return DataHealth(
                status: .healthy,
                message: "All systems operational",
                recommendation: nil
            )
        }
    }
    
    // MARK: - Data Management
    
    /// Reset all shared data
    public func resetData() async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            guard let defaults = sharedDefaults else {
                throw SharedDataError.userDefaultsUnavailable
            }
            
            // Clear all shared data
            defaults.removeObject(forKey: Keys.budgetSummary)
            defaults.removeObject(forKey: Keys.recentTransactions)
            defaults.removeObject(forKey: Keys.topCategories)
            defaults.removeObject(forKey: Keys.widgetData)
            defaults.removeObject(forKey: Keys.lastUpdate)
            
            // Reset internal state
            currentBudgetSummary = nil
            recentTransactions = []
            topCategories = []
            lastSuccessfulUpdate = nil
            lastError = nil
            
            // Reload widgets with empty data
            WidgetCenter.shared.reloadAllTimelines()
            
            recordMetric("resetData", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Reset all shared data")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Resetting shared data")
            throw appError
        }
    }
    
    /// Validate data integrity
    public func validateDataIntegrity() async throws {
        let startTime = Date()
        
        do {
            // Check app group access
            guard sharedDefaults != nil else {
                throw SharedDataError.userDefaultsUnavailable
            }
            
            // Validate current budget summary
            if let summary = currentBudgetSummary {
                try summary.validate()
            }
            
            // Validate recent transactions
            for transaction in recentTransactions {
                guard transaction.amount >= 0 else {
                    throw SharedDataError.dataCorrupted
                }
                guard !transaction.category.isEmpty else {
                    throw SharedDataError.dataCorrupted
                }
            }
            
            // Validate top categories
            for category in topCategories {
                guard category.amount >= 0 else {
                    throw SharedDataError.dataCorrupted
                }
                guard !category.name.isEmpty else {
                    throw SharedDataError.dataCorrupted
                }
            }
            
            recordMetric("validateDataIntegrity", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Data integrity validated")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Validating data integrity")
            throw appError
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadExistingData() {
        guard let defaults = sharedDefaults else { return }
        
        // Load budget summary
        if let data = defaults.data(forKey: Keys.budgetSummary),
           let summary = try? JSONDecoder().decode(BudgetSummary.self, from: data) {
            currentBudgetSummary = summary
        }
        
        // Load recent transactions
        if let data = defaults.data(forKey: Keys.recentTransactions),
           let transactions = try? JSONDecoder().decode([RecentTransaction].self, from: data) {
            recentTransactions = transactions
        }
        
        // Load top categories
        if let data = defaults.data(forKey: Keys.topCategories),
           let categories = try? JSONDecoder().decode([CategorySpending].self, from: data) {
            topCategories = categories
        }
        
        // Load last update time
        let timestamp = defaults.double(forKey: Keys.lastUpdate)
        if timestamp > 0 {
            lastSuccessfulUpdate = Date(timeIntervalSince1970: timestamp)
        }
        
        print("✅ SharedDataManager: Loaded existing data")
    }
    
    private func saveBudgetSummary(_ summary: BudgetSummary) async throws {
        guard let defaults = sharedDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(summary)
            defaults.set(data, forKey: Keys.budgetSummary)
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdate)
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveRecentTransactions(_ transactions: [RecentTransaction]) async throws {
        guard let defaults = sharedDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(transactions)
            defaults.set(data, forKey: Keys.recentTransactions)
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveTopCategories(_ categories: [CategorySpending]) async throws {
        guard let defaults = sharedDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(categories)
            defaults.set(data, forKey: Keys.topCategories)
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveWidgetData(_ widgetData: WidgetData) async throws {
        guard let defaults = sharedDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(widgetData)
            defaults.set(data, forKey: Keys.widgetData)
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdate)
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func performMigrationIfNeeded() {
        guard let defaults = sharedDefaults else { return }
        
        let savedVersion = defaults.integer(forKey: Keys.dataVersion)
        
        if savedVersion < currentDataVersion {
            // Perform any necessary migration here
            print("🔄 SharedDataManager: Migrating data from version \(savedVersion) to \(currentDataVersion)")
            
            // Set new version
            defaults.set(currentDataVersion, forKey: Keys.dataVersion)
            
            print("✅ SharedDataManager: Migration completed")
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
            if duration > 1.0 {
                print("⚠️ SharedDataManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 SharedDataManager Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
}

// MARK: - Supporting Types

public struct DataHealth {
    public enum Status {
        case healthy
        case warning
        case error
        case critical
        
        public var color: String {
            switch self {
            case .healthy: return "green"
            case .warning: return "yellow"
            case .error: return "orange"
            case .critical: return "red"
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }
    
    public let status: Status
    public let message: String
    public let recommendation: String?
    
    public var isHealthy: Bool {
        return status == .healthy
    }
    
    public var needsAttention: Bool {
        return status == .error || status == .critical
    }
}

// MARK: - Widget Integration Extensions

extension SharedDataManager {
    /// Get widget-optimized budget summary
    public func getWidgetBudgetSummary() -> BudgetSummary? {
        return currentBudgetSummary
    }
    
    /// Get widget-optimized recent transactions
    public func getWidgetRecentTransactions(limit: Int = 3) -> [RecentTransaction] {
        return Array(recentTransactions.prefix(limit))
    }
    
    /// Get widget-optimized top categories
    public func getWidgetTopCategories(limit: Int = 3) -> [CategorySpending] {
        return Array(topCategories.prefix(limit))
    }
    
    /// Force widget refresh
    public func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 SharedDataManager: Forced widget refresh")
    }
    
    /// Get timeline recommendations for widgets
    public func getTimelineRecommendations() -> (refreshInterval: TimeInterval, policy: WidgetUpdatePolicy) {
        let hasRecentData = lastSuccessfulUpdate?.timeIntervalSinceNow ?? -Double.infinity > -1800 // 30 minutes
        
        if hasRecentData && lastError == nil {
            return (refreshInterval: 3600, policy: .atEnd) // 1 hour
        } else {
            return (refreshInterval: 1800, policy: .atEnd) // 30 minutes
        }
    }
}

public enum WidgetUpdatePolicy {
    case atEnd
    case after(Date)
    case never
}

// MARK: - Testing Support

#if DEBUG
extension SharedDataManager {
    /// Create test shared data manager
    static func createTestManager() -> SharedDataManager {
        return SharedDataManager()
    }
    
    /// Load test data for development
    func loadTestData() async {
        do {
            // Test budget summary
            let testSummary = BudgetSummary(
                monthlyBudget: 2500.0,
                totalSpent: 1750.0,
                remainingBudget: 750.0,
                categoryCount: 8,
                transactionCount: 45,
                currentMonth: "December 2024"
            )
            
            // Test recent transactions
            let testTransactions = [
                RecentTransaction(amount: 45.67, category: "Groceries", date: Date(), note: "Weekly shopping"),
                RecentTransaction(amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-86400), note: "Bus fare"),
                RecentTransaction(amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-172800), note: "Movie tickets"),
                RecentTransaction(amount: 25.00, category: "Dining", date: Date().addingTimeInterval(-259200), note: "Lunch"),
                RecentTransaction(amount: 150.00, category: "Utilities", date: Date().addingTimeInterval(-345600), note: "Electric bill")
            ]
            
            // Test top categories
            let testCategories = [
                CategorySpending(name: "Groceries", amount: 450.0, percentage: 18.0, color: "blue"),
                CategorySpending(name: "Utilities", amount: 350.0, percentage: 14.0, color: "green"),
                CategorySpending(name: "Transportation", amount: 280.0, percentage: 11.2, color: "orange"),
                CategorySpending(name: "Entertainment", amount: 220.0, percentage: 8.8, color: "purple"),
                CategorySpending(name: "Dining", amount: 180.0, percentage: 7.2, color: "red")
            ]
            
            // Update all data
            try await updateBudgetData(
                monthlyBudget: testSummary.monthlyBudget,
                totalSpent: testSummary.totalSpent,
                remainingBudget: testSummary.remainingBudget,
                categoryCount: testSummary.categoryCount,
                transactionCount: testSummary.transactionCount
            )
            
            try await updateRecentTransactions(testTransactions)
            try await updateTopCategories(testCategories)
            
            print("✅ SharedDataManager: Loaded test data")
            
        } catch {
            print("❌ SharedDataManager: Failed to load test data - \(error.localizedDescription)")
        }
    }
    
    /// Clear all data for testing
    func clearTestData() async {
        do {
            try await resetData()
            print("✅ SharedDataManager: Cleared test data")
        } catch {
            print("❌ SharedDataManager: Failed to clear test data - \(error.localizedDescription)")
        }
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        hasBudgetSummary: Bool,
        transactionCount: Int,
        categoryCount: Int,
        hasError: Bool,
        isProcessing: Bool,
        hasSharedDefaults: Bool
    ) {
        return (
            hasBudgetSummary: currentBudgetSummary != nil,
            transactionCount: recentTransactions.count,
            categoryCount: topCategories.count,
            hasError: lastError != nil,
            isProcessing: isProcessing,
            hasSharedDefaults: sharedDefaults != nil
        )
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Simulate error for testing
    func simulateErrorForTesting(_ error: SharedDataError) async {
        lastError = AppError.from(error)
        ErrorHandler.shared.handle(AppError.from(error), context: "Testing error simulation")
    }
    
    /// Force data corruption for testing
    func simulateDataCorruptionForTesting() async {
        guard let defaults = sharedDefaults else { return }
        
        // Write invalid data
        defaults.set("corrupted_data".data(using: .utf8), forKey: Keys.budgetSummary)
        
        // Try to load it (should fail)
        loadExistingData()
        
        print("🧪 SharedDataManager: Simulated data corruption for testing")
    }
    
    /// Reset state for testing
    func resetStateForTesting() async {
        currentBudgetSummary = nil
        recentTransactions = []
        topCategories = []
        lastSuccessfulUpdate = nil
        lastError = nil
        isProcessing = false
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
        
        print("🧪 SharedDataManager: Reset state for testing")
    }
    
    /// Create mock widget data for testing
    func createMockWidgetData() -> WidgetData {
        let mockSummary = BudgetSummary(
            monthlyBudget: 2000.0,
            totalSpent: 1500.0,
            remainingBudget: 500.0,
            categoryCount: 6,
            transactionCount: 25,
            currentMonth: "Test Month"
        )
        
        let mockTransactions = [
            RecentTransaction(amount: 50.0, category: "Test Category", date: Date(), note: "Test transaction")
        ]
        
        let mockCategories = [
            CategorySpending(name: "Test Category", amount: 100.0, percentage: 10.0, color: "blue")
        ]
        
        return WidgetData(
            budgetSummary: mockSummary,
            recentTransactions: mockTransactions,
            topCategories: mockCategories,
            appVersion: "1.0.0-test"
        )
    }
    
    /// Validate test environment
    func validateTestEnvironment() -> Bool {
        // Check if we're in a test environment
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        if isTest {
            print("🧪 SharedDataManager: Running in test environment")
        }
        
        return isTest
    }
}

// Mock UserDefaults for testing
public class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    public override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    public override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    public override func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }
    
    public override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    public override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    public override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    public func clearAll() {
        storage.removeAll()
    }
    
    public var allKeys: [String] {
        return Array(storage.keys)
    }
    
    public var allValues: [String: Any] {
        return storage
    }
}
#endif

// MARK: - Extensions

extension SharedDataManager {
    /// Get formatted data summary for debugging
    public func getDataSummary() -> String {
        var summary = "SharedDataManager Summary:\n"
        
        if let budget = currentBudgetSummary {
            summary += "Budget: \(budget.formattedMonthlyBudget()) | Spent: \(budget.formattedTotalSpent()) | Remaining: \(budget.formattedRemainingBudget())\n"
            summary += "Status: \(budget.statusMessage)\n"
            summary += "Categories: \(budget.categoryCount) | Transactions: \(budget.transactionCount)\n"
        } else {
            summary += "No budget data available\n"
        }
        
        summary += "Recent Transactions: \(recentTransactions.count)\n"
        summary += "Top Categories: \(topCategories.count)\n"
        
        if let lastUpdate = lastSuccessfulUpdate {
            summary += "Last Updated: \(lastUpdate.formatted())\n"
        } else {
            summary += "Never updated\n"
        }
        
        let health = getDataHealth()
        summary += "Health: \(health.status) - \(health.message)\n"
        
        return summary
    }
    
    /// Export data for backup purposes
    public func exportDataForBackup() async throws -> [String: Any] {
        let startTime = Date()
        
        do {
            var exportData: [String: Any] = [:]
            
            // Export budget summary
            if let summary = currentBudgetSummary {
                let summaryData = try JSONEncoder().encode(summary)
                exportData["budgetSummary"] = summaryData
            }
            
            // Export recent transactions
            if !recentTransactions.isEmpty {
                let transactionsData = try JSONEncoder().encode(recentTransactions)
                exportData["recentTransactions"] = transactionsData
            }
            
            // Export top categories
            if !topCategories.isEmpty {
                let categoriesData = try JSONEncoder().encode(topCategories)
                exportData["topCategories"] = categoriesData
            }
            
            // Add metadata
            exportData["exportDate"] = Date().timeIntervalSince1970
            exportData["dataVersion"] = currentDataVersion
            exportData["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            
            recordMetric("exportDataForBackup", duration: Date().timeIntervalSince(startTime))
            return exportData
            
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    /// Import data from backup
    public func importDataFromBackup(_ backupData: [String: Any]) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Import budget summary
            if let summaryData = backupData["budgetSummary"] as? Data {
                let summary = try JSONDecoder().decode(BudgetSummary.self, from: summaryData)
                try summary.validate()
                currentBudgetSummary = summary
                try await saveBudgetSummary(summary)
            }
            
            // Import recent transactions
            if let transactionsData = backupData["recentTransactions"] as? Data {
                let transactions = try JSONDecoder().decode([RecentTransaction].self, from: transactionsData)
                recentTransactions = transactions
                try await saveRecentTransactions(transactions)
            }
            
            // Import top categories
            if let categoriesData = backupData["topCategories"] as? Data {
                let categories = try JSONDecoder().decode([CategorySpending].self, from: categoriesData)
                topCategories = categories
                try await saveTopCategories(categories)
            }
            
            // Update complete widget data
            try await updateCompleteWidgetData()
            
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            recordMetric("importDataFromBackup", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Imported data from backup")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Importing data from backup")
            throw appError
        }
    }
    
    /// Get data size estimation
    public func getDataSizeEstimation() -> (bytes: Int, description: String) {
        var totalBytes = 0
        var components: [String] = []
        
        if let summary = currentBudgetSummary,
           let data = try? JSONEncoder().encode(summary) {
            totalBytes += data.count
            components.append("Budget: \(data.count) bytes")
        }
        
        if !recentTransactions.isEmpty,
           let data = try? JSONEncoder().encode(recentTransactions) {
            totalBytes += data.count
            components.append("Transactions: \(data.count) bytes")
        }
        
        if !topCategories.isEmpty,
           let data = try? JSONEncoder().encode(topCategories) {
            totalBytes += data.count
            components.append("Categories: \(data.count) bytes")
        }
        
        let description = components.isEmpty ? "No data" : components.joined(separator: ", ")
        return (bytes: totalBytes, description: "Total: \(totalBytes) bytes (\(description))")
    }
    
    /// Cleanup old data based on age
    public func cleanupOldData(maxAge: TimeInterval = 7 * 24 * 60 * 60) async { // 7 days default
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        // Clean old transactions
        let recentTransactionsCount = recentTransactions.count
        recentTransactions = recentTransactions.filter { $0.date >= cutoffDate }
        
        if recentTransactions.count != recentTransactionsCount {
            do {
                try await saveRecentTransactions(recentTransactions)
                print("🧹 SharedDataManager: Cleaned \(recentTransactionsCount - recentTransactions.count) old transactions")
            } catch {
                print("⚠️ SharedDataManager: Failed to save cleaned transactions - \(error.localizedDescription)")
            }
        }
    }
    
    /// Get widget refresh suggestions
    public func getWidgetRefreshSuggestions() -> [String] {
        var suggestions: [String] = []
        
        let health = getDataHealth()
        
        switch health.status {
        case .critical:
            suggestions.append("Critical: App Group configuration issue - contact support")
        case .error:
            suggestions.append("Error detected: \(health.message)")
        case .warning:
            if currentBudgetSummary == nil {
                suggestions.append("Add budget data in the main app")
            }
            if lastSuccessfulUpdate == nil {
                suggestions.append("Open the main app to initialize data")
            }
        case .healthy:
            if let lastUpdate = lastSuccessfulUpdate,
               lastUpdate.timeIntervalSinceNow < -3600 {
                suggestions.append("Data is more than 1 hour old - consider refreshing")
            }
        }
        
        if recentTransactions.isEmpty {
            suggestions.append("No recent transactions available for widget")
        }
        
        if topCategories.isEmpty {
            suggestions.append("No category data available for widget")
        }
        
        return suggestions
    }
}

// MARK: - Widget-Specific Extensions

extension SharedDataManager.BudgetSummary {
    /// Get widget display text for budget status
    public var widgetDisplayText: String {
        if isOverBudget {
            return "Over Budget"
        } else if percentageUsed > 90 {
            return "Almost Used"
        } else if percentageUsed > 75 {
            return "Mostly Used"
        } else if percentageUsed > 50 {
            return "Half Used"
        } else {
            return "On Track"
        }
    }
    
    /// Get compact status for small widgets
    public var compactStatus: String {
        if isOverBudget {
            return "Over"
        } else {
            return "\(Int(percentageRemaining))% left"
        }
    }
    
    /// Get progress value for progress bars (0.0 to 1.0)
    public var progressValue: Double {
        return min(1.0, max(0.0, percentageUsed / 100.0))
    }
}

extension SharedDataManager.RecentTransaction {
    /// Get display text for widgets
    public var widgetDisplayText: String {
        return "\(formattedAmount()) • \(category)"
    }
    
    /// Get compact display for small widgets
    public var compactDisplayText: String {
        return "\(formattedAmount())"
    }
}

extension SharedDataManager.CategorySpending {
    /// Get widget display text
    public var widgetDisplayText: String {
        return "\(name): \(formattedAmount())"
    }
    
    /// Get compact display for small widgets
    public var compactDisplayText: String {
        return "\(String(name.prefix(8))): \(formattedPercentage())"
    }
}
