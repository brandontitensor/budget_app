//
//  BudgetViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//  Updated: 7/6/25 - Fixed Swift 6 compliance, main actor isolation, and type inference issues
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for managing budget operations with enhanced error handling and state management
@MainActor
public final class BudgetViewModel: ObservableObject {
    
    // MARK: - Types
    
    public enum ViewState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case empty
        case error(AppError)
        
        public static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.empty, .empty):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var hasError: Bool {
            if case .error = self { return true }
            return false
        }
        
        var isEmpty: Bool {
            if case .empty = self { return true }
            return false
        }
        
        var error: AppError? {
            if case .error(let error) = self { return error }
            return nil
        }
    }
    
    public enum OperationType: String, CaseIterable, Sendable {
        case loadBudgets = "loadBudgets"
        case saveBudgets = "saveBudgets"
        case addCategory = "addCategory"
        case updateCategory = "updateCategory"
        case deleteCategory = "deleteCategory"
        case validateCategory = "validateCategory"
        case exportData = "exportData"
        case importData = "importData"
        
        var description: String {
            switch self {
            case .loadBudgets: return "Loading budgets"
            case .saveBudgets: return "Saving budgets"
            case .addCategory: return "Adding category"
            case .updateCategory: return "Updating category"
            case .deleteCategory: return "Deleting category"
            case .validateCategory: return "Validating category"
            case .exportData: return "Exporting data"
            case .importData: return "Importing data"
            }
        }
    }
    
    public struct BudgetSummary: Sendable, Equatable {
        public let totalYearlyBudget: Double
        public let totalMonthlyBudget: Double
        public let categoryCount: Int
        public let averageMonthlyBudget: Double
        public let largestCategory: String?
        public let smallestCategory: String?
        public let lastUpdated: Date
        
        public init(
            totalYearlyBudget: Double,
            totalMonthlyBudget: Double,
            categoryCount: Int,
            averageMonthlyBudget: Double,
            largestCategory: String? = nil,
            smallestCategory: String? = nil,
            lastUpdated: Date = Date()
        ) {
            self.totalYearlyBudget = totalYearlyBudget
            self.totalMonthlyBudget = totalMonthlyBudget
            self.categoryCount = categoryCount
            self.averageMonthlyBudget = averageMonthlyBudget
            self.largestCategory = largestCategory
            self.smallestCategory = smallestCategory
            self.lastUpdated = lastUpdated
        }
        
        public var isValid: Bool {
            return categoryCount > 0 && totalMonthlyBudget > 0
        }
        
        public var formattedYearlyBudget: String {
            return NumberFormatter.formatCurrency(totalYearlyBudget)
        }
        
        public var formattedMonthlyBudget: String {
            return NumberFormatter.formatCurrency(totalMonthlyBudget)
        }
        
        public var averageCategoryBudget: Double {
            return categoryCount > 0 ? totalMonthlyBudget / Double(categoryCount) : 0
        }
    }
    
    public struct BudgetAnalytics: Sendable, Equatable {
        public let totalBudget: Double
        public let averageCategoryBudget: Double
        public let categoryCount: Int
        public let monthlyDistribution: [Int: Double]
        public let categoryDistribution: [String: Double]
        public let largestCategory: (key: String, value: Double)?
        public let smallestCategory: (key: String, value: Double)?
        public let generatedAt: Date
        
        public init(
            totalBudget: Double,
            averageCategoryBudget: Double,
            categoryCount: Int,
            monthlyDistribution: [Int: Double],
            categoryDistribution: [String: Double],
            largestCategory: (key: String, value: Double)? = nil,
            smallestCategory: (key: String, value: Double)? = nil,
            generatedAt: Date = Date()
        ) {
            self.totalBudget = totalBudget
            self.averageCategoryBudget = averageCategoryBudget
            self.categoryCount = categoryCount
            self.monthlyDistribution = monthlyDistribution
            self.categoryDistribution = categoryDistribution
            self.largestCategory = largestCategory
            self.smallestCategory = smallestCategory
            self.generatedAt = generatedAt
        }
        
        public var isBalanced: Bool {
            return monthlyVariation < 20.0
        }
        
        public var monthlyVariation: Double {
            let values = Array(monthlyDistribution.values)
            guard values.count > 1 else { return 0 }
            
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            return sqrt(variance) / mean * 100
        }
        
        public var efficiencyScore: Double {
            let balanceScore = isBalanced ? 1.0 : 0.5
            let utilizationScore = totalBudget > 0 ? min(1.0, averageCategoryBudget / (totalBudget / 12)) : 0
            return (balanceScore + utilizationScore) / 2.0
        }
    }
    
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [String]
        public let warnings: [String]
        
        public init(isValid: Bool = true, errors: [String] = [], warnings: [String] = []) {
            self.isValid = isValid
            self.errors = errors
            self.warnings = warnings
        }
    }
    
    public struct BudgetExportData: Codable, Sendable {
        public let monthlyBudgets: [String: [String: Double]]
        public let selectedYear: Int
        public let selectedMonth: Int
        public let totalYearlyBudget: Double
        public let categoryCount: Int
        public let exportDate: Date
        public let appVersion: String
        public let dataVersion: String
        
        public init(from viewModel: BudgetViewModel) {
            // Convert Int keys to String for JSON compatibility
            self.monthlyBudgets = Dictionary(uniqueKeysWithValues:
                viewModel.monthlyBudgets.map { (String($0.key), $0.value) }
            )
            self.selectedYear = viewModel.selectedYear
            self.selectedMonth = viewModel.selectedMonth
            self.totalYearlyBudget = viewModel.totalYearlyBudget
            self.categoryCount = viewModel.categoryCount
            self.exportDate = Date()
            self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            self.dataVersion = "2.0"
        }
    }
    
    // MARK: - Dependencies
    private let budgetManager: BudgetManager
    private let errorHandler: ErrorHandler
    private let themeManager: ThemeManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published public private(set) var viewState: ViewState = .idle
    @Published public private(set) var currentOperation: OperationType?
    @Published public private(set) var monthlyBudgets: [Int: [String: Double]] = [:]
    @Published public private(set) var budgetSummary: BudgetSummary?
    @Published public private(set) var budgetAnalytics: BudgetAnalytics?
    @Published public private(set) var lastSaveDate: Date?
    @Published public private(set) var hasUnsavedChanges = false
    @Published public private(set) var validationErrors: [String: [String]] = [:]
    
    // MARK: - Input Properties
    @Published public var selectedYear: Int
    @Published public var selectedMonth: Int
    @Published public var newCategoryName = ""
    @Published public var newCategoryAmount: Double = 0
    
    // MARK: - Performance Monitoring
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.budgetvm.metrics", qos: .utility)
    @MainActor private var operationMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Computed Properties
    public var isProcessing: Bool {
        currentOperation != nil || viewState.isLoading
    }
    
    public var canSave: Bool {
        hasUnsavedChanges && !isProcessing && !viewState.hasError
    }
    
    public var totalYearlyBudget: Double {
        monthlyBudgets.values.reduce(0) { total, categoryBudgets in
            total + categoryBudgets.values.reduce(0, +)
        }
    }
    
    public var totalMonthlyBudget: Double {
        monthlyBudgets[selectedMonth, default: [:]].values.reduce(0, +)
    }
    
    public var categoryCount: Int {
        monthlyBudgets[selectedMonth, default: [:]].count
    }
    
    public var availableCategories: [String] {
        Set(monthlyBudgets.values.flatMap { $0.keys }).sorted()
    }
    
    public var currentMonthCategories: [String] {
        Array(monthlyBudgets[selectedMonth, default: [:]].keys).sorted()
    }
    
    public var isValidNewCategory: Bool {
        validateNewCategory().isValid
    }
    
    public var hasValidationIssues: Bool {
        !validationErrors.isEmpty
    }
    
    // MARK: - Initialization
    public init(
        budgetManager: BudgetManager? = nil,
        errorHandler: ErrorHandler? = nil,
        themeManager: ThemeManager? = nil
    ) {
        // Use actual instances or create minimal test instances
        self.budgetManager = budgetManager ?? BudgetManager.shared
        self.errorHandler = errorHandler ?? ErrorHandler.shared
        self.themeManager = themeManager ?? ThemeManager.shared
        
        // Initialize with current date
        let calendar = Calendar.current
        let now = Date()
        self.selectedYear = calendar.component(.year, from: now)
        self.selectedMonth = calendar.component(.month, from: now)
        
        setupBindings()
        setupPerformanceMonitoring()
        
        print("✅ BudgetViewModel: Initialized for \(selectedMonth)/\(selectedYear)")
    }
    
    // MARK: - Public Methods
    
    /// Load budgets for the current year
    public func loadBudgets() async {
        await performOperation(.loadBudgets) {
            var newBudgets: [Int: [String: Double]] = [:]
            
            for month in 1...12 {
                let budgets = self.budgetManager.getMonthlyBudgets(for: month, year: self.selectedYear)
                newBudgets[month] = Dictionary(
                    uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) }
                )
            }
            
            self.monthlyBudgets = newBudgets
            self.updateBudgetSummary()
            self.updateBudgetAnalytics()
            self.updateViewState()
            self.hasUnsavedChanges = false
            
            print("✅ BudgetViewModel: Loaded budgets for \(self.selectedYear)")
        }
    }
    
    /// Refresh budget data
    public func refreshBudgets() async {
        await loadBudgets()
    }
    
    /// Save all budget changes
    public func saveBudgets() async {
        guard hasUnsavedChanges else { return }
        
        await performOperation(.saveBudgets) {
            // Validate all budgets before saving
            try self.validateAllBudgets()
            
            // Save each month's budgets
            for (month, budgets) in self.monthlyBudgets {
                try await self.budgetManager.updateMonthlyBudgets(
                    budgets,
                    for: month,
                    year: self.selectedYear
                )
            }
            
            self.hasUnsavedChanges = false
            self.lastSaveDate = Date()
            
            print("✅ BudgetViewModel: Saved budgets for \(self.selectedYear)")
        }
    }
    
    /// Add a new category
    public func addCategory(includeFutureMonths: Bool = false) async {
        await performOperation(.addCategory) {
            let trimmedName = self.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate the new category
            let validation = self.validateNewCategory()
            guard validation.isValid else {
                throw AppError.validation(message: validation.errors.first ?? "Invalid category")
            }
            
            // Add to current month
            self.monthlyBudgets[self.selectedMonth, default: [:]][trimmedName] = self.newCategoryAmount
            
            if includeFutureMonths {
                // Add to future months in the year
                for month in (self.selectedMonth + 1)...12 {
                    self.monthlyBudgets[month, default: [:]][trimmedName] = self.newCategoryAmount
                }
            }
            
            self.resetNewCategoryFields()
            self.hasUnsavedChanges = true
            self.updateBudgetSummary()
            self.updateBudgetAnalytics()
            
            print("✅ BudgetViewModel: Added category '\(trimmedName)' with amount \(self.newCategoryAmount)")
        }
    }
    
    /// Update category amount for a specific month
    public func updateCategory(_ categoryName: String, amount: Double, month: Int? = nil) async {
        let targetMonth = month ?? selectedMonth
        
        await performOperation(.updateCategory) {
            guard amount >= 0 else {
                throw AppError.validation(message: "Budget amount cannot be negative")
            }
            
            self.monthlyBudgets[targetMonth, default: [:]][categoryName] = amount
            self.hasUnsavedChanges = true
            self.updateBudgetSummary()
            self.updateBudgetAnalytics()
            
            print("✅ BudgetViewModel: Updated category '\(categoryName)' to \(amount) for month \(targetMonth)")
        }
    }
    
    /// Delete a category from a specific month
    public func deleteCategory(_ categoryName: String, month: Int? = nil) async {
        let targetMonth = month ?? selectedMonth
        
        await performOperation(.deleteCategory) {
            self.monthlyBudgets[targetMonth]?.removeValue(forKey: categoryName)
            self.hasUnsavedChanges = true
            self.updateBudgetSummary()
            self.updateBudgetAnalytics()
            
            print("✅ BudgetViewModel: Deleted category '\(categoryName)' from month \(targetMonth)")
        }
    }
    
    /// Export budget data
    public func exportBudgetData() async -> BudgetExportData? {
        var exportData: BudgetExportData?
        
        await performOperation(.exportData) {
            exportData = BudgetExportData(from: self)
            print("✅ BudgetViewModel: Exported budget data")
        }
        
        return exportData
    }
    
    /// Import budget data
    public func importBudgetData(_ data: BudgetExportData) async {
        await performOperation(.importData) {
            // Convert String keys back to Int for proper type
            let importedBudgets: [Int: [String: Double]] = Dictionary(
                uniqueKeysWithValues: data.monthlyBudgets.compactMap { (stringKey, value) in
                    guard let intKey = Int(stringKey) else { return nil }
                    return (intKey, value)
                }
            )
            
            self.monthlyBudgets = importedBudgets
            self.hasUnsavedChanges = true
            self.updateBudgetSummary()
            self.updateBudgetAnalytics()
            self.updateViewState()
            
            print("✅ BudgetViewModel: Imported budget data")
        }
    }
    
    /// Clear validation errors
    public func clearValidationErrors() {
        validationErrors.removeAll()
    }
    
    /// Reset new category input fields
    public func resetNewCategoryFields() {
        newCategoryName = ""
        newCategoryAmount = 0
        clearValidationErrors()
    }
    
    /// Retry last failed operation
    public func retryLastOperation() async {
        clearValidationErrors()
        await loadBudgets()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor new category input changes
        Publishers.CombineLatest($newCategoryName, $newCategoryAmount)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.validateNewCategoryInput()
            }
            .store(in: &cancellables)
        
        // Monitor selected month/year changes
        Publishers.CombineLatest($selectedMonth, $selectedYear)
            .dropFirst() // Skip initial value
            .sink { [weak self] _, _ in
                Task { [weak self] in
                    await self?.refreshBudgets()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logPerformanceMetrics()
            }
        }
        #endif
    }
    
    private func performOperation<T>(
        _ operation: OperationType,
        _ block: @MainActor @escaping () async throws -> T
    ) async {
        let startTime = Date()
        currentOperation = operation
        
        if viewState != .loading {
            viewState = .loading
        }
        
        do {
            _ = try await block()
            
            currentOperation = nil
            
            // Clear error state on success
            if viewState.hasError {
                updateViewState()
            }
        } catch {
            currentOperation = nil
            let appError = AppError.from(error)
            viewState = .error(appError)
            errorHandler.handle(appError, context: "BudgetViewModel: \(operation.description)")
        }
        
        await recordMetric(operation.description, duration: Date().timeIntervalSince(startTime))
    }
    
    private func updateViewState() {
        if monthlyBudgets.isEmpty {
            viewState = .empty
        } else {
            viewState = .loaded
        }
    }
    
    private func updateBudgetSummary() {
        let totalYearly = totalYearlyBudget
        let totalMonthly = totalMonthlyBudget
        let count = categoryCount
        let average = count > 0 ? totalMonthly / Double(count) : 0
        
        // Find largest and smallest categories for current month
        let currentMonthBudgets = monthlyBudgets[selectedMonth] ?? [:]
        let largest = currentMonthBudgets.max { $0.value < $1.value }
        let smallest = currentMonthBudgets.min { $0.value < $1.value }
        
        budgetSummary = BudgetSummary(
            totalYearlyBudget: totalYearly,
            totalMonthlyBudget: totalMonthly,
            categoryCount: count,
            averageMonthlyBudget: average,
            largestCategory: largest?.key,
            smallestCategory: smallest?.key
        )
    }
    
    private func updateBudgetAnalytics() {
        let monthlyDistribution = monthlyBudgets.mapValues { categories in
            categories.values.reduce(0, +)
        }
        
        let categoryDistribution = monthlyBudgets.values.reduce(into: [String: Double]()) { result, categories in
            for (category, amount) in categories {
                result[category, default: 0] += amount
            }
        }
        
        let largest = categoryDistribution.max { $0.value < $1.value }
        let smallest = categoryDistribution.min { $0.value < $1.value }
        
        budgetAnalytics = BudgetAnalytics(
            totalBudget: totalYearlyBudget,
            averageCategoryBudget: categoryCount > 0 ? totalMonthlyBudget / Double(categoryCount) : 0,
            categoryCount: categoryCount,
            monthlyDistribution: monthlyDistribution,
            categoryDistribution: categoryDistribution,
            largestCategory: largest.map { ($0.key, $0.value) },
            smallestCategory: smallest.map { ($0.key, $0.value) }
        )
    }
    
    private func validateNewCategory() -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            errors.append("Category name cannot be empty")
        } else if trimmedName.count > 50 {
            errors.append("Category name must be 50 characters or less")
        }
        
        if newCategoryAmount < 0 {
            errors.append("Budget amount cannot be negative")
        } else if newCategoryAmount == 0 {
            warnings.append("Budget amount is zero")
        } else if newCategoryAmount > 100000 {
            warnings.append("Budget amount seems unusually large")
        }
        
        // Check for duplicate category in current month
        if let currentCategories = monthlyBudgets[selectedMonth], currentCategories.keys.contains(trimmedName) {
            errors.append("Category '\(trimmedName)' already exists for this month")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateNewCategoryInput() {
        let validation = validateNewCategory()
        
        if !validation.errors.isEmpty {
            validationErrors["newCategory"] = validation.errors
        } else {
            validationErrors.removeValue(forKey: "newCategory")
        }
    }
    
    private func validateAllBudgets() throws {
        for (month, categories) in monthlyBudgets {
            for (category, amount) in categories {
                if amount < 0 {
                    throw AppError.validation(message: "Negative budget amount found for \(category) in month \(month)")
                }
                if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw AppError.validation(message: "Empty category name found in month \(month)")
                }
            }
        }
    }
    
    @MainActor
    private func recordMetric(_ operation: String, duration: TimeInterval) async {
        operationMetrics[operation] = duration
        
        #if DEBUG
        if duration > 1.0 {
            print("⚠️ BudgetViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
        }
        #endif
    }
    
    @MainActor
    private func logPerformanceMetrics() {
        guard !operationMetrics.isEmpty else { return }
        
        #if DEBUG
        print("📊 BudgetViewModel Performance Metrics:")
        for (operation, duration) in operationMetrics.sorted(by: { $0.value > $1.value }) {
            print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
        }
        #endif
        
        operationMetrics.removeAll()
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
        print("🧹 BudgetViewModel: Cleaned up resources")
    }
}

