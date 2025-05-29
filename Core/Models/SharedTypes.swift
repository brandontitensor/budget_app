//
//  SharedTypes.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/17/24.
//

import SwiftUI
import Foundation
import Combine
import WidgetKit
import CoreData

// MARK: - Theme Manager
@MainActor
public final class ThemeManager: ObservableObject {
    // MARK: - Types
    public struct ColorOption: Identifiable, Hashable, Codable {
        public let id: UUID
        let name: String
        let colorComponents: ColorComponents
        
        var color: Color {
            Color(
                red: colorComponents.red,
                green: colorComponents.green,
                blue: colorComponents.blue,
                opacity: colorComponents.opacity
            )
        }
        
        init(name: String, color: Color) {
            self.id = UUID()
            self.name = name
            self.colorComponents = ColorComponents(from: color)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: ColorOption, rhs: ColorOption) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public struct ColorComponents: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
        
        init(from color: Color) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.opacity = Double(a)
        }
    }
    
    // MARK: - Constants
    public static let defaultPrimaryColor = ColorOption(name: "Blue", color: .blue)
    
    public static let availableColors: [ColorOption] = [
        ColorOption(name: "Blue", color: .blue),
        ColorOption(name: "Purple", color: .purple),
        ColorOption(name: "Green", color: .green),
        ColorOption(name: "Orange", color: .orange),
        ColorOption(name: "Pink", color: .pink),
        ColorOption(name: "Teal", color: .teal)
    ]
    
    // MARK: - Published Properties
    @Published public var primaryColor: Color {
        didSet {
            UserDefaults.standard.set(colorOption.name, forKey: "primaryColorName")
            updateGlobalAppearance()
        }
    }
    
    @Published public var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    // MARK: - Initialization
    public static let shared = ThemeManager()
    
    private init() {
        if let colorName = UserDefaults.standard.string(forKey: "primaryColorName"),
           let storedColor = ThemeManager.availableColors.first(where: { $0.name == colorName }) {
            self.primaryColor = storedColor.color
        } else {
            self.primaryColor = ThemeManager.defaultPrimaryColor.color
            UserDefaults.standard.set("Blue", forKey: "primaryColorName")
        }
        
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    // MARK: - Public Methods
    public func resetToDefaults() {
        primaryColor = ThemeManager.defaultPrimaryColor.color
        isDarkMode = false
    }
    
    public func colorForCategory(_ category: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        let index = abs(category.hashValue) % colors.count
        return colors[index]
    }
    
    public func primaryGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func updateGlobalAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
    }
    
    private var colorOption: ColorOption {
        ThemeManager.availableColors.first { $0.color == primaryColor } ?? ThemeManager.defaultPrimaryColor
    }
}

