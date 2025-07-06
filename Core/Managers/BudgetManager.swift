//
//  BudgetManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 7/6/25 - Fixed Swift 6 concurrency, CoreData methods, and removed duplicate extensions
//

import Foundation
import Combine
import WidgetKit

/// Central coordinator for budget-related operations with enhanced state management
@MainActor
public final class BudgetManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = BudgetManager()
    
    // MARK: - Types
    
    public enum BudgetManagerError: LocalizedError {
        case invalidEntry(String)
        case invalidBudget(String)
        case dataLoadFailed(Error)
        case dataSaveFailed(Error)
        case validationFailed(String)
        case cacheCorrupted
        
        public var errorDescription: String? {
            switch self {
            case .invalidEntry(let details):
                return "Invalid budget entry: \(details)"
            case .invalidBudget(let details):
                return "Invalid budget: \(details)"
            case .dataLoadFailed(let error):
                return "Failed to load data: \(error.localizedDescription)"
            case .dataSaveFailed(let error):
                return "Failed to save data: \(error.localizedDescription)"
            case .validationFailed(let details):
                return "Validation failed: \(details)"
            case .cacheCorrupted:
                return "Cache data is corrupted"
            }
        }
    }
    
    public enum BudgetSortOption: String, CaseIterable {
        case date = "Date"
        case amount = "Amount"
        case category = "Category"
        
        public var systemImageName: String {
            switch self {
            case .date: return "calendar"
            case .amount: return "dollarsign"
            case .category: return "folder"
            }
        }
    }
    
    public struct DataStatistics: Sendable {
        public let totalEntries: Int
        public let totalBudgets: Int
        public let totalSpent: Double
        public let totalBudgeted: Double
        public let categoriesCount: Int
        public let lastUpdate: Date
        
        public var budgetUtilization: Double {
            guard totalBudgeted > 0 else { return 0 }
            return (totalSpent / totalBudgeted) * 100
        }
        
        public var isOverBudget: Bool {
            return totalSpent > totalBudgeted
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
    private let performanceQueue = DispatchQueue(label: "com.brandonsbudget.performance", qos: .utility)
    private var operationMetrics: [String: TimeInterval] = [:]
    
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
        isLoading = true
        defer { Task { @MainActor in self.isLoading = false } }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading budget data"
        ) {
            let loadedEntries = try await self.coreDataManager.getAllBudgetEntries()
            let loadedBudgets = try await self.coreDataManager.getAllMonthlyBudgets()
            
            return (entries: loadedEntries, budgets: loadedBudgets)
        }
        
        if let (loadedEntries, loadedBudgets) = result {
            entries = loadedEntries.sorted { $0.date > $1.date }
            monthlyBudgets = loadedBudgets.sorted {
                $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
            }
            lastSyncDate = Date()
            invalidateCache()
            dataStatistics = getDataStatistics()
            updateWidgetData()
            
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
            
            let currentEntries = try await self.coreDataManager.getBudgetEntries(
                for: TimePeriod.thisMonth,
                category: nil
            )
            let currentBudgets = try await self.coreDataManager.getMonthlyBudgets(
                for: currentMonth,
                year: currentYear
            )
            
            return (entries: currentEntries, budgets: currentBudgets)
        }
        
        if let (currentEntries, currentBudgets) = result {
            // Update entries with fresh current month data
            let calendar = Calendar.current
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            // Remove old current month data
            entries.removeAll { entry in
                let entryMonth = calendar.component(.month, from: entry.date)
                let entryYear = calendar.component(.year, from: entry.date)
                return entryMonth == currentMonth && entryYear == currentYear
            }
            
            // Add fresh current month data
            entries.append(contentsOf: currentEntries)
            entries.sort { $0.date > $1.date }
            
            // Update monthly budgets for current month
            monthlyBudgets.removeAll { budget in
                budget.month == currentMonth && budget.year == currentYear
            }
            monthlyBudgets.append(contentsOf: currentBudgets)
            
            invalidateCache()
            dataStatistics = getDataStatistics()
            updateWidgetData()
            
            recordMetric("refreshOverviewData", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Overview data refreshed")
        }
    }
    
    /// Refresh purchase-specific data
    public func refreshPurchaseData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing purchase data"
        ) {
            return try await self.coreDataManager.getAllBudgetEntries()
        }
        
        if let freshEntries = result {
            entries = freshEntries.sorted { $0.date > $1.date }
            invalidateCache()
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
        entries.removeAll()
        monthlyBudgets.removeAll()
        invalidateCache()
        
        await loadData()
        print("🔄 BudgetManager: All data reloaded from scratch")
    }
    
    /// Validate data integrity
    public func validateDataIntegrity() async -> Bool {
        let result = await AsyncErrorHandler.executeSilently(
            context: "Validating data integrity"
        ) {
            // Check for data consistency
            let entriesFromDB = try await self.coreDataManager.getAllBudgetEntries()
            let budgetsFromDB = try await self.coreDataManager.getAllMonthlyBudgets()
            
            // Validate entries
            for entry in entriesFromDB {
                try self.validateEntry(entry)
            }
            
            // Validate budgets
            for budget in budgetsFromDB {
                try self.validateBudget(budget)
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
            try await self.coreDataManager.addEntry(entry)
            return entry
        }
        
        switch result {
        case .success(let addedEntry):
            entries.insert(addedEntry, at: 0)
            entries.sort { $0.date > $1.date }
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Added entry - \(addedEntry.amount.formattedAsCurrency) for \(addedEntry.category)")
            
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
            try await self.coreDataManager.updateEntry(entry)
            return entry
        }
        
        switch result {
        case .success(let updatedEntry):
            if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
                entries[index] = updatedEntry
                entries.sort { $0.date > $1.date }
            }
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Updated entry - \(updatedEntry.amount.formattedAsCurrency) for \(updatedEntry.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Delete a budget entry
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Deleting budget entry"
        ) {
            try await self.coreDataManager.deleteEntry(entry)
            return entry.id
        }
        
        switch result {
        case .success(let deletedId):
            entries.removeAll { $0.id == deletedId }
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Deleted entry - \(entry.amount.formattedAsCurrency) for \(entry.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Budget Management
    
    /// Add or update a monthly budget
    public func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) async throws {
        try validateBudget(budget)
        
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Adding/updating monthly budget"
        ) {
            try await self.coreDataManager.addOrUpdateMonthlyBudget(budget)
            return budget
        }
        
        switch result {
        case .success(let savedBudget):
            if let existingIndex = monthlyBudgets.firstIndex(where: {
                $0.category == savedBudget.category &&
                $0.month == savedBudget.month &&
                $0.year == savedBudget.year
            }) {
                monthlyBudgets[existingIndex] = savedBudget
            } else {
                monthlyBudgets.append(savedBudget)
            }
            
            monthlyBudgets.sort {
                $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
            }
            
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Saved budget - \(savedBudget.amount.formattedAsCurrency) for \(savedBudget.category)")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Update multiple monthly budgets
    public func updateMonthlyBudgets(_ budgets: [String: Double], for month: Int, year: Int) async throws {
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Updating multiple monthly budgets"
        ) {
            var savedBudgets: [MonthlyBudget] = []
            
            for (category, amount) in budgets {
                let budget = try MonthlyBudget(
                    id: UUID(),
                    category: category,
                    amount: amount,
                    month: month,
                    year: year,
                    isHistorical: false
                )
                
                try await self.coreDataManager.addOrUpdateMonthlyBudget(budget)
                savedBudgets.append(budget)
            }
            
            return savedBudgets
        }
        
        switch result {
        case .success(let savedBudgets):
            // Remove old budgets for this month/year
            monthlyBudgets.removeAll { $0.month == month && $0.year == year }
            
            // Add new budgets
            monthlyBudgets.append(contentsOf: savedBudgets)
            monthlyBudgets.sort {
                $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
            }
            
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Updated \(savedBudgets.count) budgets for \(month)/\(year)")
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Data Retrieval Methods
    
    /// Get entries with filtering and sorting
    public func getEntries(
        for period: TimePeriod? = nil,
        category: String? = nil,
        sortedBy sortOption: BudgetSortOption = .date,
        ascending: Bool = false
    ) -> [BudgetEntry] {
        var filteredEntries = entries
        
        // Apply period filter
        if let period = period {
            let dateInterval = period.dateInterval()
            filteredEntries = filteredEntries.filter { entry in
                dateInterval.contains(entry.date)
            }
        }
        
        // Apply category filter
        if let category = category {
            filteredEntries = filteredEntries.filter { $0.category == category }
        }
        
        // Apply sorting
        switch sortOption {
        case .date:
            filteredEntries.sort { ascending ? $0.date < $1.date : $0.date > $1.date }
        case .amount:
            filteredEntries.sort { ascending ? $0.amount < $1.amount : $0.amount > $1.amount }
        case .category:
            filteredEntries.sort { ascending ? $0.category < $1.category : $0.category > $1.category }
        }
        
        return filteredEntries
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
            try await self.coreDataManager.forceSave()
            return true
        }
        
        switch result {
        case .success:
            lastSyncDate = Date()
            print("✅ BudgetManager: Current state saved")
            
        case .failure(let error):
            throw error
        }
    }
    
    /// Perform background save
    public func performBackgroundSave() async throws {
        let result = await AsyncErrorHandler.executeWithResult(
            context: "Performing background save"
        ) {
            try await self.coreDataManager.saveContext()
            return true
        }
        
        switch result {
        case .success:
            lastSyncDate = Date()
            print("✅ BudgetManager: Background save completed")
            
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupObservers() {
        // Setup data change observers if needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataUpdate),
            name: .budgetDataUpdated,
            object: nil
        )
    }
    
    @objc private func handleDataUpdate() {
        Task { @MainActor in
            dataStatistics = getDataStatistics()
            updateWidgetData()
        }
    }
    
    private func getDataStatistics() -> DataStatistics {
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let totalBudgeted = monthlyBudgets.reduce(0) { $0 + $1.amount }
        let categories = Set(entries.map { $0.category }.appending(contentsOf: monthlyBudgets.map { $0.category }))
        
        return DataStatistics(
            totalEntries: entries.count,
            totalBudgets: monthlyBudgets.count,
            totalSpent: totalSpent,
            totalBudgeted: totalBudgeted,
            categoriesCount: categories.count,
            lastUpdate: lastSyncDate ?? Date()
        )
    }
    
    private func validateEntry(_ entry: BudgetEntry) throws {
        guard entry.amount >= 0 else {
            throw BudgetManagerError.invalidEntry("Amount cannot be negative")
        }
        guard !entry.category.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw BudgetManagerError.invalidEntry("Category cannot be empty")
        }
        guard entry.date <= Date() else {
            throw BudgetManagerError.invalidEntry("Date cannot be in the future")
        }
    }
    
    private func validateBudget(_ budget: MonthlyBudget) throws {
        guard budget.amount >= 0 else {
            throw BudgetManagerError.invalidBudget("Budget amount cannot be negative")
        }
        guard !budget.category.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw BudgetManagerError.invalidBudget("Category cannot be empty")
        }
        guard budget.month >= 1 && budget.month <= 12 else {
            throw BudgetManagerError.invalidBudget("Month must be between 1 and 12")
        }
        guard budget.year >= 2000 && budget.year <= 2100 else {
            throw BudgetManagerError.invalidBudget("Year must be reasonable")
        }
    }
    
    private func invalidateCache() {
        budgetCache.removeAll()
        entriesCache.removeAll()
        lastCacheUpdate = nil
    }
    
    private func updateWidgetData() {
        widgetUpdateDebouncer.run { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Update SharedDataManager with current data
                let summary = SharedDataManager.BudgetSummary(
                    monthlyBudget: self.getCurrentMonthBudget(),
                    totalSpent: self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                        .reduce(0) { $0 + $1.amount },
                    remainingBudget: max(0, self.getCurrentMonthBudget() - self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                        .reduce(0) { $0 + $1.amount }),
                    categoryCount: Set(self.monthlyBudgets.filter { $0.month == Calendar.current.component(.month, from: Date()) && $0.year == Calendar.current.component(.year, from: Date()) }.map { $0.category }).count,
                    transactionCount: self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
                )
                
                do {
                    try await SharedDataManager.shared.updateBudgetSummary(summary)
                } catch {
                    print("❌ BudgetManager: Failed to update widget data - \(error)")
                }
            }
        }
    }
    
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
}

// MARK: - Extensions for Data Retrieval

public extension BudgetManager {
    
    /// Get total spending for a category in a time period
    func getTotalSpending(for category: String, in period: TimePeriod) -> Double {
        return getEntries(for: period, category: category)
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Get spending trend for a category over time
    func getSpendingTrend(for category: String, months: Int = 6) -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        var trend: [Double] = []
        
        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let month = calendar.component(.month, from: monthDate)
            let year = calendar.component(.year, from: monthDate)
            
            let monthlySpending = entries.filter { entry in
                let entryMonth = calendar.component(.month, from: entry.date)
                let entryYear = calendar.component(.year, from: entry.date)
                return entry.category == category && entryMonth == month && entryYear == year
            }.reduce(0) { $0 + $1.amount }
            
            trend.append(monthlySpending)
        }
        
        return trend.reversed()
    }
    
    /// Get budget utilization percentage for a category
    func getBudgetUtilization(for category: String, month: Int, year: Int) -> Double {
        let budgetAmount = getMonthlyBudgets(for: month, year: year)
            .first { $0.category == category }?.amount ?? 0
        
        guard budgetAmount > 0 else { return 0 }
        
        let spentAmount = entries.filter { entry in
            let calendar = Calendar.current
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entry.category == category && entryMonth == month && entryYear == year
        }.reduce(0) { $0 + $1.amount }
        
        return (spentAmount / budgetAmount) * 100
    }
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

private extension Array {
    func appending(contentsOf other: [Element]) -> [Element] {
        var result = self
        result.append(contentsOf: other)
        return result
    }
}

// MARK: - Supporting Types

private class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func run(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem { action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let budgetDataUpdated = Notification.Name("budgetDataUpdated")
}

// MARK: - Testing Support

#if DEBUG
extension BudgetManager {
    /// Reset for testing
    func resetForTesting() {
        entries.removeAll()
        monthlyBudgets.removeAll()
        invalidateCache()
        dataStatistics = getDataStatistics()
        operationMetrics.removeAll()
    }
    
    /// Load test data
    func loadTestData() async {
        // Test entries
        let testEntries = [
            try! BudgetEntry(id: UUID(), amount: 45.67, category: "Groceries", date: Date(), note: "Weekly shopping"),
            try! BudgetEntry(id: UUID(), amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-86400), note: "Bus fare"),
            try! BudgetEntry(id: UUID(), amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-172800), note: "Movie tickets")
        ]
        
        // Test budgets
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        let testBudgets = [
            try! MonthlyBudget(id: UUID(), category: "Groceries", amount: 400.0, month: currentMonth, year: currentYear),
            try! MonthlyBudget(id: UUID(), category: "Transportation", amount: 200.0, month: currentMonth, year: currentYear),
            try! MonthlyBudget(id: UUID(), category: "Entertainment", amount: 150.0, month: currentMonth, year: currentYear)
        ]
        
        entries = testEntries
        monthlyBudgets = testBudgets
        dataStatistics = getDataStatistics()
        updateWidgetData()
        
        print("📊 BudgetManager: Test data loaded")
    }
    
    /// Get metrics for testing
    func getMetricsForTesting() -> [String: TimeInterval] {
        return operationMetrics
    }
}
#endif