// MARK: - Extensions

private extension NumberFormatter {
    static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

// MARK: - Testing Support

#if DEBUG
extension BudgetViewModel {
    /// Load test data for development
    func loadTestData() async {
        let testBudgets: [Int: [String: Double]] = [
            1: ["Groceries": 400.0, "Transportation": 200.0, "Entertainment": 150.0],
            2: ["Groceries": 420.0, "Transportation": 180.0, "Entertainment": 160.0],
            3: ["Groceries": 380.0, "Transportation": 220.0, "Entertainment": 140.0]
        ]
        
        monthlyBudgets = testBudgets
        updateBudgetSummary()
        updateBudgetAnalytics()
        updateViewState()
        
        print("📊 BudgetViewModel: Test data loaded")
    }
    
    /// Simulate slow operation for testing
    func simulateSlowOperation() async {
        await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
    
    /// Get validation state for testing
    func getValidationStateForTesting() -> [String: [String]] {
        return validationErrors
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return operationMetrics
    }
    
    /// Reset for testing
    func resetForTesting() {
        monthlyBudgets.removeAll()
        budgetSummary = nil
        budgetAnalytics = nil
        validationErrors.removeAll()
        hasUnsavedChanges = false
        viewState = .idle
        resetNewCategoryFields()
        operationMetrics.removeAll()
    }
}
#endif
