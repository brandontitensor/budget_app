//
//  BudgetOverviewView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import Charts
import Foundation

/// Main dashboard view showing budget overview and recent transactions with comprehensive error handling
struct BudgetOverviewView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @AppStorage("userName") private var userName: String = "User"
    
    // MARK: - State Management
    @StateObject private var viewModel = OverviewViewModel()
    @State private var currentMonthEntries: [BudgetEntry] = []
    @State private var recentTransactions: [BudgetEntry] = []
    @State private var budgetSummary: BudgetSummaryData?
    @State private var spendingData: [SpendingData] = []
    @State private var categoryBreakdown: [CategoryBreakdown] = []
    @State private var isInitialLoad = true
    @State private var lastRefreshDate: Date = Date()
    @State private var refreshTask: Task<Void, Never>?
    
    // MARK: - Loading States
    @State private var loadingStates = LoadingState()
    @State private var errorStates = ErrorState()
    
    // MARK: - UI State
    @State private var selectedTimeframe: TimeFrame = .thisMonth
    @State private var selectedSpendingData: SpendingData?
    @State private var showingDetailView = false
    @State private var animateOnAppear = false
    @State private var pullToRefreshOffset: CGFloat = 0
    
    // MARK: - Constants
    private let maxRecentTransactions = 5
    private let refreshThreshold: TimeInterval = 300 // 5 minutes
    private let animationDuration: Double = 0.6
    
    // MARK: - Supporting Types
    private struct LoadingState {
        var isLoading = false
        var isRefreshing = false
        var isSummaryLoading = false
        var isTransactionsLoading = false
        var isSpendingDataLoading = false
    }
    
    private struct ErrorState {
        var summaryError: AppError?
        var transactionsError: AppError?
        var spendingDataError: AppError?
        var hasAnyError: Bool {
            summaryError != nil || transactionsError != nil || spendingDataError != nil
        }
    }
    
    enum TimeFrame: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisQuarter = "This Quarter"
        case thisYear = "This Year"
        
        var timePeriod: TimePeriod {
            switch self {
            case .thisWeek: return .thisWeek
            case .thisMonth: return .thisMonth
            case .thisQuarter: return .thisQuarter
            case .thisYear: return .thisYear
            }
        }
        
        var systemImageName: String {
            switch self {
            case .thisWeek: return "calendar.badge.clock"
            case .thisMonth: return "calendar.circle"
            case .thisQuarter: return "calendar.circle.fill"
            case .thisYear: return "calendar.badge.plus"
            }
        }
    }
    
    struct BudgetSummaryData: Equatable {
        let totalBudgeted: Double
        let totalSpent: Double
        let remainingBudget: Double
        let percentageUsed: Double
        let categoryCount: Int
        let transactionCount: Int
        let isOverBudget: Bool
        let lastUpdated: Date
        
        var statusColor: Color {
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
        
        var statusMessage: String {
            if isOverBudget {
                let overAmount = totalSpent - totalBudgeted
                return "Over budget by \(overAmount.asCurrency)"
            } else if remainingBudget <= 0 {
                return "Budget fully used"
            } else {
                return "\(remainingBudget.asCurrency) remaining"
            }
        }
    }
    
    struct CategoryBreakdown: Identifiable {
        let id = UUID()
        let category: String
        let spent: Double
        let budgeted: Double
        let percentage: Double
        let color: Color
        
        var isOverBudget: Bool {
            spent > budgeted
        }
        
        var remaining: Double {
            budgeted - spent
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                if loadingStates.isLoading && isInitialLoad {
                    loadingView
                } else {
                    mainContent
                }
                
                // Global error overlay
                if errorStates.hasAnyError {
                    errorOverlay
                }
            }
        }
        .navigationTitle(greetingText)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(themeManager.semanticColors.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarContent
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onReceive(budgetManager.$entries) { _ in
            handleDataChange()
        }
        .onReceive(budgetManager.$monthlyBudgets) { _ in
            handleDataChange()
        }
        .refreshable {
            await performRefresh()
        }
        .errorAlert(onRetry: {
            Task<Void, Never>{
                await performRefresh()
            }
        })
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                themeManager.semanticColors.backgroundPrimary,
                themeManager.semanticColors.backgroundSecondary.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Loading your budget overview...")
                    .font(.headline)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Gathering your financial insights")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                welcomeSection
                timeFrameSelector
                budgetSummarySection
                spendingChartSection
                categoryBreakdownSection
                recentTransactionsSection
                quickActionsSection
            }
            .padding()
            .opacity(animateOnAppear ? 1 : 0)
            .offset(y: animateOnAppear ? 0 : 20)
            .animation(.easeOut(duration: animationDuration), value: animateOnAppear)
        }
        .background(Color.clear)
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(greetingText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Spacer()
                
                if let summary = budgetSummary {
                    OverviewStatusIndicator(
                        color: summary.statusColor,
                        isAnimated: summary.isOverBudget
                    )
                }
            }
            
            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
            
            if lastRefreshDate.timeIntervalSinceNow > -refreshThreshold {
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: lastRefreshDate, relativeTo: Date()))")
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textTertiary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var timeFrameSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    TimeFrameButton(
                        timeframe: timeframe,
                        isSelected: selectedTimeframe == timeframe,
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTimeframe = timeframe
                            }
                            Task<Void, Never>{
                                await loadDataForTimeframe(timeframe)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var budgetSummarySection: some View {
        if loadingStates.isSummaryLoading {
            BudgetSummaryCardSkeleton()
        } else if let error = errorStates.summaryError {
            ErrorCard(
                error: error,
                onRetry: {
                    Task<Void, Never>{
                        await loadBudgetSummary()
                    }
                }
            )
        } else if let summary = budgetSummary {
            BudgetSummaryCard(
                budgeted: summary.totalBudgeted,
                spent: summary.totalSpent,
                primaryColor: themeManager.primaryColor
            )
            .onTapGesture {
                showingDetailView = true
            }
            .animation(.easeInOut(duration: 0.3), value: budgetSummary)
        } else {
            EmptyBudgetCard()
        }
    }
    
    private var spendingChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Spending by Category",
                subtitle: selectedTimeframe.rawValue,
                icon: "chart.pie.fill",
                color: themeManager.primaryColor
            )
            
            if loadingStates.isSpendingDataLoading {
                SpendingChartSkeleton()
            } else if let error = errorStates.spendingDataError {
                ErrorCard(
                    error: error,
                    onRetry: {
                        Task<Void, Never>{
                            await loadSpendingData()
                        }
                    }
                )
            } else if spendingData.isEmpty {
                EmptySpendingChart()
            } else {
                SpendingPieChart(
                    spendingData: spendingData,
                    selectedData: $selectedSpendingData
                )
                .frame(height: 300)
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(
            color: .black.opacity(Double(AppConstants.UI.defaultShadowOpacity)),
            radius: AppConstants.UI.defaultShadowRadius,
            x: 0,
            y: 2
        )
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Category Breakdown",
                subtitle: "\(categoryBreakdown.count) categories",
                icon: "list.bullet.rectangle",
                color: themeManager.primaryColor
            )
            
            if categoryBreakdown.isEmpty {
                EmptyCategoryBreakdown()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(categoryBreakdown.prefix(5)) { breakdown in
                        CategoryBreakdownRow(breakdown: breakdown)
                    }
                    
                    if categoryBreakdown.count > 5 {
                        Button("View All Categories") {
                            // Navigate to detailed category view
                        }
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryColor)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Recent Transactions",
                subtitle: "\(recentTransactions.count) transactions",
                icon: "clock.fill",
                color: themeManager.primaryColor
            )
            
            if loadingStates.isTransactionsLoading {
                TransactionListSkeleton()
            } else if let error = errorStates.transactionsError {
                ErrorCard(
                    error: error,
                    onRetry: {
                        Task<Void, Never>{
                            await loadRecentTransactions()
                        }
                    }
                )
            } else if recentTransactions.isEmpty {
                EmptyTransactionsList()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                // Navigate to transaction detail
                            }
                        
                        if transaction.id != recentTransactions.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                    
                    if recentTransactions.count == maxRecentTransactions {
                        NavigationLink(destination: PurchasesView()) {
                            HStack {
                                Text("View All Transactions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(themeManager.semanticColors.textTertiary)
                            }
                            .foregroundColor(themeManager.primaryColor)
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Quick Actions",
                subtitle: "Common tasks",
                icon: "bolt.fill",
                color: themeManager.primaryColor
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Add Purchase",
                    systemImage: "plus.circle.fill",
                    color: themeManager.primaryColor,
                    action: {
                        // Open add purchase view
                    }
                )
                
                QuickActionButton(
                    title: "Update Budget",
                    systemImage: "dollarsign.circle.fill",
                    color: themeManager.semanticColors.success,
                    action: {
                        // Open update budget view
                    }
                )
                
                QuickActionButton(
                    title: "View Reports",
                    systemImage: "chart.bar.fill",
                    color: themeManager.semanticColors.info,
                    action: {
                        // Open reports view
                    }
                )
                
                QuickActionButton(
                    title: "Export Data",
                    systemImage: "square.and.arrow.up.fill",
                    color: .purple,
                    action: {
                        // Open export view
                    }
                )
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
    
    private var errorOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Unable to load data")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Some information may be unavailable. Try refreshing to reload.")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                Task<Void, Never>{
                    await performRefresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .transition(.opacity.combined(with: .scale))
    }
    
    private var toolbarContent: some View {
        HStack(spacing: 16) {
            Button(action: {
                Task<Void, Never>{
                    await performRefresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.primaryColor)
                    .rotationEffect(.degrees(loadingStates.isRefreshing ? 360 : 0))
                    .animation(
                        loadingStates.isRefreshing ?
                            .linear(duration: 1.0).repeatForever(autoreverses: false) :
                            .default,
                        value: loadingStates.isRefreshing
                    )
            }
            .disabled(loadingStates.isRefreshing)
            
            Menu {
                Button("Export Data", systemImage: "square.and.arrow.up") {
                    // Handle export
                }
                
                Button("Settings", systemImage: "gear") {
                    // Navigate to settings
                }
                
                if AppConstants.Features.enableDebugLogging {
                    Button("Debug Info", systemImage: "info.circle") {
                        // Show debug information
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.primaryColor)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 5..<12:
            greeting = "Good morning"
        case 12..<17:
            greeting = "Good afternoon"
        case 17..<22:
            greeting = "Good evening"
        default:
            greeting = "Good night"
        }
        
        let name = userName.isEmpty ? "there" : userName
        return "\(greeting), \(name)!"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    // MARK: - Data Loading Methods
    
    private func setupInitialState() {
        guard isInitialLoad else { return }
        
        // Setup initial animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: animationDuration)) {
                animateOnAppear = true
            }
        }
    }
    
    private func loadInitialData() async {
        guard isInitialLoad else { return }
        
        await MainActor.run {
            loadingStates.isLoading = true
            isInitialLoad = false
        }
        
        // Load all data concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadBudgetSummary() }
            group.addTask { await self.loadRecentTransactions() }
            group.addTask { await self.loadSpendingData() }
            group.addTask { await self.loadCategoryBreakdown() }
        }
        
        await MainActor.run {
            loadingStates.isLoading = false
            lastRefreshDate = Date()
        }
    }
    
    private func performRefresh() async {
        await MainActor.run {
            loadingStates.isRefreshing = true
            errorStates = ErrorState() // Clear all errors
        }
        
        // Provide haptic feedback
        if settingsManager.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Load fresh data
        await loadInitialData()
        
        await MainActor.run {
            loadingStates.isRefreshing = false
            lastRefreshDate = Date()
        }
    }
    
    private func loadBudgetSummary() async {
        await MainActor.run {
            loadingStates.isSummaryLoading = true
            errorStates.summaryError = nil
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading budget summary",
            errorTransform: { .dataLoad(underlying: $0) }
        ) {
            let timePeriod = selectedTimeframe.timePeriod
            let entries = try await budgetManager.getEntries(for: timePeriod)
            let budgets = budgetManager.getMonthlyBudgets(
                for: Calendar.current.component(.month, from: Date()),
                year: Calendar.current.component(.year, from: Date())
            )
            
            let totalBudgeted = budgets.reduce(0) { $0 + $1.amount }
            let totalSpent = entries.reduce(0) { $0 + $1.amount }
            let remainingBudget = totalBudgeted - totalSpent
            let percentageUsed = totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0
            
            return BudgetSummaryData(
                totalBudgeted: totalBudgeted,
                totalSpent: totalSpent,
                remainingBudget: remainingBudget,
                percentageUsed: percentageUsed,
                categoryCount: budgets.count,
                transactionCount: entries.count,
                isOverBudget: totalSpent > totalBudgeted,
                lastUpdated: Date()
            )
        }
        
        await MainActor.run {
            loadingStates.isSummaryLoading = false
            
            if let summary = result {
                budgetSummary = summary
            } else if let error = errorHandler.errorHistory.first?.error {
                errorStates.summaryError = error
            }
        }
    }
    
    private func loadRecentTransactions() async {
        await MainActor.run {
            loadingStates.isTransactionsLoading = true
            errorStates.transactionsError = nil
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading recent transactions"
        ) {
            let allEntries = try await budgetManager.getEntries(
                for: selectedTimeframe.timePeriod,
                sortedBy: .date,
                ascending: false
            )
            return Array(allEntries.prefix(maxRecentTransactions))
        }
        
        await MainActor.run {
            loadingStates.isTransactionsLoading = false
            
            if let transactions = result {
                recentTransactions = transactions
            } else if let error = errorHandler.errorHistory.first?.error {
                errorStates.transactionsError = error
            }
        }
    }
    
    private func loadSpendingData() async {
        await MainActor.run {
            loadingStates.isSpendingDataLoading = true
            errorStates.spendingDataError = nil
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading spending data"
        ) {
            let entries = try await budgetManager.getEntries(for: selectedTimeframe.timePeriod)
            let groupedEntries = Dictionary(grouping: entries) { $0.category }
            let totalSpent = entries.reduce(0) { $0 + $1.amount }
            
            return groupedEntries.compactMap { category, categoryEntries in
                let amount = categoryEntries.reduce(0) { $0 + $1.amount }
                let percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0
                
                guard amount > 0 else { return nil }
                
                return try? SpendingData(
                    category: category,
                    amount: amount,
                    percentage: percentage,
                    color: themeManager.colorForCategory(category)
                )
            }
            .sorted { (lhs: SpendingData, rhs: SpendingData) in lhs.amount > rhs.amount }
        }
        
        await MainActor.run {
            loadingStates.isSpendingDataLoading = false
            
            if let data = result {
                spendingData = data
            } else if let error = errorHandler.errorHistory.first?.error {
                errorStates.spendingDataError = error
            }
        }
    }
    
    private func loadCategoryBreakdown() async {
        let result = await AsyncErrorHandler.execute(
            context: "Loading category breakdown"
        ) {
            let entries = try await budgetManager.getEntries(for: selectedTimeframe.timePeriod)
            let budgets = budgetManager.getMonthlyBudgets(
                for: Calendar.current.component(.month, from: Date()),
                year: Calendar.current.component(.year, from: Date())
            )
            
            let spentByCategory = Dictionary(grouping: entries) { $0.category }
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            
            return budgets.compactMap { budget in
                let spent = spentByCategory[budget.category] ?? 0
                let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0
                
                return CategoryBreakdown(
                    category: budget.category,
                    spent: spent,
                    budgeted: budget.amount,
                    percentage: percentage,
                    color: themeManager.colorForCategory(budget.category)
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
    
    private func loadDataForTimeframe(_ timeframe: TimeFrame) async {
        // Cancel previous refresh task
        refreshTask?.cancel()
        
        refreshTask = Task<Void, Never>{
            async let summaryTask = loadBudgetSummary()
            async let transactionsTask = loadRecentTransactions()
            async let spendingTask = loadSpendingData()
            async let categoryTask = loadCategoryBreakdown()
            
            await summaryTask
            await transactionsTask
            await spendingTask
            await categoryTask
        }
        
        await refreshTask?.value
    }
    
    private func handleDataChange() {
        // Debounce rapid changes
        refreshTask?.cancel()
        refreshTask = Task<Void, Never>{
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard !Task.isCancelled else { return }
            
            await loadInitialData()
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// MARK: - Supporting View Components

private struct OverviewStatusIndicator: View {
    let color: Color
    let isAnimated: Bool
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .opacity(isAnimated ? 0.6 : 1.0)
            .scaleEffect(isAnimated ? 1.2 : 1.0)
            .animation(
                isAnimated ?
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    .default,
                value: isAnimated
            )
    }
}

private struct TimeFrameButton: View {
    let timeframe: BudgetOverviewView.TimeFrame
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: timeframe.systemImageName)
                    .font(.system(size: 14, weight: .medium))
                
                Text(timeframe.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? themeManager.primaryColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : themeManager.primaryColor.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .foregroundColor(isSelected ? .white : themeManager.primaryColor)
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewSectionHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeManager.primaryColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
            }
            
            Spacer()
        }
    }
}

private struct OverviewBudgetSummaryCard: View {
    let summary: BudgetOverviewView.BudgetSummaryData
    let themeColor: Color
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget Overview")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.semanticColors.textPrimary)
                    
                    Text(summary.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(summary.statusColor)
                }
                
                Spacer()
                
                OverviewStatusIndicator(
                    color: summary.statusColor,
                    isAnimated: summary.isOverBudget
                )
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(summary.percentageUsed * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(summary.statusColor)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.semanticColors.backgroundTertiary)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(summary.statusColor)
                            .frame(
                                width: geometry.size.width * min(summary.percentageUsed, 1.0),
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.8), value: summary.percentageUsed)
                    }
                }
                .frame(height: 8)
            }
            
            // Summary Numbers
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Budgeted",
                    amount: summary.totalBudgeted,
                    color: themeManager.primaryColor
                )
                
                Divider()
                    .frame(height: 40)
                
                SummaryItem(
                    title: "Spent",
                    amount: summary.totalSpent,
                    color: summary.statusColor
                )
                
                Divider()
                    .frame(height: 40)
                
                SummaryItem(
                    title: "Remaining",
                    amount: summary.remainingBudget,
                    color: summary.remainingBudget >= 0 ? themeManager.semanticColors.success : themeManager.semanticColors.error
                )
            }
            
            // Quick Stats
            HStack {
                QuickStat(
                    title: "Categories",
                    value: "\(summary.categoryCount)",
                    systemImage: "folder.fill"
                )
                
                Spacer()
                
                QuickStat(
                    title: "Transactions",
                    value: "\(summary.transactionCount)",
                    systemImage: "list.bullet"
                )
                
                Spacer()
                
                QuickStat(
                    title: "Last Updated",
                    value: RelativeDateTimeFormatter().localizedString(for: summary.lastUpdated, relativeTo: Date()),
                    systemImage: "clock.fill"
                )
            }
        }
        .padding(20)
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(
            color: .black.opacity(Double(AppConstants.UI.defaultShadowOpacity)),
            radius: AppConstants.UI.defaultShadowRadius,
            x: 0,
            y: 2
        )
    }
}

