//
//  OverviewViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for the BudgetOverviewView with comprehensive state management and error handling
@MainActor
public final class OverviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var loadingState: LoadingState = .idle
    @Published public private(set) var budgetSummary: BudgetSummaryData?
    @Published public private(set) var spendingData: [SpendingData] = []
    @Published public private(set) var recentTransactions: [BudgetEntry] = []
    @Published public private(set) var categoryBreakdown: [CategoryBreakdown] = []
    @Published public private(set) var lastRefreshDate: Date?
    @Published public private(set) var currentError: AppError?
    @Published public var selectedTimeframe: TimePeriod = .thisMonth
    @Published public var selectedSpendingCategory: SpendingData?
    
    // MARK: - Types
    public enum LoadingState: Equatable {
        case idle
        case loading
        case refreshing
        case loadingComponent(ComponentType)
        case loaded
        case failed(AppError)
        
        public enum ComponentType: String, CaseIterable {
            case summary = "summary"
            case transactions = "transactions"
            case spending = "spending"
            case categories = "categories"
            
            public var displayName: String {
                switch self {
                case .summary: return "Budget Summary"
                case .transactions: return "Recent Transactions"
                case .spending: return "Spending Data"
                case .categories: return "Categories"
                }
            }
        }
        
        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing, .loadingComponent: return true
            default: return false
            }
        }
        
        public var hasError: Bool {
            if case .failed = self { return true }
            return false
        }
        
        public var errorMessage: String? {
            if case .failed(let error) = self {
                return error.errorDescription
            }
            return nil
        }
    }
    
    public struct BudgetSummaryData: Equatable {
        public let totalBudgeted: Double
        public let totalSpent: Double
        public let remainingBudget: Double
        public let percentageUsed: Double
        public let categoryCount: Int
        public let transactionCount: Int
        public let isOverBudget: Bool
        public let lastUpdated: Date
        public let timeframe: TimePeriod
        
        public var statusColor: Color {
            if isOverBudget {
                return .red
            } else if percentageUsed > 0.9 {
                return .orange
            } else if percentageUsed > 0.7 {
                return .yellow
            } else {
                return .green
            }
        }
        
        public var statusMessage: String {
            if isOverBudget {
                let overAmount = totalSpent - totalBudgeted
                return "Over budget by \(overAmount.asCurrency)"
            } else if remainingBudget <= 0 {
                return "Budget fully used"
            } else {
                return "\(remainingBudget.asCurrency) remaining"
            }
        }
        
        public var progressPercentage: Double {
            return min(percentageUsed, 1.0)
        }
        
        public var healthScore: Double {
            if isOverBudget {
                return 0.0
            } else if percentageUsed <= 0.7 {
                return 1.0
            } else if percentageUsed <= 0.9 {
                return 0.7
            } else {
                return 0.3
            }
        }
        
        public init(
            totalBudgeted: Double,
            totalSpent: Double,
            categoryCount: Int,
            transactionCount: Int,
            timeframe: TimePeriod
        ) {
            self.totalBudgeted = max(0, totalBudgeted)
            self.totalSpent = max(0, totalSpent)
            self.remainingBudget = totalBudgeted - totalSpent
            self.percentageUsed = totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0
            self.categoryCount = max(0, categoryCount)
            self.transactionCount = max(0, transactionCount)
            self.isOverBudget = totalSpent > totalBudgeted
            self.lastUpdated = Date()
            self.timeframe = timeframe
        }
    }
    
    public struct CategoryBreakdown: Identifiable, Equatable {
        public let id = UUID()
        public let category: String
        public let spent: Double
        public let budgeted: Double
        public let percentage: Double
        public let color: Color
        public let transactionCount: Int
        
        public var isOverBudget: Bool {
            spent > budgeted
        }
        
        public var remaining: Double {
            budgeted - spent
        }
        
        public var efficiency: Double {
            guard budgeted > 0 else { return 0 }
            return min(spent / budgeted, 1.0)
        }
        
        public var status: Status {
            if isOverBudget {
                return .overBudget
            } else if percentage > 90 {
                return .nearLimit
            } else if percentage > 70 {
                return .moderate
            } else {
                return .onTrack
            }
        }
        
        public enum Status: String, CaseIterable {
            case onTrack = "On Track"
            case moderate = "Moderate"
            case nearLimit = "Near Limit"
            case overBudget = "Over Budget"
            
            public var color: Color {
                switch self {
                case .onTrack: return .green
                case .moderate: return .yellow
                case .nearLimit: return .orange
                case .overBudget: return .red
                }
            }
            
            public var systemImageName: String {
                switch self {
                case .onTrack: return "checkmark.circle.fill"
                case .moderate: return "exclamationmark.circle"
                case .nearLimit: return "exclamationmark.triangle.fill"
                case .overBudget: return "xmark.circle.fill"
                }
            }
        }
    }
    
    public struct DataMetrics {
        public let totalCategories: Int
        public let totalTransactions: Int
        public let averageTransactionAmount: Double
        public let topSpendingCategory: String?
        public let spendingTrend: SpendingTrend
        public let lastUpdateTime: Date
        
        public enum SpendingTrend: String, CaseIterable {
            case increasing = "Increasing"
            case stable = "Stable"
            case decreasing = "Decreasing"
            case insufficient = "Insufficient Data"
            
            public var color: Color {
                switch self {
                case .increasing: return .red
                case .stable: return .blue
                case .decreasing: return .green
                case .insufficient: return .gray
                }
            }
            
            public var systemImageName: String {
                switch self {
                case .increasing: return "arrow.up.right"
                case .stable: return "arrow.right"
                case .decreasing: return "arrow.down.right"
                case .insufficient: return "questionmark"
                }
            }
        }
    }
    
    // MARK: - Private Properties
    private let budgetManager: BudgetManager
    private let themeManager: ThemeManager
    private let errorHandler: ErrorHandler
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentTransactions = 5
    private let dataRefreshInterval: TimeInterval = 300 // 5 minutes
    private var refreshTimer: Timer?
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.overview.metrics", qos: .utility)
    
    // MARK: - Initialization
    public init(
        budgetManager: BudgetManager = .shared,
        themeManager: ThemeManager = .shared,
        errorHandler: ErrorHandler = .shared
    ) {
        self.budgetManager = budgetManager
        self.themeManager = themeManager
        self.errorHandler = errorHandler
        
        setupBindings()
        setupPerformanceMonitoring()
        print("✅ OverviewViewModel: Initialized successfully")
    }
    
    // MARK: - Public Methods
    
    /// Load initial data for the overview
    public func loadInitialData() async {
        let startTime = Date()
        
        guard !loadingState.isLoading else { return }
        
        await MainActor.run {
            loadingState = .loading
            currentError = nil
        }
        
        do {
            // Load all data concurrently
            async let summaryTask = loadBudgetSummary()
            async let transactionsTask = loadRecentTransactions()
            async let spendingTask = loadSpendingData()
            async let categoriesTask = loadCategoryBreakdown()
            
            let _ = try await (summaryTask, transactionsTask, spendingTask, categoriesTask)
            
            await MainActor.run {
                loadingState = .loaded
                lastRefreshDate = Date()
                currentError = nil
            }
            
            recordMetric("loadInitialData", duration: Date().timeIntervalSince(startTime))
            print("✅ OverviewViewModel: Initial data loaded successfully")
            
        } catch {
            await handleError(AppError.from(error), context: "Loading initial data")
        }
    }
    
    /// Refresh all data
    public func refreshData() async {
        let startTime = Date()
        
        await MainActor.run {
            loadingState = .refreshing
            currentError = nil
        }
        
        do {
            // Load all data concurrently
            async let summaryTask = loadBudgetSummary()
            async let transactionsTask = loadRecentTransactions()
            async let spendingTask = loadSpendingData()
            async let categoriesTask = loadCategoryBreakdown()
            
            let _ = try await (summaryTask, transactionsTask, spendingTask, categoriesTask)
            
            await MainActor.run {
                loadingState = .loaded
                lastRefreshDate = Date()
                currentError = nil
            }
            
            recordMetric("refreshData", duration: Date().timeIntervalSince(startTime))
            print("✅ OverviewViewModel: Data refreshed successfully")
            
        } catch {
            await handleError(AppError.from(error), context: "Refreshing data")
        }
    }
    
    /// Load data for a specific timeframe
    public func loadDataForTimeframe(_ timeframe: TimePeriod) async {
        let startTime = Date()
        
        guard selectedTimeframe != timeframe || budgetSummary?.timeframe != timeframe else {
            return // Already loaded for this timeframe
        }
        
        await MainActor.run {
            selectedTimeframe = timeframe
            loadingState = .loading
        }
        
        do {
            // Load data for the new timeframe
            async let summaryTask = loadBudgetSummary()
            async let transactionsTask = loadRecentTransactions()
            async let spendingTask = loadSpendingData()
            async let categoriesTask = loadCategoryBreakdown()
            
            let _ = try await (summaryTask, transactionsTask, spendingTask, categoriesTask)
            
            await MainActor.run {
                loadingState = .loaded
                lastRefreshDate = Date()
            }
            
            recordMetric("loadDataForTimeframe", duration: Date().timeIntervalSince(startTime))
            print("✅ OverviewViewModel: Data loaded for timeframe: \(timeframe.displayName)")
            
        } catch {
            await handleError(AppError.from(error), context: "Loading data for timeframe")
        }
    }
    
    /// Get data metrics and insights
    public func getDataMetrics() -> DataMetrics {
        let totalCategories = Set(recentTransactions.map { $0.category }).count
        let totalTransactions = recentTransactions.count
        let averageAmount = totalTransactions > 0 ? 
            recentTransactions.reduce(0) { $0 + $1.amount } / Double(totalTransactions) : 0
        
        let topCategory = spendingData.max(by: { $0.amount < $1.amount })?.category
        
        // Simple trend calculation based on recent vs older transactions
        let trend: DataMetrics.SpendingTrend
        if recentTransactions.count < 5 {
            trend = .insufficient
        } else {
            let recentAvg = Array(recentTransactions.prefix(3)).reduce(0) { $0 + $1.amount } / 3
            let olderAvg = Array(recentTransactions.suffix(3)).reduce(0) { $0 + $1.amount } / 3
            
            if recentAvg > olderAvg * 1.1 {
                trend = .increasing
            } else if recentAvg < olderAvg * 0.9 {
                trend = .decreasing
            } else {
                trend = .stable
            }
        }
        
        return DataMetrics(
            totalCategories: totalCategories,
            totalTransactions: totalTransactions,
            averageTransactionAmount: averageAmount,
            topSpendingCategory: topCategory,
            spendingTrend: trend,
            lastUpdateTime: lastRefreshDate ?? Date()
        )
    }
    
    /// Clear all data
    public func clearData() {
        loadingState = .idle
        budgetSummary = nil
        spendingData = []
        recentTransactions = []
        categoryBreakdown = []
        selectedSpendingCategory = nil
        currentError = nil
        lastRefreshDate = nil
    }
    
    /// Handle selection of spending category
    public func selectSpendingCategory(_ category: SpendingData?) {
        selectedSpendingCategory = category
    }
    
    /// Check if data needs refresh
    public func needsDataRefresh() -> Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        return Date().timeIntervalSince(lastRefresh) > dataRefreshInterval
    }
    
    /// Force refresh if data is stale
    public func refreshIfNeeded() async {
        if needsDataRefresh() {
            await refreshData()
        }
    }
    
    // MARK: - Private Data Loading Methods
    
    private func loadBudgetSummary() async throws {
        await MainActor.run {
            loadingState = .loadingComponent(.summary)
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading budget summary",
            errorTransform: { .dataLoad(underlying: $0) }
        ) {
            let entries = try await self.budgetManager.getEntries(
                for: self.selectedTimeframe,
                sortedBy: .date,
                ascending: false
            )
            
            let calendar = Calendar.current
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            let budgets = self.budgetManager.getMonthlyBudgets(for: currentMonth, year: currentYear)
            
            let totalBudgeted = budgets.reduce(0) { $0 + $1.amount }
            let totalSpent = entries.reduce(0) { $0 + $1.amount }
            
            return BudgetSummaryData(
                totalBudgeted: totalBudgeted,
                totalSpent: totalSpent,
                categoryCount: budgets.count,
                transactionCount: entries.count,
                timeframe: self.selectedTimeframe
            )
        }
        
        await MainActor.run {
            if let summary = result {
                budgetSummary = summary
            }
        }
    }
    
    private func loadRecentTransactions() async throws {
        await MainActor.run {
            loadingState = .loadingComponent(.transactions)
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading recent transactions"
        ) {
            let entries = try await self.budgetManager.getEntries(
                for: self.selectedTimeframe,
                sortedBy: .date,
                ascending: false
            )
            return Array(entries.prefix(self.maxRecentTransactions))
        }
        
        await MainActor.run {
            if let transactions = result {
                recentTransactions = transactions
            }
        }
    }
    
    private func loadSpendingData() async throws {
        await MainActor.run {
            loadingState = .loadingComponent(.spending)
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading spending data"
        ) {
            let entries = try await self.budgetManager.getEntries(for: self.selectedTimeframe)
            let groupedEntries = Dictionary(grouping: entries) { $0.category }
            let totalSpent = entries.reduce(0) { $0 + $1.amount }
            
            return groupedEntries.compactMap { (category: String, categoryEntries: [BudgetEntry]) in
                let amount = categoryEntries.reduce(0) { $0 + $1.amount }
                let percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0
                
                guard amount > 0 else { return nil }
                
                return try? SpendingData(
                    category: category,
                    amount: amount,
                    percentage: percentage,
                    color: self.themeManager.colorForCategory(category)
                )
            }
            .sorted { (lhs: SpendingData, rhs: SpendingData) in lhs.amount > rhs.amount }
        }
        
        await MainActor.run {
            if let data = result {
                spendingData = data
            }
        }
    }
    
    private func loadCategoryBreakdown() async throws {
        await MainActor.run {
            loadingState = .loadingComponent(.categories)
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading category breakdown"
        ) {
            let entries = try await self.budgetManager.getEntries(for: self.selectedTimeframe)
            let calendar = Calendar.current
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            let budgets = self.budgetManager.getMonthlyBudgets(for: currentMonth, year: currentYear)
            
            let spentByCategory = Dictionary(grouping: entries) { $0.category }
                .mapValues { categoryEntries in
                    (
                        amount: categoryEntries.reduce(0) { $0 + $1.amount },
                        count: categoryEntries.count
                    )
                }
            
            return budgets.compactMap { budget in
                let categoryData = spentByCategory[budget.category]
                let spent = categoryData?.amount ?? 0
                let transactionCount = categoryData?.count ?? 0
                let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0
                
                return CategoryBreakdown(
                    category: budget.category,
                    spent: spent,
                    budgeted: budget.amount,
                    percentage: percentage,
                    color: self.themeManager.colorForCategory(budget.category),
                    transactionCount: transactionCount
                )
            }
            .sorted { $0.spent > $1.spent }
        }
        
        await MainActor.run {
            if let breakdown = result {
                categoryBreakdown = breakdown
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: AppError, context: String) async {
        await MainActor.run {
            currentError = error
            loadingState = .failed(error)
        }
        
        errorHandler.handle(error, context: context)
        
        print("❌ OverviewViewModel: Error in \(context) - \(error.localizedDescription)")
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Listen to budget manager changes
        budgetManager.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task<Void, Never>{ [weak self] in
                    await self?.handleDataChange()
                }
            }
            .store(in: &cancellables)
        
        budgetManager.$monthlyBudgets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task<Void, Never>{ [weak self] in
                    await self?.handleDataChange()
                }
            }
            .store(in: &cancellables)
        
        // Setup automatic refresh timer
        setupRefreshTimer()
    }
    
    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: dataRefreshInterval, repeats: true) { [weak self] _ in
            Task<Void, Never>{ [weak self] in
                await self?.refreshIfNeeded()
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func handleDataChange() async {
        // Debounce rapid changes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard !loadingState.isLoading else { return }
        
        await refreshData()
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 2.0 {
                print("⚠️ OverviewViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 OverviewViewModel Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Analytics and Insights
    
    /// Get spending insights for the current data
    public func getSpendingInsights() -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        
        // Check for over-budget categories
        let overBudgetCategories = categoryBreakdown.filter { $0.isOverBudget }
        if !overBudgetCategories.isEmpty {
            insights.append(.overBudget(categories: overBudgetCategories.map { $0.category }))
        }
        
        // Check for categories nearing budget
        let nearLimitCategories = categoryBreakdown.filter { 
            $0.percentage > 80 && !$0.isOverBudget 
        }
        if !nearLimitCategories.isEmpty {
            insights.append(.nearBudgetLimit(categories: nearLimitCategories.map { $0.category }))
        }
        
        // Check spending trend
        let metrics = getDataMetrics()
        if metrics.spendingTrend == .increasing {
            insights.append(.increasingSpending)
        }
        
        // Check for top spending category
        if let topCategory = metrics.topSpendingCategory {
            insights.append(.topSpendingCategory(category: topCategory))
        }
        
        // Check for low activity
        if metrics.totalTransactions < 5 {
            insights.append(.lowActivity)
        }
        
        return insights
    }
    
    public enum SpendingInsight: Identifiable, Equatable {
        case overBudget(categories: [String])
        case nearBudgetLimit(categories: [String])
        case increasingSpending
        case topSpendingCategory(category: String)
        case lowActivity
        
        public var id: String {
            switch self {
            case .overBudget: return "overBudget"
            case .nearBudgetLimit: return "nearBudgetLimit"
            case .increasingSpending: return "increasingSpending"
            case .topSpendingCategory: return "topSpendingCategory"
            case .lowActivity: return "lowActivity"
            }
        }
        
        public var title: String {
            switch self {
            case .overBudget(let categories):
                return "Over Budget: \(categories.joined(separator: ", "))"
            case .nearBudgetLimit(let categories):
                return "Near Limit: \(categories.joined(separator: ", "))"
            case .increasingSpending:
                return "Spending is Increasing"
            case .topSpendingCategory(let category):
                return "Top Category: \(category)"
            case .lowActivity:
                return "Low Activity"
            }
        }
        
        public var message: String {
            switch self {
            case .overBudget:
                return "Consider adjusting your budget or reducing spending in these categories."
            case .nearBudgetLimit:
                return "Monitor spending closely to avoid going over budget."
            case .increasingSpending:
                return "Your spending trend is increasing. Review your recent purchases."
            case .topSpendingCategory(let category):
                return "\(category) is your highest spending category this period."
            case .lowActivity:
                return "Few transactions recorded. Make sure to log all your purchases."
            }
        }
        
        public var severity: Severity {
            switch self {
            case .overBudget: return .high
            case .nearBudgetLimit: return .medium
            case .increasingSpending: return .medium
            case .topSpendingCategory: return .low
            case .lowActivity: return .low
            }
        }
        
        public var color: Color {
            switch severity {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .overBudget: return "exclamationmark.triangle.fill"
            case .nearBudgetLimit: return "exclamationmark.circle"
            case .increasingSpending: return "arrow.up.right"
            case .topSpendingCategory: return "star.fill"
            case .lowActivity: return "clock"
            }
        }
        
        public enum Severity: String, CaseIterable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
        print("🧹 OverviewViewModel: Cleaned up resources")
    }
}

// MARK: - Extensions

extension OverviewViewModel.LoadingState {
    public static func == (lhs: OverviewViewModel.LoadingState, rhs: OverviewViewModel.LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.refreshing, .refreshing): return true
        case (.loaded, .loaded): return true
        case (.loadingComponent(let lhsType), .loadingComponent(let rhsType)): 
            return lhsType == rhsType
        case (.failed(let lhsError), .failed(let rhsError)): 
            return lhsError.localizedDescription == rhsError.localizedDescription
        default: return false
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension OverviewViewModel {
    /// Create test view model with mock data
    static func createTestViewModel() -> OverviewViewModel {
        let viewModel = OverviewViewModel()
        Task<Void, Never>{
            await viewModel.loadTestData()
        }
        return viewModel
    }
    
    /// Load test data for development
    func loadTestData() async {
        await MainActor.run {
            loadingState = .loaded
            
            // Test budget summary
            budgetSummary = BudgetSummaryData(
                totalBudgeted: 2500.0,
                totalSpent: 1750.0,
                categoryCount: 8,
                transactionCount: 45,
                timeframe: .thisMonth
            )
            
            // Test spending data
            spendingData = [
                try! SpendingData(category: "Groceries", amount: 450.0, percentage: 25.7, color: .blue),
                try! SpendingData(category: "Transportation", amount: 350.0, percentage: 20.0, color: .green),
                try! SpendingData(category: "Entertainment", amount: 300.0, percentage: 17.1, color: .orange),
                try! SpendingData(category: "Dining", amount: 250.0, percentage: 14.3, color: .purple),
                try! SpendingData(category: "Utilities", amount: 200.0, percentage: 11.4, color: .red)
            ]
            
            // Test recent transactions
            recentTransactions = [
                try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date(), note: "Weekly shopping"),
                try! BudgetEntry(amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-86400), note: "Bus fare"),
                try! BudgetEntry(amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-172800), note: "Movie tickets"),
                try! BudgetEntry(amount: 25.00, category: "Dining", date: Date().addingTimeInterval(-259200), note: "Lunch"),
                try! BudgetEntry(amount: 150.00, category: "Utilities", date: Date().addingTimeInterval(-345600), note: "Electric bill")
            ]
            
            // Test category breakdown
            categoryBreakdown = [
                CategoryBreakdown(category: "Groceries", spent: 450.0, budgeted: 500.0, percentage: 90.0, color: .blue, transactionCount: 12),
                CategoryBreakdown(category: "Transportation", spent: 350.0, budgeted: 300.0, percentage: 116.7, color: .green, transactionCount: 8),
                CategoryBreakdown(category: "Entertainment", spent: 300.0, budgeted: 400.0, percentage: 75.0, color: .orange, transactionCount: 6),
                CategoryBreakdown(category: "Dining", spent: 250.0, budgeted: 350.0, percentage: 71.4, color: .purple, transactionCount: 10),
                CategoryBreakdown(category: "Utilities", spent: 200.0, budgeted: 250.0, percentage: 80.0, color: .red, transactionCount: 3)
            ]
            
            lastRefreshDate = Date()
            currentError = nil
        }
        
        print("✅ OverviewViewModel: Loaded test data")
    }
    
    /// Simulate loading state for testing
    func simulateLoadingState() async {
        await MainActor.run {
            loadingState = .loading
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await loadTestData()
    }
    
    /// Simulate error state for testing
    func simulateErrorState() async {
        await MainActor.run {
            let error = AppError.dataLoad(underlying: NSError(
                domain: "TestError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated error for testing"]
            ))
            loadingState = .failed(error)
            currentError = error
        }
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        hasData: Bool,
        isLoading: Bool,
        hasError: Bool,
        metricsCount: Int
    ) {
        return (
            hasData: budgetSummary != nil && !spendingData.isEmpty,
            isLoading: loadingState.isLoading,
            hasError: currentError != nil,
            metricsCount: operationMetrics.count
        )
    }
    
    /// Reset state for testing
    func resetStateForTesting() {
        clearData()
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
        
        refreshTimer?.invalidate()
        setupRefreshTimer()
    }
}
#endif
