//
//  BudgetViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//


import Foundation
import SwiftUI
import Combine

/// ViewModel for managing budget operations with enhanced error handling and state management
@MainActor
public final class BudgetViewModel: ObservableObject {
    // MARK: - Types
    public enum ViewState {
        case idle
        case loading
        case loaded
        case empty
        case error(AppError)
        
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
    }
    
    public enum OperationType {
        case loadBudgets
        case saveBudgets
        case addCategory
        case updateCategory
        case deleteCategory
        case validateCategory
        
        var description: String {
            switch self {
            case .loadBudgets: return "Loading budgets"
            case .saveBudgets: return "Saving budgets"
            case .addCategory: return "Adding category"
            case .updateCategory: return "Updating category"
            case .deleteCategory: return "Deleting category"
            case .validateCategory: return "Validating category"
            }
        }
    }
    
    public struct BudgetSummary {
        let totalYearlyBudget: Double
        let totalMonthlyBudget: Double
        let categoryCount: Int
        let averageMonthlyBudget: Double
        let largestCategory: String?
        let smallestCategory: String?
        
        var isValid: Bool {
            totalMonthlyBudget >= 0 && categoryCount >= 0
        }
        
        var formattedYearlyBudget: String {
            totalYearlyBudget.asCurrency
        }
        
        var formattedMonthlyBudget: String {
            totalMonthlyBudget.asCurrency
        }
    }
    
    public struct CategoryValidation {
        let isValid: Bool
        let errors: [String]
        let warnings: [String]
        
        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }
        var hasIssues: Bool { hasErrors || hasWarnings }
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
    @Published public private(set) var lastSaveDate: Date?
    @Published public private(set) var hasUnsavedChanges = false
    @Published public private(set) var validationErrors: [String: [String]] = [:]
    
    // MARK: - Input Properties
    @Published public var selectedYear: Int
    @Published public var selectedMonth: Int
    @Published public var newCategoryName = ""
    @Published public var newCategoryAmount: Double = 0
    
    // MARK: - Computed Properties
    public var isProcessing: Bool {
        currentOperation != nil || viewState.isLoading
    }
    
