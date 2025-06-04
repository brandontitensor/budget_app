//
//  BudgetWidget.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//  Updated: 6/4/25 - Enhanced with improved data handling, error states, and better visual design
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

/// Timeline entry for budget widget with comprehensive data
struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let budgetSummary: SharedDataManager.BudgetSummary?
    let recentTransactions: [SharedDataManager.RecentTransaction]
    let topCategories: [SharedDataManager.CategorySpending]
    let widgetData: SharedDataManager.WidgetData?
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
    
    // MARK: - Widget Entry Types
    
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
        budgetSummary: SharedDataManager.BudgetSummary(
            monthlyBudget: 2500.0,
            totalSpent: 1750.0,
            remainingBudget: 750.0,
            categoryCount: 8,
            transactionCount: 45
        ),
        recentTransactions: [
            SharedDataManager.RecentTransaction(
                amount: 45.67,
                category: "Groceries",
                date: Date(),
                note: "Weekly shopping"
            ),
            SharedDataManager.RecentTransaction(
                amount: 12.50,
                category: "Transportation",
                date: Date().addingTimeInterval(-86400),
                note: "Bus fare"
            )
        ],
        topCategories: [
            SharedDataManager.CategorySpending(name: "Groceries", amount: 450.0, percentage: 18.0),
            SharedDataManager.CategorySpending(name: "Utilities", amount: 350.0, percentage: 14.0)
        ],
        widgetData: nil,
        errorState: nil,
        lastUpdateDate: Date()
    )
    
    static let errorEntry = BudgetWidgetEntry(
        date: Date(),
        budgetSummary: nil,
        recentTransactions: [],
        topCategories: [],
        widgetData: nil,
        errorState: .noData,
        lastUpdateDate: nil
    )
}

// MARK: - Widget Provider

/// Timeline provider for budget widget with enhanced data handling
struct BudgetWidgetProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // MARK: - TimelineProvider Implementation
    
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        return BudgetWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        performanceMonitor.startTiming("WidgetSnapshot")
        defer { performanceMonitor.endTiming("WidgetSnapshot") }
        
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        performanceMonitor.startTiming("WidgetTimeline")
        defer { performanceMonitor.endTiming("WidgetTimeline") }
        
        let currentDate = Date()
        let entry = createEntry()
        
        // Determine next update time based on data freshness and error state
        let nextUpdate = calculateNextUpdateTime(from: currentDate, entry: entry)
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextUpdate)
        )
        
        completion(timeline)
        
        #if DEBUG
        print("🔄 BudgetWidget: Timeline updated - Next refresh: \(nextUpdate)")
        #endif
    }
    
    // MARK: - Entry Creation
    
    private func createEntry() -> BudgetWidgetEntry {
        // Check data health
        let dataHealth = sharedDataManager.getDataHealth()
        
        // Handle critical errors
        if !dataHealth.isHealthy {
            let errorState = mapDataHealthToErrorState(dataHealth)
            return BudgetWidgetEntry(
                date: Date(),
                budgetSummary: nil,
                recentTransactions: [],
                topCategories: [],
                widgetData: nil,
                errorState: errorState,
                lastUpdateDate: nil
            )
        }
        
        // Get widget data
        let widgetData = sharedDataManager.getWidgetData()
        let budgetSummary = sharedDataManager.getBudgetSummary()
        
        // Check for stale data
        let errorState = checkForStaleData(widgetData: widgetData)
        
        return BudgetWidgetEntry(
            date: Date(),
            budgetSummary: budgetSummary,
            recentTransactions: widgetData?.recentTransactions ?? [],
            topCategories: widgetData?.topCategories ?? [],
            widgetData: widgetData,
            errorState: errorState,
            lastUpdateDate: widgetData?.lastUpdated
        )
    }
    
    private func mapDataHealthToErrorState(_ health: DataHealth) -> BudgetWidgetEntry.WidgetErrorState {
        switch health.status {
        case .critical:
            return .appGroupUnavailable
        case .error:
            return .corruptedData
        case .warning:
            return .noData
        case .healthy:
            return .noData // Fallback
        }
    }
    
    private func checkForStaleData(widgetData: SharedDataManager.WidgetData?) -> BudgetWidgetEntry.WidgetErrorState? {
        guard let widgetData = widgetData else {
            return .noData
        }
        
        // Check if data is more than 2 hours old
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        if widgetData.lastUpdated < twoHoursAgo {
            return .staleData
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
    @Environment(\.colorScheme) private var colorScheme
    
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

/// Compact widget for system small size
struct SmallBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: SharedDataManager.BudgetSummary {
        entry.budgetSummary ?? SharedDataManager.BudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            remainingBudget: 0
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
        .widgetURL(URL(string: "brandonsbudget://overview"))
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

/// Medium-sized widget with more detailed information
struct MediumBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: SharedDataManager.BudgetSummary {
        entry.budgetSummary ?? SharedDataManager.BudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            remainingBudget: 0
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
            
            // Right side - Quick actions or recent transaction
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
        .widgetURL(URL(string: "brandonsbudget://overview"))
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
    
    private func recentTransactionView(_ transaction: SharedDataManager.RecentTransaction) -> some View {
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
        Link(destination: URL(string: "brandonsbudget://addPurchase")!) {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Add")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 60, height: 60)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Large Widget

/// Large widget with comprehensive budget overview
struct LargeBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    private var budgetSummary: SharedDataManager.BudgetSummary {
        entry.budgetSummary ?? SharedDataManager.BudgetSummary(
            monthlyBudget: 0,
            totalSpent: 0,
            remainingBudget: 0
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header section
            headerSection
            
            // Budget overview section
            budgetOverviewSection
            
            // Bottom section - Recent transactions or top categories
            if !entry.recentTransactions.isEmpty {
                recentTransactionsSection
            } else if !entry.topCategories.isEmpty {
                topCategoriesSection
            } else {
                emptyStateSection
            }
        }
        .padding(16)
        .widgetURL(URL(string: "brandonsbudget://overview"))
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
            HStack {
                Text("Recent Transactions")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Link("View All", destination: URL(string: "brandonsbudget://purchases")!)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                ForEach(entry.recentTransactions.prefix(3), id: \.id) { transaction in
                    transactionRow(transaction)
                }
            }
        }
    }
    
    private func transactionRow(_ transaction: SharedDataManager.RecentTransaction) -> some View {
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
            
            Text(transaction.relativeDate())
                .font(.caption2)
                .foregroundColor(.secondary)
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
    
    private func categoryRow(_ category: SharedDataManager.CategorySpending) -> some View {
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
            
            Link("Add Transaction", destination: URL(string: "brandonsbudget://addPurchase")!)
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Error Widget

/// Widget view for error states
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
            
            if widgetFamily == .systemLarge {
                Spacer()
                
                Link("Open App", destination: URL(string: "brandonsbudget://")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(widgetFamily == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "brandonsbudget://"))
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
            
            // Small Widget - Over Budget
            BudgetWidgetView(entry: BudgetWidgetEntry(
                date: Date(),
                budgetSummary: SharedDataManager.BudgetSummary(
                    monthlyBudget: 2000,
                    totalSpent: 2300,
                    remainingBudget: -300
                ),
                recentTransactions: [],
                topCategories: [],
                widgetData: nil,
                errorState: nil,
                lastUpdateDate: Date()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Over Budget")
            
            // Medium Widget
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            // Large Widget
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
            
            // Error State - Small
            BudgetWidgetView(entry: .errorEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Error - Small")
            
            // Error State - Medium
            BudgetWidgetView(entry: .errorEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Error - Medium")
            
            // Dark Mode
            BudgetWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
