//
//  PurchasesViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//


import Foundation
import Combine
import SwiftUI

/// Comprehensive view model for managing purchases with advanced error handling and state management
@MainActor
public final class PurchasesViewModel: ObservableObject {
    // MARK: - Types
    
    public enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case refreshing
        case error(AppError)
        
        public var isLoading: Bool {
            switch self {
            case .loading, .refreshing: return true
            default: return false
            }
        }
        
        public var hasError: Bool {
            if case .error = self { return true }
            return false
        }
        
        public var errorValue: AppError? {
            if case .error(let error) = self { return error }
            return nil
        }
        
        public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.refreshing, .refreshing):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.id == rhsError.id
            default:
                return false
            }
        }
    }
    
    public enum FilterState {
        case none
        case search(String)
        case category(String)
        case timePeriod(TimePeriod)
        case combined(search: String?, category: String?, timePeriod: TimePeriod?)
        
        public var hasActiveFilters: Bool {
            switch self {
            case .none:
                return false
            case .search(let text):
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .category(let category):
                return category != "All"
            case .timePeriod(let period):
                return period != .thisMonth
            case .combined(let search, let category, let timePeriod):
                return (search?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ||
                       (category != "All" && category != nil) ||
                       (timePeriod != .thisMonth && timePeriod != nil)
            }
        }
    }
    
    public struct PurchaseStatistics {
        public let totalAmount: Double
        public let entryCount: Int
        public let averageAmount: Double
        public let categoryBreakdown: [String: Double]
        public let largestPurchase: BudgetEntry?
        public let smallestPurchase: BudgetEntry?
        public let mostFrequentCategory: String?
        public let dateRange: DateInterval?
        
        public var isEmpty: Bool {
            return entryCount == 0
        }
        
        public var formattedTotalAmount: String {
            return NumberFormatter.formatCurrency(totalAmount)
        }
        
        public var formattedAverageAmount: String {
            return NumberFormatter.formatCurrency(averageAmount)
        }
    }
    
    public enum OperationType {
        case loading
        case adding
        case updating(BudgetEntry)
        case deleting(BudgetEntry)
        case exporting
        case importing
    }
    
    // MARK: - Dependencies
    private let budgetManager: BudgetManager
    private let errorHandler: ErrorHandler
    private let settingsManager: SettingsManager
    
    // MARK: - Published Properties
    @Published public private(set) var loadingState: LoadingState = .idle
    @Published public private(set) var allEntries: [BudgetEntry] = []
    @Published public private(set) var filteredEntries: [BudgetEntry] = []
    @Published public private(set) var availableCategories: [String] = []
    @Published public private(set) var statistics: PurchaseStatistics?
    @Published public private(set) var lastRefreshDate: Date?
    @Published public private(set) var currentOperation: OperationType?
    
    // MARK: - Filter Properties
    @Published public var searchText: String = "" {
        didSet { scheduleFilterUpdate() }
    }
    @Published public var selectedCategory: String = "All" {
        didSet { scheduleFilterUpdate() }
    }
    @Published public var selectedTimePeriod: TimePeriod = .thisMonth {
        didSet { scheduleFilterUpdate() }
    }
    @Published public var sortOption: BudgetSortOption = .date {
        didSet { scheduleFilterUpdate() }
    }
    @Published public var sortAscending: Bool = false {
        didSet { scheduleFilterUpdate() }
    }
    
    // MARK: - Error State
    @Published public private(set) var hasError: Bool = false
    @Published public private(set) var currentError: AppError?
    @Published public private(set) var retryCount: Int = 0
    private let maxRetries = 3
    
    // MARK: - Performance and Caching
    private var lastFilterUpdate = Date()
    private let filterDebounceInterval: TimeInterval = 0.3
    private var filterUpdateTask: Task<Void, Never>?
    private var statisticsCache: (entries: [BudgetEntry], stats: PurchaseStatistics)?
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.purchases.metrics", qos: .utility)
    
    // MARK: - Initialization
    
    public init(
        budgetManager: BudgetManager,
        errorHandler: ErrorHandler,
        settingsManager: SettingsManager
    ) {
        self.budgetManager = budgetManager
        self.errorHandler = errorHandler
        self.settingsManager = settingsManager
        
        setupObservers()
        setupPerformanceMonitoring()
        
        print("✅ PurchasesViewModel: Initialized successfully")
    }
    
    // MARK: - Public Interface
    
    /// Load initial data
    public func loadData() async {
        await performOperation(.loading) {
            try await loadPurchasesData()
        }
    }
    
    /// Refresh data from source
    public func refreshData() async {
        await performOperation(.refreshing) {
            try await loadPurchasesData(forceRefresh: true)
        }
    }
    
    /// Add a new purchase
    public func addPurchase(
        amount: Double,
        category: String,
        date: Date,
        note: String? = nil
    ) async throws {
        await performOperation(.adding) {
            let entry = try BudgetEntry(
                amount: amount,
                category: category,
                date: date,
                note: note
            )
            
            try await budgetManager.addEntry(entry)
            await loadPurchasesData()
        }
    }
    
    /// Update an existing purchase
    public func updatePurchase(_ entry: BudgetEntry) async throws {
        await performOperation(.updating(entry)) {
            try await budgetManager.updateEntry(entry)
            await loadPurchasesData()
        }
    }
    
    /// Delete a purchase
    public func deletePurchase(_ entry: BudgetEntry) async throws {
        await performOperation(.deleting(entry)) {
            try await budgetManager.deleteEntry(entry)
            
            // Update local state immediately for better UX
            allEntries.removeAll { $0.id == entry.id }
            await applyFiltersAndSort()
        }
    }
    
    /// Delete multiple purchases
    public func deletePurchases(_ entries: [BudgetEntry]) async throws {
        for entry in entries {
            try await deletePurchase(entry)
        }
    }
    
    /// Clear all filters
    public func clearFilters() {
        searchText = ""
        selectedCategory = "All"
        selectedTimePeriod = .thisMonth
        sortOption = .date
        sortAscending = false
    }
    
    /// Get available categories with "All" option
    public func getAvailableCategoriesWithAll() -> [String] {
        return ["All"] + availableCategories.sorted()
    }
    
    /// Check if filters are active
    public var hasActiveFilters: Bool {
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
               selectedCategory != "All" ||
               selectedTimePeriod != .thisMonth ||
               sortOption != .date ||
               sortAscending != false
    }
    
    /// Get current filter state
    public var currentFilterState: FilterState {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let search = trimmedSearch.isEmpty ? nil : trimmedSearch
        let category = selectedCategory == "All" ? nil : selectedCategory
        let timePeriod = selectedTimePeriod == .thisMonth ? nil : selectedTimePeriod
        
        if search == nil && category == nil && timePeriod == nil {
            return .none
        } else {
            return .combined(search: search, category: category, timePeriod: timePeriod)
        }
    }
    
    /// Export current filtered data
    public func exportData(configuration: CSVExport.ExportConfiguration) async throws -> CSVExport.ExportResult {
        return try await performOperationWithResult(.exporting) {
            return try await CSVExport.exportBudgetEntries(filteredEntries, configuration: configuration)
        }
    }
    
    /// Get detailed statistics for current data
    public func getDetailedStatistics() -> PurchaseStatistics? {
        return calculateStatistics(for: filteredEntries)
    }
    
    /// Retry last failed operation
    public func retryLastOperation() async {
        guard retryCount < maxRetries else {
            await handleError(AppError.validation(message: "Maximum retry attempts reached"))
            return
        }
        
        retryCount += 1
        clearError()
        
        // Retry based on current state
        switch loadingState {
        case .error:
            await loadData()
        default:
            await refreshData()
        }
    }
    
    /// Clear current error state
    public func clearError() {
        hasError = false
        currentError = nil
        
        if case .error = loadingState {
            loadingState = .loaded
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupObservers() {
        // Observe budget manager changes
        budgetManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
               Task<Void, Never>{ [weak self] in
                    await self?.handleBudgetManagerUpdate()
                }
            }
            .store(in: &cancellables)
        
        // Monitor error handler for global errors
        errorHandler.$currentError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                // Only handle errors related to purchases
                if error.context?.contains("purchase") == true {
                   Task<Void, Never>{ [weak self] in
                        await self?.handleError(error)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func handleBudgetManagerUpdate() async {
        // Only reload if we're not currently loading
        guard !loadingState.isLoading else { return }
        
        await loadPurchasesData()
    }
    
    private func performOperation<T>(_ operationType: OperationType, operation: @escaping () async throws -> T) async {
        let startTime = Date()
        currentOperation = operationType
        
        // Update loading state
        switch operationType {
        case .loading:
            loadingState = .loading
        case .refreshing:
            loadingState = .refreshing
        default:
            break
        }
        
        clearError()
        
        do {
            let _ = try await operation()
            
            // Update state on success
            if case .loading = operationType {
                loadingState = .loaded
                lastRefreshDate = Date()
                retryCount = 0
            } else if case .refreshing = operationType {
                loadingState = .loaded
                lastRefreshDate = Date()
                retryCount = 0
            }
            
            currentOperation = nil
            
            recordMetric(String(describing: operationType), duration: Date().timeIntervalSince(startTime))
            
        } catch {
            await handleError(AppError.from(error))
            currentOperation = nil
        }
    }
    
    private func performOperationWithResult<T>(_ operationType: OperationType, operation: @escaping () async throws -> T) async throws -> T {
        let startTime = Date()
        currentOperation = operationType
        clearError()
        
        do {
            let result = try await operation()
            currentOperation = nil
            recordMetric(String(describing: operationType), duration: Date().timeIntervalSince(startTime))
            return result
        } catch {
            currentOperation = nil
            await handleError(AppError.from(error))
            throw error
        }
    }
    
    private func loadPurchasesData(forceRefresh: Bool = false) async throws {
        let startTime = Date()
        
        // Load entries from budget manager
        let entries = try await budgetManager.getEntries(
            sortedBy: .date,
            ascending: false
        )
        
        // Update local state
        allEntries = entries
        
        // Load categories
        availableCategories = budgetManager.getAvailableCategories()
        
        // Apply current filters
        await applyFiltersAndSort()
        
        recordMetric("loadPurchasesData", duration: Date().timeIntervalSince(startTime))
        print("✅ PurchasesViewModel: Loaded \(entries.count) purchases")
    }
    
    private func scheduleFilterUpdate() {
        // Cancel previous filter update
        filterUpdateTask?.cancel()
        
        let updateTime = Date()
        lastFilterUpdate = updateTime
        
        filterUpdateTask =Task<Void, Never>{
            // Debounce the update
            try? await Task.sleep(nanoseconds: UInt64(filterDebounceInterval * 1_000_000_000))
            
            // Only proceed if this is still the latest update
            if lastFilterUpdate == updateTime && !Task.isCancelled {
                await applyFiltersAndSort()
            }
        }
    }
    
    private func applyFiltersAndSort() async {
        let startTime = Date()
        
        var filtered = allEntries
        
        // Apply time period filter
        if selectedTimePeriod != .thisMonth {
            let interval = selectedTimePeriod.dateInterval()
            filtered = filtered.filter { entry in
                entry.date >= interval.start && entry.date <= interval.end
            }
        }
        
        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply search filter
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let searchTerms = trimmedSearch.lowercased()
            filtered = filtered.filter { entry in
                entry.category.lowercased().contains(searchTerms) ||
                (entry.note?.lowercased().contains(searchTerms) ?? false) ||
                entry.formattedAmount.contains(searchTerms)
            }
        }
        
        // Apply sorting
        filtered = sortEntries(filtered, by: sortOption, ascending: sortAscending)
        
        // Update filtered entries
        filteredEntries = filtered
        
        // Update statistics
        statistics = calculateStatistics(for: filtered)
        
        recordMetric("applyFiltersAndSort", duration: Date().timeIntervalSince(startTime))
    }
    
    private func sortEntries(
        _ entries: [BudgetEntry],
        by option: BudgetSortOption,
        ascending: Bool
    ) -> [BudgetEntry] {
        let sorted = entries.sorted { entry1, entry2 in
            let result: Bool
            switch option {
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
    
    private func calculateStatistics(for entries: [BudgetEntry]) -> PurchaseStatistics {
        // Use cache if entries haven't changed
        if let cache = statisticsCache, cache.entries.count == entries.count {
            let entriesMatch = zip(cache.entries, entries).allSatisfy { $0.id == $1.id }
            if entriesMatch {
                return cache.stats
            }
        }
        
        let totalAmount = entries.reduce(0) { $0 + $1.amount }
        let entryCount = entries.count
        let averageAmount = entryCount > 0 ? totalAmount / Double(entryCount) : 0
        
        // Category breakdown
        let categoryBreakdown = Dictionary(grouping: entries, by: { $0.category })
            .mapValues { categoryEntries in
                categoryEntries.reduce(0) { $0 + $1.amount }
            }
        
        // Find largest and smallest purchases
        let sortedByAmount = entries.sorted { $0.amount > $1.amount }
        let largestPurchase = sortedByAmount.first
        let smallestPurchase = sortedByAmount.last
        
        // Most frequent category
        let mostFrequentCategory = categoryBreakdown.max(by: { $0.value < $1.value })?.key
        
        // Date range
        let sortedByDate = entries.sorted { $0.date < $1.date }
        let dateRange: DateInterval?
        if let first = sortedByDate.first, let last = sortedByDate.last {
            dateRange = DateInterval(start: first.date, end: last.date)
        } else {
            dateRange = nil
        }
        
        let stats = PurchaseStatistics(
            totalAmount: totalAmount,
            entryCount: entryCount,
            averageAmount: averageAmount,
            categoryBreakdown: categoryBreakdown,
            largestPurchase: largestPurchase,
            smallestPurchase: smallestPurchase,
            mostFrequentCategory: mostFrequentCategory,
            dateRange: dateRange
        )
        
        // Cache the result
        statisticsCache = (entries: entries, stats: stats)
        
        return stats
    }
    
    private func handleError(_ error: AppError) async {
        hasError = true
        currentError = error
        
        if case .loading = loadingState {
            loadingState = .error(error)
        } else if case .refreshing = loadingState {
            loadingState = .error(error)
        }
        
        // Report to global error handler
        errorHandler.handle(error, context: "Purchases view model")
        
        print("❌ PurchasesViewModel: Error - \(error.errorDescription ?? "Unknown error")")
    }
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 1.0 {
                print("⚠️ PurchasesViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 PurchasesViewModel Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        filterUpdateTask?.cancel()
        cancellables.removeAll()
        print("🧹 PurchasesViewModel: Cleaned up resources")
    }
}

// MARK: - Extensions

extension PurchasesViewModel {
    /// Get formatted summary for current data
    public var formattedSummary: String {
        let count = filteredEntries.count
        let total = statistics?.totalAmount ?? 0
        
        if count == 0 {
            return "No purchases found"
        } else if count == 1 {
            return "1 purchase • \(NumberFormatter.formatCurrency(total))"
        } else {
            return "\(count) purchases • \(NumberFormatter.formatCurrency(total))"
        }
    }
    
    /// Check if data is empty
    public var isEmpty: Bool {
        return filteredEntries.isEmpty && !loadingState.isLoading
    }
    
    /// Check if export is available
    public var canExport: Bool {
        return !filteredEntries.isEmpty && !loadingState.isLoading
    }
    
    /// Get filter description for UI
    public var filterDescription: String {
        var components: [String] = []
        
        if selectedTimePeriod != .thisMonth {
            components.append(selectedTimePeriod.shortDisplayName)
        }
        
        if selectedCategory != "All" {
            components.append(selectedCategory)
        }
        
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            components.append("'\(trimmedSearch)'")
        }
        
        if components.isEmpty {
            return "All purchases"
        } else {
            return components.joined(separator: " • ")
        }
    }
    
    /// Get time period options for filtering
    public var timePeriodsForFiltering: [TimePeriod] {
        return TimePeriod.commonPeriods
    }
    
    /// Get sort options for purchases
    public var sortOptionsForPurchases: [BudgetSortOption] {
        return [.date, .amount, .category]
    }
}

// MARK: - Search and Filter Helpers

extension PurchasesViewModel {
    /// Search purchases by text
    public func searchPurchases(_ searchText: String) {
        self.searchText = searchText
    }
    
    /// Filter by category
    public func filterByCategory(_ category: String) {
        selectedCategory = category
    }
    
    /// Filter by time period
    public func filterByTimePeriod(_ timePeriod: TimePeriod) {
        selectedTimePeriod = timePeriod
    }
    
    /// Sort purchases
    public func sortPurchases(by option: BudgetSortOption, ascending: Bool) {
        sortOption = option
        sortAscending = ascending
    }
    
    /// Get purchases for specific category
    public func getPurchasesForCategory(_ category: String) -> [BudgetEntry] {
        return filteredEntries.filter { $0.category == category }
    }
    
    /// Get purchases for date range
    public func getPurchasesForDateRange(_ startDate: Date, _ endDate: Date) -> [BudgetEntry] {
        return filteredEntries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
    }
}

// MARK: - Analytics and Insights

extension PurchasesViewModel {
    /// Get spending trends
    public func getSpendingTrends() -> [String: Double] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        }
        
        return grouped.mapValues { entries in
            entries.reduce(0) { $0 + $1.amount }
        }
    }
    
    /// Get category insights
    public func getCategoryInsights() -> [(category: String, amount: Double, percentage: Double)] {
        guard let stats = statistics, stats.totalAmount > 0 else { return [] }
        
        return stats.categoryBreakdown.map { category, amount in
            let percentage = (amount / stats.totalAmount) * 100
            return (category: category, amount: amount, percentage: percentage)
        }.sorted { $0.amount > $1.amount }
    }
    
    /// Get recent activity summary
    public func getRecentActivitySummary(days: Int = 7) -> (count: Int, amount: Double) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentEntries = filteredEntries.filter { $0.date >= cutoffDate }
        
        return (
            count: recentEntries.count,
            amount: recentEntries.reduce(0) { $0 + $1.amount }
        )
    }
}

// MARK: - Testing Support

#if DEBUG
extension PurchasesViewModel {
    /// Create test view model
    static func createTestViewModel() -> PurchasesViewModel {
        return PurchasesViewModel(
            budgetManager: BudgetManager.shared,
            errorHandler: ErrorHandler.shared,
            settingsManager: SettingsManager.shared
        )
    }
    
    /// Load test data
    func loadTestData() async {
        let testEntries = [
            try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date(), note: "Weekly shopping"),
            try! BudgetEntry(amount: 12.50, category: "Transportation", date: Date().addingTimeInterval(-86400), note: "Bus fare"),
            try! BudgetEntry(amount: 89.99, category: "Entertainment", date: Date().addingTimeInterval(-172800), note: "Movie tickets"),
            try! BudgetEntry(amount: 25.00, category: "Dining", date: Date().addingTimeInterval(-259200), note: "Lunch"),
            try! BudgetEntry(amount: 150.00, category: "Utilities", date: Date().addingTimeInterval(-345600), note: "Electric bill")
        ]
        
        allEntries = testEntries
        availableCategories = ["Groceries", "Transportation", "Entertainment", "Dining", "Utilities"]
        await applyFiltersAndSort()
        loadingState = .loaded
        lastRefreshDate = Date()
        
        print("✅ PurchasesViewModel: Loaded test data")
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        entryCount: Int,
        filteredCount: Int,
        categoryCount: Int,
        hasError: Bool,
        isLoading: Bool,
        retryCount: Int
    ) {
        return (
            entryCount: allEntries.count,
            filteredCount: filteredEntries.count,
            categoryCount: availableCategories.count,
            hasError: hasError,
            isLoading: loadingState.isLoading,
            retryCount: retryCount
        )
    }
    
    /// Simulate error for testing
    func simulateErrorForTesting(_ error: AppError) async {
        await handleError(error)
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
    
    /// Reset state for testing
    func resetStateForTesting() {
        allEntries = []
        filteredEntries = []
        availableCategories = []
        statistics = nil
        lastRefreshDate = nil
        loadingState = .idle
        hasError = false
        currentError = nil
        retryCount = 0
        currentOperation = nil
        
        searchText = ""
        selectedCategory = "All"
        selectedTimePeriod = .thisMonth
        sortOption = .date
        sortAscending = false
        
        statisticsCache = nil
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
        
        print("🧪 PurchasesViewModel: Reset state for testing")
    }
}
#endif