    public var canSave: Bool {
        hasUnsavedChanges && !isProcessing && viewState != .error("")
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
    
    public var isValidNewCategory: Bool {
        validateNewCategory().isValid
    }
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.budgetvm.metrics", qos: .utility)
    
    // MARK: - Initialization
    public init(
        budgetManager: BudgetManager = BudgetManager.shared,
        errorHandler: ErrorHandler = ErrorHandler.shared,
        themeManager: ThemeManager = ThemeManager.shared
    ) {
        self.budgetManager = budgetManager
        self.errorHandler = errorHandler
        self.themeManager = themeManager
        
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
                let budgets = budgetManager.getMonthlyBudgets(for: month, year: selectedYear)
                newBudgets[month] = Dictionary(
                    uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) }
                )
            }
            
            monthlyBudgets = newBudgets
            updateBudgetSummary()
            updateViewState()
            hasUnsavedChanges = false
            
            print("✅ BudgetViewModel: Loaded budgets for \(selectedYear)")
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
            try validateAllBudgets()
            
            // Save each month's budgets
            for (month, budgets) in monthlyBudgets {
                try await budgetManager.updateMonthlyBudgets(
                    budgets,
                    for: month,
                    year: selectedYear
                )
            }
            
            hasUnsavedChanges = false
            lastSaveDate = Date()
            
            print("✅ BudgetViewModel: Saved budgets for \(selectedYear)")
        }
    }
    
    /// Add a new category
    public func addCategory(includeFutureMonths: Bool = false) async {
        await performOperation(.addCategory) {
            let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate the new category
            let validation = validateNewCategory()
            guard validation.isValid else {
                throw AppError.validation(message: validation.errors.first ?? "Invalid category")
            }
            
            // Add to budget manager
            try await budgetManager.addCategory(
                trimmedName,
                amount: newCategoryAmount,
                month: selectedMonth,
                year: selectedYear,
                includeFutureMonths: includeFutureMonths
            )
            
            // Update local state
            if includeFutureMonths {
                for month in selectedMonth...12 {
                    monthlyBudgets[month, default: [:]][trimmedName] = newCategoryAmount
                }
            } else {
                monthlyBudgets[selectedMonth, default: [:]][trimmedName] = newCategoryAmount
            }
            
            resetNewCategoryFields()
            markAsChanged()
            updateBudgetSummary()
            
            print("✅ BudgetViewModel: Added category '\(trimmedName)' with amount \(newCategoryAmount.asCurrency)")
        }
    }
    
    /// Update an existing category
    public func updateCategory(
        oldName: String,
        newName: String,
        newAmount: Double,
        applyToFutureMonths: Bool = false
    ) async {
        await performOperation(.updateCategory) {
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate the update
            try validateCategoryUpdate(oldName: oldName, newName: trimmedName, amount: newAmount)
            
            // Update local state
            let monthsToUpdate = applyToFutureMonths ? Array(selectedMonth...12) : [selectedMonth]
            
            for month in monthsToUpdate {
                var budget = monthlyBudgets[month, default: [:]]
                budget.removeValue(forKey: oldName)
                if newAmount > 0 {
                    budget[trimmedName] = newAmount
                }
                monthlyBudgets[month] = budget
            }
            
            markAsChanged()
            updateBudgetSummary()
            
            print("✅ BudgetViewModel: Updated category '\(oldName)' to '\(trimmedName)' with amount \(newAmount.asCurrency)")
        }
    }
    
    /// Delete a category
    public func deleteCategory(
        _ categoryName: String,
        fromMonth: Int? = nil,
        includeFutureMonths: Bool = false
    ) async {
        await performOperation(.deleteCategory) {
            let month = fromMonth ?? selectedMonth
            
            // Check if category can be deleted
            guard !AppConstants.DefaultCategories.required.contains(categoryName) else {
                throw AppError.validation(message: "Cannot delete required category '\(categoryName)'")
            }
            
            // Delete from budget manager
            try await budgetManager.deleteMonthlyBudget(
                category: categoryName,
                fromMonth: month,
                year: selectedYear,
                includeFutureMonths: includeFutureMonths
            )
            
            // Update local state
            let monthsToUpdate = includeFutureMonths ? Array(month...12) : [month]
            
            for monthToUpdate in monthsToUpdate {
                monthlyBudgets[monthToUpdate]?.removeValue(forKey: categoryName)
            }
            
            markAsChanged()
            updateBudgetSummary()
            
            print("✅ BudgetViewModel: Deleted category '\(categoryName)'")
        }
    }
    
    /// Change selected year
    public func changeYear(_ newYear: Int) async {
        guard newYear != selectedYear else { return }
        
        selectedYear = newYear
        await loadBudgets()
        
        print("📅 BudgetViewModel: Changed year to \(newYear)")
    }
    
    /// Change selected month
    public func changeMonth(_ newMonth: Int) {
        guard newMonth != selectedMonth else { return }
        guard (1...12).contains(newMonth) else { return }
        
        selectedMonth = newMonth
        updateBudgetSummary()
        
        print("📅 BudgetViewModel: Changed month to \(newMonth)")
    }
    
    /// Load current year's budget into future year
    public func loadCurrentYearBudget() async {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard currentYear != selectedYear else { return }
        
        await performOperation(.loadBudgets) {
            for month in 1...12 {
                let currentYearBudgets = budgetManager.getMonthlyBudgets(for: month, year: currentYear)
                monthlyBudgets[month] = Dictionary(
                    uniqueKeysWithValues: currentYearBudgets.map { ($0.category, $0.amount) }
                )
            }
            
            markAsChanged()
            updateBudgetSummary()
            
            print("✅ BudgetViewModel: Loaded \(currentYear) budget into \(selectedYear)")
        }
    }
    
    /// Validate a specific category
    public func validateCategory(_ categoryName: String, amount: Double) -> CategoryValidation {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Name validation
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Category name cannot be empty")
        } else if trimmedName.count > AppConstants.Validation.maxCategoryNameLength {
            errors.append("Category name is too long (max \(AppConstants.Validation.maxCategoryNameLength) characters)")
        }
        
        // Amount validation
        if amount < 0 {
            errors.append("Amount cannot be negative")
        } else if amount > AppConstants.Validation.maximumTransactionAmount {
            errors.append("Amount exceeds maximum limit of \(AppConstants.Validation.maximumTransactionAmount.asCurrency)")
        } else if amount == 0 {
            warnings.append("Amount is zero - category will be inactive")
        }
        
        // Duplicate name check
        if monthlyBudgets[selectedMonth]?.keys.contains(trimmedName) == true {
            errors.append("A category with this name already exists")
        }
        
        // Required category check
        if AppConstants.DefaultCategories.required.contains(trimmedName) && amount == 0 {
            warnings.append("This is a required category")
        }
        
        return CategoryValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// Get budget data for a specific month
    public func getBudgetForMonth(_ month: Int) -> [String: Double] {
        return monthlyBudgets[month, default: [:]]
    }
    
    /// Get formatted month name
    public func monthName(_ month: Int) -> String {
        let calendar = Calendar.current
        guard (1...12).contains(month) else { return "Invalid" }
        return calendar.monthSymbols[month - 1]
    }
    
    /// Get total budget for a specific month
    public func totalBudgetForMonth(_ month: Int) -> Double {
        return monthlyBudgets[month, default: [:]].values.reduce(0, +)
    }
    
    /// Reset new category fields
    public func resetNewCategoryFields() {
        newCategoryName = ""
        newCategoryAmount = 0
    }
    
    /// Get validation errors for UI display
    public func getValidationErrorsForCategory(_ categoryName: String) -> [String] {
        return validationErrors[categoryName] ?? []
    }
    
    /// Check if there are any validation issues
    public var hasValidationIssues: Bool {
        !validationErrors.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor budget manager changes
        budgetManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                Task { [weak self] in
                    await self?.refreshBudgets()
                }
            }
            .store(in: &cancellables)
        
        // Monitor new category input changes
        $newCategoryName
            .combineLatest($newCategoryAmount)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.validateNewCategoryInput()
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
    
    private func performOperation<T>(
        _ operation: OperationType,
        _ block: @escaping () async throws -> T
    ) async {
        let startTime = Date()
        currentOperation = operation
        
        if viewState != .loading {
            viewState = .loading
        }
        
        let result = await AsyncErrorHandler.execute(
            context: operation.description,
            errorTransform: { error in
                AppError.from(error)
            }
        ) {
            try await block()
        }
        
        currentOperation = nil
        
        if result != nil {
            if case .error = viewState {
                updateViewState() // Clear error state on success
            }
        } else if let latestError = errorHandler.errorHistory.first?.error {
            viewState = .error(latestError)
        }
        
        recordMetric(operation.description, duration: Date().timeIntervalSince(startTime))
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
        let average = count > 0 ? totalYearly / 12.0 : 0
        
        let currentMonthBudgets = monthlyBudgets[selectedMonth, default: [:]]
        let largest = currentMonthBudgets.max(by: { $0.value < $1.value })?.key
        let smallest = currentMonthBudgets.min(by: { $0.value < $1.value })?.key
        
        budgetSummary = BudgetSummary(
            totalYearlyBudget: totalYearly,
            totalMonthlyBudget: totalMonthly,
            categoryCount: count,
            averageMonthlyBudget: average,
            largestCategory: largest,
            smallestCategory: smallest
        )
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
    }
    
    private func validateNewCategory() -> CategoryValidation {
        return validateCategory(newCategoryName, amount: newCategoryAmount)
    }
    
    private func validateNewCategoryInput() {
        let validation = validateNewCategory()
        
        // Update validation errors
        if validation.hasIssues {
            validationErrors["newCategory"] = validation.errors + validation.warnings
        } else {
            validationErrors.removeValue(forKey: "newCategory")
        }
    }
    
    private func validateCategoryUpdate(oldName: String, newName: String, amount: Double) throws {
        // Basic validation
        let validation = validateCategory(newName, amount: amount)
        
        if validation.hasErrors {
            throw AppError.validation(message: validation.errors.joined(separator: ", "))
        }
        
        // Check if rename conflicts with existing category (unless it's the same category)
        if newName != oldName && monthlyBudgets[selectedMonth]?.keys.contains(newName) == true {
            throw AppError.validation(message: "A category with the name '\(newName)' already exists")
        }
    }
    
    private func validateAllBudgets() throws {
        var allErrors: [String] = []
        
        for (month, budgets) in monthlyBudgets {
            for (category, amount) in budgets {
                let validation = validateCategory(category, amount: amount)
                if validation.hasErrors {
                    allErrors.append("Month \(month), \(category): \(validation.errors.joined(separator: ", "))")
                }
            }
        }
        
        if !allErrors.isEmpty {
            throw AppError.validation(message: "Validation errors: \(allErrors.joined(separator: "; "))")
        }
    }
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ BudgetViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 BudgetViewModel Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        cancellables.removeAll()
        print("🧹 BudgetViewModel: Cleaned up resources")
    }
}

