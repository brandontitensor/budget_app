//
//  BudgetManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 5/30/25 - Enhanced with centralized error handling and improved performance
//

import Foundation
import Combine
import SwiftUI

/// Manages budget data operations with proper error handling, validation, and state management
@MainActor
public final class BudgetManager: ObservableObject {
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
        public let dataIntegrityScore: Double // 0.0 to 1.0
        
        public var summary: String {
            return "Entries: \(entryCount), Budgets: \(budgetCount), Categories: \(categoryCount)"
        }
        
        public var healthStatus: HealthStatus {
            if dataIntegrityScore >= 0.9 { return .excellent }
            if dataIntegrityScore >= 0.7 { return .good }
            if dataIntegrityScore >= 0.5 { return .fair }
            return .poor
        }
        
        public enum HealthStatus: String, CaseIterable {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case poor = "Poor"
            
            var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return .blue
                case .fair: return .orange
                case .poor: return .red
                }
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = BudgetManager()
    
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
    private let operationQueue = DispatchQueue(label: "com.brandonsbudget.budgetmanager", qos: .userInitiated)
    private var dataValidationTimer: Timer?
    private let widgetUpdateDebouncer = Debouncer(delay: 1.0)
    
    // MARK: - Cache Properties
    private var categoryCache: Set<String> = []
    private var budgetCache: [String: Double] = [:]
    private var statisticsCache: DataStatistics?
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Initialization
    private init() {
        setupDataValidationTimer()
        setupCoreDataObserver()
        
        #if DEBUG
        setupPerformanceMonitoring()
        #endif
    }
    
    // MARK: - Public Data Access Methods
    
    /// Get all budget entries with optional filtering
    public func getEntries(
        for timePeriod: TimePeriod? = nil,
        category: String? = nil,
        sortedBy sortOption: BudgetSortOption = .date,
        ascending: Bool = false
    ) async throws -> [BudgetEntry] {
        let startTime = Date()
        
        do {
            let allEntries = try await coreDataManager.getAllEntries()
            var filteredEntries = allEntries
            
            // Apply time period filter
            if let timePeriod = timePeriod {
                let interval = timePeriod.dateInterval()
                filteredEntries = filteredEntries.filter { entry in
                    entry.date >= interval.start && entry.date <= interval.end
                }
            }
            
            // Apply category filter
            if let category = category {
                filteredEntries = filteredEntries.filter { $0.category == category }
            }
            
            // Apply sorting
            filteredEntries = sortEntries(filteredEntries, by: sortOption, ascending: ascending)
            
            recordMetric("getEntries", duration: Date().timeIntervalSince(startTime))
            return filteredEntries
            
        } catch {
            throw AppError.dataLoad(underlying: error)
        }
    }
    
