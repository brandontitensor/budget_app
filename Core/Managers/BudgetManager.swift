//
//  BudgetManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 7/7/25 - Fixed Swift 6 concurrency, missing try keywords, and removed duplicate extensions
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
    private var cancellables = Set<AnyCancellable>()
    private let performanceQueue = DispatchQueue(label: "com.brandonsbudget.performance", qos: .utility)
    
    // Performance monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    
    // Cache management
    private var entryCache: [String: [BudgetEntry]] = [:]
    private var budgetCache: [String: [MonthlyBudget]] = [:]
    private let debouncer = Debouncer(delay: 0.5)
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
        Task {
            await loadInitialData()
        }
    }
    
    private func setupNotifications() {
        // Listen for data changes
        coreDataManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.invalidateCache()
            }
            .store(in: &cancellables)
        
        // App lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { [weak self] in
                    try? await self?.saveCurrentState()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { [weak self] in
                    try? await self?.performBackgroundSave()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    /// Load initial data from Core Data
    public func loadInitialData() async {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let entriesLoad = coreDataManager.fetchAllEntries()
            async let budgetsLoad = coreDataManager.fetchMonthlyBudgets()
            
            let (loadedEntries, loadedBudgets) = try await (entriesLoad, budgetsLoad)
            
            entries = loadedEntries
            monthlyBudgets = loadedBudgets
            dataStatistics = getDataStatistics()
            lastSyncDate = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            recordMetric("loadInitialData", duration: duration)
            
            updateWidgetData()
            print("✅ BudgetManager: Initial data loaded - \(entries.count) entries, \(monthlyBudgets.count) budgets")
            
        } catch {
            let appError = AppError.from(error)
            await MainActor.run {
                ErrorHandler.shared.handle(appError, context: "Loading initial data")
            }
        }
    }
    
    /// Refresh data from storage
    public func refreshData() async {
        await loadInitialData()
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
        case .success(let savedEntry):
            entries.append(savedEntry)
            entries.sort { $0.date > $1.date }
            invalidateCache()
            updateWidgetData()
            dataStatistics = getDataStatistics()
            print("✅ BudgetManager: Added entry - \(savedEntry.amount.formattedAsCurrency) for \(savedEntry.category)")
            
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
    
    // MARK: - Validation
    
    private func validateEntry(_ entry: BudgetEntry) throws {
        guard entry.amount > 0 else {
            throw BudgetManagerError.invalidEntry("Amount must be greater than zero")
        }
        
        guard !entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BudgetManagerError.invalidEntry("Category cannot be empty")
        }
        
        guard entry.amount <= 999999.99 else {
            throw BudgetManagerError.invalidEntry("Amount exceeds maximum allowed value")
        }
    }
    
    private func validateBudget(_ budget: MonthlyBudget) throws {
        guard budget.amount >= 0 else {
            throw BudgetManagerError.invalidBudget("Budget amount cannot be negative")
        }
        
        guard !budget.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BudgetManagerError.invalidBudget("Category cannot be empty")
        }
        
        guard budget.month >= 1 && budget.month <= 12 else {
            throw BudgetManagerError.invalidBudget("Month must be between 1 and 12")
        }
        
        guard budget.year >= 1900 && budget.year <= 2100 else {
            throw BudgetManagerError.invalidBudget("Year must be between 1900 and 2100")
        }
    }
    
    // MARK: - Cache Management
    
    private func invalidateCache() {
        entryCache.removeAll()
        budgetCache.removeAll()
    }
    
    // MARK: - Analytics and Statistics
    
    private func getDataStatistics() -> DataStatistics {
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let totalBudgeted = monthlyBudgets.reduce(0) { $0 + $1.amount }
        let categoriesCount = Set(entries.map { $0.category }).union(Set(monthlyBudgets.map { $0.category })).count
        
        return DataStatistics(
            totalEntries: entries.count,
            totalBudgets: monthlyBudgets.count,
            totalSpent: totalSpent,
            totalBudgeted: totalBudgeted,
            categoriesCount: categoriesCount,
            lastUpdate: Date()
        )
    }
    
    // MARK: - Widget Data Updates
    
    private func updateWidgetData() {
        debouncer.run { [weak self] in
            Task { [weak self] in
                await self?.performWidgetDataUpdate()
            }
        }
    }
    
    private func performWidgetDataUpdate() async {
        do {
            // Prepare current data
            let summary = SharedDataManager.BudgetSummary(
                monthlyBudget: self.getCurrentMonthBudget(),
                totalSpent: self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount },
                remainingBudget: max(0, self.getCurrentMonthBudget() - self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount }),
                categoryCount: Set(self.monthlyBudgets.filter { $0.month == Calendar.current.component(.month, from: Date()) && $0.year == Calendar.current.component(.year, from: Date()) }.map { $0.category }).count,
                transactionCount: self.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
            )
            
            try await SharedDataManager.shared.updateBudgetSummary(summary)
        } catch {
            print("❌ BudgetManager: Failed to update widget data - \(error)")
        }
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
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
        print("🧹 BudgetManager: Cleaned up resources")
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
