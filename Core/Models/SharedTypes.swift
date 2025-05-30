//
//  SharedTypes.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/17/24.
//

import SwiftUI
import Foundation
import Combine
import WidgetKit
import CoreData

// MARK: - Theme Manager
@MainActor
public final class ThemeManager: ObservableObject {
    // MARK: - Types
    public struct ColorOption: Identifiable, Hashable, Codable {
        public let id: UUID
        let name: String
        let colorComponents: ColorComponents
        
        var color: Color {
            Color(
                red: colorComponents.red,
                green: colorComponents.green,
                blue: colorComponents.blue,
                opacity: colorComponents.opacity
            )
        }
        
        init(name: String, color: Color) {
            self.id = UUID()
            self.name = name
            self.colorComponents = ColorComponents(from: color)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: ColorOption, rhs: ColorOption) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public struct ColorComponents: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
        
        init(from color: Color) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.opacity = Double(a)
        }
    }
    
    // MARK: - Constants
    public static let defaultPrimaryColor = ColorOption(name: "Blue", color: .blue)
    
    public static let availableColors: [ColorOption] = [
        ColorOption(name: "Blue", color: .blue),
        ColorOption(name: "Purple", color: .purple),
        ColorOption(name: "Green", color: .green),
        ColorOption(name: "Orange", color: .orange),
        ColorOption(name: "Pink", color: .pink),
        ColorOption(name: "Teal", color: .teal)
    ]
    
    // MARK: - Published Properties
    @Published public var primaryColor: Color {
        didSet {
            UserDefaults.standard.set(colorOption.name, forKey: "primaryColorName")
            updateGlobalAppearance()
        }
    }
    
    @Published public var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    // MARK: - Initialization
    public static let shared = ThemeManager()
    
    private init() {
        if let colorName = UserDefaults.standard.string(forKey: "primaryColorName"),
           let storedColor = ThemeManager.availableColors.first(where: { $0.name == colorName }) {
            self.primaryColor = storedColor.color
        } else {
            self.primaryColor = ThemeManager.defaultPrimaryColor.color
            UserDefaults.standard.set("Blue", forKey: "primaryColorName")
        }
        
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    // MARK: - Public Methods
    public func resetToDefaults() {
        primaryColor = ThemeManager.defaultPrimaryColor.color
        isDarkMode = false
    }
    
    public func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
    
    public func primaryGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func updateGlobalAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
    }
    
    private var colorOption: ColorOption {
        ThemeManager.availableColors.first { $0.color == primaryColor } ?? ThemeManager.defaultPrimaryColor
    }
}

