//
//  FilterSortViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//

import Foundation
import Combine

/// ViewModel for managing filter and sort options with enhanced state management and error handling
@MainActor
class FilterSortViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var groupByCategory = false
    @Published var showOnlyOverBudget = false
    @Published var showOnlyWithActivity = false
    @Published var showZeroBudget = true
    @Published var showHighSpending = false
    @Published var showPercentages = true
    @Published var showTrends = false
    @Published var compactView = false
    @Published var previewText: String?
    
    // MARK: - Private Properties
    private let errorHandler = ErrorHandler.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Constants
    private enum UserDefaultsKeys {
        static let groupByCategory = "FilterSort.groupByCategory"
        static let showOnlyOverBudget = "FilterSort.showOnlyOverBudget"
        static let showOnlyWithActivity = "FilterSort.showOnlyWithActivity"
        static let showZeroBudget = "FilterSort.showZeroBudget"
        static let showHighSpending = "FilterSort.showHighSpending"
        static let showPercentages = "FilterSort.showPercentages"
        static let showTrends = "FilterSort.showTrends"
        static let compactView = "FilterSort.compactView"
    }
    
    // MARK: - Initialization
    init() {
        loadSavedPreferences()
        setupPropertyObservers()
    }
    
    // MARK: - Public Methods
    
    /// Configure initial state with provided values
    func configure(timePeriod: TimePeriod, sortOption: BudgetSortOption, sortAscending: Bool) {
        updatePreview(timePeriod: timePeriod, sortOption: sortOption, sortAscending: sortAscending)
    }
    
    /// Update preview text based on current settings
    func updatePreview(timePeriod: TimePeriod, sortOption: BudgetSortOption, sortAscending: Bool) {
        let preview = generatePreviewText(
            timePeriod: timePeriod,
            sortOption: sortOption,
            sortAscending: sortAscending
        )
        previewText = preview
    }
    
    /// Reset all options to their default values
    func resetToDefaults() {
        do {
            groupByCategory = false
            showOnlyOverBudget = false
            showOnlyWithActivity = false
            showZeroBudget = true
            showHighSpending = false
            showPercentages = true
            showTrends = false
            compactView = false
            
            clearSavedPreferences()
            print("✅ FilterSortViewModel: Reset to defaults")
            
        } catch {
            errorHandler.handle(
                AppError.from(error),
                context: "Resetting filter options to defaults"
            )
        }
    }
    
    /// Get current filter criteria for data processing
    func getFilterCriteria() -> FilterCriteria {
        return FilterCriteria(
            groupByCategory: groupByCategory,
            showOnlyOverBudget: showOnlyOverBudget,
            showOnlyWithActivity: showOnlyWithActivity,
            showZeroBudget: showZeroBudget,
            showHighSpending: showHighSpending,
            showPercentages: showPercentages,
            showTrends: showTrends,
            compactView: compactView
        )
    }
    
    /// Validate current filter configuration
    func validateConfiguration() -> ValidationResult {
        var warnings: [String] = []
        var isValid = true
        
        // Check for conflicting options
        if !showZeroBudget && !showOnlyWithActivity && !showOnlyOverBudget {
            warnings.append("No data will be shown with current filter settings")
            isValid = false
        }
        
        if showOnlyOverBudget && showOnlyWithActivity {
            warnings.append("Combining 'Over Budget' and 'Has Activity' filters may show limited results")
        }
        
        if compactView && showTrends {
            warnings.append("Trends may not be visible in compact view")
        }
        
        return ValidationResult(isValid: isValid, warnings: warnings)
    }
    
    /// Export current configuration
    func exportConfiguration() -> [String: Any] {
        return [
            "groupByCategory": groupByCategory,
            "showOnlyOverBudget": showOnlyOverBudget,
            "showOnlyWithActivity": showOnlyWithActivity,
            "showZeroBudget": showZeroBudget,
            "showHighSpending": showHighSpending,
            "showPercentages": showPercentages,
            "showTrends": showTrends,
            "compactView": compactView,
            "exportDate": Date().timeIntervalSince1970,
            "version": "1.0"
        ]
    }
    
    /// Import configuration from exported data
    func importConfiguration(_ data: [String: Any]) {
        do {
            if let groupByCategory = data["groupByCategory"] as? Bool {
                self.groupByCategory = groupByCategory
            }
            if let showOnlyOverBudget = data["showOnlyOverBudget"] as? Bool {
                self.showOnlyOverBudget = showOnlyOverBudget
            }
            if let showOnlyWithActivity = data["showOnlyWithActivity"] as? Bool {
                self.showOnlyWithActivity = showOnlyWithActivity
            }
            if let showZeroBudget = data["showZeroBudget"] as? Bool {
                self.showZeroBudget = showZeroBudget
            }
            if let showHighSpending = data["showHighSpending"] as? Bool {
                self.showHighSpending = showHighSpending
            }
            if let showPercentages = data["showPercentages"] as? Bool {
                self.showPercentages = showPercentages
            }
            if let showTrends = data["showTrends"] as? Bool {
                self.showTrends = showTrends
            }
            if let compactView = data["compactView"] as? Bool {
                self.compactView = compactView
            }
            
            saveAllPreferences()
            print("✅ FilterSortViewModel: Imported configuration successfully")
            
        } catch {
            errorHandler.handle(
                AppError.from(error),
                context: "Importing filter configuration"
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedPreferences() {
        groupByCategory = userDefaults.bool(forKey: UserDefaultsKeys.groupByCategory)
        showOnlyOverBudget = userDefaults.bool(forKey: UserDefaultsKeys.showOnlyOverBudget)
        showOnlyWithActivity = userDefaults.bool(forKey: UserDefaultsKeys.showOnlyWithActivity)
        showZeroBudget = userDefaults.object(forKey: UserDefaultsKeys.showZeroBudget) as? Bool ?? true
        showHighSpending = userDefaults.bool(forKey: UserDefaultsKeys.showHighSpending)
        showPercentages = userDefaults.object(forKey: UserDefaultsKeys.showPercentages) as? Bool ?? true
        showTrends = userDefaults.bool(forKey: UserDefaultsKeys.showTrends)
        compactView = userDefaults.bool(forKey: UserDefaultsKeys.compactView)
    }
    
    private func setupPropertyObservers() {
        // Observe changes to save preferences automatically
        $groupByCategory
            .sink { [weak self] _ in self?.savePreference(\.groupByCategory, key: UserDefaultsKeys.groupByCategory) }
            .store(in: &cancellables)
        
        $showOnlyOverBudget
            .sink { [weak self] _ in self?.savePreference(\.showOnlyOverBudget, key: UserDefaultsKeys.showOnlyOverBudget) }
            .store(in: &cancellables)
        
        $showOnlyWithActivity
            .sink { [weak self] _ in self?.savePreference(\.showOnlyWithActivity, key: UserDefaultsKeys.showOnlyWithActivity) }
            .store(in: &cancellables)
        
        $showZeroBudget
            .sink { [weak self] _ in self?.savePreference(\.showZeroBudget, key: UserDefaultsKeys.showZeroBudget) }
            .store(in: &cancellables)
        
        $showHighSpending
            .sink { [weak self] _ in self?.savePreference(\.showHighSpending, key: UserDefaultsKeys.showHighSpending) }
            .store(in: &cancellables)
        
        $showPercentages
            .sink { [weak self] _ in self?.savePreference(\.showPercentages, key: UserDefaultsKeys.showPercentages) }
            .store(in: &cancellables)
        
        $showTrends
            .sink { [weak self] _ in self?.savePreference(\.showTrends, key: UserDefaultsKeys.showTrends) }
            .store(in: &cancellables)
        
        $compactView
            .sink { [weak self] _ in self?.savePreference(\.compactView, key: UserDefaultsKeys.compactView) }
            .store(in: &cancellables)
    }
    
    private func savePreference<T>(_ keyPath: KeyPath<FilterSortViewModel, T>, key: String) {
        let value = self[keyPath: keyPath]
        userDefaults.set(value, forKey: key)
    }
    
    private func saveAllPreferences() {
        userDefaults.set(groupByCategory, forKey: UserDefaultsKeys.groupByCategory)
        userDefaults.set(showOnlyOverBudget, forKey: UserDefaultsKeys.showOnlyOverBudget)
        userDefaults.set(showOnlyWithActivity, forKey: UserDefaultsKeys.showOnlyWithActivity)
        userDefaults.set(showZeroBudget, forKey: UserDefaultsKeys.showZeroBudget)
        userDefaults.set(showHighSpending, forKey: UserDefaultsKeys.showHighSpending)
        userDefaults.set(showPercentages, forKey: UserDefaultsKeys.showPercentages)
        userDefaults.set(showTrends, forKey: UserDefaultsKeys.showTrends)
        userDefaults.set(compactView, forKey: UserDefaultsKeys.compactView)
    }
    
    private func clearSavedPreferences() {
        userDefaults.removeObject(forKey: UserDefaultsKeys.groupByCategory)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showOnlyOverBudget)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showOnlyWithActivity)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showZeroBudget)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showHighSpending)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showPercentages)
        userDefaults.removeObject(forKey: UserDefaultsKeys.showTrends)
        userDefaults.removeObject(forKey: UserDefaultsKeys.compactView)
    }
    
    private func generatePreviewText(
        timePeriod: TimePeriod,
        sortOption: BudgetSortOption,
        sortAscending: Bool
    ) -> String {
        var components: [String] = []
        
        // Time period
        components.append("Showing data for \(timePeriod.displayName.lowercased())")
        
        // Sorting
        let direction = sortAscending ? "ascending" : "descending"
        components.append("sorted by \(sortOption.displayName.lowercased()) (\(direction))")
        
        // Filters
        var filters: [String] = []
        if showOnlyOverBudget { filters.append("over budget items") }
        if showOnlyWithActivity { filters.append("categories with activity") }
        if !showZeroBudget { filters.append("excluding zero budgets") }
        if showHighSpending { filters.append("high spending categories") }
        
        if !filters.isEmpty {
            components.append("filtered to show \(filters.joined(separator: ", "))")
        }
        
        // Display options
        var displayOptions: [String] = []
        if groupByCategory { displayOptions.append("grouped by category") }
        if showPercentages { displayOptions.append("with percentages") }
        if showTrends { displayOptions.append("with trend indicators") }
        if compactView { displayOptions.append("in compact view") }
        
        if !displayOptions.isEmpty {
            components.append("displayed \(displayOptions.joined(separator: ", "))")
        }
        
        return components.joined(separator: ", ") + "."
    }
}