    /// Get monthly budgets for a specific period
    public func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { $0.month == month && $0.year == year }
    }
    
    /// Get all available categories
    public func getAvailableCategories() -> [String] {
        if isCacheValid() && !categoryCache.isEmpty {
            return Array(categoryCache).sorted()
        }
        
        let entryCategories = Set(entries.map { $0.category })
        let budgetCategories = Set(monthlyBudgets.map { $0.category })
        let allCategories = entryCategories.union(budgetCategories)
        
        categoryCache = allCategories
        return Array(allCategories).sorted()
    }
    
    /// Get current month's total budget
    public func getCurrentMonthBudget() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        let cacheKey = "\(currentYear)-\(currentMonth)"
        if let cachedBudget = budgetCache[cacheKey], isCacheValid() {
            return cachedBudget
        }
        
        let total = getMonthlyBudgets(for: currentMonth, year: currentYear)
            .reduce(0) { $0 + $1.amount }
        
        budgetCache[cacheKey] = total
        return total
    }
    
    /// Get data statistics with performance metrics
    public func getDataStatistics() -> DataStatistics {
        if let cached = statisticsCache, isCacheValid() {
            return cached
        }
        
        let startTime = Date()
        
        let entryCount = entries.count
        let budgetCount = monthlyBudgets.count
        let categoryCount = getAvailableCategories().count
        let totalSpent = entries.reduce(0) { $0 + $1.amount }
        let totalBudgeted = monthlyBudgets.reduce(0) { $0 + $1.amount }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let oldestEntry = sortedEntries.first?.date
        let newestEntry = sortedEntries.last?.date
        
        // Calculate data integrity score
        let integrityScore = calculateDataIntegrityScore()
        
        let statistics = DataStatistics(
            entryCount: entryCount,
            budgetCount: budgetCount,
            categoryCount: categoryCount,
            totalSpent: totalSpent,
            totalBudgeted: totalBudgeted,
            oldestEntry: oldestEntry,
            newestEntry: newestEntry,
            dataIntegrityScore: integrityScore
        )
        
        statisticsCache = statistics
        recordMetric("getDataStatistics", duration: Date().timeIntervalSince(startTime))
        
        return statistics
    }
    
    // MARK: - Data Modification Methods
    
    /// Add a new budget entry with validation
    public func addEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate entry
            try validateEntry(entry)
            
            // Check for duplicates
            if await hasDuplicateEntry(entry) {
                throw AppError.validation(message: "A similar entry already exists")
            }
            
            // Add to Core Data
            try await coreDataManager.addEntry(entry)
            
            // Update local cache
            await MainActor.run {
                entries.append(entry)
                entries.sort { $0.date > $1.date }
                invalidateCache()
                updateWidgetData()
            }
            
            recordMetric("addEntry", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Added entry - \(entry.category): \(entry.amount.asCurrency)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Adding budget entry")
            throw appError
        }
    }
    
    /// Update an existing budget entry
    public func updateEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate entry
            try validateEntry(entry)
            
            // Update in Core Data
            try await coreDataManager.updateEntry(entry)
            
            // Update local cache
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[index] = entry
                    entries.sort { $0.date > $1.date }
                    invalidateCache()
                    updateWidgetData()
                } else {
                    throw BudgetManagerError.categoryNotFound
                }
            }
            
            recordMetric("updateEntry", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Updated entry - \(entry.category): \(entry.amount.asCurrency)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Updating budget entry")
            throw appError
        }
    }
    
    /// Delete a budget entry
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete from Core Data
            try await coreDataManager.deleteEntry(entry)
            
            // Update local cache
            await MainActor.run {
                entries.removeAll { $0.id == entry.id }
                invalidateCache()
                updateWidgetData()
            }
            
            recordMetric("deleteEntry", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Deleted entry - \(entry.category): \(entry.amount.asCurrency)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Deleting budget entry")
            throw appError
        }
    }
    
    // MARK: - Monthly Budget Methods
    
    /// Add or update a monthly budget
    public func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate budget
            try validateMonthlyBudget(budget)
            
            // Add to Core Data
            try await coreDataManager.addOrUpdateMonthlyBudget(budget)
            
            // Update local cache
            await MainActor.run {
                // Remove existing budget for same category/month/year
                monthlyBudgets.removeAll { 
                    $0.category == budget.category && 
                    $0.month == budget.month && 
                    $0.year == budget.year 
                }
                
                monthlyBudgets.append(budget)
                monthlyBudgets.sort { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
                invalidateCache()
            }
            
            recordMetric("addOrUpdateMonthlyBudget", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Updated monthly budget - \(budget.category): \(budget.amount.asCurrency)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Adding/updating monthly budget")
            throw appError
        }
    }
    
    /// Add a new category with optional budget for future months
    public func addCategory(
        _ name: String,
        amount: Double,
        month: Int,
        year: Int,
        includeFutureMonths: Bool = false
    ) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate category name
            guard !trimmedName.isEmpty else {
                throw AppError.validation(message: "Category name cannot be empty")
            }
            
            guard trimmedName.count <= AppConstants.Validation.maxCategoryNameLength else {
                throw AppError.validation(message: "Category name is too long")
            }
            
            // Validate amount
            guard amount > 0 && amount <= AppConstants.Validation.maximumTransactionAmount else {
                throw AppError.validation(message: "Invalid budget amount")
            }
            
            // Create budgets for specified months
            var budgetsToAdd: [MonthlyBudget] = []
            
            if includeFutureMonths {
                for futureMonth in month...12 {
                    let budget = try MonthlyBudget(
                        category: trimmedName,
                        amount: amount,
                        month: futureMonth,
                        year: year
                    )
                    budgetsToAdd.append(budget)
                }
            } else {
                let budget = try MonthlyBudget(
                    category: trimmedName,
                    amount: amount,
                    month: month,
                    year: year
                )
                budgetsToAdd.append(budget)
            }
            
            // Add all budgets
            for budget in budgetsToAdd {
                try await addOrUpdateMonthlyBudget(budget)
            }
            
            recordMetric("addCategory", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Added category '\(trimmedName)' with \(budgetsToAdd.count) budget(s)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Adding new category")
            throw appError
        }
    }
    
    /// Delete monthly budgets for a category
    public func deleteMonthlyBudget(
        category: String,
        fromMonth: Int,
        year: Int,
        includeFutureMonths: Bool = false
    ) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete from Core Data
            try await coreDataManager.deleteMonthlyBudget(
                category: category,
                fromMonth: fromMonth,
                year: year,
                includeFutureMonths: includeFutureMonths
            )
            
            // Update local cache
            await MainActor.run {
                if includeFutureMonths {
                    monthlyBudgets.removeAll { budget in
                        budget.category == category &&
                        budget.year == year &&
                        budget.month >= fromMonth
                    }
                } else {
                    monthlyBudgets.removeAll { budget in
                        budget.category == category &&
                        budget.year == year &&
                        budget.month == fromMonth
                    }
                }
                invalidateCache()
            }
            
            recordMetric("deleteMonthlyBudget", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Deleted monthly budget for '\(category)'")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Deleting monthly budget")
            throw appError
        }
    }
    
    /// Update multiple monthly budgets for a specific month and year
    public func updateMonthlyBudgets(
        _ budgets: [String: Double],
        for month: Int,
        year: Int
    ) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            for (category, amount) in budgets {
                if amount > 0 {
                    let budget = try MonthlyBudget(
                        category: category,
                        amount: amount,
                        month: month,
                        year: year
                    )
                    try await addOrUpdateMonthlyBudget(budget)
                } else {
                    // Delete budget if amount is 0
                    try await deleteMonthlyBudget(
                        category: category,
                        fromMonth: month,
                        year: year,
                        includeFutureMonths: false
                    )
                }
            }
            
            recordMetric("updateMonthlyBudgets", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Updated \(budgets.count) monthly budgets for \(month)/\(year)")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Updating monthly budgets")
            throw appError
        }
    }
    
    // MARK: - Import/Export Methods
    
    /// Import budget entries from CSV import results
    public func processImportedPurchases(
        _ importResults: CSVImport.ImportResults<CSVImport.PurchaseImportData>,
        categoryMappings: [String: String] = [:]
    ) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            let dateFormatter = DateFormatter()
            var importedCount = 0
            var errors: [String] = []
            
            for purchaseData in importResults.data {
                do {
                    // Apply category mapping if provided
                    let mappedCategory = categoryMappings[purchaseData.category] ?? purchaseData.category
                    
                    // Try different date formats
                    var parsedDate: Date?
                    for dateFormat in ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy"] {
                        dateFormatter.dateFormat = dateFormat
                        if let date = dateFormatter.date(from: purchaseData.date) {
                            parsedDate = date
                            break
                        }
                    }
                    
                    guard let date = parsedDate else {
                        errors.append("Invalid date format: \(purchaseData.date)")
                        continue
                    }
                    
                    let entry = try BudgetEntry(
                        amount: purchaseData.amount,
                        category: mappedCategory,
                        date: date,
                        note: purchaseData.note
                    )
                    
                    try await addEntry(entry)
                    importedCount += 1
                    
                } catch {
                    errors.append("Failed to import purchase: \(error.localizedDescription)")
                }
            }
            
            recordMetric("processImportedPurchases", duration: Date().timeIntervalSince(startTime))
            
            if !errors.isEmpty {
                let errorMessage = "Import completed with \(errors.count) errors: \(errors.joined(separator: ", "))"
                throw AppError.csvImport(underlying: NSError(
                    domain: "BudgetManager",
                    code: 3001,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                ))
            }
            
            print("✅ BudgetManager: Imported \(importedCount) purchases successfully")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Processing imported purchases")
            throw appError
        }
    }
    
    /// Import monthly budgets from CSV import results
    public func processImportedBudgets(
        _ importResults: CSVImport.ImportResults<CSVImport.BudgetImportData>
    ) async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            var importedCount = 0
            var errors: [String] = []
            
            for budgetData in importResults.data {
                do {
                    let budget = try budgetData.toMonthlyBudget()
                    try await addOrUpdateMonthlyBudget(budget)
                    importedCount += 1
                } catch {
                    errors.append("Failed to import budget: \(error.localizedDescription)")
                }
            }
            
            recordMetric("processImportedBudgets", duration: Date().timeIntervalSince(startTime))
            
            if !errors.isEmpty {
                let errorMessage = "Import completed with \(errors.count) errors: \(errors.joined(separator: ", "))"
                throw AppError.csvImport(underlying: NSError(
                    domain: "BudgetManager",
                    code: 3002,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                ))
            }
            
            print("✅ BudgetManager: Imported \(importedCount) budgets successfully")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Processing imported budgets")
            throw appError
        }
    }
    
    // MARK: - Data Loading and Management
    
    /// Load all data from Core Data
    public func loadData() {
        Task {
            await loadDataAsync()
        }
    }
    
    private func loadDataAsync() async {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let entriesTask = coreDataManager.getAllEntries()
            async let budgetsTask = coreDataManager.getAllMonthlyBudgets()
            
            let (loadedEntries, loadedBudgets) = try await (entriesTask, budgetsTask)
            
            await MainActor.run {
                entries = loadedEntries.sorted { $0.date > $1.date }
                monthlyBudgets = loadedBudgets.sorted { 
                    $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) 
                }
                lastSyncDate = Date()
                invalidateCache()
                
                // Update statistics
                dataStatistics = getDataStatistics()
            }
            
            recordMetric("loadData", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Loaded \(entries.count) entries and \(monthlyBudgets.count) budgets")
            
        } catch {
            await MainActor.run {
                let appError = AppError.dataLoad(underlying: error)
                errorHandler.handle(appError, context: "Loading budget data")
            }
        }
    }
    
    /// Reset all data (with confirmation)
    public func resetAllData() async throws {
        let startTime = Date()
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Clear Core Data
            try await coreDataManager.deleteAllData()
            
            // Clear local cache
            await MainActor.run {
                entries.removeAll()
                monthlyBudgets.removeAll()
                invalidateCache()
                lastSyncDate = nil
                dataStatistics = getDataStatistics()
                updateWidgetData()
            }
            
            recordMetric("resetAllData", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetManager: Reset all data successfully")
            
        } catch {
            let appError = AppError.from(error)
            errorHandler.handle(appError, context: "Resetting all data")
            throw appError
        }
    }
    
    // MARK: - Widget and External Integration
    
    /// Update widget data with debouncing
    public func updateWidgetData() {
        widgetUpdateDebouncer.debounce {
            Task { @MainActor in
                await self.performWidgetUpdate()
            }
        }
    }
    
    private func performWidgetUpdate() async {
        do {
            // Update shared data for widget
            let sharedDataManager = SharedDataManager.shared
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
            
            await sharedDataManager.updateBudgetData(
                monthlyBudget: currentBudget,
                totalSpent: totalSpent,
                remainingBudget: remainingBudget
            )
            
            print("🔄 BudgetManager: Updated widget data - Budget: \(currentBudget.asCurrency), Spent: \(totalSpent.asCurrency)")
            
        } catch {
            print("⚠️ BudgetManager: Failed to update widget data - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation Methods
    
    private func validateEntry(_ entry: BudgetEntry) throws {
        guard entry.amount > 0 else {
            throw AppError.validation(message: "Entry amount must be greater than zero")
        }
        
        guard entry.amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw AppError.validation(message: "Entry amount exceeds maximum allowed")
        }
        
        guard !entry.category.isEmpty else {
            throw AppError.validation(message: "Entry category cannot be empty")
        }
        
        guard entry.date <= Date() else {
            throw AppError.validation(message: "Entry date cannot be in the future")
        }
    }
    
    private func validateMonthlyBudget(_ budget: MonthlyBudget) throws {
        guard budget.amount >= 0 else {
            throw AppError.validation(message: "Budget amount cannot be negative")
        }
        
        guard budget.amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw AppError.validation(message: "Budget amount exceeds maximum allowed")
        }
        
        guard !budget.category.isEmpty else {
            throw AppError.validation(message: "Budget category cannot be empty")
        }
        
        guard (1...12).contains(budget.month) else {
            throw AppError.validation(message: "Invalid month value")
        }
        
        guard budget.year >= 1900 && budget.year <= 9999 else {
            throw AppError.validation(message: "Invalid year value")
        }
    }
    
    private func hasDuplicateEntry(_ entry: BudgetEntry) async -> Bool {
        // Check for entries with same amount, category, and date (within same day)
        let calendar = Calendar.current
        
        return entries.contains { existingEntry in
            existingEntry.amount == entry.amount &&
            existingEntry.category == entry.category &&
            calendar.isDate(existingEntry.date, inSameDayAs: entry.date)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sortEntries(
        _ entries: [BudgetEntry],
        by sortOption: BudgetSortOption,
        ascending: Bool
    ) -> [BudgetEntry] {
        let sorted = entries.sorted { entry1, entry2 in
            let result: Bool
            switch sortOption {
            case .date:
                result = entry1.date < entry2.date
            case .amount, .amountSpent:
                result = entry1.amount < entry2.amount
            case .category:
                result = entry1.category < entry2.category
            case .budgetedAmount:
                result = entry1.amount < entry2.amount // Fallback to amount
            }
            return ascending ? result : !result
        }
        return sorted
    }
    
    private func calculateDataIntegrityScore() -> Double {
        var score: Double = 1.0
        
        // Check for data consistency
        let totalEntries = entries.count
        guard totalEntries > 0 else { return 1.0 }
        
        // Check for entries with missing categories
        let entriesWithoutCategories = entries.filter { $0.category.isEmpty }.count
        score -= Double(entriesWithoutCategories) / Double(totalEntries) * 0.3
        
        // Check for negative amounts
        let negativeAmountEntries = entries.filter { $0.amount <= 0 }.count
        score -= Double(negativeAmountEntries) / Double(totalEntries) * 0.4
        
        // Check for future dates
        let futureEntries = entries.filter { $0.date > Date() }.count
        score -= Double(futureEntries) / Double(totalEntries) * 0.2
        
        // Check for extremely large amounts (potential data corruption)
        let extremeAmountEntries = entries.filter { $0.amount > AppConstants.Validation.maximumTransactionAmount }.count
        score -= Double(extremeAmountEntries) / Double(totalEntries) * 0.1
        
        return max(0.0, min(1.0, score))
    }
    
    // MARK: - Cache Management
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastCacheUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    private func invalidateCache() {
        categoryCache.removeAll()
        budgetCache.removeAll()
        statisticsCache = nil
        lastCacheUpdate = Date()
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        #if DEBUG
        operationMetrics[operation] = duration
        if duration > 1.0 { // Log slow operations
            print("⚠️ BudgetManager: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
        }
        #endif
    }
    
    // MARK: - Setup Methods
    
    private func setupDataValidationTimer() {
        dataValidationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performDataValidation()
            }
        }
    }
    
    private func setupCoreDataObserver() {
        coreDataManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func logPerformanceMetrics() {
        #if DEBUG
        guard !operationMetrics.isEmpty else { return }
        
        print("📊 BudgetManager Performance Metrics:")
        for (operation, duration) in operationMetrics.sorted(by: { $0.value > $1.value }) {
            print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
        }
        
        operationMetrics.removeAll()
        #endif
    }
    
    // MARK: - Data Validation
    
    private func performDataValidation() async {
        do {
            let hasUnsavedChanges = await coreDataManager.hasUnsavedChanges()
            if hasUnsavedChanges {
                print("ℹ️ BudgetManager: Found unsaved changes, triggering save")
                try await coreDataManager.forceSave()
            }
            
            // Validate data integrity
            let stats = getDataStatistics()
            if stats.healthStatus == .poor {
                print("⚠️ BudgetManager: Poor data integrity detected (score: \(stats.dataIntegrityScore))")
                // Could trigger data repair or user notification here
            }
            
        } catch {
            print("⚠️ BudgetManager: Data validation failed - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        dataValidationTimer?.invalidate()
        cancellables.removeAll()
        print("🧹 BudgetManager: Cleaned up resources")
    }
}

// MARK: - Debouncer Helper

private class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem { action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Testing Support

#if DEBUG
extension BudgetManager {
    /// Load test data for development and previews
    func loadTestData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Create test entries
        let testEntries = [
            try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date().addingTimeInterval(-86400), note: "Weekly shopping"),
            try! BudgetEntry(amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-172800), note: "Bus fare"),
            try! BudgetEntry(amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-259200), note: "Movie tickets"),
            try! BudgetEntry(amount: 125.00, category: "Utilities", date: Date().addingTimeInterval(-345600), note: "Electric bill"),
            try! BudgetEntry(amount: 67.23, category: "Groceries", date: Date().addingTimeInterval(-432000), note: "Organic produce")
        ]
        
        // Create test monthly budgets
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        let testBudgets = [
            try! MonthlyBudget(category: "Groceries", amount: 500.00, month: currentMonth, year: currentYear),
            try! MonthlyBudget(category: "Transportation", amount: 200.00, month: currentMonth, year: currentYear),
            try! MonthlyBudget(category: "Entertainment", amount: 150.00, month: currentMonth, year: currentYear),
            try! MonthlyBudget(category: "Utilities", amount: 300.00, month: currentMonth, year: currentYear)
        ]
        
        await MainActor.run {
            entries = testEntries
            monthlyBudgets = testBudgets
            lastSyncDate = Date()
            invalidateCache()
            dataStatistics = getDataStatistics()
            updateWidgetData()
        }
        
        print("✅ BudgetManager: Loaded test data - \(testEntries.count) entries, \(testBudgets.count) budgets")
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetrics() -> [String: TimeInterval] {
        return operationMetrics
    }
    
    /// Force cache invalidation for testing
    func invalidateCacheForTesting() {
        invalidateCache()
    }
    
    /// Get cache status for testing
    func getCacheStatus() -> (isValid: Bool, entryCount: Int, budgetCacheCount: Int) {
        return (
            isValid: isCacheValid(),
            entryCount: categoryCache.count,
            budgetCacheCount: budgetCache.count
        )
    }
}
#endif