// MARK: - Budget Manager
@MainActor
public final class BudgetManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var entries: [BudgetEntry] = []
    @Published private(set) var monthlyBudgets: [MonthlyBudget] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Dependencies
    private let coreDataManager: CoreDataManager
    private let calendar = Calendar.current
    private var dataRefreshTimer: Timer?
    private let dataRefreshInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Type Aliases for CSV Import
    public typealias PurchaseImportData = CSVImport.PurchaseImportData
    public typealias BudgetImportData = CSVImport.BudgetImportData
    public typealias ImportResults = CSVImport.ImportResults
    
    // MARK: - Error Types
    public enum BudgetManagerError: LocalizedError {
        case dataLoadFailed(Error)
        case entrySaveFailed(Error)
        case budgetSaveFailed(Error)
        case importFailed(Error)
        case invalidData(String)
        case categoryNotFound(String)
        case duplicateEntry
        
        public var errorDescription: String? {
            switch self {
            case .dataLoadFailed(let error):
                return "Failed to load data: \(error.localizedDescription)"
            case .entrySaveFailed(let error):
                return "Failed to save entry: \(error.localizedDescription)"
            case .budgetSaveFailed(let error):
                return "Failed to save budget: \(error.localizedDescription)"
            case .importFailed(let error):
                return "Failed to import data: \(error.localizedDescription)"
            case .invalidData(let message):
                return "Invalid data: \(message)"
            case .categoryNotFound(let category):
                return "Category not found: \(category)"
            case .duplicateEntry:
                return "Duplicate entry detected"
            }
        }
    }
    
    // MARK: - Initialization
    public static let shared = BudgetManager()
    
    private init() {
        self.coreDataManager = .shared
        setupDataRefreshTimer()
        
        Task {
            await loadInitialData()
            await checkAndUpdateMonthlyBudgets()
            await MainActor.run {
                updateRemainingBudget()
            }
        }
    }
    
    // MARK: - Data Loading & Refresh
    
    /// Load initial data on app startup
    private func loadInitialData() async {
        await setLoading(true)
        
        do {
            let (loadedEntries, loadedBudgets) = try await loadAllData()
            await MainActor.run {
                self.entries = loadedEntries
                self.monthlyBudgets = loadedBudgets
                self.lastSyncDate = Date()
                print("Successfully loaded \(loadedEntries.count) entries and \(loadedBudgets.count) budgets")
            }
        } catch {
            print("Failed to load initial data: \(error.localizedDescription)")
            // Don't throw error on initial load, just log it
        }
        
        await setLoading(false)
    }
    
    /// Public method to refresh data
    func loadData() {
        Task {
            await refreshData()
        }
    }
    
    /// Refresh data from Core Data
    private func refreshData() async {
        await setLoading(true)
        
        do {
            let (loadedEntries, loadedBudgets) = try await loadAllData()
            await MainActor.run {
                self.entries = loadedEntries
                self.monthlyBudgets = loadedBudgets
                self.lastSyncDate = Date()
                updateRemainingBudget()
            }
        } catch {
            print("Failed to refresh data: \(error.localizedDescription)")
        }
        
        await setLoading(false)
    }
    
    /// Load all data from Core Data
    private func loadAllData() async throws -> ([BudgetEntry], [MonthlyBudget]) {
        async let entriesResult = coreDataManager.getAllEntries()
        async let budgetsResult = coreDataManager.getAllMonthlyBudgets()
        
        do {
            let entries = try await entriesResult
            let budgets = try await budgetsResult
            return (entries, budgets)
        } catch {
            throw BudgetManagerError.dataLoadFailed(error)
        }
    }
    
    /// Set loading state on main actor
    private func setLoading(_ loading: Bool) async {
        await MainActor.run {
            self.isLoading = loading
        }
    }
    
    // MARK: - Auto-Refresh Timer
    
    private func setupDataRefreshTimer() {
        dataRefreshTimer = Timer.scheduledTimer(withTimeInterval: dataRefreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshData()
            }
        }
    }
    
    private nonisolated func invalidateDataRefreshTimer() {
        Task { @MainActor in
            dataRefreshTimer?.invalidate()
            dataRefreshTimer = nil
        }
    }
    
    // MARK: - Entry Management
    
    /// Get entries for a specific time period
    func getEntries(for timePeriod: TimePeriod) async throws -> [BudgetEntry] {
        let dateInterval = timePeriod.dateInterval()
        return entries.filter { entry in
            entry.date >= dateInterval.start && entry.date <= dateInterval.end
        }
    }
    
    /// Add a new budget entry with validation and persistence
    func addEntry(_ entry: BudgetEntry) async throws {
        // Validate entry
        try validateEntry(entry)
        
        // Check for duplicates
        if isDuplicateEntry(entry) {
            throw BudgetManagerError.duplicateEntry
        }
        
        do {
            // Save to Core Data
            try await coreDataManager.addEntry(entry)
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Update local state
            await MainActor.run {
                self.entries.append(entry)
                self.entries.sort { $0.date > $1.date } // Keep sorted by date descending
                self.objectWillChange.send()
                updateRemainingBudget()
                print("Successfully added entry: \(entry.category) - \(entry.amount.asCurrency)")
            }
        } catch {
            throw BudgetManagerError.entrySaveFailed(error)
        }
    }
    
    /// Update an existing budget entry
    func updateEntry(_ entry: BudgetEntry) async throws {
        // Validate entry
        try validateEntry(entry)
        
        do {
            // Save to Core Data
            try await coreDataManager.updateEntry(entry)
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Update local state
            await MainActor.run {
                if let index = self.entries.firstIndex(where: { $0.id == entry.id }) {
                    self.entries[index] = entry
                    self.entries.sort { $0.date > $1.date } // Keep sorted
                    self.objectWillChange.send()
                    updateRemainingBudget()
                    print("Successfully updated entry: \(entry.category) - \(entry.amount.asCurrency)")
                }
            }
        } catch {
            throw BudgetManagerError.entrySaveFailed(error)
        }
    }
    
    /// Delete a budget entry
    func deleteEntry(_ entry: BudgetEntry) async throws {
        do {
            // Delete from Core Data
            try await coreDataManager.deleteEntry(entry)
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Update local state
            await MainActor.run {
                self.entries.removeAll { $0.id == entry.id }
                self.objectWillChange.send()
                updateRemainingBudget()
                print("Successfully deleted entry: \(entry.category) - \(entry.amount.asCurrency)")
            }
        } catch {
            throw BudgetManagerError.entrySaveFailed(error)
        }
    }
    
    /// Validate entry data
    private func validateEntry(_ entry: BudgetEntry) throws {
        if entry.amount <= 0 {
            throw BudgetManagerError.invalidData("Amount must be greater than zero")
        }
        
        if entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BudgetManagerError.invalidData("Category cannot be empty")
        }
        
        if entry.date > Date() {
            throw BudgetManagerError.invalidData("Date cannot be in the future")
        }
        
        if entry.amount > AppConstants.Validation.maximumTransactionAmount {
            throw BudgetManagerError.invalidData("Amount exceeds maximum allowed")
        }
    }
    
    /// Check if entry is a duplicate (same amount, category, and date within 1 minute)
    private func isDuplicateEntry(_ entry: BudgetEntry) -> Bool {
        return entries.contains { existingEntry in
            existingEntry.amount == entry.amount &&
            existingEntry.category == entry.category &&
            abs(existingEntry.date.timeIntervalSince(entry.date)) < 60 // Within 1 minute
        }
    }
    
    // MARK: - Budget Management
    
    /// Get current month's total budget
    func getCurrentMonthBudget() -> Double {
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        return getMonthlyBudgets(for: month, year: year)
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Get current month's spent amount
    func getCurrentMonthSpent() -> Double {
        return entries
            .filter { $0.date.isInCurrentMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Get remaining budget for current month
    func getCurrentMonthRemaining() -> Double {
        return getCurrentMonthBudget() - getCurrentMonthSpent()
    }
    
    /// Get monthly budgets for specific month and year
    func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { budget in
            budget.month == month && budget.year == year
        }
    }
    
    /// Update monthly budgets for a specific month
    func updateMonthlyBudgets(_ budgets: [String: Double], for month: Int, year: Int) async throws {
        do {
            // Validate budget data
            for (category, amount) in budgets {
                if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw BudgetManagerError.invalidData("Category name cannot be empty")
                }
                if amount < 0 {
                    throw BudgetManagerError.invalidData("Budget amount cannot be negative")
                }
                if amount > AppConstants.Validation.maximumTransactionAmount {
                    throw BudgetManagerError.invalidData("Budget amount exceeds maximum allowed")
                }
            }
            
            // Save each budget
            for (category, amount) in budgets {
                let budget = try MonthlyBudget(
                    category: category,
                    amount: amount,
                    month: month,
                    year: year
                )
                try await coreDataManager.addOrUpdateMonthlyBudget(budget)
            }
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Refresh data
            await refreshData()
            
            print("Successfully updated budgets for \(month)/\(year)")
        } catch {
            throw BudgetManagerError.budgetSaveFailed(error)
        }
    }
    
    /// Add a new category with budget amount
    func addCategory(_ category: String, amount: Double, month: Int, year: Int, includeFutureMonths: Bool) async throws {
        // Validate input
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCategory.isEmpty {
            throw BudgetManagerError.invalidData("Category name cannot be empty")
        }
        
        if amount <= 0 {
            throw BudgetManagerError.invalidData("Budget amount must be greater than zero")
        }
        
        if amount > AppConstants.Validation.maximumTransactionAmount {
            throw BudgetManagerError.invalidData("Budget amount exceeds maximum allowed")
        }
        
        do {
            if includeFutureMonths {
                // Add to all future months in the year
                for m in month...12 {
                    let budget = try MonthlyBudget(
                        category: trimmedCategory,
                        amount: amount,
                        month: m,
                        year: year
                    )
                    try await coreDataManager.addOrUpdateMonthlyBudget(budget)
                }
            } else {
                // Add to specific month only
                let budget = try MonthlyBudget(
                    category: trimmedCategory,
                    amount: amount,
                    month: month,
                    year: year
                )
                try await coreDataManager.addOrUpdateMonthlyBudget(budget)
            }
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Refresh data
            await refreshData()
            
            print("Successfully added category: \(trimmedCategory) with amount: \(amount.asCurrency)")
        } catch {
            throw BudgetManagerError.budgetSaveFailed(error)
        }
    }
    
    /// Delete monthly budget category
    func deleteMonthlyBudget(category: String, fromMonth: Int, year: Int, includeFutureMonths: Bool) async throws {
        do {
            try await coreDataManager.deleteMonthlyBudget(
                category: category,
                fromMonth: fromMonth,
                year: year,
                includeFutureMonths: includeFutureMonths
            )
            
            // Force save to ensure persistence
            try await coreDataManager.forceSave()
            
            // Refresh data
            await refreshData()
            
            print("Successfully deleted category: \(category)")
        } catch {
            throw BudgetManagerError.budgetSaveFailed(error)
        }
    }
    
    /// Get available categories for current month
    func getAvailableCategories() -> [String] {
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let currentBudgets = getMonthlyBudgets(for: currentMonth, year: currentYear)
        
        let budgetCategories = Set(currentBudgets.map { $0.category })
        let transactionCategories = Set(entries.map { $0.category })
        
        // Combine both sets and add default categories
        var allCategories = budgetCategories.union(transactionCategories)
        allCategories.insert("Uncategorized") // Always include uncategorized
        
        return Array(allCategories).sorted()
    }
    
    /// Get spending by category for current month
    func getCurrentMonthSpendingByCategory() -> [String: Double] {
        let currentMonthEntries = entries.filter { $0.date.isInCurrentMonth }
        return Dictionary(grouping: currentMonthEntries, by: { $0.category })
            .mapValues { entries in
                entries.reduce(0) { $0 + $1.amount }
            }
    }
    
    // MARK: - CSV Import Methods
    
    /// Import purchases from CSV file
    public func importPurchases(from url: URL) async throws -> CSVImport.ImportResults<CSVImport.PurchaseImportData> {
        let existingCategories = getAvailableCategories()
        do {
            return try await CSVImport.importPurchases(from: url, existingCategories: existingCategories)
        } catch {
            throw BudgetManagerError.importFailed(error)
        }
    }
    
    /// Import budgets from CSV file
    public func importBudgets(from url: URL) async throws -> CSVImport.ImportResults<CSVImport.BudgetImportData> {
        let existingCategories = getAvailableCategories()
        do {
            return try await CSVImport.importBudgets(from: url, existingCategories: existingCategories)
        } catch {
            throw BudgetManagerError.importFailed(error)
        }
    }
    
    /// Process and save imported purchase data with category mappings
    public func processImportedPurchases(
        _ importResults: CSVImport.ImportResults<CSVImport.PurchaseImportData>,
        categoryMappings: [String: String]
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var successCount = 0
        var errorCount = 0
        
        for purchaseData in importResults.data {
            do {
                guard let date = dateFormatter.date(from: purchaseData.date) else {
                    throw BudgetManagerError.invalidData("Invalid date format: \(purchaseData.date)")
                }
                
                let mappedCategory = categoryMappings[purchaseData.category] ?? purchaseData.category
                
                let entry = try BudgetEntry(
                    amount: purchaseData.amount,
                    category: mappedCategory,
                    date: date,
                    note: purchaseData.note
                )
                
                try await addEntry(entry)
                successCount += 1
            } catch {
                print("Failed to import purchase: \(error.localizedDescription)")
                errorCount += 1
            }
        }
        
        print("Import completed: \(successCount) successful, \(errorCount) failed")
        
        if errorCount > 0 && successCount == 0 {
            throw BudgetManagerError.importFailed(NSError(domain: "ImportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to import any purchases"]))
        }
    }
    
    /// Process and save imported budget data
    public func processImportedBudgets(
        _ importResults: CSVImport.ImportResults<CSVImport.BudgetImportData>
    ) async throws {
        var successCount = 0
        var errorCount = 0
        
        for budgetData in importResults.data {
            do {
                let budget = try MonthlyBudget(
                    category: budgetData.category,
                    amount: budgetData.amount,
                    month: budgetData.month,
                    year: budgetData.year,
                    isHistorical: budgetData.isHistorical
                )
                
                try await coreDataManager.addOrUpdateMonthlyBudget(budget)
                successCount += 1
            } catch {
                print("Failed to import budget: \(error.localizedDescription)")
                errorCount += 1
            }
        }
        
        if successCount > 0 {
            // Force save and refresh data
            try await coreDataManager.forceSave()
            await refreshData()
        }
        
        print("Budget import completed: \(successCount) successful, \(errorCount) failed")
        
        if errorCount > 0 && successCount == 0 {
            throw BudgetManagerError.importFailed(NSError(domain: "ImportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to import any budgets"]))
        }
    }
    
    /// Legacy method for backward compatibility
    public func processMappedImport(
        data: [CSVImport.PurchaseImportData],
        categoryMappings: [String: String]
    ) async {
        let importResults = CSVImport.ImportResults(
            data: data,
            categories: Set(data.map { $0.category }),
            existingCategories: Set(getAvailableCategories()),
            newCategories: Set(),
            totalAmount: data.reduce(0) { $0 + $1.amount }
        )
        
        do {
            try await processImportedPurchases(importResults, categoryMappings: categoryMappings)
        } catch {
            print("Failed to process imported purchases: \(error)")
        }
    }
    
    // MARK: - Data Management
    
    /// Reset all data with confirmation
    func resetAllData() async throws {
        do {
            try await coreDataManager.deleteAllData()
            
            await MainActor.run {
                self.entries = []
                self.monthlyBudgets = []
                self.lastSyncDate = nil
                self.objectWillChange.send()
                updateRemainingBudget()
            }
            
            print("Successfully reset all data")
        } catch {
            throw BudgetManagerError.dataLoadFailed(error)
        }
    }
    
    /// Export all data for backup
    func exportAllData() -> (entries: [BudgetEntry], budgets: [MonthlyBudget]) {
        return (entries: entries, budgets: monthlyBudgets)
    }
    
    /// Get data statistics
    func getDataStatistics() -> (entryCount: Int, budgetCount: Int, totalSpent: Double, oldestEntry: Date?, newestEntry: Date?) {
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let oldestEntry = entries.min(by: { $0.date < $1.date })?.date
        let newestEntry = entries.max(by: { $0.date < $1.date })?.date
        
        return (
            entryCount: entries.count,
            budgetCount: monthlyBudgets.count,
            totalSpent: totalSpent,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry
        )
    }
    
    // MARK: - Widget Support
    private func updateRemainingBudget() {
        let currentMonthBudget = getCurrentMonthBudget()
        let currentMonthSpent = getCurrentMonthSpent()
        let remaining = currentMonthBudget - currentMonthSpent
        
        SharedDataManager.shared.setMonthlyBudget(currentMonthBudget)
        SharedDataManager.shared.setRemainingBudget(remaining)
    }
    
    /// Force update widget data
    func updateWidgetData() {
        updateRemainingBudget()
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Private Helper Methods
    
    private func checkAndUpdateMonthlyBudgets() async {
        // Check if we need to create default budgets for current month
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let currentBudgets = getMonthlyBudgets(for: currentMonth, year: currentYear)
        
        if currentBudgets.isEmpty {
            // Create default "Uncategorized" budget if none exist
            do {
                try await addCategory("Uncategorized", amount: 1000, month: currentMonth, year: currentYear, includeFutureMonths: false)
            } catch {
                print("Failed to create default budget: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        invalidateDataRefreshTimer()
    }
}

// MARK: - Import Error Types
public extension BudgetManager {
    enum BudgetImportError: LocalizedError {
        case invalidFile
        case invalidFormat
        case parsingError
        case invalidDateFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The selected file is invalid"
            case .invalidFormat:
                return "The budget data format is incorrect"
            case .parsingError:
                return "Unable to parse the budget data"
            case .invalidDateFormat:
                return "Invalid date format in the budget data"
            }
        }
    }
    
    enum PurchaseImportError: LocalizedError {
        case invalidFile
        case invalidFormat
        case parsingError
        case invalidDateFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The selected file is invalid"
            case .invalidFormat:
                return "The purchase data format is incorrect"
            case .parsingError:
                return "Unable to parse the purchase data"
            case .invalidDateFormat:
                return "Invalid date format in the purchase data"
            }
        }
    }
}