// MARK: - Budget Manager
@MainActor
public final class BudgetManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var entries: [BudgetEntry] = []
    @Published private(set) var monthlyBudgets: [MonthlyBudget] = []
    
    // MARK: - Dependencies
    private let coreDataManager: CoreDataManager
    private let calendar = Calendar.current
    
    // MARK: - Type Aliases for CSV Import
    public typealias PurchaseImportData = CSVImport.PurchaseImportData
    public typealias BudgetImportData = CSVImport.BudgetImportData
    public typealias ImportResults = CSVImport.ImportResults
    
    // MARK: - Initialization
    public static let shared = BudgetManager()
    
    private init() {
        self.coreDataManager = .shared
        loadData()
        Task {
            await checkAndUpdateMonthlyBudgets()
            await MainActor.run {
                updateRemainingBudget()
            }
        }
    }
    
    // MARK: - Data Loading
    func loadData() {
        Task {
            do {
                self.entries = try await coreDataManager.getAllEntries()
                self.monthlyBudgets = try await coreDataManager.getAllMonthlyBudgets()
            } catch {
                print("Failed to load data: \(error)")
            }
        }
    }
    
    // MARK: - Entry Management
    func getEntries(for timePeriod: TimePeriod) async throws -> [BudgetEntry] {
        let dateInterval = timePeriod.dateInterval()
        return entries.filter { entry in
            entry.date >= dateInterval.start && entry.date <= dateInterval.end
        }
    }
    
    func addEntry(_ entry: BudgetEntry) async throws {
        try await coreDataManager.addEntry(entry)
        await MainActor.run {
            self.entries.append(entry)
            self.objectWillChange.send()
            updateRemainingBudget()
        }
    }
    
    func updateEntry(_ entry: BudgetEntry) async throws {
        try await coreDataManager.updateEntry(entry)
        await MainActor.run {
            if let index = self.entries.firstIndex(where: { $0.id == entry.id }) {
                self.entries[index] = entry
                self.objectWillChange.send()
                updateRemainingBudget()
            }
        }
    }
    
    func deleteEntry(_ entry: BudgetEntry) async throws {
        try await coreDataManager.deleteEntry(entry)
        await MainActor.run {
            self.entries.removeAll { $0.id == entry.id }
            self.objectWillChange.send()
            updateRemainingBudget()
        }
    }
    
    // MARK: - Budget Management
    func getCurrentMonthBudget() -> Double {
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        return getMonthlyBudgets(for: month, year: year)
            .reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { budget in
            budget.month == month && budget.year == year
        }
    }
    
    func updateMonthlyBudgets(_ budgets: [String: Double], for month: Int, year: Int) async throws {
        for (category, amount) in budgets {
            let budget = try MonthlyBudget(
                category: category,
                amount: amount,
                month: month,
                year: year
            )
            try await coreDataManager.addOrUpdateMonthlyBudget(budget)
        }
        loadData() // Reload data after update
    }
    
    func addCategory(_ category: String, amount: Double, month: Int, year: Int, includeFutureMonths: Bool) async throws {
        if includeFutureMonths {
            for m in month...12 {
                let budget = try MonthlyBudget(
                    category: category,
                    amount: amount,
                    month: m,
                    year: year
                )
                try await coreDataManager.addOrUpdateMonthlyBudget(budget)
            }
        } else {
            let budget = try MonthlyBudget(
                category: category,
                amount: amount,
                month: month,
                year: year
            )
            try await coreDataManager.addOrUpdateMonthlyBudget(budget)
        }
        loadData()
    }
    
    func deleteMonthlyBudget(category: String, fromMonth: Int, year: Int, includeFutureMonths: Bool) async throws {
        try await coreDataManager.deleteMonthlyBudget(
            category: category,
            fromMonth: fromMonth,
            year: year,
            includeFutureMonths: includeFutureMonths
        )
        loadData()
    }
    
    func getAvailableCategories() -> [String] {
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        let currentBudgets = getMonthlyBudgets(for: currentMonth, year: currentYear)
        return currentBudgets.map { $0.category }.sorted()
    }
    
    // MARK: - CSV Import Methods
    
    /// Import purchases from CSV file
    public func importPurchases(from url: URL) async throws -> CSVImport.ImportResults<CSVImport.PurchaseImportData> {
        let existingCategories = getAvailableCategories()
        return try await CSVImport.importPurchases(from: url, existingCategories: existingCategories)
    }
    
    /// Import budgets from CSV file
    public func importBudgets(from url: URL) async throws -> CSVImport.ImportResults<CSVImport.BudgetImportData> {
        let existingCategories = getAvailableCategories()
        return try await CSVImport.importBudgets(from: url, existingCategories: existingCategories)
    }
    
    /// Process and save imported purchase data with category mappings
    public func processImportedPurchases(
        _ importResults: CSVImport.ImportResults<CSVImport.PurchaseImportData>,
        categoryMappings: [String: String]
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for purchaseData in importResults.data {
            guard let date = dateFormatter.date(from: purchaseData.date) else {
                throw BudgetImportError.invalidDateFormat
            }
            
            let mappedCategory = categoryMappings[purchaseData.category] ?? purchaseData.category
            
            let entry = try BudgetEntry(
                amount: purchaseData.amount,
                category: mappedCategory,
                date: date,
                note: purchaseData.note
            )
            
            try await addEntry(entry)
        }
    }
    
    /// Process and save imported budget data
    public func processImportedBudgets(
        _ importResults: CSVImport.ImportResults<CSVImport.BudgetImportData>
    ) async throws {
        for budgetData in importResults.data {
            let budget = try MonthlyBudget(
                category: budgetData.category,
                amount: budgetData.amount,
                month: budgetData.month,
                year: budgetData.year,
                isHistorical: budgetData.isHistorical
            )
            
            try await coreDataManager.addOrUpdateMonthlyBudget(budget)
        }
        
        // Reload data after import
        loadData()
    }
    
    /// Legacy method for backward compatibility
    public func processMappedImport(
        data: [CSVImport.PurchaseImportData],
        categoryMappings: [String: String]
    ) async {
        let importResults = CSVImport.ImportResults(
            data: data,
            categories: Set(data.map { $0.category }),
            existingCategories: Set(getAvailableCategories()),
            newCategories: Set(),
            totalAmount: data.reduce(0) { $0 + $1.amount }
        )
        
        do {
            try await processImportedPurchases(importResults, categoryMappings: categoryMappings)
        } catch {
            print("Failed to process imported purchases: \(error)")
        }
    }
    
    // MARK: - Data Reset
    func resetAllData() async throws {
        try await coreDataManager.deleteAllData()
        await MainActor.run {
            self.entries = []
            self.monthlyBudgets = []
            self.objectWillChange.send()
            updateRemainingBudget()
        }
    }
    
    // MARK: - Widget Support
    private func updateRemainingBudget() {
        let currentMonthBudget = getCurrentMonthBudget()
        let currentMonthSpent = entries
            .filter { $0.date.isInCurrentMonth }
            .reduce(0) { $0 + $1.amount }
        let remaining = currentMonthBudget - currentMonthSpent
        
        SharedDataManager.shared.setMonthlyBudget(currentMonthBudget)
        SharedDataManager.shared.setRemainingBudget(remaining)
    }
    
    private func checkAndUpdateMonthlyBudgets() async {
        // Implementation for checking and updating monthly budgets
        // This would handle any necessary monthly budget updates
    }
    
    // MARK: - Import Error Types
    public enum BudgetImportError: LocalizedError {
        case invalidFile
        case invalidFormat
        case parsingError
        case invalidDateFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The selected file is invalid"
            case .invalidFormat:
                return "The budget data format is incorrect"
            case .parsingError:
                return "Unable to parse the budget data"
            case .invalidDateFormat:
                return "Invalid date format in the budget data"
            }
        }
    }
    
    public enum PurchaseImportError: LocalizedError {
        case invalidFile
        case invalidFormat
        case parsingError
        case invalidDateFormat
        
        public var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The selected file is invalid"
            case .invalidFormat:
                return "The purchase data format is incorrect"
            case .parsingError:
                return "Unable to parse the purchase data"
            case .invalidDateFormat:
                return "Invalid date format in the purchase data"
            }
        }
    }
}

