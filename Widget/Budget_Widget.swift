//
//  BudgetWidget.swift
//  Budget WidgetExtension
//
//  Self-contained widget implementation that doesn't depend on main app files
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Widget-Only Data Types

/// Lightweight budget summary for widget use
struct WidgetBudgetSummary: Codable, Sendable {
    let monthlyBudget: Double
    let totalSpent: Double
    let remainingBudget: Double
    let percentageUsed: Double
    let isOverBudget: Bool
    let categoryCount: Int
    let transactionCount: Int
    let lastUpdated: Date
    let currentMonth: String
    
    init(
        monthlyBudget: Double,
        totalSpent: Double,
        remainingBudget: Double? = nil,
        categoryCount: Int,
        transactionCount: Int,
        currentMonth: String? = nil
    ) {
        self.monthlyBudget = monthlyBudget
        self.totalSpent = totalSpent
        self.remainingBudget = remainingBudget ?? (monthlyBudget - totalSpent)
        self.percentageUsed = monthlyBudget > 0 ? (totalSpent / monthlyBudget) * 100 : 0
        self.isOverBudget = totalSpent > monthlyBudget
        self.categoryCount = categoryCount
        self.transactionCount = transactionCount
        self.lastUpdated = Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        self.currentMonth = currentMonth ?? formatter.string(from: Date())
    }
}

/// Lightweight recent transaction for widget use
struct WidgetRecentTransaction: Codable, Identifiable, Sendable {
    let id: UUID
    let amount: Double
    let category: String
    let date: Date
    let note: String?
    
    init(amount: Double, category: String, date: Date, note: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.date = date
        self.note = note
    }
}

/// Lightweight category spending for widget use
struct WidgetCategorySpending: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let amount: Double
    let percentage: Double
    let color: String
    
    init(name: String, amount: Double, percentage: Double, color: String = "#007AFF") {
        self.id = name
        self.name = name
        self.amount = amount
        self.percentage = percentage
        self.color = color
    }
}

/// Complete widget data package
struct WidgetData: Codable, Sendable {
    let budgetSummary: WidgetBudgetSummary
    let recentTransactions: [WidgetRecentTransaction]
    let topCategories: [WidgetCategorySpending]
    let lastUpdated: Date
    let appVersion: String
    
