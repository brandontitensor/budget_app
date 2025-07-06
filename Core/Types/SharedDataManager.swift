//
//  SharedDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 7/6/25 - Fixed Swift 6 concurrency issues and removed duplicate extensions
//

import Foundation
import Combine
import WidgetKit

/// Manages data sharing between the main app and widgets with proper validation and error handling
@MainActor
public final class SharedDataManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = SharedDataManager()
    
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
    
    public struct BudgetSummary: Codable, Equatable, Sendable {
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
            self.monthlyBudget = monthlyBudget
            self.totalSpent = totalSpent
            self.remainingBudget = remainingBudget
            self.percentageUsed = monthlyBudget > 0 ? (totalSpent / monthlyBudget) * 100 : 0
            self.percentageRemaining = max(0, 100 - percentageUsed)
            self.isOverBudget = totalSpent > monthlyBudget
            self.categoryCount = categoryCount
            self.transactionCount = transactionCount
            self.lastUpdated = Date()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            self.currentMonth = currentMonth ?? formatter.string(from: Date())
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
        }
    }
    
    public struct RecentTransaction: Codable, Identifiable, Equatable, Sendable {
        public let id: UUID
        public let amount: Double
        public let category: String
        public let date: Date
        public let note: String?
        
        public init(amount: Double, category: String, date: Date, note: String? = nil) {
            self.id = UUID()
            self.amount = amount
            self.category = category
            self.date = date
            self.note = note
        }
    }
    
    public struct CategorySpending: Codable, Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let amount: Double
        public let percentage: Double
        public let color: String
        
        public init(name: String, amount: Double, percentage: Double, color: String = "#007AFF") {
            self.id = name
            self.name = name
            self.amount = amount
            self.percentage = percentage
            self.color = color
        }
    }
    
    public struct WidgetData: Codable, Equatable, Sendable {
        public let budgetSummary: BudgetSummary
        public let recentTransactions: [RecentTransaction]
        public let topCategories: [CategorySpending]
        public let lastUpdated: Date
        public let appVersion: String
        
        public init(
            budgetSummary: BudgetSummary,
            recentTransactions: [RecentTransaction] = [],
            topCategories: [CategorySpending] = []
        ) {
            self.budgetSummary = budgetSummary
            self.recentTransactions = Array(recentTransactions.prefix(5)) // Max 5 transactions
            self.topCategories = Array(topCategories.prefix(5)) // Max 5 categories
            self.lastUpdated = Date()
            self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        }
        
        /// Validate the complete widget data
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
                guard category.percentage >= 0 && category.percentage <= 100 else {
                    throw SharedDataError.invalidData("Category percentage must be between 0 and 100")
                }
            }
        }
    }
    
    // MARK: - Published Properties
    @Published public private(set) var currentBudgetSummary: BudgetSummary?
    @Published public private(set) var recentTransactions: [RecentTransaction] = []
    @Published public private(set) var topCategories: [CategorySpending] = []
    @Published public private(set) var lastSuccessfulUpdate: Date?
    @Published public private(set) var lastError: AppError?
    @Published public private(set) var isProcessing = false
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults?
    private let appGroupIdentifier = "group.com.brandontitensor.BrandonsBudget"
    
    // UserDefaults keys
    private let budgetSummaryKey = "WidgetBudgetSummary"
    private let recentTransactionsKey = "WidgetRecentTransactions"
    private let topCategoriesKey = "WidgetTopCategories"
    private let widgetDataKey = "WidgetCompleteData"
    
    // Performance monitoring
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.shareddata.metrics", qos: .utility)
    private var operationMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Initialization
    private init() {
        self.userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        setupErrorHandling()
        print("✅ SharedDataManager: Initialized with app group: \(appGroupIdentifier)")
    }
    
    private func setupErrorHandling() {
        // Setup error handling if needed
    }
    
    // MARK: - Public Update Methods
    
    /// Update budget summary data
    public func updateBudgetSummary(_ summary: BudgetSummary) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try summary.validate()
            try await saveBudgetSummary(summary)
            
            currentBudgetSummary = summary
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            WidgetCenter.shared.reloadAllTimelines()
            
            await recordMetric("updateBudgetSummary", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated budget summary")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating budget summary")
            throw appError
        }
    }
    
    /// Update recent transactions data
    public func updateRecentTransactions(_ transactions: [RecentTransaction]) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let validatedTransactions = Array(transactions.prefix(5))
            try await saveRecentTransactions(validatedTransactions)
            
            recentTransactions = validatedTransactions
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            WidgetCenter.shared.reloadAllTimelines()
            
            await recordMetric("updateRecentTransactions", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated \(validatedTransactions.count) recent transactions")
            
        } catch {
            let appError = AppError.from(error)
            lastError = appError
            ErrorHandler.shared.handle(appError, context: "Updating recent transactions")
            throw appError
        }
    }
    
    /// Update top categories data
    public func updateTopCategories(_ categories: [CategorySpending]) async throws {
        let startTime = Date()
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let validatedCategories = Array(categories.prefix(5))
            try await saveTopCategories(validatedCategories)
            
            topCategories = validatedCategories
            lastSuccessfulUpdate = Date()
            lastError = nil
            
            WidgetCenter.shared.reloadAllTimelines()
            
            await recordMetric("updateTopCategories", duration: Date().timeIntervalSince(startTime))
            print("✅ SharedDataManager: Updated \(validatedCategories.count) top categories")
            
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
            
            await recordMetric("updateCompleteWidgetData", duration: Date().timeIntervalSince(startTime))
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
    
    /// Check if data is fresh
    public func isDataFresh(threshold: TimeInterval = 1800) -> Bool { // 30 minutes
        guard let lastUpdate = lastSuccessfulUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < threshold
    }
    
    // MARK: - Private Storage Methods
    
    private func saveBudgetSummary(_ summary: BudgetSummary) async throws {
        guard let userDefaults = userDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(summary)
            userDefaults.set(data, forKey: budgetSummaryKey)
            userDefaults.synchronize()
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveRecentTransactions(_ transactions: [RecentTransaction]) async throws {
        guard let userDefaults = userDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(transactions)
            userDefaults.set(data, forKey: recentTransactionsKey)
            userDefaults.synchronize()
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveTopCategories(_ categories: [CategorySpending]) async throws {
        guard let userDefaults = userDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: topCategoriesKey)
            userDefaults.synchronize()
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    private func saveWidgetData(_ widgetData: WidgetData) async throws {
        guard let userDefaults = userDefaults else {
            throw SharedDataError.userDefaultsUnavailable
        }
        
        do {
            let data = try JSONEncoder().encode(widgetData)
            userDefaults.set(data, forKey: widgetDataKey)
            userDefaults.synchronize()
        } catch {
            throw SharedDataError.encodingFailed
        }
    }
    
    // MARK: - Data Management
    
    /// Clear all shared data
    public func clearAllData() {
        guard let userDefaults = userDefaults else { return }
        
        userDefaults.removeObject(forKey: budgetSummaryKey)
        userDefaults.removeObject(forKey: recentTransactionsKey)
        userDefaults.removeObject(forKey: topCategoriesKey)
        userDefaults.removeObject(forKey: widgetDataKey)
        userDefaults.synchronize()
        
        currentBudgetSummary = nil
        recentTransactions.removeAll()
        topCategories.removeAll()
        lastSuccessfulUpdate = nil
        lastError = nil
        
        WidgetCenter.shared.reloadAllTimelines()
        print("🧹 SharedDataManager: All shared data cleared")
    }
    
    // MARK: - Performance Monitoring
    
    @MainActor
    private func recordMetric(_ operation: String, duration: TimeInterval) async {
        await withCheckedContinuation { continuation in
            metricsQueue.async {
                self.operationMetrics[operation] = duration
                
                #if DEBUG
                if duration > 2.0 {
                    print("⚠️ SharedDataManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
                }
                #endif
                
                continuation.resume()
            }
        }
    }
    
    /// Get widget refresh policy
    public func getWidgetRefreshPolicy() -> (refreshInterval: TimeInterval, policy: WidgetUpdatePolicy) {
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

// MARK: - Extensions

private extension Double {
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$\(String(format: "%.2f", self))"
    }
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
                RecentTransaction(amount: 156.78, category: "Shopping", date: Date().addingTimeInterval(-345600), note: "Clothes")
            ]
            
            // Test top categories
            let testCategories = [
                CategorySpending(name: "Groceries", amount: 450.67, percentage: 18.0, color: "#FF6B6B"),
                CategorySpending(name: "Transportation", amount: 320.50, percentage: 12.8, color: "#4ECDC4"),
                CategorySpending(name: "Entertainment", amount: 289.99, percentage: 11.6, color: "#45B7D1"),
                CategorySpending(name: "Dining", amount: 225.00, percentage: 9.0, color: "#96CEB4"),
                CategorySpending(name: "Shopping", amount: 456.78, percentage: 18.3, color: "#FFEAA7")
            ]
            
            try await updateCompleteWidgetData(
                budgetSummary: testSummary,
                transactions: testTransactions,
                categories: testCategories
            )
            
            print("📊 SharedDataManager: Test data loaded successfully")
            
        } catch {
            print("❌ SharedDataManager: Failed to load test data - \(error)")
        }
    }
    
    /// Reset for testing
    func resetForTesting() {
        clearAllData()
        operationMetrics.removeAll()
    }
    
    /// Get metrics for testing
    func getMetricsForTesting() -> [String: TimeInterval] {
        return operationMetrics
    }
}
#endif