private struct SummaryItem: View {
    let title: String
    let amount: Double
    let color: Color
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(themeManager.semanticColors.textSecondary)
            
            Text(amount.asCurrency)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickStat: View {
    let title: String
    let value: String
    let systemImage: String
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundColor(themeManager.primaryColor)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(themeManager.semanticColors.textSecondary)
        }
    }
}

private struct CategoryBreakdownRow: View {
    let breakdown: BudgetOverviewView.CategoryBreakdown
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Color Indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(breakdown.color)
                .frame(width: 4, height: 32)
            
            // Category Info
            VStack(alignment: .leading, spacing: 2) {
                Text(breakdown.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Spent: \(breakdown.spent.asCurrency) of \(breakdown.budgeted.asCurrency)")
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
            }
            
            Spacer()
            
            // Progress and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(breakdown.percentage))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(breakdown.isOverBudget ? themeManager.semanticColors.error : themeManager.semanticColors.textPrimary)
                
                if breakdown.isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.error)
                } else {
                    Text(breakdown.remaining.asCurrency)
                        .font(.caption2)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(AppConstants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ErrorCard: View {
    let error: AppError
    let onRetry: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: error.severity.icon)
                .font(.system(size: 32))
                .foregroundColor(error.severity.color)
            
            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Unknown Error")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if error.isRetryable {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.primaryColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(error.severity.color.opacity(0.1))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty State Views

private struct EmptyBudgetCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Budget Set")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Set up your monthly budget to track your spending")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Set Budget") {
                // Navigate to budget setup
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(AppConstants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .stroke(themeManager.primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct EmptySpendingChart: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Spending Data")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Add some purchases to see your spending breakdown")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyCategoryBreakdown: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            Text("No categories available")
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyTransactionsList: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Recent Transactions")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Your recent purchases will appear here")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Purchase") {
                // Navigate to add purchase
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skeleton Loading Views

private struct BudgetSummaryCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonRectangle(width: 120, height: 16)
                    SkeletonRectangle(width: 80, height: 12)
                }
                
                Spacer()
                
                SkeletonCircle(diameter: 12)
            }
            
            SkeletonRectangle(width: .infinity, height: 8)
            
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonRectangle(width: 60, height: 12)
                        SkeletonRectangle(width: 80, height: 16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .onAppear {
            isAnimating = true
        }
    }
}

private struct SpendingChartSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonCircle(diameter: 200)
            
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        SkeletonCircle(diameter: 12)
                        SkeletonRectangle(width: 80, height: 12)
                        Spacer()
                        SkeletonRectangle(width: 40, height: 12)
                    }
                }
            }
        }
        .frame(height: 300)
    }
}

private struct TransactionListSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    SkeletonCircle(diameter: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonRectangle(width: 100, height: 14)
                        SkeletonRectangle(width: 60, height: 10)
                    }
                    
                    Spacer()
                    
                    SkeletonRectangle(width: 60, height: 14)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct SkeletonRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var isAnimating = false
    
    init(width: CGFloat?, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

private struct SkeletonCircle: View {
    let diameter: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: diameter, height: diameter)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct BudgetOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal State
            BudgetOverviewView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Normal State")
            
            // Dark Mode
            BudgetOverviewView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Loading State
            BudgetOverviewView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .onAppear {
                    // Simulate loading state
                }
                .previewDisplayName("Loading State")
        }
    }
}
#endif