    init(
        budgetSummary: WidgetBudgetSummary,
        recentTransactions: [WidgetRecentTransaction] = [],
        topCategories: [WidgetCategorySpending] = []
    ) {
        self.budgetSummary = budgetSummary
        self.recentTransactions = Array(recentTransactions.prefix(5))
        self.topCategories = Array(topCategories.prefix(5))
        self.lastUpdated = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Widget Extensions

extension Double {
    /// Format as currency string for widget use
    fileprivate var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

extension Date {
    /// Format relative time for widget display
    fileprivate var formattedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension WidgetBudgetSummary {
    func formattedMonthlyBudget() -> String {
        return monthlyBudget.asCurrency
    }
    
    func formattedTotalSpent() -> String {
        return totalSpent.asCurrency
    }
    
    func formattedRemainingBudget() -> String {
        return remainingBudget.asCurrency
    }
    
    var compactStatus: String {
        if isOverBudget {
            return "Over Budget"
        } else {
            return "\(Int(percentageUsed))% used"
        }
    }
    
    var statusMessage: String {
        if isOverBudget {
            let overAmount = totalSpent - monthlyBudget
            return "Over budget by \(overAmount.asCurrency)"
        } else if remainingBudget <= 0 {
            return "Budget fully used"
        } else {
            return "\(remainingBudget.asCurrency) remaining"
        }
    }
    
    var widgetDisplayText: String {
        if isOverBudget {
            return "Over Budget"
        } else {
            return "On Track"
        }
    }
}

extension WidgetRecentTransaction {
    func formattedAmount() -> String {
        return amount.asCurrency
    }
    
    func relativeDate() -> String {
        return date.formattedRelative
    }
}

extension WidgetCategorySpending {
    func formattedAmount() -> String {
        return amount.asCurrency
    }
    
    func formattedPercentage() -> String {
        return "\(Int(percentage))%"
    }
}

// MARK: - Widget Entry

/// Timeline entry for budget widget
struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let budgetSummary: WidgetBudgetSummary?
    let recentTransactions: [WidgetRecentTransaction]
    let topCategories: [WidgetCategorySpending]
    let errorState: WidgetErrorState?
    let lastUpdateDate: Date?
    
    // MARK: - Convenience Properties
    
    var isOverBudget: Bool {
        budgetSummary?.isOverBudget ?? false
    }
    
    var percentageUsed: Double {
        budgetSummary?.percentageUsed ?? 0
    }
    
    var statusColor: Color {
        guard let summary = budgetSummary else { return .gray }
        
        if summary.isOverBudget {
            return .red
        } else if summary.percentageUsed > 90 {
            return .orange
        } else if summary.percentageUsed > 75 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var displayTitle: String {
        if let error = errorState {
            return error.displayTitle
        }
        return budgetSummary?.currentMonth ?? "Budget"
    }
    
    var hasValidData: Bool {
        return budgetSummary != nil && errorState == nil
    }
    
    // MARK: - Widget Error State
    
    enum WidgetErrorState {
        case noData
        case staleData
        case appGroupUnavailable
        case corruptedData
        
        var displayTitle: String {
            switch self {
            case .noData: return "No Data"
            case .staleData: return "Outdated"
            case .appGroupUnavailable: return "Setup Required"
            case .corruptedData: return "Data Error"
            }
        }
        
        var displayMessage: String {
            switch self {
            case .noData: return "Open app to add budget data"
            case .staleData: return "Open app to refresh"
            case .appGroupUnavailable: return "App configuration needed"
            case .corruptedData: return "Please restart app"
            }
        }
        
        var systemImage: String {
            switch self {
            case .noData: return "tray"
            case .staleData: return "clock.arrow.circlepath"
            case .appGroupUnavailable: return "gear"
            case .corruptedData: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .noData: return .gray
            case .staleData: return .orange
            case .appGroupUnavailable: return .blue
            case .corruptedData: return .red
            }
        }
    }
    
    // MARK: - Static Entries
    
    static let placeholder = BudgetWidgetEntry(
        date: Date(),
        budgetSummary: WidgetBudgetSummary(
            monthlyBudget: 2500.0,
            totalSpent: 1750.0,
            categoryCount: 8,
            transactionCount: 45
        ),
        recentTransactions: [
            WidgetRecentTransaction(
                amount: 45.67,
                category: "Groceries",
                date: Date(),
                note: "Weekly shopping"
            ),
            WidgetRecentTransaction(
                amount: 12.50,
                category: "Transportation",
                date: Date().addingTimeInterval(-86400),
                note: "Bus fare"
            )
        ],
        topCategories: [
            WidgetCategorySpending(name: "Groceries", amount: 450.0, percentage: 18.0),
            WidgetCategorySpending(name: "Utilities", amount: 350.0, percentage: 14.0)
        ],
        errorState: nil,
        lastUpdateDate: Date()
    )
    
    static let errorEntry = BudgetWidgetEntry(
        date: Date(),
        budgetSummary: nil,
        recentTransactions: [],
        topCategories: [],
        errorState: .noData,
        lastUpdateDate: nil
    )
}

// MARK: - Widget Provider

/// Timeline provider for budget widget
struct BudgetWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        return BudgetWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = createEntry()
        
        // Determine next update time
        let nextUpdate = calculateNextUpdateTime(from: currentDate, entry: entry)
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextUpdate)
        )
        
        completion(timeline)
    }
    
    // MARK: - Entry Creation
    
    private func createEntry() -> BudgetWidgetEntry {
        // Access UserDefaults directly for widget
        let appGroupIdentifier = "group.com.brandontitensor.BrandonsBudget"
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return BudgetWidgetEntry(
                date: Date(),
                budgetSummary: nil,
                recentTransactions: [],
                topCategories: [],
                errorState: .appGroupUnavailable,
                lastUpdateDate: nil
            )
        }
        
        // Try to load widget data
        var widgetData: WidgetData?
        var budgetSummary: WidgetBudgetSummary?
        
        // First try the complete widget data
        if let widgetDataData = userDefaults.data(forKey: "WidgetCompleteData") {
            widgetData = try? JSONDecoder().decode(WidgetData.self, from: widgetDataData)
            budgetSummary = widgetData?.budgetSummary
        }
        