// MARK: - Sort Options
public enum BudgetSortOption: String, CaseIterable {
    case category = "Category"
    case budgetedAmount = "Budgeted Amount"
    case amountSpent = "Amount Spent"
    case date = "Date"
    case amount = "Amount"
}

// MARK: - Filter Options
public enum FilterType: String, CaseIterable {
    case all = "All"
    case category = "Category"
    case date = "Date"
    case amount = "Amount"
}

// MARK: - Sort Direction
public enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
}

// MARK: - View Type Options
public enum ViewType: String, CaseIterable {
    case list = "List"
    case chart = "Chart"
    case summary = "Summary"
}

// MARK: - Budget Category Type
public enum BudgetCategoryType: String, CaseIterable {
    case expense = "Expense"
    case income = "Income"
    case savings = "Savings"
}

// MARK: - Chart Type
public enum ChartType: String, CaseIterable {
    case pie = "Pie"
    case bar = "Bar"
    case line = "Line"
}

// MARK: - Date Range Type
public enum DateRangeType: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case custom = "Custom"
}

// MARK: - Transaction Status
public enum TransactionStatus: String, Codable {
    case pending = "Pending"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

// MARK: - Time Period
public enum TimePeriod: Equatable, Hashable, Codable, Sendable {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case last7Days
    case last30Days
    case last12Months
    case allTime
    case custom(Date, Date)
    
    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last12Months: return "Last 12 Months"
        case .allTime: return "All Time"
        case .custom: return "Custom Range"
        }
    }
    
    public func dateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )!
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            )!
            return DateInterval(start: startOfMonth, end: now)
        case .thisYear:
            let startOfYear = calendar.date(
                from: calendar.dateComponents([.year], from: now)
            )!
            return DateInterval(start: startOfYear, end: now)
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return DateInterval(start: sevenDaysAgo, end: now)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            return DateInterval(start: thirtyDaysAgo, end: now)
        case .last12Months:
            let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now)!
            return DateInterval(start: twelveMonthsAgo, end: now)
        case .allTime:
            return DateInterval(start: .distantPast, end: now)
        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
    
    static var allCases: [TimePeriod] {
        [
            .today,
            .thisWeek,
            .thisMonth,
            .thisYear,
            .last7Days,
            .last30Days,
            .last12Months,
            .allTime,
            .custom(Date(), Date())
        ]
    }
}