// MARK: - Sort Options
public enum BudgetSortOption: String, CaseIterable {
    case category = "Category"
    case budgetedAmount = "Budgeted Amount"
    case amountSpent = "Amount Spent"
    case date = "Date"
    case amount = "Amount"
}

// MARK: - Filter Options
public enum FilterType: String, CaseIterable {
    case all = "All"
    case category = "Category"
    case date = "Date"
    case amount = "Amount"
}

// MARK: - Sort Direction
public enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
}

// MARK: - View Type Options
public enum ViewType: String, CaseIterable {
    case list = "List"
    case chart = "Chart"
    case summary = "Summary"
}

// MARK: - Budget Category Type
public enum BudgetCategoryType: String, CaseIterable {
    case expense = "Expense"
    case income = "Income"
    case savings = "Savings"
}

// MARK: - Chart Type
public enum ChartType: String, CaseIterable {
    case pie = "Pie"
    case bar = "Bar"
    case line = "Line"
}

// MARK: - Date Range Type
public enum DateRangeType: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case custom = "Custom"
}

// MARK: - Transaction Status
public enum TransactionStatus: String, Codable {
    case pending = "Pending"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

// MARK: - Time Period
public enum TimePeriod: Equatable, Hashable, Codable, Sendable {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case last7Days
    case last30Days
    case last12Months
    case allTime
    case custom(Date, Date)
    
    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last12Months: return "Last 12 Months"
        case .allTime: return "All Time"
        case .custom: return "Custom Range"
        }
    }
    
    public func dateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )!
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            )!
            return DateInterval(start: startOfMonth, end: now)
        case .thisYear:
            let startOfYear = calendar.date(
                from: calendar.dateComponents([.year], from: now)
            )!
            return DateInterval(start: startOfYear, end: now)
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return DateInterval(start: sevenDaysAgo, end: now)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            return DateInterval(start: thirtyDaysAgo, end: now)
        case .last12Months:
            let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now)!
            return DateInterval(start: twelveMonthsAgo, end: now)
        case .allTime:
            return DateInterval(start: .distantPast, end: now)
        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
    
    static var allCases: [TimePeriod] {
        [
            .today,
            .thisWeek,
            .thisMonth,
            .thisYear,
            .last7Days,
            .last30Days,
            .last12Months,
            .allTime,
            .custom(Date(), Date())
        ]
    }
}