        // Fallback to individual budget summary
        if budgetSummary == nil, let budgetSummaryData = userDefaults.data(forKey: "WidgetBudgetSummary") {
            // Try to decode as the new WidgetBudgetSummary first
            if let summary = try? JSONDecoder().decode(WidgetBudgetSummary.self, from: budgetSummaryData) {
                budgetSummary = summary
            } else {
                // Fallback: create a basic summary from any available data
                budgetSummary = WidgetBudgetSummary(
                    monthlyBudget: userDefaults.double(forKey: "monthlyBudget"),
                    totalSpent: userDefaults.double(forKey: "totalSpent"),
                    categoryCount: userDefaults.integer(forKey: "categoryCount"),
                    transactionCount: userDefaults.integer(forKey: "transactionCount")
                )
            }
        }
        
        // Check for stale data
        let errorState = checkForStaleData(widgetData: widgetData, budgetSummary: budgetSummary)
        
        return BudgetWidgetEntry(
            date: Date(),
            budgetSummary: budgetSummary,
            recentTransactions: widgetData?.recentTransactions ?? [],
            topCategories: widgetData?.topCategories ?? [],
            errorState: errorState,
            lastUpdateDate: widgetData?.lastUpdated ?? budgetSummary?.lastUpdated
        )
    }
    
    private func checkForStaleData(widgetData: WidgetData?, budgetSummary: WidgetBudgetSummary?) -> BudgetWidgetEntry.WidgetErrorState? {
        // Check if we have any data at all
        guard budgetSummary != nil else {
            return .noData
        }
        
        // Check if data is stale
        if let widgetData = widgetData {
            let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
            if widgetData.lastUpdated < twoHoursAgo {
                return .staleData
            }
        }
        
        return nil
    }
    
    private func calculateNextUpdateTime(from currentDate: Date, entry: BudgetWidgetEntry) -> Date {
        // More frequent updates if there's an error
        if entry.errorState != nil {
            return currentDate.addingTimeInterval(15 * 60) // 15 minutes
        }
        
        // Normal update interval based on time of day
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)
        
        // More frequent updates during active hours (7 AM - 10 PM)
        if hour >= 7 && hour <= 22 {
            return currentDate.addingTimeInterval(30 * 60) // 30 minutes
        } else {
            return currentDate.addingTimeInterval(2 * 60 * 60) // 2 hours during off hours
        }
    }
}

// MARK: - Widget Configuration

/// Main widget configuration
@main
struct BudgetWidget: Widget {
    private let kind = "BudgetWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BudgetWidgetProvider()
        ) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Budget Status")
        .description("Keep track of your monthly budget and spending at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Views

/// Main widget view that handles different family sizes
struct BudgetWidgetView: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily
    
    var body: some View {
        Group {
            if entry.hasValidData {
                switch widgetFamily {
                case .systemSmall:
                    SmallBudgetWidget(entry: entry)
                case .systemMedium:
                    MediumBudgetWidget(entry: entry)
                case .systemLarge:
                    LargeBudgetWidget(entry: entry)
                default:
                    SmallBudgetWidget(entry: entry)
                }
            } else {
                ErrorBudgetWidget(entry: entry)
            }
        }
        .widgetURL(URL(string: "brandonsbudget://widget"))
    }
}

// MARK: - Small Widget

struct SmallBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: WidgetBudgetSummary {
        entry.budgetSummary ?? WidgetBudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            categoryCount: 0,
            transactionCount: 0
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Budget")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundColor(entry.statusColor)
            }
            
            Spacer()
            
            // Main content
            VStack(spacing: 4) {
                Text(budgetSummary.formattedRemainingBudget())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(entry.statusColor)
                    .minimumScaleFactor(0.8)
                
                Text(budgetSummary.compactStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress bar
            ProgressView(value: min(budgetSummary.percentageUsed / 100, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: entry.statusColor))
                .scaleEffect(y: 0.6)
        }
        .padding(12)
    }
    
    private var statusIcon: String {
        if budgetSummary.isOverBudget {
            return "exclamationmark.triangle.fill"
        } else if budgetSummary.percentageUsed > 75 {
            return "exclamationmark.circle"
        } else {
            return "checkmark.circle"
        }
    }
}

// MARK: - Medium Widget

