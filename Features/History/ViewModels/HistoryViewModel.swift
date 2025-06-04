//
//  HistoryViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//

import Foundation
import Combine
import SwiftUI
import Charts

/// ViewModel for managing budget history data, filtering, sorting, and analysis with comprehensive error handling
@MainActor
public final class HistoryViewModel: ObservableObject {
    // MARK: - Types
    
    public enum ViewState {
        case loading
        case loaded
        case empty
        case error(AppError)
        case refreshing
        
        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing: return true
            default: return false
            }
        }
        
        public var isEmpty: Bool {
            if case .empty = self { return true }
            return false
        }
        
        public var hasError: Bool {
            if case .error = self { return true }
            return false
        }
        
        public var errorMessage: String? {
            if case .error(let error) = self {
                return error.errorDescription
            }
            return nil
        }
    }
    
    public struct FilterConfiguration {
        public var timePeriod: TimePeriod
        public var selectedCategories: Set<String>
        public var sortOption: BudgetSortOption
        public var sortAscending: Bool
        public var showOnlyOverBudget: Bool
        public var minimumAmount: Double?
        public var maximumAmount: Double?
        
        public init(
            timePeriod: TimePeriod = .thisMonth,
            selectedCategories: Set<String> = [],
            sortOption: BudgetSortOption = .category,
            sortAscending: Bool = true,
            showOnlyOverBudget: Bool = false,
            minimumAmount: Double? = nil,
            maximumAmount: Double? = nil
        ) {
            self.timePeriod = timePeriod
            self.selectedCategories = selectedCategories
            self.sortOption = sortOption
            self.sortAscending = sortAscending
            self.showOnlyOverBudget = showOnlyOverBudget
            self.minimumAmount = minimumAmount
            self.maximumAmount = maximumAmount
        }
        
        public var hasActiveFilters: Bool {
            return !selectedCategories.isEmpty || 
                   showOnlyOverBudget || 
                   minimumAmount != nil || 
                   maximumAmount != nil
        }
        
        public var filterDescription: String {
            var components: [String] = []
            
            if !selectedCategories.isEmpty {
                components.append("\(selectedCategories.count) categories")
            }
            if showOnlyOverBudget {
                components.append("over budget only")
            }
            if minimumAmount != nil || maximumAmount != nil {
                components.append("amount filter")
            }
            
            return components.isEmpty ? "No filters" : components.joined(separator: ", ")
        }
    }
    
    public struct AnalyticsData {
        public let totalBudgeted: Double
        public let totalSpent: Double
        public let totalRemaining: Double
        public let averageSpentPerCategory: Double
        public let categoriesOverBudget: Int
        public let categoriesUnderBudget: Int
        public let biggestOverspend: (category: String, amount: Double)?
        public let biggestUnderspend: (category: String, amount: Double)?
        public let spendingTrend: SpendingTrend
        public let efficiencyScore: Double // 0.0 to 1.0
        
        public enum SpendingTrend {
            case increasing
            case decreasing
            case stable
            case insufficient_data
            
            public var displayName: String {
                switch self {
                case .increasing: return "Increasing"
                case .decreasing: return "Decreasing"
                case .stable: return "Stable"
                case .insufficient_data: return "Insufficient Data"
                }
            }
            
            public var color: Color {
                switch self {
                case .increasing: return .red
                case .decreasing: return .green
                case .stable: return .blue
                case .insufficient_data: return .gray
                }
            }
            
            public var systemImageName: String {
                switch self {
                case .increasing: return "arrow.up.right"
                case .decreasing: return "arrow.down.right"
                case .stable: return "arrow.right"
                case .insufficient_data: return "questionmark"
                }
            }
        }
        
        public var overallHealth: BudgetHealth {
            let overBudgetRatio = Double(categoriesOverBudget) / Double(categoriesOverBudget + categoriesUnderBudget)
            
            if totalSpent > totalBudgeted * 1.2 || overBudgetRatio > 0.5 {
                return .poor
            } else if totalSpent > totalBudgeted || overBudgetRatio > 0.3 {
                return .warning
            } else if efficiencyScore > 0.8 {
                return .excellent
            } else {
                return .good
            }
        }
        
        public enum BudgetHealth: String, CaseIterable {
            case excellent = "Excellent"
            case good = "Good"
            case warning = "Warning"
            case poor = "Poor"
            
            public var color: Color {
                switch self {
                case .excellent: return .green
                case .good: return .blue
                case .warning: return .orange
                case .poor: return .red
                }
            }
            
            public var systemImageName: String {
                switch self {
                case .excellent: return "checkmark.circle.fill"
                case .good: return "checkmark.circle"
                case .warning: return "exclamationmark.triangle.fill"
                case .poor: return "xmark.circle.fill"
                }
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published public private(set) var viewState: ViewState = .loading
    @Published public private(set) var budgetHistoryData: [BudgetHistoryData] = []
    @Published public private(set) var filteredData: [BudgetHistoryData] = []
    @Published public private(set) var availableCategories: [String] = []
    @Published public private(set) var analyticsData: AnalyticsData?
    @Published public private(set) var lastRefreshDate: Date?
    
    @Published public var filterConfiguration: FilterConfiguration = FilterConfiguration() {
        didSet {
            applyFiltersAndSort()
            saveFilterPreferences()
        }
    }
    
    @Published public private(set) var isExporting = false
    @Published public private(set) var exportProgress: Double = 0.0
    @Published public private(set) var showingFilterOptions = false
    
    // MARK: - Chart Configuration
    
    @Published public var chartType: ChartType = .bar {
        didSet {
            UserDefaults.standard.set(chartType.rawValue, forKey: StorageKeys.chartType)
        }
    }
    
    @Published public var showLegend: Bool = true {
        didSet {
            UserDefaults.standard.set(showLegend, forKey: StorageKeys.showLegend)
        }
    }
    
    @Published public var animateCharts: Bool = true {
        didSet {
            UserDefaults.standard.set(animateCharts, forKey: StorageKeys.animateCharts)
        }
    }
    
    // MARK: - Dependencies
    
    private let budgetManager: BudgetManager
    private let errorHandler: ErrorHandler
    private let performanceMonitor: PerformanceMonitor
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = DispatchQueue(label: "com.brandonsbudget.history", qos: .userInitiated)
    private var refreshTask: Task<Void, Never>?
    private var analyticsTask: Task<Void, Never>?
    
    // MARK: - Storage Keys
    
    private enum StorageKeys {
        static let prefix = "HistoryViewModel."
        static let timePeriod = prefix + "timePeriod"
        static let sortOption = prefix + "sortOption"
        static let sortAscending = prefix + "sortAscending"
        static let chartType = prefix + "chartType"
        static let showLegend = prefix + "showLegend"
        static let animateCharts = prefix + "animateCharts"
        static let showOnlyOverBudget = prefix + "showOnlyOverBudget"
    }
    
    // MARK: - Chart Colors
    
    public let chartColors: [Color] = [
        Color(red: 0.12, green: 0.58, blue: 0.95), // Blue
        Color(red: 0.99, green: 0.85, blue: 0.21), // Yellow
        Color(red: 0.18, green: 0.80, blue: 0.44), // Green
        Color(red: 0.61, green: 0.35, blue: 0.71), // Purple
        Color(red: 1.00, green: 0.60, blue: 0.00), // Orange
        Color(red: 0.20, green: 0.60, blue: 0.86), // Sky Blue
        Color(red: 0.95, green: 0.27, blue: 0.57)  // Pink
    ]
    
    // MARK: - Performance Metrics
    
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.history.metrics", qos: .utility)
    
    // MARK: - Initialization
    
    public init(
        budgetManager: BudgetManager = .shared,
        errorHandler: ErrorHandler = .shared,
        performanceMonitor: PerformanceMonitor = .shared
    ) {
        self.budgetManager = budgetManager
        self.errorHandler = errorHandler
        self.performanceMonitor = performanceMonitor
        
        loadSavedPreferences()
        setupObservers()
        
        // Initial data load
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Interface
    
    /// Refresh all history data
    public func refreshData() async {
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        refreshTask = Task {
            await performDataRefresh()
        }
        
        await refreshTask?.value
    }
    
    /// Update filter configuration
    public func updateFilter(_ configuration: FilterConfiguration) {
        filterConfiguration = configuration
    }
    
    /// Clear all filters
    public func clearFilters() {
        filterConfiguration = FilterConfiguration(
            timePeriod: filterConfiguration.timePeriod,
            sortOption: filterConfiguration.sortOption,
            sortAscending: filterConfiguration.sortAscending
        )
    }
    
    /// Toggle category filter
    public func toggleCategoryFilter(_ category: String) {
        var newConfiguration = filterConfiguration
        
        if newConfiguration.selectedCategories.contains(category) {
            newConfiguration.selectedCategories.remove(category)
        } else {
            newConfiguration.selectedCategories.insert(category)
        }
        
        filterConfiguration = newConfiguration
    }
    
    /// Update time period
    public func updateTimePeriod(_ timePeriod: TimePeriod) {
        var newConfiguration = filterConfiguration
        newConfiguration.timePeriod = timePeriod
        filterConfiguration = newConfiguration
        
        // Reload data for new time period
        Task {
            await loadBudgetData()
        }
    }
    
    /// Update sort configuration
    public func updateSort(option: BudgetSortOption, ascending: Bool) {
        var newConfiguration = filterConfiguration
        newConfiguration.sortOption = option
        newConfiguration.sortAscending = ascending
        filterConfiguration = newConfiguration
    }
    
    /// Export filtered data
    public func exportData(format: ExportFormat = .csv) async throws -> URL {
        let startTime = Date()
        isExporting = true
        exportProgress = 0.0
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        do {
            exportProgress = 0.2
            
            // Prepare data for export
            let dataToExport = prepareDataForExport()
            exportProgress = 0.5
            
            // Convert to appropriate format
            let fileURL: URL
            
            switch format {
            case .csv:
                fileURL = try await exportToCSV(dataToExport)
            case .json:
                fileURL = try await exportToJSON(dataToExport)
            case .pdf:
                fileURL = try await exportToPDF(dataToExport)
            }
            
            exportProgress = 1.0
            
            recordMetric("exportData", duration: Date().timeIntervalSince(startTime))
            print("✅ HistoryViewModel: Exported data to \(fileURL.lastPathComponent)")
            
            return fileURL
            
        } catch {
            let appError = AppError.csvExport(underlying: error)
            errorHandler.handle(appError, context: "Exporting history data")
            throw appError
        }
    }
    
    /// Get chart data for current filters
    public func getChartData() -> [(category: String, budgeted: Double, spent: Double, color: Color)] {
        return filteredData.enumerated().map { index, data in
            (
                category: data.category,
                budgeted: data.budgetedAmount,
                spent: data.amountSpent,
                color: chartColors[index % chartColors.count]
            )
        }
    }
    
    /// Get spending efficiency for a category
    public func getSpendingEfficiency(for category: String) -> Double {
        guard let data = filteredData.first(where: { $0.category == category }),
              data.budgetedAmount > 0 else { return 0.0 }
        
        let efficiency = data.amountSpent / data.budgetedAmount
        return min(1.0, max(0.0, efficiency))
    }
    
    /// Get category performance summary
    public func getCategoryPerformance() -> [CategoryPerformance] {
        return filteredData.map { data in
            CategoryPerformance(
                category: data.category,
                budgeted: data.budgetedAmount,
                spent: data.amountSpent,
                efficiency: getSpendingEfficiency(for: data.category),
                status: data.isOverBudget ? .overBudget : .underBudget
            )
        }.sorted { $0.efficiency > $1.efficiency }
    }
    
    /// Get detailed analytics insights
    public func getAnalyticsInsights() -> [AnalyticsInsight] {
        guard let analytics = analyticsData else { return [] }
        
        var insights: [AnalyticsInsight] = []
        
        // Budget utilization insight
        let utilizationRate = analytics.totalBudgeted > 0 ? 
            (analytics.totalSpent / analytics.totalBudgeted) * 100 : 0
        
        insights.append(AnalyticsInsight(
            title: "Budget Utilization",
            value: "\(String(format: "%.1f", utilizationRate))%",
            description: "of total budget used",
            trend: utilizationRate > 100 ? .negative : utilizationRate > 90 ? .neutral : .positive,
            priority: utilizationRate > 100 ? .high : .normal
        ))
        
        // Category performance insight
        let overBudgetRatio = Double(analytics.categoriesOverBudget) / 
            Double(analytics.categoriesOverBudget + analytics.categoriesUnderBudget) * 100
        
        insights.append(AnalyticsInsight(
            title: "Categories Over Budget",
            value: "\(analytics.categoriesOverBudget)",
            description: "(\(String(format: "%.1f", overBudgetRatio))% of categories)",
            trend: overBudgetRatio > 30 ? .negative : overBudgetRatio > 15 ? .neutral : .positive,
            priority: overBudgetRatio > 50 ? .high : .normal
        ))
        
        // Efficiency insight
        insights.append(AnalyticsInsight(
            title: "Budget Efficiency",
            value: "\(String(format: "%.1f", analytics.efficiencyScore * 100))%",
            description: "overall budget management score",
            trend: analytics.efficiencyScore > 0.8 ? .positive : analytics.efficiencyScore > 0.6 ? .neutral : .negative,
            priority: analytics.efficiencyScore < 0.5 ? .high : .normal
        ))
        
        // Biggest overspend insight
        if let overspend = analytics.biggestOverspend {
            insights.append(AnalyticsInsight(
                title: "Biggest Overspend",
                value: overspend.amount.asCurrency,
                description: "in \(overspend.category)",
                trend: .negative,
                priority: overspend.amount > 100 ? .high : .normal
            ))
        }
        
        return insights
    }
    
    /// Show filter options
    public func showFilterOptions() {
        showingFilterOptions = true
    }
    
    /// Hide filter options
    public func hideFilterOptions() {
        showingFilterOptions = false
    }
    
    /// Get summary statistics
    public func getSummaryStatistics() -> SummaryStatistics {
        let totalBudgeted = filteredData.reduce(0) { $0 + $1.budgetedAmount }
        let totalSpent = filteredData.reduce(0) { $0 + $1.amountSpent }
        let totalRemaining = totalBudgeted - totalSpent
        let categoriesCount = filteredData.count
        let overBudgetCount = filteredData.filter { $0.isOverBudget }.count
        
        return SummaryStatistics(
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
            categoriesCount: categoriesCount,
            overBudgetCount: overBudgetCount,
            averageSpentPerCategory: categoriesCount > 0 ? totalSpent / Double(categoriesCount) : 0,
            budgetUtilization: totalBudgeted > 0 ? (totalSpent / totalBudgeted) * 100 : 0
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupObservers() {
        // Observe budget manager changes
        budgetManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                Task { [weak self] in
                    await self?.loadBudgetData()
                }
            }
            .store(in: &cancellables)
        
        // Setup performance monitoring
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func loadSavedPreferences() {
        let defaults = UserDefaults.standard
        
        // Load time period
        if let timePeriodData = defaults.data(forKey: StorageKeys.timePeriod),
           let timePeriod = try? JSONDecoder().decode(TimePeriod.self, from: timePeriodData) {
            filterConfiguration.timePeriod = timePeriod
        }
        
        // Load sort options
        if let sortOptionString = defaults.string(forKey: StorageKeys.sortOption),
           let sortOption = BudgetSortOption(rawValue: sortOptionString) {
            filterConfiguration.sortOption = sortOption
        }
        
        filterConfiguration.sortAscending = defaults.bool(forKey: StorageKeys.sortAscending)
        
        // Load chart preferences
        if let chartTypeString = defaults.string(forKey: StorageKeys.chartType),
           let chartType = ChartType(rawValue: chartTypeString) {
            self.chartType = chartType
        }
        
        showLegend = defaults.object(forKey: StorageKeys.showLegend) as? Bool ?? true
        animateCharts = defaults.object(forKey: StorageKeys.animateCharts) as? Bool ?? true
        filterConfiguration.showOnlyOverBudget = defaults.bool(forKey: StorageKeys.showOnlyOverBudget)
    }
    
    private func saveFilterPreferences() {
        let defaults = UserDefaults.standard
        
        // Save time period
        if let timePeriodData = try? JSONEncoder().encode(filterConfiguration.timePeriod) {
            defaults.set(timePeriodData, forKey: StorageKeys.timePeriod)
        }
        
        // Save sort options
        defaults.set(filterConfiguration.sortOption.rawValue, forKey: StorageKeys.sortOption)
        defaults.set(filterConfiguration.sortAscending, forKey: StorageKeys.sortAscending)
        defaults.set(filterConfiguration.showOnlyOverBudget, forKey: StorageKeys.showOnlyOverBudget)
    }
    
    private func loadInitialData() async {
        viewState = .loading
        
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // Brief delay for smooth UX
            await loadBudgetData()
        } catch {
            viewState = .error(AppError.from(error))
        }
    }
    
    private func performDataRefresh() async {
        viewState = .refreshing
        
        do {
            // Refresh budget manager data first
            await budgetManager.loadData()
            
            // Then load our data
            await loadBudgetData()
            
            lastRefreshDate = Date()
            
        } catch {
            viewState = .error(AppError.from(error))
            errorHandler.handle(AppError.from(error), context: "Refreshing history data")
        }
    }
    
    private func loadBudgetData() async {
        let startTime = Date()
        
        do {
            let historyData = await calculateBudgetHistoryData()
            
            await MainActor.run {
                budgetHistoryData = historyData
                availableCategories = Array(Set(historyData.map { $0.category })).sorted()
                applyFiltersAndSort()
                
                if historyData.isEmpty {
                    viewState = .empty
                } else {
                    viewState = .loaded
                }
            }
            
            // Calculate analytics in background
            analyticsTask?.cancel()
            analyticsTask = Task {
                await calculateAnalytics()
            }
            
            recordMetric("loadBudgetData", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            await MainActor.run {
                viewState = .error(AppError.from(error))
            }
            errorHandler.handle(AppError.from(error), context: "Loading budget history data")
        }
    }
    
    private func calculateBudgetHistoryData() async -> [BudgetHistoryData] {
        let dateInterval = filterConfiguration.timePeriod.dateInterval()
        
        // Get entries for the time period
        let entries = budgetManager.entries.filter { entry in
            entry.date >= dateInterval.start && entry.date <= dateInterval.end
        }
        
        // Get budgets for the time period
        let calendar = Calendar.current
        let month = calendar.component(.month, from: dateInterval.start)
        let year = calendar.component(.year, from: dateInterval.start)
        let budgets = budgetManager.getMonthlyBudgets(for: month, year: year)
        
        var budgetDataDict: [String: BudgetHistoryData] = [:]
        
        // Initialize with budgets
        for budget in budgets {
            budgetDataDict[budget.category] = BudgetHistoryData(
                category: budget.category,
                budgetedAmount: budget.amount,
                amountSpent: 0
            )
        }
        
        // Add spending from entries
        for entry in entries {
            let category = entry.category
            if let existingData = budgetDataDict[category] {
                budgetDataDict[category] = BudgetHistoryData(
                    category: category,
                    budgetedAmount: existingData.budgetedAmount,
                    amountSpent: existingData.amountSpent + entry.amount
                )
            } else {
                // Create entry for categories without budgets
                budgetDataDict[category] = BudgetHistoryData(
                    category: category,
                    budgetedAmount: 0,
                    amountSpent: entry.amount
                )
            }
        }
        
        return Array(budgetDataDict.values)
    }
    
    private func applyFiltersAndSort() {
        var data = budgetHistoryData
        
        // Apply category filter
        if !filterConfiguration.selectedCategories.isEmpty {
            data = data.filter { filterConfiguration.selectedCategories.contains($0.category) }
        }
        
        // Apply over budget filter
        if filterConfiguration.showOnlyOverBudget {
            data = data.filter { $0.isOverBudget }
        }
        
        // Apply amount filters
        if let minAmount = filterConfiguration.minimumAmount {
            data = data.filter { $0.amountSpent >= minAmount }
        }
        
        if let maxAmount = filterConfiguration.maximumAmount {
            data = data.filter { $0.amountSpent <= maxAmount }
        }
        
        // Apply sorting
        data = sortData(data)
        
        filteredData = data
    }
    
    private func sortData(_ data: [BudgetHistoryData]) -> [BudgetHistoryData] {
        return data.sorted { first, second in
            let result: Bool
            
            switch filterConfiguration.sortOption {
            case .category:
                result = first.category < second.category
            case .budgetedAmount:
                result = first.budgetedAmount < second.budgetedAmount
            case .amountSpent:
                result = first.amountSpent < second.amountSpent
            case .date:
                // For history, we'll sort by category as fallback
                result = first.category < second.category
            case .amount:
                result = first.amountSpent < second.amountSpent
            }
            
            return filterConfiguration.sortAscending ? result : !result
        }
    }
    
    private func calculateAnalytics() async {
        let startTime = Date()
        
        let data = budgetHistoryData
        guard !data.isEmpty else { return }
        
        let totalBudgeted = data.reduce(0) { $0 + $1.budgetedAmount }
        let totalSpent = data.reduce(0) { $0 + $1.amountSpent }
        let totalRemaining = totalBudgeted - totalSpent
        let averageSpent = totalSpent / Double(data.count)
        
        let overBudgetCategories = data.filter { $0.isOverBudget }
        let underBudgetCategories = data.filter { !$0.isOverBudget && $0.budgetedAmount > 0 }
        
        // Find biggest overspend
        let biggestOverspend = overBudgetCategories
            .map { ($0.category, $0.amountSpent - $0.budgetedAmount) }
            .max { $0.1 < $1.1 }
        
        // Find biggest underspend
        let biggestUnderspend = underBudgetCategories
            .map { ($0.category, $0.budgetedAmount - $0.amountSpent) }
            .max { $0.1 < $1.1 }
        
        // Calculate spending trend (simplified)
        let spendingTrend: AnalyticsData.SpendingTrend
        if data.count < 3 {
            spendingTrend = .insufficient_data
        } else {
            let recentSpending = data.prefix(data.count / 2).reduce(0) { $0 + $1.amountSpent }
            let olderSpending = data.suffix(data.count / 2).reduce(0) { $0 + $1.amountSpent }
            
            if recentSpending > olderSpending * 1.1 {
                spendingTrend = .increasing
            } else if recentSpending < olderSpending * 0.9 {
                spendingTrend = .decreasing
            } else {
                spendingTrend = .stable
            }
        }
        
        // Calculate efficiency score
        let efficiencyScore: Double
        if totalBudgeted > 0 {
            let utilizationRate = totalSpent / totalBudgeted
            let overBudgetPenalty = Double(overBudgetCategories.count) / Double(data.count) * 0.3
            efficiencyScore = max(0.0, min(1.0, 1.0 - abs(utilizationRate - 0.85) - overBudgetPenalty))
        } else {
            efficiencyScore = 0.0
        }
        
        let analytics = AnalyticsData(
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining,
            averageSpentPerCategory: averageSpent,
            categoriesOverBudget: overBudgetCategories.count,
            categoriesUnderBudget: underBudgetCategories.count,
            biggestOverspend: biggestOverspend,
            biggestUnderspend: biggestUnderspend,
            spendingTrend: spendingTrend,
            efficiencyScore: efficiencyScore
        )
        
        await MainActor.run {
            analyticsData = analytics
        }
        
        recordMetric("calculateAnalytics", duration: Date().timeIntervalSince(startTime))
    }
    
    // MARK: - Export Implementation
    
    private func prepareDataForExport() -> [ExportDataRow] {
        return filteredData.map { data in
            ExportDataRow(
                category: data.category,
                budgetedAmount: data.budgetedAmount,
                amountSpent: data.amountSpent,
                remainingAmount: data.remainingAmount,
                percentageSpent: data.percentageSpent,
                isOverBudget: data.isOverBudget,
                timePeriod: filterConfiguration.timePeriod.displayName
            )
        }
    }
    
    private func exportToCSV(_ data: [ExportDataRow]) async throws -> URL {
        var csvContent = "Category,Budgeted Amount,Amount Spent,Remaining Amount,Percentage Spent,Is Over Budget,Time Period\n"
        
        for row in data {
            csvContent += "\(row.category),"
            csvContent += "\(row.budgetedAmount),"
            csvContent += "\(row.amountSpent),"
            csvContent += "\(row.remainingAmount),"
            csvContent += "\(row.percentageSpent),"
            csvContent += "\(row.isOverBudget),"
            csvContent += "\(row.timePeriod)\n"
        }
        
        return try await saveToFile(content: csvContent, fileName: "budget_history", extension: "csv")
    }
    
    private func exportToJSON(_ data: [ExportDataRow]) async throws -> URL {
        let exportData = ExportContainer(
            data: data,
            metadata: ExportMetadata(
                exportDate: Date(),
                timePeriod: filterConfiguration.timePeriod.displayName,
                filterDescription: filterConfiguration.filterDescription,
                totalRecords: data.count
            )
        )
        
        let jsonData = try JSONEncoder().encode(exportData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw AppError.csvExport(underlying: NSError(
                domain: "HistoryViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to string"]
            ))
        }
        
        return try await saveToFile(content: jsonString, fileName: "budget_history", extension: "json")
    }
    
    private func exportToPDF(_ data: [ExportDataRow]) async throws -> URL {
        // For now, create a simple text-based PDF content
        // In a real implementation, you'd use PDFKit or similar
        var pdfContent = "Budget History Report\n"
        pdfContent += "Generated: \(Date().formatted())\n"
        pdfContent += "Time Period: \(filterConfiguration.timePeriod.displayName)\n"
        pdfContent += "Filters: \(filterConfiguration.filterDescription)\n\n"
        
        for row in data {
            pdfContent += "Category: \(row.category)\n"
            pdfContent += "Budgeted: \(row.budgetedAmount.asCurrency)\n"
            pdfContent += "Spent: \(row.amountSpent.asCurrency)\n"
            pdfContent += "Remaining: \(row.remainingAmount.asCurrency)\n"
            pdfContent += "Percentage: \(String(format: "%.1f", row.percentageSpent))%\n"
            pdfContent += "Status: \(row.isOverBudget ? "Over Budget" : "Under Budget")\n\n"
        }
        
        return try await saveToFile(content: pdfContent, fileName: "budget_history", extension: "txt")
    }
    
    private func saveToFile(content: String, fileName: String, extension: String) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let fileURL = documentsPath.appendingPathComponent("\(fileName)_\(timestamp).\(`extension`)")
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ HistoryViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 HistoryViewModel Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTask?.cancel()
        analyticsTask?.cancel()
        cancellables.removeAll()
        print("🧹 HistoryViewModel: Cleaned up resources")
    }
}

// MARK: - Supporting Types

public struct CategoryPerformance {
    public let category: String
    public let budgeted: Double
    public let spent: Double
    public let efficiency: Double
    public let status: BudgetStatus
    
    public enum BudgetStatus {
        case overBudget
        case underBudget
        case onTarget
        
        public var color: Color {
            switch self {
            case .overBudget: return .red
            case .underBudget: return .green
            case .onTarget: return .blue
            }
        }
        
        public var displayName: String {
            switch self {
            case .overBudget: return "Over Budget"
            case .underBudget: return "Under Budget"
            case .onTarget: return "On Target"
            }
        }
    }
    
    public var remainingAmount: Double {
        return budgeted - spent
    }
    
    public var percentageUsed: Double {
        guard budgeted > 0 else { return 0 }
        return (spent / budgeted) * 100
    }
}

public struct AnalyticsInsight {
    public let title: String
    public let value: String
    public let description: String
    public let trend: Trend
    public let priority: Priority
    
    public enum Trend {
        case positive
        case negative
        case neutral
        
        public var color: Color {
            switch self {
            case .positive: return .green
            case .negative: return .red
            case .neutral: return .orange
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .positive: return "arrow.up.circle.fill"
            case .negative: return "arrow.down.circle.fill"
            case .neutral: return "minus.circle.fill"
            }
        }
    }
    
    public enum Priority {
        case low
        case normal
        case high
        case critical
        
        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
}

public struct SummaryStatistics {
    public let totalBudgeted: Double
    public let totalSpent: Double
    public let totalRemaining: Double
    public let categoriesCount: Int
    public let overBudgetCount: Int
    public let averageSpentPerCategory: Double
    public let budgetUtilization: Double
    
    public var formattedTotalBudgeted: String {
        totalBudgeted.asCurrency
    }
    
    public var formattedTotalSpent: String {
        totalSpent.asCurrency
    }
    
    public var formattedTotalRemaining: String {
        totalRemaining.asCurrency
    }
    
    public var formattedAverageSpent: String {
        averageSpentPerCategory.asCurrency
    }
    
    public var utilizationStatus: String {
        if budgetUtilization > 100 {
            return "Over Budget"
        } else if budgetUtilization > 90 {
            return "Near Limit"
        } else if budgetUtilization > 75 {
            return "On Track"
        } else {
            return "Under Budget"
        }
    }
    
    public var utilizationColor: Color {
        if budgetUtilization > 100 {
            return .red
        } else if budgetUtilization > 90 {
            return .orange
        } else if budgetUtilization > 75 {
            return .yellow
        } else {
            return .green
        }
    }
}

private struct ExportDataRow: Codable {
    let category: String
    let budgetedAmount: Double
    let amountSpent: Double
    let remainingAmount: Double
    let percentageSpent: Double
    let isOverBudget: Bool
    let timePeriod: String
}

private struct ExportContainer: Codable {
    let data: [ExportDataRow]
    let metadata: ExportMetadata
}

private struct ExportMetadata: Codable {
    let exportDate: Date
    let timePeriod: String
    let filterDescription: String
    let totalRecords: Int
    let appVersion: String
    
    init(exportDate: Date, timePeriod: String, filterDescription: String, totalRecords: Int) {
        self.exportDate = exportDate
        self.timePeriod = timePeriod
        self.filterDescription = filterDescription
        self.totalRecords = totalRecords
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Chart Extensions

extension HistoryViewModel {
    /// Get chart data configured for specific chart types
    public func getConfiguredChartData(for type: ChartType) -> ChartConfiguration {
        let baseData = getChartData()
        
        switch type {
        case .bar:
            return ChartConfiguration(
                type: .bar,
                data: baseData,
                showValues: true,
                showGrid: true,
                animated: animateCharts
            )
        case .pie:
            return ChartConfiguration(
                type: .pie,
                data: baseData,
                showValues: false,
                showGrid: false,
                animated: animateCharts
            )
        case .line:
            return ChartConfiguration(
                type: .line,
                data: baseData,
                showValues: false,
                showGrid: true,
                animated: animateCharts
            )
        case .donut:
            return ChartConfiguration(
                type: .donut,
                data: baseData,
                showValues: false,
                showGrid: false,
                animated: animateCharts
            )
        }
    }
    
    /// Get color for category at index
    public func colorForCategory(at index: Int) -> Color {
        return chartColors[index % chartColors.count]
    }
    
    /// Get formatted legend data
    public func getLegendData() -> [LegendItem] {
        return filteredData.enumerated().map { index, data in
            LegendItem(
                color: chartColors[index % chartColors.count],
                label: data.category,
                value: data.amountSpent.asCurrency,
                percentage: data.percentageSpent
            )
        }
    }
}

public struct ChartConfiguration {
    public let type: ChartType
    public let data: [(category: String, budgeted: Double, spent: Double, color: Color)]
    public let showValues: Bool
    public let showGrid: Bool
    public let animated: Bool
}

public struct LegendItem {
    public let color: Color
    public let label: String
    public let value: String
    public let percentage: Double
}

// MARK: - Filter Extensions

extension HistoryViewModel {
    /// Get available filter options
    public func getAvailableFilterOptions() -> FilterOptions {
        let allCategories = Array(Set(budgetHistoryData.map { $0.category })).sorted()
        let amountRange = getAmountRange()
        
        return FilterOptions(
            categories: allCategories,
            minAmount: amountRange.min,
            maxAmount: amountRange.max,
            timePeriods: TimePeriod.commonPeriods
        )
    }
    
    private func getAmountRange() -> (min: Double, max: Double) {
        let amounts = budgetHistoryData.map { $0.amountSpent }
        return (
            min: amounts.min() ?? 0,
            max: amounts.max() ?? 0
        )
    }
    
    /// Apply quick filter presets
    public func applyQuickFilter(_ filter: QuickFilter) {
        var newConfiguration = filterConfiguration
        
        switch filter {
        case .overBudgetOnly:
            newConfiguration.showOnlyOverBudget = true
            newConfiguration.selectedCategories.removeAll()
        case .highSpenders:
            newConfiguration.showOnlyOverBudget = false
            newConfiguration.selectedCategories.removeAll()
            // Set minimum amount to top 25% of spending
            let sortedAmounts = budgetHistoryData.map { $0.amountSpent }.sorted(by: >)
            if let threshold = sortedAmounts.dropFirst(sortedAmounts.count / 4).first {
                newConfiguration.minimumAmount = threshold
            }
        case .underBudgetOnly:
            newConfiguration.showOnlyOverBudget = false
            newConfiguration.selectedCategories.removeAll()
            // This would need additional logic to filter for under-budget items
        case .noFilters:
            newConfiguration = FilterConfiguration(
                timePeriod: newConfiguration.timePeriod,
                sortOption: newConfiguration.sortOption,
                sortAscending: newConfiguration.sortAscending
            )
        }
        
        filterConfiguration = newConfiguration
    }
}

public struct FilterOptions {
    public let categories: [String]
    public let minAmount: Double
    public let maxAmount: Double
    public let timePeriods: [TimePeriod]
}

public enum QuickFilter: String, CaseIterable {
    case overBudgetOnly = "Over Budget Only"
    case highSpenders = "High Spenders"
    case underBudgetOnly = "Under Budget Only"
    case noFilters = "No Filters"
    
    public var displayName: String {
        return rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .overBudgetOnly: return "exclamationmark.triangle.fill"
        case .highSpenders: return "arrow.up.circle.fill"
        case .underBudgetOnly: return "checkmark.circle.fill"
        case .noFilters: return "clear.fill"
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension HistoryViewModel {
    /// Create test view model with mock data
    static func createTestViewModel() -> HistoryViewModel {
        let viewModel = HistoryViewModel()
        viewModel.loadTestData()
        return viewModel
    }
    
    /// Load test data for development
    func loadTestData() {
        let testData = [
            BudgetHistoryData(category: "Groceries", budgetedAmount: 500, amountSpent: 450),
            BudgetHistoryData(category: "Entertainment", budgetedAmount: 200, amountSpent: 250),
            BudgetHistoryData(category: "Transportation", budgetedAmount: 300, amountSpent: 280),
            BudgetHistoryData(category: "Utilities", budgetedAmount: 400, amountSpent: 380),
            BudgetHistoryData(category: "Dining", budgetedAmount: 150, amountSpent: 175)
        ]
        
        budgetHistoryData = testData
        availableCategories = testData.map { $0.category }.sorted()
        applyFiltersAndSort()
        viewState = .loaded
        
        // Generate test analytics
        Task {
            await calculateAnalytics()
        }
        
        print("✅ HistoryViewModel: Loaded test data")
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        dataCount: Int,
        filteredCount: Int,
        categoriesCount: Int,
        hasAnalytics: Bool,
        hasActiveFilters: Bool,
        currentState: ViewState
    ) {
        return (
            dataCount: budgetHistoryData.count,
            filteredCount: filteredData.count,
            categoriesCount: availableCategories.count,
            hasAnalytics: analyticsData != nil,
            hasActiveFilters: filterConfiguration.hasActiveFilters,
            currentState: viewState
        )
    }
    
    /// Test error handling
    func simulateError(_ error: AppError) {
        viewState = .error(error)
        errorHandler.handle(error, context: "Testing error simulation")
    }
    
    /// Test loading states
    func simulateLoadingState() {
        viewState = .loading
    }
    
    /// Test empty state
    func simulateEmptyState() {
        budgetHistoryData = []
        filteredData = []
        availableCategories = []
        viewState = .empty
    }
    
    /// Force analytics calculation for testing
    func forceAnalyticsCalculation() async {
        await calculateAnalytics()
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Clear all data for testing
    func clearDataForTesting() {
        budgetHistoryData = []
        filteredData = []
        availableCategories = []
        analyticsData = nil
        viewState = .empty
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
    }
}
#endif