// MARK: - Shared Data Manager
final class SharedDataManager {
    // MARK: - Singleton
    static let shared = SharedDataManager()
    
    // MARK: - Constants
    private enum Keys {
        static let remainingBudget = "remainingBudget"
        static let monthlyBudget = "monthlyBudget"
        static let suiteName = "group.com.brandontitensor.BrandonsBudget"
    }
    
    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    
    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: Keys.suiteName)
    }
    
    // MARK: - Public Methods
    func setRemainingBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.remainingBudget)
    }
    
    func getRemainingBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.remainingBudget) ?? 0.0
    }
    
    func setMonthlyBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.monthlyBudget)
    }
    
    func getMonthlyBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.monthlyBudget) ?? 0.0
    }
    
    func resetData() {
        setRemainingBudget(0.0)
        setMonthlyBudget(0.0)
    }
}

// MARK: - Year Picker View
/// A reusable view for selecting years with validation and proper range handling
struct YearPickerView: View {
    // MARK: - Properties
    @Binding var selectedYear: Int
    let onDismiss: () -> Void
    let onYearSelected: (Int) -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constants
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let yearRange: ClosedRange<Int>
    
    // MARK: - Initialization
    init(
        selectedYear: Binding<Int>,
        onDismiss: @escaping () -> Void,
        onYearSelected: @escaping (Int) -> Void,
        numberOfPastYears: Int = 5,
        numberOfFutureYears: Int = 5
    ) {
        self._selectedYear = selectedYear
        self.onDismiss = onDismiss
        self.onYearSelected = onYearSelected
        
        // Calculate year range
        self.yearRange = (currentYear - numberOfPastYears)...(currentYear + numberOfFutureYears)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(yearRange, id: \.self) { year in
                        yearRow(for: year)
                    }
                } footer: {
                    Text("Showing years from \(yearRange.lowerBound) to \(yearRange.upperBound)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Select Year")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") {
                    onYearSelected(selectedYear)
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - View Components
    private func yearRow(for year: Int) -> some View {
        Button(action: { selectYear(year) }) {
            HStack {
                Text(String(year))
                    .foregroundColor(.primary)
                Spacer()
                if year == selectedYear {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                if year == currentYear {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel(for: year))
        .accessibilityAddTraits(year == selectedYear ? [.isSelected] : [])
    }
    
    // MARK: - Helper Methods
    private func selectYear(_ year: Int) {
        selectedYear = year
    }
    
    private func createAccessibilityLabel(for year: Int) -> String {
        var label = String(year)
        if year == currentYear {
            label += ", current year"
        }
        if year == selectedYear {
            label += ", selected"
        }
        return label
    }
}

// MARK: - Data Validation Utilities
public struct DataValidator {
    /// Validate a budget entry
    public static func validateBudgetEntry(_ entry: BudgetEntry) throws {
        if entry.amount <= 0 {
            throw ValidationError.invalidAmount("Amount must be greater than zero")
        }
        
        if entry.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalidCategory("Category cannot be empty")
        }
        
        if entry.date > Date() {
            throw ValidationError.invalidDate("Date cannot be in the future")
        }
        
        if entry.amount > AppConstants.Validation.maximumTransactionAmount {
            throw ValidationError.invalidAmount("Amount exceeds maximum allowed")
        }
    }
    
    /// Validate a monthly budget
    public static func validateMonthlyBudget(_ budget: MonthlyBudget) throws {
        if budget.amount < 0 {
            throw ValidationError.invalidAmount("Budget amount cannot be negative")
        }
        
        if budget.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalidCategory("Category cannot be empty")
        }
        
        if budget.month < 1 || budget.month > 12 {
            throw ValidationError.invalidDate("Month must be between 1 and 12")
        }
        
        if budget.year < 1900 || budget.year > 9999 {
            throw ValidationError.invalidDate("Invalid year")
        }
    }
    
    /// Validation error types
    public enum ValidationError: LocalizedError {
        case invalidAmount(String)
        case invalidCategory(String)
        case invalidDate(String)
        case invalidData(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidAmount(let message): return "Invalid amount: \(message)"
            case .invalidCategory(let message): return "Invalid category: \(message)"
            case .invalidDate(let message): return "Invalid date: \(message)"
            case .invalidData(let message): return "Invalid data: \(message)"
            }
        }
    }
}

// MARK: - Performance Monitoring
public class PerformanceMonitor {
    private static var startTimes: [String: Date] = [:]
    