// MARK: - Shared Data Manager
final class SharedDataManager {
    // MARK: - Singleton
    static let shared = SharedDataManager()
    
    // MARK: - Constants
    private enum Keys {
        static let remainingBudget = "remainingBudget"
        static let monthlyBudget = "monthlyBudget"
        static let suiteName = "group.com.brandontitensor.BrandonsBudget"
    }
    
    // MARK: - Properties
    private let sharedDefaults: UserDefaults?
    
    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: Keys.suiteName)
    }
    
    // MARK: - Public Methods
    func setRemainingBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.remainingBudget)
    }
    
    func getRemainingBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.remainingBudget) ?? 0.0
    }
    
    func setMonthlyBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: Keys.monthlyBudget)
    }
    
    func getMonthlyBudget() -> Double {
        return sharedDefaults?.double(forKey: Keys.monthlyBudget) ?? 0.0
    }
    
    func resetData() {
        setRemainingBudget(0.0)
        setMonthlyBudget(0.0)
    }
}

// MARK: - Year Picker View
/// A reusable view for selecting years with validation and proper range handling
struct YearPickerView: View {
    // MARK: - Properties
    @Binding var selectedYear: Int
    let onDismiss: () -> Void
    let onYearSelected: (Int) -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constants
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let yearRange: ClosedRange<Int>
    
    // MARK: - Initialization
    init(
        selectedYear: Binding<Int>,
        onDismiss: @escaping () -> Void,
        onYearSelected: @escaping (Int) -> Void,
        numberOfPastYears: Int = 5,
        numberOfFutureYears: Int = 5
    ) {
        self._selectedYear = selectedYear
        self.onDismiss = onDismiss
        self.onYearSelected = onYearSelected
        
        // Calculate year range
        self.yearRange = (currentYear - numberOfPastYears)...(currentYear + numberOfFutureYears)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(yearRange, id: \.self) { year in
                        yearRow(for: year)
                    }
                } footer: {
                    Text("Showing years from \(yearRange.lowerBound) to \(yearRange.upperBound)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Select Year")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") {
                    onYearSelected(selectedYear)
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - View Components
    private func yearRow(for year: Int) -> some View {
        Button(action: { selectYear(year) }) {
            HStack {
                Text(String(year))
                    .foregroundColor(.primary)
                Spacer()
                if year == selectedYear {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                if year == currentYear {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel(for: year))
        .accessibilityAddTraits(year == selectedYear ? [.isSelected] : [])
    }
    
    // MARK: - Helper Methods
    private func selectYear(_ year: Int) {
        selectedYear = year
    }
    
    private func createAccessibilityLabel(for year: Int) -> String {
        var label = String(year)
        if year == currentYear {
            label += ", current year"
        }
        if year == selectedYear {
            label += ", selected"
        }
        return label
    }
}

// MARK: - Testing Support
#if DEBUG
extension SharedDataManager {
    static func createMock() -> SharedDataManager {
        return SharedDataManager()
    }
}

extension ThemeManager {
    static func createMock() -> ThemeManager {
        return ThemeManager()
    }
}

extension BudgetManager {
    static func createMock() -> BudgetManager {
        return BudgetManager()
    }
}
#endif

// MARK: - Preview Provider
#if DEBUG
struct YearPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Current year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date())),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Current Year")
            
            // Past year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date()) - 2),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Past Year")
            
            // Future year selected
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date()) + 2),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .previewDisplayName("Future Year")
            
            // Dark mode
            YearPickerView(
                selectedYear: .constant(Calendar.current.component(.year, from: Date())),
                onDismiss: {},
                onYearSelected: { _ in }
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
