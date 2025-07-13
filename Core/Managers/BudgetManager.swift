//
//  BudgetManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
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
        case methodNotImplemented(String)
        
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
            case .methodNotImplemented(let method):
                return "Method not implemented: \(method)"
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
    @Published public private(set) var currentError: AppError?
    @Published public private(set) var categories: [String] = []
    @Published public private(set) var overviewData: BudgetOverviewData?
    @Published public private(set) var purchaseData: [BudgetEntry] = []
    @Published public private(set) var historyData: [BudgetHistoryData] = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let dataManager: CoreDataManager
    private let notificationManager: NotificationManager
    
    // MARK: - Initialization
    private init() {
        self.dataManager = CoreDataManager.shared
        self.notificationManager = NotificationManager.shared
        setupDataBinding()
    }
    
    // MARK: - Data Loading Methods (Missing Methods Added)
    
    /// Load initial data - Called from BrandonsBudgetApp.swift and ContentView.swift
    public func loadData() async throws {
        isLoading = true
        currentError = nil
        
        do {
            // Load all data
            try await loadEntries()
            try await loadMonthlyBudgets()
            try await loadCategories()
            
            // Update statistics
            updateDataStatistics()
            
            // Update last sync date
            lastSyncDate = Date()
            
            print("✅ BudgetManager: Data loaded successfully")
            
        } catch {
            currentError = AppError.dataLoad(underlying: error)
            print("❌ BudgetManager: Failed to load data - \(error)")
            throw BudgetManagerError.dataLoadFailed(error)
        }
        
        isLoading = false
    }
    
    /// Reload all data - Called from ContentView.swift
    public func reloadAllData() async throws {
        isLoading = true
        currentError = nil
        
        do {
            // Clear existing data
            entries.removeAll()
            monthlyBudgets.removeAll()
            categories.removeAll()
            
            // Reload everything
            try await loadData()
            
            print("✅ BudgetManager: All data reloaded successfully")
            
        } catch {
            currentError = AppError.dataLoad(underlying: error)
            print("❌ BudgetManager: Failed to reload all data - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    /// Refresh data - General refresh method
    public func refreshData() async throws {
        try await loadData()
    }
    
    /// Refresh overview-specific data - Called from ContentView.swift
    public func refreshOverviewData() async throws {
        isLoading = true
        
        do {
            // Load overview-specific data
            try await loadEntries()
            try await loadMonthlyBudgets()
            
            // Calculate overview statistics
            overviewData = calculateOverviewData()
            
            print("✅ BudgetManager: Overview data refreshed")
            
        } catch {
            currentError = AppError.dataLoad(underlying: error)
            print("❌ BudgetManager: Failed to refresh overview data - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    /// Refresh purchase-specific data
    public func refreshPurchaseData() async throws {
        isLoading = true
        
        do {
            try await loadEntries()
            purchaseData = entries
            print("✅ BudgetManager: Purchase data refreshed")
            
        } catch {
            currentError = AppError.dataLoad(underlying: error)
            print("❌ BudgetManager: Failed to refresh purchase data - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    /// Refresh history-specific data
    public func refreshHistoryData() async throws {
        isLoading = true
        
        do {
            try await loadEntries()
            try await loadMonthlyBudgets()
            historyData = calculateHistoryData()
            print("✅ BudgetManager: History data refreshed")
            
        } catch {
            currentError = AppError.dataLoad(underlying: error)
            print("❌ BudgetManager: Failed to refresh history data - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Category Management Methods (Missing Methods Added)
    
    /// Add a new category - Called from BudgetView.swift
    public func addCategory(name: String, amount: Double, month: Int, year: Int) async throws {
        isLoading = true
        
        do {
            // Validate input
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BudgetManagerError.validationFailed("Category name cannot be empty")
            }
            
            guard amount > 0 else {
                throw BudgetManagerError.validationFailed("Amount must be greater than 0")
            }
            
            // Check if category already exists for this month
            if let existingBudget = monthlyBudgets.first(where: { $0.month == month && $0.year == year }),
               existingBudget.categories.keys.contains(name) {
                throw BudgetManagerError.validationFailed("Category already exists for this month")
            }
            
            // Add category to monthly budget
            let monthKey = "\(year)-\(String(format: "%02d", month))"
            
            // Find or create monthly budget
            if let index = monthlyBudgets.firstIndex(where: { $0.month == month && $0.year == year }) {
                monthlyBudgets[index].categories[name] = amount
            } else {
                let newBudget = MonthlyBudget(
                    id: UUID(),
                    month: month,
                    year: year,
                    categories: [name: amount]
                )
                monthlyBudgets.append(newBudget)
            }
            
            // Add to categories list if not already there
            if !categories.contains(name) {
                categories.append(name)
            }
            
            // Save changes
            try await saveMonthlyBudgets()
            
            print("✅ BudgetManager: Category '\(name)' added successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            print("❌ BudgetManager: Failed to add category - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    /// Delete a monthly budget category - Called from EditCategoryView.swift
    public func deleteMonthlyBudget(
        category: String,
        fromMonth: Int,
        year: Int,
        includeFutureMonths: Bool = false
    ) async throws {
        isLoading = true
        
        do {
            if includeFutureMonths {
                // Remove from current month and all future months
                monthlyBudgets = monthlyBudgets.map { budget in
                    var updatedBudget = budget
                    if (budget.year > year) || (budget.year == year && budget.month >= fromMonth) {
                        updatedBudget.categories.removeValue(forKey: category)
                    }
                    return updatedBudget
                }
            } else {
                // Remove only from the specific month
                if let index = monthlyBudgets.firstIndex(where: { $0.month == fromMonth && $0.year == year }) {
                    monthlyBudgets[index].categories.removeValue(forKey: category)
                    
                    // Remove the entire monthly budget if no categories left
                    if monthlyBudgets[index].categories.isEmpty {
                        monthlyBudgets.remove(at: index)
                    }
                }
            }
            
            // Check if category should be removed from categories list
            let categoryStillExists = monthlyBudgets.contains { $0.categories.keys.contains(category) }
            if !categoryStillExists {
                categories.removeAll { $0 == category }
            }
            
            // Save changes
            try await saveMonthlyBudgets()
            
            print("✅ BudgetManager: Category '\(category)' deleted successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            print("❌ BudgetManager: Failed to delete category - \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Entry Management
    
    public func addEntry(_ entry: BudgetEntry) async throws {
        isLoading = true
        
        do {
            entries.append(entry)
            try await saveEntries()
            updateDataStatistics()
            
            print("✅ BudgetManager: Entry added successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    public func updateEntry(_ entry: BudgetEntry) async throws {
        isLoading = true
        
        do {
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = entry
                try await saveEntries()
                updateDataStatistics()
                
                print("✅ BudgetManager: Entry updated successfully")
            }
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        isLoading = true
        
        do {
            entries.removeAll { $0.id == entry.id }
            try await saveEntries()
            updateDataStatistics()
            
            print("✅ BudgetManager: Entry deleted successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Private Helper Methods
    
    private func setupDataBinding() {
        // Set up any Combine publishers if needed
    }
    
    private func loadEntries() async throws {
        // Implementation depends on your data storage system
        // This is a placeholder - replace with your actual data loading logic
        entries = try await dataManager.loadBudgetEntries()
    }
    
    private func loadMonthlyBudgets() async throws {
        // Implementation depends on your data storage system
        monthlyBudgets = try await dataManager.loadMonthlyBudgets()
    }
    
    private func loadCategories() async throws {
        // Extract unique categories from entries and monthly budgets
        var uniqueCategories = Set<String>()
        
        // Add categories from entries
        entries.forEach { uniqueCategories.insert($0.category) }
        
        // Add categories from monthly budgets
        monthlyBudgets.forEach { budget in
            budget.categories.keys.forEach { uniqueCategories.insert($0) }
        }
        
        categories = Array(uniqueCategories).sorted()
    }
    
    private func saveEntries() async throws {
        try await dataManager.saveBudgetEntries(entries)
    }
    
    private func saveMonthlyBudgets() async throws {
        try await dataManager.saveMonthlyBudgets(monthlyBudgets)
    }
    
    private func updateDataStatistics() {
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let totalBudgeted = monthlyBudgets.reduce(0) { total, budget in
            total + budget.categories.values.reduce(0, +)
        }
        
        dataStatistics = DataStatistics(
            totalEntries: entries.count,
            totalBudgets: monthlyBudgets.count,
            totalSpent: totalSpent,
            totalBudgeted: totalBudgeted,
            categoriesCount: categories.count,
            lastUpdate: Date()
        )
    }
    
    private func calculateOverviewData() -> BudgetOverviewData? {
        guard !monthlyBudgets.isEmpty else { return nil }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        // Get current month's budget
        guard let currentBudget = monthlyBudgets.first(where: { 
            $0.month == currentMonth && $0.year == currentYear 
        }) else {
            return nil
        }
        
        // Calculate totals
        let totalBudgeted = currentBudget.categories.values.reduce(0, +)
        
        // Filter entries for current month
        let currentMonthEntries = entries.filter { entry in
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entryMonth == currentMonth && entryYear == currentYear
        }
        
        let totalSpent = currentMonthEntries.reduce(0) { $0 + $1.amount }
        
        // Calculate category breakdowns
        var categoryBreakdowns: [BudgetOverviewData.CategoryBreakdown] = []
        
        for (category, budgetedAmount) in currentBudget.categories {
            let categoryEntries = currentMonthEntries.filter { $0.category == category }
            let categorySpent = categoryEntries.reduce(0) { $0 + $1.amount }
            let transactionCount = categoryEntries.count
            
            let breakdown = BudgetOverviewData.CategoryBreakdown(
                category: category,
                spent: categorySpent,
                budgeted: budgetedAmount,
                transactionCount: transactionCount
            )
            categoryBreakdowns.append(breakdown)
        }
        
        // Get recent transactions (last 10)
        let recentTransactions = Array(currentMonthEntries.sorted { $0.date > $1.date }.prefix(10))
        
        return BudgetOverviewData(
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            categoryCount: currentBudget.categories.count,
            transactionCount: currentMonthEntries.count,
            timeframe: .thisMonth,
            categoryBreakdowns: categoryBreakdowns,
            recentTransactions: recentTransactions
        )
    }
    
    private func calculateHistoryData() -> [BudgetHistoryData] {
        var historyData: [BudgetHistoryData] = []
        
        // Group entries by category
        let entriesByCategory = Dictionary(grouping: entries) { $0.category }
        
        // Get all unique categories from both entries and budgets
        var allCategories = Set<String>()
        entriesByCategory.keys.forEach { allCategories.insert($0) }
        monthlyBudgets.forEach { budget in
            budget.categories.keys.forEach { allCategories.insert($0) }
        }
        
        // Calculate history data for each category
        for category in allCategories {
            let categoryEntries = entriesByCategory[category] ?? []
            let totalSpent = categoryEntries.reduce(0) { $0 + $1.amount }
            
            // Find the most recent budget for this category
            let budgetedAmount = monthlyBudgets
                .sorted { ($0.year * 12 + $0.month) > ($1.year * 12 + $1.month) }
                .first { $0.categories.keys.contains(category) }?
                .categories[category] ?? 0.0
            
            let data = BudgetHistoryData(
                category: category,
                budgetedAmount: budgetedAmount,
                amountSpent: totalSpent
            )
            
            historyData.append(data)
        }
        
        return historyData.sorted { $0.category < $1.category }
    }
    
    // MARK: - Critical Missing Methods Implementation
    
    /// Save the current state of budget data
    public func saveCurrentState() async throws {
        isLoading = true
        currentError = nil
        
        do {
            try await saveEntries()
            try await saveMonthlyBudgets()
            
            // Update statistics after save
            updateDataStatistics()
            
            print("✅ BudgetManager: Current state saved successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            print("❌ BudgetManager: Failed to save current state - \(error)")
            throw BudgetManagerError.dataSaveFailed(error)
        }
        
        isLoading = false
    }
    
    /// Perform background save operations
    public func performBackgroundSave() async throws {
        let result = await AsyncErrorHandler.execute(
            context: "Background save operation"
        ) {
            try await saveCurrentState()
            return true
        }
        
        if result == nil {
            throw BudgetManagerError.dataSaveFailed(NSError(domain: "BudgetManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Background save failed"]))
        }
    }
    
    /// Validate the integrity of stored data
    public func validateDataIntegrity() async -> Bool {
        let result = await AsyncErrorHandler.execute(
            context: "Data integrity validation"
        ) {
            // Validate entries
            for entry in entries {
                guard entry.amount > 0,
                      !entry.category.isEmpty,
                      entry.date <= Date() else {
                    print("❌ Invalid entry found: \(entry)")
                    return false
                }
            }
            
            // Validate monthly budgets
            for budget in monthlyBudgets {
                guard budget.month >= 1 && budget.month <= 12,
                      budget.year >= 2020 && budget.year <= 2030,
                      !budget.categories.isEmpty else {
                    print("❌ Invalid budget found: \(budget)")
                    return false
                }
                
                // Validate category amounts
                for (_, amount) in budget.categories {
                    guard amount > 0 else {
                        print("❌ Invalid category amount found: \(amount)")
                        return false
                    }
                }
            }
            
            return true
        }
        
        return result ?? false
    }
    
    // MARK: - Data Retrieval Methods
    
    /// Get entries filtered by time period
    public func getEntries(for timePeriod: TimePeriod) async throws -> [BudgetEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredEntries = entries.filter { entry in
            switch timePeriod {
            case .thisWeek:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(entry.date, equalTo: now, toGranularity: .year)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return calendar.isDate(entry.date, equalTo: lastMonth, toGranularity: .month)
            case .lastYear:
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return calendar.isDate(entry.date, equalTo: lastYear, toGranularity: .year)
            case .allTime:
                return true
            }
        }
        
        return filteredEntries.sorted { $0.date > $1.date }
    }
    
    /// Get monthly budgets for a specific month/year
    public func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { $0.month == month && $0.year == year }
    }
    
    /// Get list of available categories
    public func getAvailableCategories() -> [String] {
        return categories
    }
    
    /// Get current data statistics
    public func getDataStatistics() -> DataStatistics? {
        return dataStatistics
    }
    
    // MARK: - Budget Management Methods
    
    /// Add a new monthly budget
    public func addMonthlyBudget(_ budget: MonthlyBudget) async throws {
        isLoading = true
        
        do {
            // Check if budget already exists for this month/year
            if monthlyBudgets.contains(where: { $0.month == budget.month && $0.year == budget.year }) {
                throw BudgetManagerError.invalidBudget("Budget already exists for \(budget.month)/\(budget.year)")
            }
            
            monthlyBudgets.append(budget)
            
            // Update categories
            for category in budget.categories.keys {
                if !categories.contains(category) {
                    categories.append(category)
                }
            }
            
            try await saveMonthlyBudgets()
            updateDataStatistics()
            
            print("✅ BudgetManager: Monthly budget added successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    /// Update category amount for a specific month/year
    public func updateCategoryAmount(category: String, amount: Double, month: Int, year: Int) async throws {
        isLoading = true
        
        do {
            guard amount > 0 else {
                throw BudgetManagerError.validationFailed("Amount must be greater than 0")
            }
            
            if let index = monthlyBudgets.firstIndex(where: { $0.month == month && $0.year == year }) {
                monthlyBudgets[index].categories[category] = amount
            } else {
                // Create new budget for this month
                let newBudget = MonthlyBudget(
                    id: UUID(),
                    month: month,
                    year: year,
                    categories: [category: amount]
                )
                monthlyBudgets.append(newBudget)
            }
            
            // Add category if not exists
            if !categories.contains(category) {
                categories.append(category)
            }
            
            try await saveMonthlyBudgets()
            updateDataStatistics()
            
            print("✅ BudgetManager: Category amount updated successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    /// Delete a category budget for a specific month/year
    public func deleteCategoryBudget(category: String, month: Int, year: Int) async throws {
        isLoading = true
        
        do {
            if let index = monthlyBudgets.firstIndex(where: { $0.month == month && $0.year == year }) {
                monthlyBudgets[index].categories.removeValue(forKey: category)
                
                // Remove budget entirely if no categories left
                if monthlyBudgets[index].categories.isEmpty {
                    monthlyBudgets.remove(at: index)
                }
                
                // Check if category should be removed from categories list
                let categoryStillExists = monthlyBudgets.contains { $0.categories.keys.contains(category) }
                if !categoryStillExists {
                    categories.removeAll { $0 == category }
                }
                
                try await saveMonthlyBudgets()
                updateDataStatistics()
                
                print("✅ BudgetManager: Category budget deleted successfully")
            }
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Data Management Methods
    
    /// Reset all stored data
    public func resetAllData() async throws {
        isLoading = true
        
        do {
            entries.removeAll()
            monthlyBudgets.removeAll()
            categories.removeAll()
            dataStatistics = nil
            overviewData = nil
            purchaseData.removeAll()
            historyData.removeAll()
            
            try await saveEntries()
            try await saveMonthlyBudgets()
            
            print("✅ BudgetManager: All data reset successfully")
            
        } catch {
            currentError = AppError.dataSave(underlying: error)
            throw BudgetManagerError.dataSaveFailed(error)
        }
        
        isLoading = false
    }
    
    /// Invalidate cache for testing
    public func invalidateCacheForTesting() {
        // Clear all cached data
        overviewData = nil
        purchaseData.removeAll()
        historyData.removeAll()
        dataStatistics = nil
        
        print("✅ BudgetManager: Cache invalidated for testing")
    }
}