    /// Start timing an operation
    public static func startTiming(_ operation: String) {
        startTimes[operation] = Date()
    }
    
    /// End timing an operation and return duration
    public static func endTiming(_ operation: String) -> TimeInterval? {
        guard let startTime = startTimes[operation] else { return nil }
        let duration = Date().timeIntervalSince(startTime)
        startTimes.removeValue(forKey: operation)
        
        #if DEBUG
        print("⏱️ \(operation) took \(String(format: "%.2f", duration * 1000))ms")
        #endif
        
        return duration
    }
    
    /// Measure execution time of a closure
    public static func measure<T>(_ operation: String, _ closure: () throws -> T) rethrows -> T {
        startTiming(operation)
        defer { _ = endTiming(operation) }
        return try closure()
    }
    
    /// Measure execution time of an async closure
    public static func measureAsync<T>(_ operation: String, _ closure: () async throws -> T) async rethrows -> T {
        startTiming(operation)
        defer { _ = endTiming(operation) }
        return try await closure()
    }
}

// MARK: - App State Monitoring
public class AppStateMonitor: ObservableObject {
    @Published public var isActive = true
    @Published public var isInBackground = false
    @Published public var hasUnsavedChanges = false
    
    public static let shared = AppStateMonitor()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = true
            self.isInBackground = false
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = false
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isInBackground = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Testing Support
#if DEBUG
extension SharedDataManager {
    static func createMock() -> SharedDataManager {
        return SharedDataManager()
    }
}

extension ThemeManager {
    static func createMock() -> ThemeManager {
        return ThemeManager()
    }
}

extension BudgetManager {
    static func createMock() -> BudgetManager {
        return BudgetManager()
    }
    
    /// Create test data for previews
    func loadTestData() {
        Task {
            // Add test entries
            let testEntries = [
                try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date()),
                try! BudgetEntry(amount: 25.00, category: "Transportation", date: Date().adding(days: -1)),
                try! BudgetEntry(amount: 15.99, category: "Entertainment", date: Date().adding(days: -2))
            ]
            
            await MainActor.run {
                self.entries = testEntries
            }
            
            // Add test budgets
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())
            
            let testBudgets = [
                try! MonthlyBudget(category: "Groceries", amount: 500, month: currentMonth, year: currentYear),
                try! MonthlyBudget(category: "Transportation", amount: 200, month: currentMonth, year: currentYear),
                try! MonthlyBudget(category: "Entertainment", amount: 150, month: currentMonth, year: currentYear)
            ]
            
            await MainActor.run {
                self.monthlyBudgets = testBudgets
                updateRemainingBudget()
            }
        }
    }
}
#endif

// MARK: - Preview Provider
#if DEBUG
struct YearPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Current year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date())),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Current Year")
            
            // Past year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date()) - 2),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Past Year")
            
            // Future year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date()) + 2),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Future Year")
            
            // Dark mode
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date())),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
