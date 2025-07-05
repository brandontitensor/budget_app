//
//  BudgetViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//  Enhanced version with comprehensive error handling, Swift 6 compliance, and performance monitoring
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
    
    public struct BudgetSummary: Sendable {
        public let totalYearlyBudget: Double
        public let totalMonthlyBudget: Double
        public let categoryCount: Int
        public let averageMonthlyBudget: Double
        public let largestCategory: String?
        public let smallestCategory: String?
        public let lastUpdated: Date
        
        public var isValid: Bool {
            totalMonthlyBudget >= 0 && categoryCount >= 0
        }
        
        public var formattedYearlyBudget: String {
            String(format: "$%.2f", totalYearlyBudget)
        }
        
        public var formattedMonthlyBudget: String {
            String(format: "$%.2f", totalMonthlyBudget)
        }
        
        public var formattedAverageBudget: String {
            String(format: "$%.2f", averageMonthlyBudget)
        }
    }
    
    public struct CategoryValidation: Sendable {
        public let isValid: Bool
        public let errors: [String]
        public let warnings: [String]
        
        public var hasErrors: Bool { !errors.isEmpty }
        public var hasWarnings: Bool { !warnings.isEmpty }
        public var hasIssues: Bool { hasErrors || hasWarnings }
        
        public static let valid = CategoryValidation(isValid: true, errors: [], warnings: [])
    }
    
    public struct BudgetAnalytics: Sendable {
        public let monthlyVariance: Double
        public let categoryDistribution: [String: Double]
        public let seasonalTrends: [String: Double]
        public let budgetUtilization: Double
        public let recommendedAdjustments: [String]
        
        public var hasRecommendations: Bool {
            !recommendedAdjustments.isEmpty
        }
    }
    
    public struct BudgetExportData: Codable, Sendable {
        public let monthlyBudgets: [String: [String: Double]] // Convert Int keys to String for JSON
        public let summary: ExportSummary
        public let exportDate: Date
        public let appVersion: String
        public let dataVersion: String
        
        public struct ExportSummary: Codable, Sendable {
            public let totalCategories: Int
            public let totalYearlyBudget: Double
            public let averageMonthlyBudget: Double
        }
        
        public init(from viewModel: BudgetViewModel) {
            // Convert Int keys to String for JSON compatibility
            self.monthlyBudgets = Dictionary(
                uniqueKeysWithValues: viewModel.monthlyBudgets.map { (String($0.key), $0.value) }
            )
            
            self.summary = ExportSummary(
                totalCategories: viewModel.categoryCount,
                totalYearlyBudget: viewModel.totalYearlyBudget,
                averageMonthlyBudget: viewModel.budgetSummary?.averageMonthlyBudget ?? 0
            )
            
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
        // Use default instances if not provided to avoid main actor issues
        self.budgetManager = budgetManager ?? BudgetManagerMock()
        self.errorHandler = errorHandler ?? ErrorHandlerMock()
        self.themeManager = themeManager ?? ThemeManagerMock()
        
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
                let budgets = await self.budgetManager.getMonthlyBudgets(for: month, year: self.selectedYear)
                newBudgets[month] = Dictionary(
                    uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) }
                )
            }
            
            await MainActor.run { [weak self] in
                self?.monthlyBudgets = newBudgets
                self?.updateBudgetSummary()
                self?.updateBudgetAnalytics()
                self?.updateViewState()
                self?.hasUnsavedChanges = false
            }
            
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
            
            await MainActor.run { [weak self] in
                self?.hasUnsavedChanges = false
                self?.lastSaveDate = Date()
            }
            
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
            await MainActor.run { [weak self] in
                guard let self = self else { return }
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
            }
            
            print("✅ BudgetViewModel: Added category '\(trimmedName)' with amount \(self.newCategoryAmount)")
        }
    }
    
    /// Update category amount for a specific month
    public func updateCategory(_ categoryName: String, amount: Double, month: Int? = nil) async {
        let targetMonth = month ?? selectedMonth
        
        await performOperation(.updateCategory) {
            guard amount >= 0 else {
                throw AppError.validation(message: "Amount cannot be negative")
            }
            
            await MainActor.run { [weak self] in
                self?.monthlyBudgets[targetMonth, default: [:]][categoryName] = amount
                self?.hasUnsavedChanges = true
                self?.updateBudgetSummary()
                self?.updateBudgetAnalytics()
            }
            
            print("✅ BudgetViewModel: Updated '\(categoryName)' to \(amount) for month \(targetMonth)")
        }
    }
    
    /// Delete a category
    public func deleteCategory(_ categoryName: String, fromAllMonths: Bool = false) async {
        await performOperation(.deleteCategory) {
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                if fromAllMonths {
                    // Remove from all months
                    for month in self.monthlyBudgets.keys {
                        self.monthlyBudgets[month]?.removeValue(forKey: categoryName)
                    }
                } else {
                    // Remove from current month only
                    self.monthlyBudgets[self.selectedMonth]?.removeValue(forKey: categoryName)
                }
                
                self.hasUnsavedChanges = true
                self.updateBudgetSummary()
                self.updateBudgetAnalytics()
            }
            
            print("✅ BudgetViewModel: Deleted category '\(categoryName)'")
        }
    }
    
    /// Validate a new category
    public func validateNewCategory() -> CategoryValidation {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        var errors: [String] = []
        var warnings: [String] = []
        
        // Name validation
        if trimmedName.isEmpty {
            errors.append("Category name cannot be empty")
        } else if trimmedName.count > 50 {
            errors.append("Category name cannot exceed 50 characters")
        } else if currentMonthCategories.contains(where: { $0.lowercased() == trimmedName.lowercased() }) {
            errors.append("Category '\(trimmedName)' already exists")
        }
        
        // Amount validation
        if newCategoryAmount < 0 {
            errors.append("Amount cannot be negative")
        } else if newCategoryAmount == 0 {
            warnings.append("Amount is zero - category will not contribute to budget")
        } else if newCategoryAmount > 10000 {
            warnings.append("Large amount - please verify this is correct")
        }
        
        return CategoryValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
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
            // Convert String keys back to Int
            let importedBudgets = Dictionary(
                uniqueKeysWithValues: data.monthlyBudgets.compactMap { (stringKey, value) in
                    guard let intKey = Int(stringKey) else { return nil }
                    return (intKey, value)
                }
            )
            
            await MainActor.run { [weak self] in
                self?.monthlyBudgets = importedBudgets
                self?.hasUnsavedChanges = true
                self?.updateBudgetSummary()
                self?.updateBudgetAnalytics()
                self?.updateViewState()
            }
            
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
        _ block: @escaping () async throws -> T
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
        let average = count > 0 ? totalMonthly / Double(count) : 0
        
        let categories = monthlyBudgets[selectedMonth, default: [:]]
        let largest = categories.max { $0.value < $1.value }?.key
        let smallest = categories.min { $0.value < $1.value }?.key
        
        budgetSummary = BudgetSummary(
            totalYearlyBudget: totalYearly,
            totalMonthlyBudget: totalMonthly,
            categoryCount: count,
            averageMonthlyBudget: average,
            largestCategory: largest,
            smallestCategory: smallest,
            lastUpdated: Date()
        )
    }
    
    private func updateBudgetAnalytics() {
        let monthlyAmounts = monthlyBudgets.values.map { $0.values.reduce(0, +) }
        let variance = calculateVariance(monthlyAmounts)
        
        let allCategories = monthlyBudgets.values.flatMap { $0.keys }
        let uniqueCategories = Set(allCategories)
        let distribution = Dictionary(uniqueKeysWithValues: uniqueCategories.map { category in
            let total = monthlyBudgets.values.compactMap { $0[category] }.reduce(0, +)
            return (category, total)
        })
        
        var recommendations: [String] = []
        if variance > 1000 {
            recommendations.append("Consider evening out monthly budget allocations")
        }
        if categoryCount > 15 {
            recommendations.append("Consider consolidating similar categories")
        }
        if totalMonthlyBudget == 0 {
            recommendations.append("Set up your first budget categories")
        }
        
        budgetAnalytics = BudgetAnalytics(
            monthlyVariance: variance,
            categoryDistribution: distribution,
            seasonalTrends: [:], // Could implement seasonal analysis
            budgetUtilization: calculateUtilization(),
            recommendedAdjustments: recommendations
        )
    }
    
    private func validateNewCategoryInput() {
        let validation = validateNewCategory()
        
        if validation.hasErrors {
            validationErrors["newCategory"] = validation.errors
        } else {
            validationErrors.removeValue(forKey: "newCategory")
        }
        
        if validation.hasWarnings {
            validationErrors["newCategoryWarnings"] = validation.warnings
        } else {
            validationErrors.removeValue(forKey: "newCategoryWarnings")
        }
    }
    
    private func validateAllBudgets() throws {
        for (month, budgets) in monthlyBudgets {
            for (category, amount) in budgets {
                if amount < 0 {
                    throw AppError.validation(message: "Negative amount found in \(category) for month \(month)")
                }
                if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw AppError.validation(message: "Empty category name found for month \(month)")
                }
            }
        }
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count - 1)
    }
    
    private func calculateUtilization() -> Double {
        // This would compare actual spending vs budget
        // For now, return a placeholder
        return 0.75
    }
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async { [weak self] in
            self?.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ BudgetViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = self.operationMetrics
            if !metrics.isEmpty {
                print("📊 BudgetViewModel Performance Metrics:")
                for (operation, duration) in metrics.sorted(by: { $0.value > $1.value }) {
                    print("  \(operation): \(String(format: "%.2f", duration * 1000))ms")
                }
            }
        }
    }
}