// MARK: - Public Extensions

extension BudgetViewModel {
    /// Get analytics data for the current budgets
    public func getAnalytics() -> BudgetAnalytics {
        let allBudgets = monthlyBudgets.values.flatMap { $0.values }
        let totalAmount = allBudgets.reduce(0, +)
        let averageAmount = allBudgets.isEmpty ? 0 : totalAmount / Double(allBudgets.count)
        
        let categoryDistribution = Dictionary(grouping: monthlyBudgets.values.flatMap { $0 }) { $0.key }
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        
        return BudgetAnalytics(
            totalBudget: totalAmount,
            averageCategoryBudget: averageAmount,
            categoryCount: availableCategories.count,
            monthlyDistribution: monthlyBudgets.mapValues { $0.values.reduce(0, +) },
            categoryDistribution: categoryDistribution,
            largestCategory: categoryDistribution.max(by: { $0.value < $1.value }),
            smallestCategory: categoryDistribution.min(by: { $0.value < $1.value })
        )
    }
    
    /// Export budget data for backup or sharing
    public func exportBudgetData() -> BudgetExportData {
        return BudgetExportData(
            year: selectedYear,
            monthlyBudgets: monthlyBudgets,
            exportDate: Date(),
            summary: budgetSummary
        )
    }
    
