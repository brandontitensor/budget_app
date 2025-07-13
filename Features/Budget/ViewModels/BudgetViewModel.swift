//
//  BudgetViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for budget-related operations with enhanced state management and validation
@MainActor
public final class BudgetViewModel: ObservableObject {
    
    // MARK: - Types
    
    public enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(AppError)
        case empty
        
        public var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        public var hasError: Bool {
            if case .error = self { return true }
            return false
        }
        
        public var isEmpty: Bool {
            if case .empty = self { return true }
            return false
        }
    }
    
    public enum OperationType: String, CaseIterable {
        case loadBudgets = "Loading budgets"
        case saveBudget = "Saving budget"
        case deleteBudget = "Deleting budget"
        case addCategory = "Adding category"
        case updateCategory = "Updating category"
        case deleteCategory = "Deleting category"
        case calculateAnalytics = "Calculating analytics"
        case exportData = "Exporting data"
        case validateData = "Validating data"
    }
    
    public struct BudgetSummary: Equatable {
        public let totalBudgeted: Double
        public let totalSpent: Double
        public let remainingBudget: Double
        public let categoryCount: Int
        public let monthYear: String
        public let lastUpdated: Date
        
        public var utilizationPercentage: Double {
            guard totalBudgeted > 0 else { return 0 }
            return (totalSpent / totalBudgeted) * 100
        }
        
        public var isOverBudget: Bool {
            return totalSpent > totalBudgeted
        }
    }
    
    public struct BudgetAnalytics: Equatable {
        public let averageMonthlySpending: Double
        public let highestSpendingCategory: String?
        public let lowestSpendingCategory: String?
        public let budgetTrend: BudgetTrend
        public let recommendations: [String]
        public let projectedEndOfMonthSpending: Double
        
        public enum BudgetTrend: String, CaseIterable {
            case increasing = "Increasing"
            case decreasing = "Decreasing"
            case stable = "Stable"
            case volatile = "Volatile"
        }
    }
    
    public struct PerformanceMetrics {
        public let operationType: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let success: Bool
        public let errorDetails: String?
        public let dataVersion: String
        
        public init(operationType: String, duration: TimeInterval, success: Bool, errorDetails: String? = nil) {
            self.operationType = operationType
            self.duration = duration
            self.timestamp = Date()
            self.success = success
            self.errorDetails = errorDetails
            // Using Bundle info for data version tracking
            self.dataVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
    @Published private var operationMetrics: [String: TimeInterval] = [:]
    
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
        
        Task<Void, Never>{
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
                Task<Void, Never>{ [weak self] in
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
            currentOperation = nil
            
            recordMetric("loadBudgets", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Budgets loaded successfully")
            
        } catch {
            let appError = AppError.from(error)
            viewState = .error(appError)
            currentOperation = nil
            errorHandler.handle(appError, context: "Loading budgets")
            recordMetric("loadBudgets", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    public func refreshBudgets() async {
        await loadBudgets()
    }
    
    // MARK: - Budget Management
    
    public func addCategory(name: String, amount: Double) async {
        let startTime = Date()
        currentOperation = .addCategory
        clearValidationErrors()
        
        do {
            // Validate input
            let validation = validateCategory(name: name, amount: amount)
            guard validation.isValid else {
                if let error = validation.error {
                    addValidationError(for: "newCategory", message: error.errorDescription ?? "Invalid category")
                }
                currentOperation = nil
                return
            }
            
            // Add to current month
            if monthlyBudgets[selectedMonth] == nil {
                monthlyBudgets[selectedMonth] = [:]
            }
            monthlyBudgets[selectedMonth]?[name] = amount
            
            // Save to budget manager
            let monthlyBudget = MonthlyBudget(
                id: UUID(),
                month: selectedMonth,
                year: selectedYear,
                category: name,
                amount: amount,
                createdDate: Date(),
                lastModified: Date()
            )
            
            try await budgetManager.addMonthlyBudget(monthlyBudget)
            
            // Update UI state
            hasUnsavedChanges = true
            calculateBudgetSummary()
            calculateBudgetAnalytics()
            
            // Clear input fields
            newCategoryName = ""
            newCategoryAmount = 0
            
            currentOperation = nil
            recordMetric("addCategory", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Category '\(name)' added successfully")
            
        } catch {
            let appError = AppError.from(error)
            addValidationError(for: "newCategory", message: appError.errorDescription ?? "Failed to add category")
            currentOperation = nil
            errorHandler.handle(appError, context: "Adding category")
            recordMetric("addCategory", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    public func updateCategory(name: String, newAmount: Double) async {
        let startTime = Date()
        currentOperation = .updateCategory
        
        do {
            // Validate amount
            guard newAmount >= 0 else {
                addValidationError(for: name, message: "Amount must be non-negative")
                currentOperation = nil
                return
            }
            
            // Update local state
            monthlyBudgets[selectedMonth]?[name] = newAmount
            
            // Update in budget manager
            try await budgetManager.updateCategoryAmount(
                category: name,
                month: selectedMonth,
                year: selectedYear,
                amount: newAmount
            )
            
            hasUnsavedChanges = true
            calculateBudgetSummary()
            calculateBudgetAnalytics()
            
            currentOperation = nil
            recordMetric("updateCategory", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Category '\(name)' updated successfully")
            
        } catch {
            let appError = AppError.from(error)
            addValidationError(for: name, message: appError.errorDescription ?? "Failed to update category")
            currentOperation = nil
            errorHandler.handle(appError, context: "Updating category")
            recordMetric("updateCategory", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    public func deleteCategory(name: String) async {
        let startTime = Date()
        currentOperation = .deleteCategory
        
        do {
            // Remove from local state
            monthlyBudgets[selectedMonth]?.removeValue(forKey: name)
            
            // Remove from budget manager
            try await budgetManager.deleteCategoryBudget(
                category: name,
                month: selectedMonth,
                year: selectedYear
            )
            
            hasUnsavedChanges = true
            calculateBudgetSummary()
            calculateBudgetAnalytics()
            
            currentOperation = nil
            recordMetric("deleteCategory", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Category '\(name)' deleted successfully")
            
        } catch {
            let appError = AppError.from(error)
            currentOperation = nil
            errorHandler.handle(appError, context: "Deleting category")
            recordMetric("deleteCategory", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    // MARK: - Data Persistence
    
    public func saveBudgets() async {
        let startTime = Date()
        currentOperation = .saveBudget
        
        do {
            try await budgetManager.saveCurrentState()
            
            hasUnsavedChanges = false
            lastSaveDate = Date()
            currentOperation = nil
            
            recordMetric("saveBudgets", duration: Date().timeIntervalSince(startTime))
            print("✅ BudgetViewModel: Budgets saved successfully")
            
        } catch {
            let appError = AppError.from(error)
            currentOperation = nil
            errorHandler.handle(appError, context: "Saving budgets")
            recordMetric("saveBudgets", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    private func autoSaveBudgets() async {
        guard canSave else { return }
        await saveBudgets()
    }
    
    // MARK: - Analytics and Calculations
    
    private func calculateBudgetSummary() {
        guard !monthlyBudgets.isEmpty else {
            budgetSummary = nil
            return
        }
        
        let currentMonthBudgets = monthlyBudgets[selectedMonth, default: [:]]
        let totalBudgeted = currentMonthBudgets.values.reduce(0, +)
        
        // Get spending data for the current month
        let currentMonthEntries = budgetManager.entries.filter { entry in
            let calendar = Calendar.current
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entryMonth == selectedMonth && entryYear == selectedYear
        }
        
        let totalSpent = currentMonthEntries.reduce(0) { $0 + $1.amount }
        let remainingBudget = totalBudgeted - totalSpent
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthYear = monthFormatter.string(from: Calendar.current.date(
            from: DateComponents(year: selectedYear, month: selectedMonth)
        ) ?? Date())
        
        budgetSummary = BudgetSummary(
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            remainingBudget: remainingBudget,
            categoryCount: currentMonthBudgets.count,
            monthYear: monthYear,
            lastUpdated: Date()
        )
    }
    
    private func calculateBudgetAnalytics() {
        guard !monthlyBudgets.isEmpty else {
            budgetAnalytics = nil
            return
        }
        
        // Calculate average monthly spending
        let allMonthlyTotals = monthlyBudgets.values.map { $0.values.reduce(0, +) }
        let averageMonthlySpending = allMonthlyTotals.isEmpty ? 0 : allMonthlyTotals.reduce(0, +) / Double(allMonthlyTotals.count)
        
        // Find highest and lowest spending categories
        let currentMonthBudgets = monthlyBudgets[selectedMonth, default: [:]]
        let sortedCategories = currentMonthBudgets.sorted { $0.value > $1.value }
        let highestSpendingCategory = sortedCategories.first?.key
        let lowestSpendingCategory = sortedCategories.last?.key
        
        // Determine budget trend based on recent months' spending patterns
        let budgetTrend: BudgetAnalytics.BudgetTrend = calculateBudgetTrend(from: allMonthlyTotals)
        
        // Generate recommendations
        var recommendations: [String] = []
        if let summary = budgetSummary {
            if summary.isOverBudget {
                recommendations.append("Consider reducing spending in high-cost categories")
            }
            if summary.utilizationPercentage < 50 {
                recommendations.append("You're under budget - consider increasing savings")
            }
        }
        
        // Project end of month spending (simplified)
        let currentMonthProgress = Calendar.current.component(.day, from: Date()) / 30.0
        let projectedEndOfMonthSpending = currentMonthProgress > 0 ? (budgetSummary?.totalSpent ?? 0) / currentMonthProgress : 0
        
        budgetAnalytics = BudgetAnalytics(
            averageMonthlySpending: averageMonthlySpending,
            highestSpendingCategory: highestSpendingCategory,
            lowestSpendingCategory: lowestSpendingCategory,
            budgetTrend: budgetTrend,
            recommendations: recommendations,
            projectedEndOfMonthSpending: projectedEndOfMonthSpending
        )
    }
    
    // MARK: - Validation
    
    private func validateNewCategory() -> ValidationResult {
        return validateCategory(name: newCategoryName, amount: newCategoryAmount)
    }
    
    private func validateCategory(name: String, amount: Double) -> ValidationResult {
        // Validate name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(.validation(message: "Category name cannot be empty"))
        }
        
        guard name.count <= 50 else {
            return .invalid(.validation(message: "Category name must be 50 characters or less"))
        }
        
        // Check for duplicate category in current month
        if monthlyBudgets[selectedMonth]?.keys.contains(name) == true {
            return .invalid(.validation(message: "Category already exists for this month"))
        }
        
        // Validate amount
        guard amount >= 0 else {
            return .invalid(.validation(message: "Amount must be non-negative"))
        }
        
        guard amount <= 999999.99 else {
            return .invalid(.validation(message: "Amount cannot exceed $999,999.99"))
        }
        
        return .valid
    }
    
    private func validateNewCategoryInput() {
        clearValidationErrors(for: "newCategory")
        
        let validation = validateNewCategory()
        if case .invalid(let error) = validation {
            addValidationError(for: "newCategory", message: error.errorDescription ?? "Invalid input")
        }
    }
    
    // MARK: - Validation Error Management
    
    private func addValidationError(for field: String, message: String) {
        if validationErrors[field] == nil {
            validationErrors[field] = []
        }
        validationErrors[field]?.append(message)
    }
    
    private func clearValidationErrors(for field: String? = nil) {
        if let field = field {
            validationErrors.removeValue(forKey: field)
        } else {
            validationErrors.removeAll()
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval, success: Bool = true) {
        let metric = PerformanceMetrics(
            operationType: operation,
            duration: duration,
            success: success,
            errorDetails: success ? nil : "Operation failed"
        )
        
        metricsQueue.async { [weak self] in
            Task<Void, Never>{ @MainActor [weak self] in
                self?.operationMetrics[operation] = duration
            }
        }
        
        // Log performance issues
        if duration > 1.0 {
            print("⚠️ BudgetViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - Month/Year Management
    
    public func selectMonth(_ month: Int, year: Int) {
        selectedMonth = month
        selectedYear = year
        calculateBudgetSummary()
        calculateBudgetAnalytics()
        clearValidationErrors()
    }
    
    public func goToNextMonth() {
        let calendar = Calendar.current
        let currentDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)) ?? Date()
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            selectedMonth = calendar.component(.month, from: nextMonth)
            selectedYear = calendar.component(.year, from: nextMonth)
            calculateBudgetSummary()
            calculateBudgetAnalytics()
        }
    }
    
    public func goToPreviousMonth() {
        let calendar = Calendar.current
        let currentDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)) ?? Date()
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            selectedMonth = calendar.component(.month, from: previousMonth)
            selectedYear = calendar.component(.year, from: previousMonth)
            calculateBudgetSummary()
            calculateBudgetAnalytics()
        }
    }
    
    // MARK: - Utility Methods
    
    public func resetNewCategoryFields() {
        newCategoryName = ""
        newCategoryAmount = 0
        clearValidationErrors(for: "newCategory")
    }
    
    public func getBudgetForCategory(_ category: String) -> Double {
        return monthlyBudgets[selectedMonth]?[category] ?? 0
    }
    
    public func getCategoriesForMonth(_ month: Int) -> [String] {
        return Array(monthlyBudgets[month, default: [:]].keys).sorted()
    }
    
    public func getTotalBudgetForMonth(_ month: Int) -> Double {
        return monthlyBudgets[month, default: [:]].values.reduce(0, +)
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateBudgetTrend(from monthlyTotals: [Double]) -> BudgetAnalytics.BudgetTrend {
        guard monthlyTotals.count >= 2 else { return .stable }
        
        // Take the last 3-6 months if available
        let recentMonths = Array(monthlyTotals.suffix(min(6, monthlyTotals.count)))
        guard recentMonths.count >= 2 else { return .stable }
        
        // Calculate month-over-month changes
        var changes: [Double] = []
        for i in 1..<recentMonths.count {
            if recentMonths[i-1] > 0 {
                let changePercent = (recentMonths[i] - recentMonths[i-1]) / recentMonths[i-1]
                changes.append(changePercent)
            }
        }
        
        guard !changes.isEmpty else { return .stable }
        
        // Calculate average change and volatility
        let averageChange = changes.reduce(0, +) / Double(changes.count)
        let variance = changes.map { pow($0 - averageChange, 2) }.reduce(0, +) / Double(changes.count)
        let volatility = sqrt(variance)
        
        // Determine trend based on thresholds
        let significantChangeThreshold = 0.10 // 10% change
        let volatilityThreshold = 0.20 // 20% volatility
        
        if volatility > volatilityThreshold {
            return .volatile
        } else if averageChange > significantChangeThreshold {
            return .increasing
        } else if averageChange < -significantChangeThreshold {
            return .decreasing
        } else {
            return .stable
        }
    }
}