struct MediumBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: WidgetBudgetSummary {
        entry.budgetSummary ?? WidgetBudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            categoryCount: 0,
            transactionCount: 0
        )
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Budget info
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(entry.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                // Budget amounts
                VStack(alignment: .leading, spacing: 4) {
                    budgetRow(
                        label: "Budget",
                        amount: budgetSummary.formattedMonthlyBudget(),
                        color: .blue
                    )
                    
                    budgetRow(
                        label: "Spent",
                        amount: budgetSummary.formattedTotalSpent(),
                        color: .primary
                    )
                    
                    budgetRow(
                        label: "Remaining",
                        amount: budgetSummary.formattedRemainingBudget(),
                        color: entry.statusColor
                    )
                }
                
                // Progress bar
                ProgressView(value: min(budgetSummary.percentageUsed / 100, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: entry.statusColor))
            }
            
            // Right side - Quick action or recent transaction
            VStack(spacing: 8) {
                Spacer()
                
                if let recentTransaction = entry.recentTransactions.first {
                    recentTransactionView(recentTransaction)
                } else {
                    quickActionButton
                }
                
                Spacer()
            }
        }
        .padding(16)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.statusColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(budgetSummary.percentageUsed))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func budgetRow(label: String, amount: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(amount)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
    
    private func recentTransactionView(_ transaction: WidgetRecentTransaction) -> some View {
        VStack(spacing: 4) {
            Text("Recent")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(transaction.formattedAmount())
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(transaction.category)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var quickActionButton: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("Add")
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .frame(width: 60, height: 60)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Large Widget

struct LargeBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: WidgetBudgetSummary {
        entry.budgetSummary ?? WidgetBudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            categoryCount: 0,
            transactionCount: 0
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header section
            headerSection
            
            // Budget overview section
            budgetOverviewSection
            
            // Bottom section
            if !entry.recentTransactions.isEmpty {
                recentTransactionsSection
            } else if !entry.topCategories.isEmpty {
                topCategoriesSection
            } else {
                emptyStateSection
            }
        }
        .padding(16)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let lastUpdate = entry.lastUpdateDate {
                    Text("Updated \(lastUpdate.formattedRelative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(budgetSummary.widgetDisplayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(entry.statusColor)
                }
                
                Text("\(budgetSummary.categoryCount) categories")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var budgetOverviewSection: some View {
        VStack(spacing: 8) {
            // Budget amounts row
            HStack {
                budgetAmountCard(
                    title: "Budget",
                    amount: budgetSummary.formattedMonthlyBudget(),
                    color: .blue
                )
                
                budgetAmountCard(
                    title: "Spent",
                    amount: budgetSummary.formattedTotalSpent(),
                    color: .primary
                )
                
                budgetAmountCard(
                    title: "Remaining",
                    amount: budgetSummary.formattedRemainingBudget(),
                    color: entry.statusColor
                )
            }
            
            // Progress bar with percentage
            VStack(spacing: 4) {
                ProgressView(value: min(budgetSummary.percentageUsed / 100, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: entry.statusColor))
                
                HStack {
                    Text(budgetSummary.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(budgetSummary.percentageUsed))% used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func budgetAmountCard(title: String, amount: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(amount)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Transactions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                ForEach(entry.recentTransactions.prefix(3), id: \.id) { transaction in
                    transactionRow(transaction)
                }
            }
        }
    }
    
    private func transactionRow(_ transaction: WidgetRecentTransaction) -> some View {
        HStack {
            Text(transaction.category)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text(transaction.formattedAmount())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top Categories")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                ForEach(entry.topCategories.prefix(3), id: \.id) { category in
                    categoryRow(category)
                }
            }
        }
    }
    
    private func categoryRow(_ category: WidgetCategorySpending) -> some View {
        HStack {
            Text(category.name)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text(category.formattedAmount())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(category.formattedPercentage())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("No recent activity")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Error Widget

struct ErrorBudgetWidget: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily
    
    private var errorState: BudgetWidgetEntry.WidgetErrorState {
        entry.errorState ?? .noData
    }
    
    var body: some View {
        VStack(spacing: widgetFamily == .systemSmall ? 8 : 12) {
            Image(systemName: errorState.systemImage)
                .font(widgetFamily == .systemSmall ? .title2 : .title)
                .foregroundColor(errorState.color)
            
            VStack(spacing: 4) {
                Text(errorState.displayTitle)
                    .font(widgetFamily == .systemSmall ? .caption : .subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                if widgetFamily != .systemSmall {
                    Text(errorState.displayMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(widgetFamily == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct BudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small Widget - Normal State
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Normal")
            
            // Medium Widget
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            // Large Widget
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
            
            // Error State
            BudgetWidgetView(entry: .errorEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Error State")
        }
    }
}
#endif