// MARK: - Mock Dependencies (for standalone compilation)

// These mocks allow the ViewModel to compile independently
// Replace with actual implementations when integrating

private class BudgetManagerMock {
    func getMonthlyBudgets(for month: Int, year: Int) async -> [(category: String, amount: Double)] {
        return []
    }
    
    func updateMonthlyBudgets(_ budgets: [String: Double], for month: Int, year: Int) async throws {
        // Mock implementation
    }
}

private class ErrorHandlerMock {
    func handle(_ error: AppError, context: String) {
        print("🚨 Error: \(error) in \(context)")
    }
}

private class ThemeManagerMock {
    // Mock theme manager
}



// MARK: - Testing Support

#if DEBUG
extension BudgetViewModel {
    /// Create a test view model with mock data
    public static func createTestViewModel() -> BudgetViewModel {
        let viewModel = BudgetViewModel()
        
        Task {
            await viewModel.loadTestData()
        }
        
        return viewModel
    }
    
    /// Load test data for development and previews
    public func loadTestData() async {
        monthlyBudgets = [
            1: ["Groceries": 500.0, "Transportation": 200.0, "Entertainment": 150.0],
            2: ["Groceries": 500.0, "Transportation": 200.0, "Entertainment": 150.0],
            3: ["Groceries": 550.0, "Transportation": 200.0, "Entertainment": 100.0],
            4: ["Groceries": 500.0, "Transportation": 250.0, "Entertainment": 150.0],
            5: ["Groceries": 600.0, "Transportation": 200.0, "Entertainment": 200.0],
            6: ["Groceries": 500.0, "Transportation": 200.0, "Entertainment": 150.0]
        ]
        
        updateBudgetSummary()
        updateBudgetAnalytics()
        updateViewState()
        
        print("✅ BudgetViewModel: Loaded test data")
    }
    
    /// Get internal state for testing
    public func getInternalStateForTesting() -> (
        hasUnsavedChanges: Bool,
        isProcessing: Bool,
        validationErrorCount: Int,
        metricsCount: Int
    ) {
        return metricsQueue.sync {
            return (
                hasUnsavedChanges: hasUnsavedChanges,
                isProcessing: isProcessing,
                validationErrorCount: validationErrors.count,
                metricsCount: operationMetrics.count
            )
        }
    }
    
    /// Force validation update for testing
    public func forceValidationUpdateForTesting() {
        validateNewCategoryInput()
    }
    
    /// Get performance metrics for testing
    public func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Simulate error for testing
    public func simulateErrorForTesting(_ error: AppError) {
        viewState = .error(error)
        errorHandler.handle(error, context: "Testing simulation")
    }
    
    /// Reset state for testing
    public func resetStateForTesting() {
        viewState = .idle
        currentOperation = nil
        monthlyBudgets = [:]
        budgetSummary = nil
        budgetAnalytics = nil
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