// MARK: - Supporting Types

struct FilterCriteria {
    let groupByCategory: Bool
    let showOnlyOverBudget: Bool
    let showOnlyWithActivity: Bool
    let showZeroBudget: Bool
    let showHighSpending: Bool
    let showPercentages: Bool
    let showTrends: Bool
    let compactView: Bool
    
    /// Apply filters to budget history data
    func apply(to data: [BudgetHistoryData]) -> [BudgetHistoryData] {
        var filteredData = data
        
        // Apply filters
        if showOnlyOverBudget {
            filteredData = filteredData.filter { $0.isOverBudget }
        }
        
        if showOnlyWithActivity {
            filteredData = filteredData.filter { $0.amountSpent > 0 }
        }
        
        if !showZeroBudget {
            filteredData = filteredData.filter { $0.budgetedAmount > 0 }
        }
        
        if showHighSpending {
            // Define high spending as > 75% of budget or > average spending
            let averageSpending = data.reduce(0) { $0 + $1.amountSpent } / Double(data.count)
            filteredData = filteredData.filter {
                $0.percentageSpent > 75 || $0.amountSpent > averageSpending
            }
        }
        
        return filteredData
    }
    
    /// Get display configuration
    func getDisplayConfig() -> DisplayConfiguration {
        return DisplayConfiguration(
            showPercentages: showPercentages,
            showTrends: showTrends,
            compactView: compactView,
            groupByCategory: groupByCategory
        )
    }
}

struct DisplayConfiguration {
    let showPercentages: Bool
    let showTrends: Bool
    let compactView: Bool
    let groupByCategory: Bool
}