    /// Import budget data from backup
    public func importBudgetData(_ data: BudgetExportData) async {
        await performOperation(.loadBudgets) {
            monthlyBudgets = data.monthlyBudgets
            selectedYear = data.year
            markAsChanged()
            updateBudgetSummary()
            updateViewState()
            
            print("✅ BudgetViewModel: Imported budget data for \(data.year)")
        }
    }
}

// MARK: - Supporting Types

public struct BudgetAnalytics {
    public let totalBudget: Double
    public let averageCategoryBudget: Double
    public let categoryCount: Int
    public let monthlyDistribution: [Int: Double]
    public let categoryDistribution: [String: Double]
    public let largestCategory: (key: String, value: Double)?
    public let smallestCategory: (key: String, value: Double)?
    
    public var isBalanced: Bool {
        guard let largest = largestCategory?.value,
              let smallest = smallestCategory?.value,
              smallest > 0 else { return false }
        
        return largest / smallest <= 10.0 // Less than 10x difference
    }
    
    public var monthlyVariation: Double {
        let values = Array(monthlyDistribution.values)
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

public struct BudgetExportData: Codable {
    public let year: Int
    public let monthlyBudgets: [Int: [String: Double]]
    public let exportDate: Date
    public let summary: BudgetViewModel.BudgetSummary?
    
    public var formattedExportDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: exportDate)
    }
}

// MARK: - Testing Support

#if DEBUG
extension BudgetViewModel {
    /// Create a test view model with mock data
    static func createTestViewModel() -> BudgetViewModel {
        let viewModel = BudgetViewModel()
        
        // Add some test data
        Task {
            await viewModel.loadTestData()
        }
        
        return viewModel
    }
    
    /// Load test data for development and previews
    func loadTestData() async {
        monthlyBudgets = [
            1: ["Groceries": 500.0, "Transportation": 200.0, "Entertainment": 150.0],
            2: ["Groceries": 500.0, "Transportation": 200.0, "Entertainment": 150.0],
            3: ["Groceries": 550.0, "Transportation": 200.0, "Entertainment": 100.0]
        ]
        
        updateBudgetSummary()
        updateViewState()
        
        print("✅ BudgetViewModel: Loaded test data")
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        hasUnsavedChanges: Bool,
        isProcessing: Bool,
        validationErrorCount: Int,
        metricsCount: Int
    ) {
        return (
            hasUnsavedChanges: hasUnsavedChanges,
            isProcessing: isProcessing,
            validationErrorCount: validationErrors.count,
            metricsCount: operationMetrics.count
        )
    }
    
    /// Force validation update for testing
    func forceValidationUpdateForTesting() {
        validateNewCategoryInput()
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Simulate error for testing
    func simulateErrorForTesting(_ error: AppError) {
        viewState = .error(error)
        errorHandler.handle(error, context: "Testing simulation")
    }
    
    /// Reset state for testing
    func resetStateForTesting() {
        viewState = .idle
        currentOperation = nil
        monthlyBudgets = [:]
        budgetSummary = nil
        lastSaveDate = nil
        hasUnsavedChanges = false
        validationErrors = [:]
        resetNewCategoryFields()
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
        
        print("🧪 BudgetViewModel: Reset state for testing")
    }
}
#endif
