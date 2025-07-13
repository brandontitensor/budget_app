//
//  HistoryViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for budget history with enhanced error handling and performance optimization
@MainActor
public final class HistoryViewModel: ObservableObject {
    
    // MARK: - Types
    
    public enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case refreshing
        case error(AppError)
        
        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing:
                return true
            default:
                return false
            }
        }
        
        public var hasError: Bool {
            if case .error = self { return true }
            return false
        }
    }
    
    public enum FilterType: String, CaseIterable {
        case all = "All"
        case category = "Category"
        case amount = "Amount"
        case date = "Date"
        
        public var systemImageName: String {
            switch self {
            case .all: return "list.bullet"
            case .category: return "folder"
            case .amount: return "dollarsign"
            case .date: return "calendar"
            }
        }
    }
    
    public enum SortOption: String, CaseIterable {
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
    
    public struct HistoryAnalytics: Equatable {
        public let totalEntries: Int
        public let totalAmount: Double
        public let averageTransactionAmount: Double
        public let topCategory: String?
        public let topCategoryAmount: Double
        public let dateRange: String
        public let trends: [String]
        
        public init(
            totalEntries: Int,
            totalAmount: Double,
            averageTransactionAmount: Double,
            topCategory: String?,
            topCategoryAmount: Double,
            dateRange: String,
            trends: [String]
        ) {
            self.totalEntries = totalEntries
            self.totalAmount = totalAmount
            self.averageTransactionAmount = averageTransactionAmount
            self.topCategory = topCategory
            self.topCategoryAmount = topCategoryAmount
            self.dateRange = dateRange
            self.trends = trends
        }
    }
    
    public struct PerformanceMetrics {
        public let operationType: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let success: Bool
        public let recordCount: Int
        public let cacheHit: Bool
        
        public init(
            operationType: String,
            duration: TimeInterval,
            success: Bool,
            recordCount: Int = 0,
            cacheHit: Bool = false
        ) {
            self.operationType = operationType
            self.duration = duration
            self.timestamp = Date()
            self.success = success
            self.recordCount = recordCount
            self.cacheHit = cacheHit
        }
    }
    
    // MARK: - Dependencies
    private let budgetManager: BudgetManager
    private let errorHandler: ErrorHandler
    private let themeManager: ThemeManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published public private(set) var loadingState: LoadingState = .idle
    @Published public private(set) var historyData: [BudgetHistoryData] = []
    @Published public private(set) var filteredData: [BudgetHistoryData] = []
    @Published public private(set) var analytics: HistoryAnalytics?
    @Published public private(set) var currentError: AppError?
    @Published public private(set) var lastRefreshDate: Date?
    
    // MARK: - Filter and Sort State
    @Published public var selectedTimePeriod: TimePeriod = .thisMonth
    @Published public var selectedFilter: FilterType = .all
    @Published public var selectedSort: SortOption = .date
    @Published public var sortAscending = false
    @Published public var searchText = ""
    @Published public var selectedCategories: Set<String> = []
    @Published public var amountRange: ClosedRange<Double> = 0...10000
    @Published public var dateRange: ClosedRange<Date> = Date()...Date()
    
    // MARK: - UI State
    @Published public var showingFilterPanel = false
    @Published public var showingExportOptions = false
    @Published public var selectedDataPoint: BudgetHistoryData?
    
    // MARK: - Performance Monitoring
    private let performanceQueue = DispatchQueue(label: "com.brandonsbudget.historyvm.performance", qos: .utility)
    @Published private var operationMetrics: [String: PerformanceMetrics] = [:]
    private let maxCacheSize = 100
    private var dataCache: [String: [BudgetHistoryData]] = [:]
    
    // MARK: - Constants
    private let refreshThreshold: TimeInterval = 300 // 5 minutes
    private let maxHistoryItems = 1000
    private let batchSize = 50
    
    // MARK: - Computed Properties
    
    public var isLoading: Bool {
        loadingState.isLoading
    }
    
    public var hasError: Bool {
        loadingState.hasError || currentError != nil
    }
    
    public var isEmpty: Bool {
        filteredData.isEmpty && !isLoading
    }
    
    public var availableCategories: [String] {
        Array(Set(historyData.map { $0.category })).sorted()
    }
    
    public var totalFilteredAmount: Double {
        filteredData.reduce(0) { $0 + $1.amount }
    }
    
    public var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        return Date().timeIntervalSince(lastRefresh) > refreshThreshold
    }
    
    // MARK: - Initialization
    
    public init(
        budgetManager: BudgetManager? = nil,
        errorHandler: ErrorHandler? = nil,
        themeManager: ThemeManager? = nil
    ) {
        self.budgetManager = budgetManager ?? BudgetManager.shared
        self.errorHandler = errorHandler ?? ErrorHandler.shared
        self.themeManager = themeManager ?? ThemeManager.shared
        
        setupBindings()
        
        Task<Void, Never>{
            await loadInitialData()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor filter changes
        Publishers.CombineLatest4(
            $selectedFilter,
            $searchText.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main),
            $selectedCategories,
            $amountRange
        )
        .sink { [weak self] _, _, _, _ in
            Task<Void, Never>{ [weak self] in
                await self?.applyFilters()
            }
        }
        .store(in: &cancellables)
        
        // Monitor sort changes
        Publishers.CombineLatest($selectedSort, $sortAscending)
            .sink { [weak self] _, _ in
                Task<Void, Never>{ [weak self] in
                    await self?.applySorting()
                }
            }
            .store(in: &cancellables)
        
        // Monitor time period changes
        $selectedTimePeriod
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] timePeriod in
                Task<Void, Never>{ [weak self] in
                    await self?.refreshData(for: timePeriod)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    public func loadInitialData() async {
        let startTime = Date()
        loadingState = .loading
        currentError = nil
        
        do {
            // Check cache first
            let cacheKey = generateCacheKey(for: selectedTimePeriod)
            if let cachedData = dataCache[cacheKey] {
                historyData = cachedData
                await applyFilters()
                calculateAnalytics()
                loadingState = .loaded
                lastRefreshDate = Date()
                recordMetric("loadInitialData", duration: Date().timeIntervalSince(startTime), recordCount: cachedData.count, cacheHit: true)
                return
            }
            
            // Load from budget manager
            let entries = try await budgetManager.getEntries(
                for: selectedTimePeriod,
                sortedBy: .date,
                ascending: false
            )
            
            // Convert to history data
            let historyItems = entries.prefix(maxHistoryItems).map { entry in
                BudgetHistoryData(
                    id: entry.id,
                    date: entry.date,
                    amount: entry.amount,
                    category: entry.category,
                    note: entry.note,
                    timePeriod: selectedTimePeriod
                )
            }
            
            historyData = Array(historyItems)
            
            // Cache the data
            dataCache[cacheKey] = historyData
            cleanupCache()
            
            await applyFilters()
            calculateAnalytics()
            
            loadingState = .loaded
            lastRefreshDate = Date()
            currentError = nil
            
            recordMetric("loadInitialData", duration: Date().timeIntervalSince(startTime), recordCount: historyData.count)
            print("✅ HistoryViewModel: Initial data loaded successfully (\(historyData.count) items)")
            
        } catch {
            let appError = AppError.from(error)
            loadingState = .error(appError)
            currentError = appError
            errorHandler.handle(appError, context: "Loading history data")
            recordMetric("loadInitialData", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    public func refreshData(for timePeriod: TimePeriod? = nil) async {
        let targetTimePeriod = timePeriod ?? selectedTimePeriod
        let startTime = Date()
        loadingState = .refreshing
        currentError = nil
        
        do {
            // Clear cache for this time period
            let cacheKey = generateCacheKey(for: targetTimePeriod)
            dataCache.removeValue(forKey: cacheKey)
            
            // Load fresh data
            let entries = try await budgetManager.getEntries(
                for: targetTimePeriod,
                sortedBy: .date,
                ascending: false
            )
            
            let historyItems = entries.prefix(maxHistoryItems).map { entry in
                BudgetHistoryData(
                    id: entry.id,
                    date: entry.date,
                    amount: entry.amount,
                    category: entry.category,
                    note: entry.note,
                    timePeriod: targetTimePeriod
                )
            }
            
            historyData = Array(historyItems)
            
            // Update cache
            dataCache[cacheKey] = historyData
            cleanupCache()
            
            await applyFilters()
            calculateAnalytics()
            
            loadingState = .loaded
            lastRefreshDate = Date()
            currentError = nil
            
            recordMetric("refreshData", duration: Date().timeIntervalSince(startTime), recordCount: historyData.count)
            print("✅ HistoryViewModel: Data refreshed successfully (\(historyData.count) items)")
            
        } catch {
            let appError = AppError.from(error)
            loadingState = .error(appError)
            currentError = appError
            errorHandler.handle(appError, context: "Refreshing history data")
            recordMetric("refreshData", duration: Date().timeIntervalSince(startTime), success: false)
        }
    }
    
    public func refreshData(budgetManager: BudgetManager, timePeriod: TimePeriod) async {
        await refreshData(for: timePeriod)
    }
    
    public func updateTimePeriod(_ timePeriod: TimePeriod, budgetManager: BudgetManager) async {
        selectedTimePeriod = timePeriod
        await refreshData(for: timePeriod)
    }
    
    // MARK: - Filtering and Sorting
    
    private func applyFilters() async {
        let startTime = Date()
        
        var filtered = historyData
        
        // Apply text search
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = filtered.filter { item in
                item.category.localizedCaseInsensitiveContains(searchText) ||
                (item.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply category filter
        if !selectedCategories.isEmpty {
            filtered = filtered.filter { selectedCategories.contains($0.category) }
        }
        
        // Apply amount range filter
        filtered = filtered.filter { amountRange.contains($0.amount) }
        
        // Apply date range filter
        filtered = filtered.filter { dateRange.contains($0.date) }
        
        // Apply type-specific filter
        switch selectedFilter {
        case .all:
            break // No additional filtering
        case .category:
            // Group by category (implementation depends on UI needs)
            break
        case .amount:
            // Sort by amount (handled in sorting)
            break
        case .date:
            // Sort by date (handled in sorting)
            break
        }
        
        filteredData = filtered
        await applySorting()
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("applyFilters", duration: duration, recordCount: filteredData.count)
    }
    
    private func applySorting() async {
        let startTime = Date()
        
        filteredData.sort { item1, item2 in
            let comparison: Bool
            
            switch selectedSort {
            case .date:
                comparison = item1.date < item2.date
            case .amount:
                comparison = item1.amount < item2.amount
            case .category:
                comparison = item1.category < item2.category
            }
            
            return sortAscending ? comparison : !comparison
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("applySorting", duration: duration, recordCount: filteredData.count)
    }
    
    // MARK: - Analytics
    
    private func calculateAnalytics() {
        guard !historyData.isEmpty else {
            analytics = nil
            return
        }
        
        let totalEntries = historyData.count
        let totalAmount = historyData.reduce(0) { $0 + $1.amount }
        let averageTransactionAmount = totalAmount / Double(totalEntries)
        
        // Find top category
        let categoryTotals = Dictionary(grouping: historyData) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        let topCategory = categoryTotals.max { $0.value < $1.value }
        
        // Create date range string
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let sortedDates = historyData.map { $0.date }.sorted()
        let dateRange: String
        if let firstDate = sortedDates.first, let lastDate = sortedDates.last {
            if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
                dateRange = dateFormatter.string(from: firstDate)
            } else {
                dateRange = "\(dateFormatter.string(from: firstDate)) - \(dateFormatter.string(from: lastDate))"
            }
        } else {
            dateRange = "No data"
        }
        
        // Generate trends (simplified)
        var trends: [String] = []
        if totalEntries > 10 {
            let recentEntries = historyData.prefix(5)
            let olderEntries = historyData.dropFirst(5).prefix(5)
            
            let recentAverage = recentEntries.reduce(0) { $0 + $1.amount } / Double(recentEntries.count)
            let olderAverage = olderEntries.reduce(0) { $0 + $1.amount } / Double(olderEntries.count)
            
            if recentAverage > olderAverage * 1.1 {
                trends.append("Spending is increasing")
            } else if recentAverage < olderAverage * 0.9 {
                trends.append("Spending is decreasing")
            } else {
                trends.append("Spending is stable")
            }
        }
        
        analytics = HistoryAnalytics(
            totalEntries: totalEntries,
            totalAmount: totalAmount,
            averageTransactionAmount: averageTransactionAmount,
            topCategory: topCategory?.key,
            topCategoryAmount: topCategory?.value ?? 0,
            dateRange: dateRange,
            trends: trends
        )
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey(for timePeriod: TimePeriod) -> String {
        return "history_\(timePeriod.rawValue)"
    }
    
    private func cleanupCache() {
        if dataCache.count > maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = Array(dataCache.keys.prefix(dataCache.count - maxCacheSize))
            keysToRemove.forEach { dataCache.removeValue(forKey: $0) }
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(
        _ operation: String,
        duration: TimeInterval,
        success: Bool = true,
        recordCount: Int = 0,
        cacheHit: Bool = false
    ) {
        let metric = PerformanceMetrics(
            operationType: operation,
            duration: duration,
            success: success,
            recordCount: recordCount,
            cacheHit: cacheHit
        )
        
        performanceQueue.async { [weak self] in
            Task<Void, Never>{ @MainActor [weak self] in
                self?.operationMetrics[operation] = metric
            }
        }
        
        // Log slow operations
        if duration > 0.5 {
            print("⚠️ HistoryViewModel: Slow operation '\(operation)' took \(String(format: "%.3f", duration))s")
        }
    }
    
    public func logPerformanceMetrics() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task<Void, Never>{ @MainActor in
                let metrics = self.operationMetrics
                let totalOperations = metrics.count
                let avgDuration = metrics.values.reduce(0) { $0 + $1.duration } / Double(max(totalOperations, 1))
                let cacheHitRate = Double(metrics.values.filter { $0.cacheHit }.count) / Double(max(totalOperations, 1)) * 100
                
                print("📊 HistoryViewModel Performance Summary:")
                print("   Total Operations: \(totalOperations)")
                print("   Average Duration: \(String(format: "%.3f", avgDuration))s")
                print("   Cache Hit Rate: \(String(format: "%.1f", cacheHitRate))%")
            }
        }
    }
    
    // MARK: - Public Interface
    
    public func selectDataPoint(_ dataPoint: BudgetHistoryData?) {
        selectedDataPoint = dataPoint
    }
    
    public func clearFilters() {
        selectedFilter = .all
        searchText = ""
        selectedCategories.removeAll()
        amountRange = 0...10000
        dateRange = Date()...Date()
    }
    
    public func exportData() async -> URL? {
        // Implementation for data export
        // This would typically generate a CSV or PDF file
        return nil
    }
    
    public func getDataForCategory(_ category: String) -> [BudgetHistoryData] {
        return filteredData.filter { $0.category == category }
    }
    
    public func getDataForDateRange(_ startDate: Date, _ endDate: Date) -> [BudgetHistoryData] {
        return filteredData.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    public func refreshIfNeeded() async {
        if needsRefresh {
            await refreshData()
        }
    }
}
