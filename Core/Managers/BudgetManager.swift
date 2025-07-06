//
//  BudgetManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 7/5/25 - Enhanced with centralized error handling, improved performance, and missing async methods
//

import Foundation
import Combine
import SwiftUI
import WidgetKit

/// Manages budget data operations with proper error handling, validation, and state management
@MainActor
public final class BudgetManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = BudgetManager()
    
    // MARK: - Types
    public enum BudgetManagerError: LocalizedError {
        case invalidEntry
        case duplicateEntry
        case categoryNotFound
        case budgetExceeded
        case dataCorruption
        case syncFailure
        case validationFailed(String)
        case importError(String)
        case exportError(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidEntry:
                return "Invalid budget entry data"
            case .duplicateEntry:
                return "Entry already exists"
            case .categoryNotFound:
                return "Budget category not found"
            case .budgetExceeded:
                return "Budget limit exceeded"
            case .dataCorruption:
                return "Budget data appears to be corrupted"
            case .syncFailure:
                return "Failed to sync budget data"
            case .validationFailed(let message):
                return "Validation failed: \(message)"
            case .importError(let message):
                return "Import failed: \(message)"
            case .exportError(let message):
                return "Export failed: \(message)"
            }
        }
    }
    
    public struct DataStatistics {
        public let entryCount: Int
        public let budgetCount: Int
        public let categoryCount: Int
        public let totalSpent: Double
        public let totalBudgeted: Double
        public let oldestEntry: Date?
        public let newestEntry: Date?
        public let lastSyncDate: Date?
        public let healthStatus: HealthStatus
        
        public enum HealthStatus: String {
            case healthy = "Healthy"
            case warning = "Warning"
            case error = "Error"
            case critical = "Critical"
        }
    }
    
    // MARK: - Published Properties
    @Published public private(set) var entries: [BudgetEntry] = []
    @Published public private(set) var monthlyBudgets: [MonthlyBudget] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var dataStatistics: DataStatistics?
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    private let errorHandler = ErrorHandler.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Cache management
    private var budgetCache: [String: MonthlyBudget] = [:]
    private var entriesCache: [UUID: BudgetEntry] = [:]
    private var lastCacheUpdate: Date?
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // Performance monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let performanceQueue = DispatchQueue(label: "com.brandonsbudget.performance", qos: .utility)
    
    // Widget update debouncing
    private var widgetUpdateDebouncer = Debouncer(delay: 1.0)
    
    private init() {
        setupObservers()
        dataStatistics = getDataStatistics()
        print("✅ BudgetManager: Initialized")
    }
    
    // MARK: - Public Data Loading Methods
    
    /// Load all budget data asynchronously
    public func loadData() async {
        let startTime = Date()
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading budget data"
        ) {
            let loadedEntries = try await coreDataManager.getAllBudgetEntries()
            let loadedBudgets = try await coreDataManager.getAllMonthlyBudgets()
            
            return (entries: loadedEntries, budgets: loadedBudgets)
        }
        
        if let (loadedEntries, loadedBudgets) = result {
            await MainActor.run {
                entries = loadedEntries.sorted { $0.date > $1.date }
                monthlyBudgets = loadedBudgets.sorted {
                    $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
                }
                lastSyncDate = Date()
                invalidateCache()
                dataStatistics = getDataStatistics()
                updateWidgetData()
            }
            
            recordMetric("loadData", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Loaded \(entries.count) entries and \(monthlyBudgets.count) budgets")
        }
    }
    
    /// Refresh all data from Core Data
    public func refreshData() async {
        await loadData()
        print("🔄 BudgetManager: Data refreshed")
    }
    
    /// Refresh overview-specific data
    public func refreshOverviewData() async {
        let startTime = Date()
        
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing overview data"
        ) {
            // Reload current month data
            let calendar = Calendar.current
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            let currentEntries = try await coreDataManager.getBudgetEntries(
                for: TimePeriod.currentMonth,
                category: nil
            )
            let currentBudgets = try await coreDataManager.getMonthlyBudgets(
                for: currentMonth,
                year: currentYear
            )
            
            return (entries: currentEntries, budgets: currentBudgets)
        }
        
        if let (currentEntries, currentBudgets) = result {
            await MainActor.run {
                // Update entries with fresh current month data
                let calendar = Calendar.current
                let now = Date()
                let currentMonth = calendar.component(.month, from: now)
                let currentYear = calendar.component(.year, from: now)
                
                // Remove old current month entries and add fresh ones
                entries.removeAll { entry in
                    calendar.component(.month, from: entry.date) == currentMonth &&
                    calendar.component(.year, from: entry.date) == currentYear
                }
                entries.append(contentsOf: currentEntries)
                entries.sort { $0.date > $1.date }
                
                // Update budgets
                monthlyBudgets.removeAll { budget in
                    budget.month == currentMonth && budget.year == currentYear
                }
                monthlyBudgets.append(contentsOf: currentBudgets)
                monthlyBudgets.sort {
                    $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
                }
                
                invalidateCache()
                updateWidgetData()
            }
            
            recordMetric("refreshOverviewData", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Overview data refreshed")
        }
    }
    
    /// Refresh purchase-specific data
    public func refreshPurchaseData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing purchase data"
        ) {
            try await coreDataManager.getAllBudgetEntries()
        }
        
        if let freshEntries = result {
            await MainActor.run {
                entries = freshEntries.sorted { $0.date > $1.date }
                invalidateCache()
            }
            print("✅ BudgetManager: Purchase data refreshed")
        }
    }
    
    /// Refresh history-specific data
    public func refreshHistoryData() async {
        await loadData() // History needs all data
        print("✅ BudgetManager: History data refreshed")
    }
    
    /// Reload all data from scratch
    public func reloadAllData() async {
        await MainActor.run {
            entries.removeAll()
            monthlyBudgets.removeAll()
            invalidateCache()
        }
        
        await loadData()
        print("🔄 BudgetManager: All data reloaded from scratch")
    }
    
    /// Validate data integrity
    public func validateDataIntegrity() async -> Bool {
        let result = await AsyncErrorHandler.executeSilently(
            context: "Validating data integrity"
        ) {
            // Check for data consistency
            let entriesFromDB = try await coreDataManager.getAllBudgetEntries()
            let budgetsFromDB = try await coreDataManager.getAllMonthlyBudgets()
            
            // Validate entries
            for entry in entriesFromDB {
                try validateEntry(entry)
            }
            
            // Validate budgets
            for budget in budgetsFromDB {
                try validateBudget(budget)
            }
            
            return true
        }
        
        let isValid = result ?? false
        print(isValid ? "✅ BudgetManager: Data integrity validated" : "❌ BudgetManager: Data integrity issues found")
        return isValid
    }
    
    // MARK: - Entry Management
    
    /// Add a new budget entry
    public func addEntry(_ entry: BudgetEntry) async throws {
        try validateEntry(entry)
        
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Adding budget entry"
        ) {
            try await coreDataManager.addEntry(entry)
            return entry
        }
        
        switch result {
        case .success(let addedEntry):
            await MainActor.run {
                entries.insert(addedEntry, at: 0)
                entries.sort { $0.date > $1.date }
                invalidateCache()
                updateWidgetData()
                dataStatistics = getDataStatistics()
            }
            print("✅ BudgetManager: Added entry - \(addedEntry.amount.asCurrency) for \(addedEntry.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Update an existing budget entry
    public func updateEntry(_ entry: BudgetEntry) async throws {
        try validateEntry(entry)
        
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Updating budget entry"
        ) {
            try await coreDataManager.updateEntry(entry)
            return entry
        }
        
        switch result {
        case .success(let updatedEntry):
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
                    entries[index] = updatedEntry
                    entries.sort { $0.date > $1.date }
                }
                invalidateCache()
                updateWidgetData()
                dataStatistics = getDataStatistics()
            }
            print("✅ BudgetManager: Updated entry - \(updatedEntry.amount.asCurrency) for \(updatedEntry.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Delete a budget entry
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Deleting budget entry"
        ) {
            try await coreDataManager.deleteEntry(entry)
            return entry.id
        }
        
        switch result {
        case .success(let deletedId):
            await MainActor.run {
                entries.removeAll { $0.id == deletedId }
                invalidateCache()
                updateWidgetData()
                dataStatistics = getDataStatistics()
            }
            print("✅ BudgetManager: Deleted entry - \(entry.amount.asCurrency) for \(entry.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Budget Management
    
    /// Add or update a monthly budget
    public func addOrUpdateBudget(_ budget: MonthlyBudget) async throws {
        try validateBudget(budget)
        
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Adding/updating monthly budget"
        ) {
            try await coreDataManager.addOrUpdateMonthlyBudget(budget)
            return budget
        }
        
        switch result {
        case .success(let savedBudget):
            await MainActor.run {
                // Remove existing budget for same category/month/year
                monthlyBudgets.removeAll {
                    $0.category == savedBudget.category &&
                    $0.month == savedBudget.month &&
                    $0.year == savedBudget.year
                }
                monthlyBudgets.append(savedBudget)
                monthlyBudgets.sort {
                    $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
                }
                invalidateCache()
                updateWidgetData()
                dataStatistics = getDataStatistics()
            }
            print("✅ BudgetManager: Saved budget - \(savedBudget.amount.asCurrency) for \(savedBudget.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Data Retrieval
    
    /// Get entries with filtering and sorting
    public func getEntries(
        for period: TimePeriod? = nil,
        category: String? = nil,
        sortedBy sortKey: SortKey = .date,
        ascending: Bool = false
    ) async throws -> [BudgetEntry] {
        var filteredEntries = entries
        
        // Filter by time period
        if let period = period {
            let dateRange = period.dateRange
            filteredEntries = filteredEntries.filter {
                $0.date >= dateRange.start && $0.date <= dateRange.end
            }
        }
        
        // Filter by category
        if let category = category {
            filteredEntries = filteredEntries.filter { $0.category == category }
        }
        
        // Sort entries
        switch sortKey {
        case .date:
            filteredEntries.sort { ascending ? $0.date < $1.date : $0.date > $1.date }
        case .amount:
            filteredEntries.sort { ascending ? $0.amount < $1.amount : $0.amount > $1.amount }
        case .category:
            filteredEntries.sort { ascending ? $0.category < $1.category : $0.category > $1.category }
        }
        
        return filteredEntries
    }
    
    public enum SortKey {
        case date, amount, category
    }
    
    /// Get monthly budgets for specific month/year
    public func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { $0.month == month && $0.year == year }
    }
    
    /// Get current month budget
    public func getCurrentMonthBudget() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        return getMonthlyBudgets(for: currentMonth, year: currentYear)
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Get available categories
    public func getAvailableCategories() -> [String] {
        let entryCategories = Set(entries.map { $0.category })
        let budgetCategories = Set(monthlyBudgets.map { $0.category })
        return Array(entryCategories.union(budgetCategories)).sorted()
    }
    
    // MARK: - State Management
    
    /// Save current state
    public func saveCurrentState() async throws {
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Saving current state"
        ) {
            try await coreDataManager.forceSave()
            return true
        }
        
        switch result {
        case .success:
            await MainActor.run {
                lastSyncDate = Date()
            }
            print("✅ BudgetManager: Current state saved")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Perform background save
    public func performBackgroundSave() async throws {
        try await saveCurrentState()
        await updateWidgetData()
        print("✅ BudgetManager: Background save completed")
    }
    
    /// Perform final save before app termination
    public func performFinalSave() async throws {
        try await coreDataManager.forceSave()
        await updateWidgetData()
        print("✅ BudgetManager: Final save completed")
    }
    
    /// Clear caches
    public func clearCaches() async {
        await MainActor.run {
            invalidateCache()
        }
        print("🧹 BudgetManager: Caches cleared")
    }
    
    // MARK: - Widget Integration
    
    /// Update widget data with debouncing
    public func updateWidgetData() {
        widgetUpdateDebouncer.debounce {
            Task { @MainActor in
                await self.performWidgetUpdate()
            }
        }
    }
    
    private func performWidgetUpdate() async {
        let result = await AsyncErrorHandler.executeSilently(
            context: "Updating widget data"
        ) {
            let currentBudget = getCurrentMonthBudget()
            
            // Calculate spent amount for current month
            let calendar = Calendar.current
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            let monthlyEntries = entries.filter { entry in
                calendar.component(.month, from: entry.date) == currentMonth &&
                calendar.component(.year, from: entry.date) == currentYear
            }
            
            let totalSpent = monthlyEntries.reduce(0) { $0 + $1.amount }
            let remainingBudget = currentBudget - totalSpent
            
            try await SharedDataManager.shared.updateBudgetData(
                monthlyBudget: currentBudget,
                totalSpent: totalSpent,
                remainingBudget: remainingBudget,
                categoryCount: getAvailableCategories().count,
                transactionCount: entries.count
            )
            
            return true
        }
        
        if result != nil {
            print("✅ BudgetManager: Widget data updated")
        }
    }
    
    /// Generate complete widget data
    public func generateWidgetData() async throws -> [String: Any] {
        let currentBudget = getCurrentMonthBudget()
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        let monthlyEntries = entries.filter { entry in
            calendar.component(.month, from: entry.date) == currentMonth &&
            calendar.component(.year, from: entry.date) == currentYear
        }
        
        let totalSpent = monthlyEntries.reduce(0) { $0 + $1.amount }
        
        return [
            "monthlyBudget": currentBudget,
            "totalSpent": totalSpent,
            "remainingBudget": currentBudget - totalSpent,
            "categoryCount": getAvailableCategories().count,
            "transactionCount": entries.count,
            "lastUpdated": Date()
        ]
    }
    
    // MARK: - Statistics and Analytics
    
    /// Get comprehensive data statistics
    public func getDataStatistics() -> DataStatistics {
        let entryDates = entries.map { $0.date }
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let totalBudgeted = monthlyBudgets.reduce(0) { $0 + $1.amount }
        let categories = getAvailableCategories()
        
        let healthStatus: DataStatistics.HealthStatus
        if entries.isEmpty && monthlyBudgets.isEmpty {
            healthStatus = .warning
        } else if totalSpent > totalBudgeted * 1.2 {
            healthStatus = .error
        } else if errorHandler.hasCriticalErrors() {
            healthStatus = .critical
        } else {
            healthStatus = .healthy
        }
        
        return DataStatistics(
            entryCount: entries.count,
            budgetCount: monthlyBudgets.count,
            categoryCount: categories.count,
            totalSpent: totalSpent,
            totalBudgeted: totalBudgeted,
            oldestEntry: entryDates.min(),
            newestEntry: entryDates.max(),
            lastSyncDate: lastSyncDate,
            healthStatus: healthStatus
        )
    }
    
    // MARK: - Validation
    
    private func validateEntry(_ entry: BudgetEntry) throws {
        guard entry.amount > 0 else {
            throw BudgetManagerError.validationFailed("Entry amount must be greater than zero")
        }
        
        guard entry.amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw BudgetManagerError.validationFailed("Entry amount exceeds maximum allowed")
        }
        
        guard !entry.category.isEmpty else {
            throw BudgetManagerError.validationFailed("Entry category cannot be empty")
        }
        
        guard entry.date <= Date() else {
            throw BudgetManagerError.validationFailed("Entry date cannot be in the future")
        }
    }
    
    private func validateBudget(_ budget: MonthlyBudget) throws {
        guard budget.amount >= 0 else {
            throw BudgetManagerError.validationFailed("Budget amount cannot be negative")
        }
        
        guard !budget.category.isEmpty else {
            throw BudgetManagerError.validationFailed("Budget category cannot be empty")
        }
        
        guard budget.month >= 1 && budget.month <= 12 else {
            throw BudgetManagerError.validationFailed("Invalid month value")
        }
        
        guard budget.year >= 2020 && budget.year <= 2030 else {
            throw BudgetManagerError.validationFailed("Invalid year value")
        }
    }
    
    // MARK: - Cache Management
    
    private func invalidateCache() {
        budgetCache.removeAll()
        entriesCache.removeAll()
        lastCacheUpdate = nil
    }
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastCacheUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheExpiration
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        performanceQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ BudgetManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    // MARK: - Setup and Observers
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Debouncer Utility

private class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Extensions

public extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$\(String(format: "%.2f", self))"
    }
}

// MARK: - Testing Support

#if DEBUG
extension BudgetManager {
    /// Reset all data for testing
    func resetForTesting() {
        entries.removeAll()
        monthlyBudgets.removeAll()
        invalidateCache()
        lastSyncDate = nil
        dataStatistics = getDataStatistics()
    }
    
    /// Load test data
    func loadTestData() async {
        let testEntries = [
            try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date(), note: "Weekly shopping"),
            try! BudgetEntry(amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-86400), note: "Bus fare"),
            try! BudgetEntry(amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-172800), note: "Movie tickets")
        ]
        
        await MainActor.run {
            entries = testEntries
            dataStatistics = getDataStatistics()
        }
        
        print("✅ BudgetManager: Test data loaded")
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetrics() -> [String: TimeInterval] {
        return performanceQueue.sync {
            return operationMetrics
        }
    }
}
#endif
