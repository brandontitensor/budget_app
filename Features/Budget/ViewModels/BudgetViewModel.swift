//
//  BudgetViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//  Updated: 7/7/25 - Fixed Swift 6 compliance, main actor isolation, and Equatable conformance
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
        public let largestCategoryKey: String?
        public let largestCategoryValue: Double?
        public let smallestCategoryKey: String?
        public let smallestCategoryValue: Double?
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
            self.largestCategoryKey = largestCategory?.key
            self.largestCategoryValue = largestCategory?.value
            self.smallestCategoryKey = smallestCategory?.key
            self.smallestCategoryValue = smallestCategory?.value
            self.generatedAt = generatedAt
        }
        
        // Custom Equatable implementation for tuples
        public static func == (lhs: BudgetAnalytics, rhs: BudgetAnalytics) -> Bool {
            return lhs.totalBudget == rhs.totalBudget &&
                   lhs.averageCategoryBudget == rhs.averageCategoryBudget &&
                   lhs.categoryCount == rhs.categoryCount &&
                   lhs.monthlyDistribution == rhs.monthlyDistribution &&
                   lhs.categoryDistribution == rhs.categoryDistribution &&
                   lhs.largestCategoryKey == rhs.largestCategoryKey &&
                   lhs.largestCategoryValue == rhs.largestCategoryValue &&
                   lhs.smallestCategoryKey == rhs.smallestCategoryKey &&
                   lhs.smallestCategoryValue == rhs.smallestCategoryValue &&
                   lhs.generatedAt == rhs.generatedAt
        }
        
        public var largestCategory: (key: String, value: Double)? {
            guard let key = largestCategoryKey, let value = largestCategoryValue else { return nil }
            return (key: key, value: value)
        }
        
        public var smallestCategory: (key: String, value: Double)? {
            guard let key = smallestCategoryKey, let value = smallestCategoryValue else { return nil }
            return (key: key, value: value)
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
    private var operationMetrics: [String: TimeInterval] = [:]
    
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
        
        // Initialize current date
        let calendar = Calendar.current
        let now = Date()
        self.selectedYear = calendar.component(.year, from: now)
        self.selectedMonth = calendar.component(.month, from: now)
        
        setupBindings()
        
        Task {
            await loadBudgets()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor new category input for real-time validation
        $newCategoryName
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.validateNewCategoryInput()
            }
            .store(in: &cancellables)
        
        $newCategoryAmount
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.validateNewCategoryInput()
            }
            .store(in: &cancellables)
        
        // Monitor budget changes for auto-save
        $monthlyBudgets
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.autoSaveBudgets()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    public func loadBudgets() async {
        let startTime = Date()
        viewState = .loading
        currentOperation = .loadBudgets
        
        do {
            // Load budget data from manager
            let budgets = budgetManager.monthlyBudgets
            
            // Convert to our format
            var monthlyBudgetsDict: [Int: [String: Double]] = [:]
            for budget in budgets {
                if monthlyBudgetsDict[budget.month] == nil {
                    monthlyBudgetsDict[budget.month] = [:]
                }
                monthlyBudgetsDict[budget.month]?[budget.category] = budget.amount
            }
            
            monthlyBudgets = monthlyBudgetsDict
            
            // Update analytics
            calculateBudgetSummary()
            calculateBudgetAnalytics()
            
            viewState = monthlyBudgets.isEmpty ? .empty : .loaded
            
            await recordMetric("loadBudgets", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Loaded budgets for \(monthlyBudgets.count) months")
            
        } catch {
            await handleError(AppError.from(error), context: "loading budgets")
        }
        
        currentOperation = nil
    }
    
    // MARK: - Budget Management
    
    public func saveBudgets() async {
        guard hasUnsavedChanges else { return }
        
        let startTime = Date()
        currentOperation = .saveBudgets
        
        do {
            try validateAllBudgets()
            
            // Convert our format to MonthlyBudget objects and save
            for (month, categories) in monthlyBudgets {
                try await budgetManager.updateMonthlyBudgets(categories, for: month, year: selectedYear)
            }
            
            hasUnsavedChanges = false
            lastSaveDate = Date()
            
            await recordMetric("saveBudgets", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Saved budgets successfully")
            
        } catch {
            await handleError(AppError.from(error), context: "saving budgets")
        }
        
        currentOperation = nil
    }
    
    public func addCategory() async {
        let validation = validateNewCategory()
        guard validation.isValid else {
            validationErrors["newCategory"] = validation.errors
            return
        }
        
        let startTime = Date()
        currentOperation = .addCategory
        
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add to current month
        if monthlyBudgets[selectedMonth] == nil {
            monthlyBudgets[selectedMonth] = [:]
        }
        monthlyBudgets[selectedMonth]?[trimmedName] = newCategoryAmount
        
        hasUnsavedChanges = true
        
        // Clear input
        newCategoryName = ""
        newCategoryAmount = 0
        clearValidationErrors()
        
        // Update analytics
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        
        await recordMetric("addCategory", duration: Date().timeIntervalSince(startTime))
        print("✅ BudgetViewModel: Added category '\(trimmedName)' with budget \(newCategoryAmount.formattedAsCurrency)")
        
        currentOperation = nil
    }
    
    public func updateCategoryBudget(_ category: String, amount: Double) async {
        guard amount >= 0 else {
            validationErrors[category] = ["Amount cannot be negative"]
            return
        }
        
        let startTime = Date()
        currentOperation = .updateCategory
        
        if monthlyBudgets[selectedMonth] == nil {
            monthlyBudgets[selectedMonth] = [:]
        }
        
        monthlyBudgets[selectedMonth]?[category] = amount
        hasUnsavedChanges = true
        
        // Clear any existing validation errors for this category
        validationErrors.removeValue(forKey: category)
        
        // Update analytics
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        
        await recordMetric("updateCategory", duration: Date().timeIntervalSince(startTime))
        print("✅ BudgetViewModel: Updated '\(category)' budget to \(amount.formattedAsCurrency)")
        
        currentOperation = nil
    }
    
    public func deleteCategory(_ category: String) async {
        let startTime = Date()
        currentOperation = .deleteCategory
        
        monthlyBudgets[selectedMonth]?.removeValue(forKey: category)
        hasUnsavedChanges = true
        
        // Remove any validation errors for this category
        validationErrors.removeValue(forKey: category)
        
        // Update analytics
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        
        await recordMetric("deleteCategory", duration: Date().timeIntervalSince(startTime))
        print("✅ BudgetViewModel: Deleted category '\(category)'")
        
        currentOperation = nil
    }
    
    // MARK: - Navigation
    
    public func changeMonth(to month: Int, year: Int) async {
        guard month >= 1 && month <= 12 else { return }
        guard year >= 1900 && year <= 2100 else { return }
        
        if hasUnsavedChanges {
            await saveBudgets()
        }
        
        selectedMonth = month
        selectedYear = year
        
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        
        print("✅ BudgetViewModel: Changed to \(month)/\(year)")
    }
    
    // MARK: - Utility Methods
    
    public func clearValidationErrors() {
        validationErrors.removeAll()
    }
    
    public func refreshData() async {
        await loadBudgets()
    }
    
    private func autoSaveBudgets() async {
        guard hasUnsavedChanges else { return }
        await saveBudgets()
    }
    
    // MARK: - Analytics Calculation
    
    private func calculateBudgetSummary() {
        let currentMonthBudgets = monthlyBudgets[selectedMonth, default: [:]]
        let totalMonthly = currentMonthBudgets.values.reduce(0, +)
        let totalYearly = totalYearlyBudget
        let categoryCount = currentMonthBudgets.count
        let averageMonthly = categoryCount > 0 ? totalMonthly / Double(categoryCount) : 0
        
        let largestCategory = currentMonthBudgets.max(by: { $0.value < $1.value })?.key
        let smallestCategory = currentMonthBudgets.min(by: { $0.value < $1.value })?.key
        
        budgetSummary = BudgetSummary(
            totalYearlyBudget: totalYearly,
            totalMonthlyBudget: totalMonthly,
            categoryCount: categoryCount,
            averageMonthlyBudget: averageMonthly,
            largestCategory: largestCategory,
            smallestCategory: smallestCategory
        )
    }
    
    private func calculateBudgetAnalytics() {
        let allCategories = Set(monthlyBudgets.values.flatMap { $0.keys })
        let totalBudget = totalYearlyBudget
        let averageCategoryBudget = !allCategories.isEmpty ? totalBudget / Double(allCategories.count) : 0
        
        // Monthly distribution
        var monthlyDistribution: [Int: Double] = [:]
        for (month, categories) in monthlyBudgets {
            monthlyDistribution[month] = categories.values.reduce(0, +)
        }
        
        // Category distribution (sum across all months)
        var categoryDistribution: [String: Double] = [:]
        for category in allCategories {
            let categoryTotal = monthlyBudgets.values.compactMap { $0[category] }.reduce(0, +)
            categoryDistribution[category] = categoryTotal
        }
        
        let largestCategory = categoryDistribution.max(by: { $0.value < $1.value })
        let smallestCategory = categoryDistribution.min(by: { $0.value < $1.value })
        
        budgetAnalytics = BudgetAnalytics(
            totalBudget: totalBudget,
            averageCategoryBudget: averageCategoryBudget,
            categoryCount: allCategories.count,
            monthlyDistribution: monthlyDistribution,
            categoryDistribution: categoryDistribution,
            largestCategory: largestCategory.map { (key: $0.key, value: $0.value) },
            smallestCategory: smallestCategory.map { (key: $0.key, value: $0.value) }
        )
    }
    
    // MARK: - Validation
    
    private func validateNewCategory() -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate category name
        if trimmedName.isEmpty {
            errors.append("Category name cannot be empty")
        } else if trimmedName.count < 2 {
            errors.append("Category name must be at least 2 characters")
        } else if trimmedName.count > 30 {
            errors.append("Category name must be 30 characters or less")
        }
        
        // Validate amount
        if newCategoryAmount < 0 {
            errors.append("Amount cannot be negative")
        } else if newCategoryAmount == 0 {
            warnings.append("Setting a budget of $0 may not be useful")
        } else if newCategoryAmount > 10000 {
            warnings.append("This is a large budget amount")
        }
        
        // Check for duplicate
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
    
    // MARK: - Error Handling
    
    private func handleError(_ error: AppError, context: String) async {
        viewState = .error(error)
        errorHandler.handle(error, context: "BudgetViewModel: \(context)")
        
        // Clear processing state
        currentOperation = nil
        
        // Provide recovery suggestions based on error type
        switch error {
        case .dataSave:
            // Suggest retry with auto-save disabled
            break
        case .validation(let message):
            // Add to validation errors for specific field display
            validationErrors["general"] = [message]
        default:
            break
        }
    }
    
    public func retryLastOperation() async {
        clearValidationErrors()
        await loadBudgets()
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) async {
        // Use detached task to avoid main actor issues
        Task.detached { [weak self] in
            await self?.performMetricRecording(operation, duration: duration)
        }
    }
    
    private func performMetricRecording(_ operation: String, duration: TimeInterval) async {
        await withCheckedContinuation { continuation in
            metricsQueue.async { [weak self] in
                self?.operationMetrics[operation] = duration
                
                #if DEBUG
                if duration > 1.0 {
                    print("⚠️ BudgetViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
                }
                #endif
                
                continuation.resume()
            }
        }
    }
    
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

private extension Double {
    var formattedAsCurrency: String {
        return NumberFormatter.formatCurrency(self)
    }
}

// MARK: - Testing Support

#if DEBUG
extension BudgetViewModel {
    /// Load test data for development
    func loadTestData() async {
        let testBudgets: [Int: [String: Double]] = [
            1: ["Groceries": 400.0, "Transportation": 200.0, "Entertainment": 150.0],
            2: ["Groceries": 420.0, "Transportation": 200.0, "Entertainment": 120.0],
            3: ["Groceries": 380.0, "Transportation": 220.0, "Entertainment": 180.0]
        ]
        
        monthlyBudgets = testBudgets
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        viewState = .loaded
        
        print("📊 BudgetViewModel: Test data loaded")
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
        currentOperation = nil
        operationMetrics.removeAll()
    }
}
#endif
