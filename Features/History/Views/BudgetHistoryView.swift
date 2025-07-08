//
//  BudgetHistoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved performance, and better state management
//

import SwiftUI
import Charts

/// View for displaying and analyzing budget history with comprehensive error handling and performance optimizations
struct BudgetHistoryView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = HistoryViewModel()
    
    // MARK: - State
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var sortOption: BudgetSortOption = .category
    @State private var sortAscending = true
    @State private var showingFilterMenu = false
    @State private var selectedDataPoint: BudgetHistoryData?
    @State private var showingExportOptions = false
    @State private var showingDetailView = false
    @State private var selectedCategory: String?
    
    // MARK: - Chart Configuration
    private let chartColors: [Color] = [
        Color(r: 0.12, g: 0.58, b: 0.95), // Blue
        Color(r: 0.99, g: 0.85, b: 0.21), // Yellow
        Color(r: 0.18, g: 0.80, b: 0.44), // Green
        Color(r: 0.61, g: 0.35, b: 0.71), // Purple
        Color(r: 1.00, g: 0.60, b: 0.00), // Orange
        Color(r: 0.20, g: 0.60, b: 0.86), // Sky Blue
        Color(r: 0.95, g: 0.27, b: 0.57)  // Pink
    ]
    
    // MARK: - Performance Configuration
    private let maxDataPoints = 100
    private let chartAnimationDuration: Double = 0.8
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerControls
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Budget History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .errorAlert(onRetry: {
                Task<Void, Never>{
                    await viewModel.refreshData(
                        budgetManager: budgetManager,
                        timePeriod: selectedTimePeriod
                    )
                }
            })
            .sheet(isPresented: $showingFilterMenu) {
                filterMenuSheet
            }
            .sheet(isPresented: $showingExportOptions) {
                exportOptionsSheet
            }
            .sheet(isPresented: $showingDetailView) {
                categoryDetailSheet
            }
            .onAppear {
                setupView()
            }
            .onChange(of: selectedTimePeriod) { _, newPeriod in
                Task<Void, Never>{
                    await viewModel.updateTimePeriod(
                        newPeriod,
                        budgetManager: budgetManager
                    )
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerControls: some View {
        VStack(spacing: AppConstants.UI.standardSpacing) {
            // Time Period Selector
            TimePeriodSelector(
                selectedPeriod: $selectedTimePeriod,
                themeColor: themeManager.primaryColor
            )
            
            // Quick Stats
            if !viewModel.budgetData.isEmpty {
                BudgetSummaryCards(
                    totalBudget: viewModel.totalBudget,
                    totalSpent: viewModel.totalSpent,
                    isOverBudget: viewModel.isOverBudget,
                    primaryColor: themeManager.primaryColor
                )
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeManager.primaryColor)
            
            Text("Loading budget history...")
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if viewModel.budgetData.isEmpty {
                    emptyStateView
                } else {
                    chartSection
                    Divider()
                        .padding(.horizontal)
                    budgetDetailsSection
                }
            }
            .padding()
        }
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            Text("No data available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            Text("Try selecting a different time period or add some budget data")
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Add Budget Data") {
                // Navigate to budget setup
                NotificationCenter.default.post(name: .openBudgetView, object: nil)
            }
            .buttonStyle(PrimaryButtonStyle(color: themeManager.primaryColor))
            .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Budget Overview",
                subtitle: selectedTimePeriod.displayName,
                icon: "chart.bar.fill",
                color: themeManager.primaryColor
            )
            
            budgetChart
            chartLegend
        }
    }
    
    private var budgetChart: some View {
        Chart {
            ForEach(Array(sortedBudgetData.enumerated()), id: \.element.id) { index, data in
                // Spent amount bars
                BarMark(
                    x: .value("Category", categoryDisplayName(data.category, index: index)),
                    y: .value("Amount", data.amountSpent)
                )
                .foregroundStyle(chartColors[index % chartColors.count])
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    if data.amountSpent > 0 {
                        Text(data.amountSpent.asCurrency)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.semanticColors.textPrimary)
                    }
                }
                
                // Budget limit indicators
                if data.budgetedAmount > 0 {
                    RuleMark(
                        xStart: .value("Category", categoryDisplayName(data.category, index: index)),
                        xEnd: .value("Category", categoryDisplayName(data.category, index: index)),
                        y: .value("Budget", data.budgetedAmount)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .annotation(position: .topTrailing) {
                        if data.isOverBudget {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .frame(height: 300)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let categoryName = value.as(String.self) {
                        Text(categoryName)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                AxisGridLine()
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(NumberFormatter.formatCompact(amount))
                            .font(.caption)
                    }
                }
                AxisGridLine()
                AxisTick()
            }
        }
        .chartAngleSelection(value: .constant(nil))
        .chartBackground { chartProxy in
            Rectangle()
                .fill(themeManager.semanticColors.backgroundSecondary.opacity(0.5))
                .cornerRadius(8)
        }
        .animation(.easeInOut(duration: chartAnimationDuration), value: sortedBudgetData)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget overview chart showing spending versus budgeted amounts")
    }
    
    private var chartLegend: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(Array(sortedBudgetData.prefix(10).enumerated()), id: \.element.id) { index, data in
                ChartLegendItem(
                    data: data,
                    color: chartColors[index % chartColors.count],
                    onTap: {
                        selectedCategory = data.category
                        showingDetailView = true
                    }
                )
            }
        }
        .padding(.top)
    }
    
    private var budgetDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Detailed Breakdown",
                subtitle: "\(sortedBudgetData.count) categories",
                icon: "list.bullet",
                color: themeManager.primaryColor
            )
            
            LazyVStack(spacing: 12) {
                ForEach(sortedBudgetData, id: \.id) { data in
                    BudgetHistoryRow(
                        data: data,
                        color: themeManager.primaryColor
                    )
                    .onTapGesture {
                        selectedCategory = data.category
                        showingDetailView = true
                    }
                    .contextMenu {
                        contextMenuContent(for: data)
                    }
                }
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showingFilterMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(themeManager.primaryColor)
                }
                .accessibilityLabel("Filter and sort options")
                
                Button {
                    showingExportOptions = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(themeManager.primaryColor)
                }
                .accessibilityLabel("Export data")
                .disabled(viewModel.budgetData.isEmpty)
            }
        }
    }
    
    // MARK: - Sheet Content
    
    private var filterMenuSheet: some View {
        NavigationView {
            FilterSortView(
                selectedTimePeriod: $selectedTimePeriod,
                sortOption: $sortOption,
                sortAscending: $sortAscending,
                onDismiss: {
                    showingFilterMenu = false
                    applySorting()
                }
            )
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var exportOptionsSheet: some View {
        NavigationView {
            ExportOptionsView(
                data: viewModel.budgetData,
                timePeriod: selectedTimePeriod,
                onDismiss: {
                    showingExportOptions = false
                }
            )
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private var categoryDetailSheet: some View {
        Group {
            if let category = selectedCategory,
               let data = viewModel.budgetData.first(where: { $0.category == category }) {
                NavigationView {
                    CategoryDetailView(
                        data: data,
                        timePeriod: selectedTimePeriod,
                        color: chartColors[sortedBudgetData.firstIndex(where: { $0.category == category }) ?? 0 % chartColors.count]
                    )
                    .navigationTitle(category)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDetailView = false
                                selectedCategory = nil
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuContent(for data: BudgetHistoryData) -> some View {
        Button {
            selectedCategory = data.category
            showingDetailView = true
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Button {
            // Export single category
            Task<Void, Never>{
                await exportCategory(data)
            }
        } label: {
            Label("Export Category", systemImage: "square.and.arrow.up")
        }
        
        if data.budgetedAmount > 0 {
            Button {
                // Navigate to edit budget
                NotificationCenter.default.post(
                    name: .openBudgetUpdate,
                    object: nil,
                    userInfo: ["category": data.category]
                )
            } label: {
                Label("Edit Budget", systemImage: "pencil")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var sortedBudgetData: [BudgetHistoryData] {
        let limited = Array(viewModel.budgetData.prefix(maxDataPoints))
        
        return limited.sorted { a, b in
            let result: Bool
            switch sortOption {
            case .category:
                result = a.category < b.category
            case .budgetedAmount:
                result = a.budgetedAmount < b.budgetedAmount
            case .amountSpent:
                result = a.amountSpent < b.amountSpent
            case .date:
                // For budget history, sort by category as fallback
                result = a.category < b.category
            case .amount:
                result = a.amountSpent < b.amountSpent
            }
            return sortAscending ? result : !result
        }
    }
    
    private func categoryDisplayName(_ category: String, index: Int) -> String {
        if category.count > 12 {
            return String(category.prefix(10)) + "..."
        }
        return category
    }
    
    private func setupView() {
        Task<Void, Never>{
            await viewModel.loadInitialData(
                budgetManager: budgetManager,
                timePeriod: selectedTimePeriod
            )
        }
    }
    
    private func refreshData() async {
        await viewModel.refreshData(
            budgetManager: budgetManager,
            timePeriod: selectedTimePeriod
        )
    }
    
    private func applySorting() {
        // Trigger view update with new sorting
        withAnimation(.easeInOut(duration: 0.3)) {
            // The sorted computed property will automatically update
        }
    }
    
    private func exportCategory(_ data: BudgetHistoryData) async {
        do {
            // Create single-category export
            let entries = try await budgetManager.getEntries(
                for: selectedTimePeriod,
                category: data.category
            )
            
            let exportURL = try await CSVExport.exportBudgetEntries(
                entries,
                configuration: CSVExport.ExportConfiguration(
                    timePeriod: selectedTimePeriod,
                    exportType: .budgetEntries
                )
            )
            
            // Share the exported file
            let activityViewController = UIActivityViewController(
                activityItems: [exportURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(activityViewController, animated: true)
            }
            
        } catch {
            ErrorHandler.shared.handle(
                AppError.from(error),
                context: "Exporting category data"
            )
        }
    }
}

// MARK: - Supporting Views

struct TimePeriodSelector: View {
    @Binding var selectedPeriod: TimePeriod
    let themeColor: Color
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimePeriod.commonPeriods, id: \.self) { period in
                    TimePeriodChip(
                        period: period,
                        isSelected: selectedPeriod == period,
                        themeColor: themeColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TimePeriodChip: View {
    let period: TimePeriod
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.shortDisplayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? themeColor : Color.gray.opacity(0.2)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BudgetSummaryCards: View {
    let totalBudget: Double
    let totalSpent: Double
    let isOverBudget: Bool
    let primaryColor: Color
    
    private var remainingBudget: Double {
        totalBudget - totalSpent
    }
    
    private var percentageUsed: Double {
        guard totalBudget > 0 else { return 0 }
        return (totalSpent / totalBudget) * 100
    }
    
    var body: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Total Budget",
                value: totalBudget.asCurrency,
                color: primaryColor,
                icon: "dollarsign.circle.fill"
            )
            
            SummaryCard(
                title: "Total Spent",
                value: totalSpent.asCurrency,
                color: isOverBudget ? .red : .green,
                icon: "creditcard.fill"
            )
            
            SummaryCard(
                title: "Remaining",
                value: remainingBudget.asCurrency,
                color: isOverBudget ? .red : primaryColor,
                icon: "banknote.fill"
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    init(title: String, subtitle: String? = nil, icon: String, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct ChartLegendItem: View {
    let data: BudgetHistoryData
    let color: Color
    let onTap: () -> Void
    
    private var formattedPercentage: String {
        data.percentageSpent.formatted(.percent.precision(.fractionLength(1)))
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(formattedPercentage)
                        .font(.caption2)
                        .foregroundColor(data.isOverBudget ? .red : .green)
                }
                
                Spacer()
                
                if data.isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.category): \(formattedPercentage) of budget used")
        .accessibilityAddTraits(.isButton)
    }
}

struct CategoryDetailView: View {
    let data: BudgetHistoryData
    let timePeriod: TimePeriod
    let color: Color
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Category Overview Card
                CategoryOverviewCard(data: data, color: color)
                
                // Progress Visualization
                CategoryProgressView(data: data, color: color)
                
                // Quick Stats
                CategoryStatsGrid(data: data)
                
                // Action Buttons
                CategoryActionButtons(category: data.category)
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct CategoryOverviewCard: View {
    let data: BudgetHistoryData
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(data.budgetedAmount.asCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Spent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(data.amountSpent.asCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(data.isOverBudget ? .red : .green)
                }
            }
            
            Divider()
            
            HStack {
                Text("Remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(data.remainingAmount.asCurrency)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(data.isOverBudget ? .red : color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct CategoryProgressView: View {
    let data: BudgetHistoryData
    let color: Color
    
    private var progressValue: Double {
        guard data.budgetedAmount > 0 else { return 0 }
        return min(data.amountSpent / data.budgetedAmount, 1.5) // Allow showing over 100%
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text(data.percentageSpent.formatted(.percent.precision(.fractionLength(1))))
                    .font(.headline)
                    .foregroundColor(data.isOverBudget ? .red : color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(data.isOverBudget ? .red : color)
                        .frame(width: geometry.size.width * progressValue, height: 20)
                        .cornerRadius(10)
                        .animation(.easeInOut(duration: 0.8), value: progressValue)
                }
            }
            .frame(height: 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct CategoryStatsGrid: View {
    let data: BudgetHistoryData
    
    private var averageDaily: Double {
        // Assuming current month for simplicity
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return data.amountSpent / Double(daysInMonth)
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Daily Average",
                value: averageDaily.asCurrency,
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "Status",
                value: data.isOverBudget ? "Over Budget" : "On Track",
                icon: data.isOverBudget ? "exclamationmark.triangle" : "checkmark.circle",
                color: data.isOverBudget ? .red : .green
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct CategoryActionButtons: View {
    let category: String
    
    var body: some View {
        VStack(spacing: 12) {
            Button {
                NotificationCenter.default.post(
                    name: .openBudgetUpdate,
                    object: nil,
                    userInfo: ["category": category]
                )
            } label: {
                Label("Edit Budget", systemImage: "pencil.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button {
                NotificationCenter.default.post(
                    name: .openAddPurchase,
                    object: nil,
                    userInfo: ["category": category]
                )
            } label: {
                Label("Add Purchase", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(color: .blue))
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - HistoryViewModel

@MainActor
class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var budgetData: [BudgetHistoryData] = []
    @Published var isLoading = false
    @Published var lastRefreshDate: Date?
    @Published var selectedTimePeriod: TimePeriod = .thisMonth
    
    // MARK: - Computed Properties
    var totalBudget: Double {
        budgetData.reduce(0) { $0 + $1.budgetedAmount }
    }
    
    var totalSpent: Double {
        budgetData.reduce(0) { $0 + $1.amountSpent }
    }
    
    var isOverBudget: Bool {
        totalSpent > totalBudget
    }
    
    var categoriesOverBudget: [BudgetHistoryData] {
        budgetData.filter { $0.isOverBudget }
    }
    
    var topSpendingCategories: [BudgetHistoryData] {
        budgetData.sorted { $0.amountSpent > $1.amountSpent }.prefix(5).map { $0 }
    }
    
    // MARK: - Private Properties
    private let errorHandler = ErrorHandler.shared
    private var dataCache: [String: [BudgetHistoryData]] = [:]
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    private var lastCacheUpdate: [String: Date] = [:]
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Public Methods
    
    /// Load initial budget history data
    func loadInitialData(budgetManager: BudgetManager, timePeriod: TimePeriod) async {
        guard !isLoading else { return }
        
        let startTime = Date()
        isLoading = true
        
        do {
            let data = try await calculateBudgetHistoryData(
                budgetManager: budgetManager,
                timePeriod: timePeriod
            )
            
            budgetData = data
            selectedTimePeriod = timePeriod
            lastRefreshDate = Date()
            
            recordMetric("loadInitialData", duration: Date().timeIntervalSince(startTime))
            print("✅ HistoryViewModel: Loaded \(data.count) budget categories")
            
        } catch {
            handleError(error, context: "Loading initial budget history data")
        }
        
        isLoading = false
    }
    
    /// Refresh data for current time period
    func refreshData(budgetManager: BudgetManager, timePeriod: TimePeriod) async {
        await loadInitialData(budgetManager: budgetManager, timePeriod: timePeriod)
    }
    
    /// Update time period and load corresponding data
    func updateTimePeriod(_ newPeriod: TimePeriod, budgetManager: BudgetManager) async {
        selectedTimePeriod = newPeriod
        
        // Check cache first
        let cacheKey = getCacheKey(for: newPeriod)
        if let cachedData = getCachedData(for: cacheKey) {
            budgetData = cachedData
            return
        }
        
        await loadInitialData(budgetManager: budgetManager, timePeriod: newPeriod)
    }
    
    /// Get budget data for a specific category
    func getCategoryData(category: String) -> BudgetHistoryData? {
        return budgetData.first { $0.category == category }
    }
    
    /// Get summary statistics
    func getSummaryStatistics() -> HistorySummary {
        return HistorySummary(
            totalCategories: budgetData.count,
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            remainingBudget: totalBudget - totalSpent,
            percentageUsed: totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0,
            categoriesOverBudget: categoriesOverBudget.count,
            topSpendingCategory: topSpendingCategories.first?.category,
            averageSpendingPerCategory: budgetData.isEmpty ? 0 : totalSpent / Double(budgetData.count),
            lastUpdated: lastRefreshDate ?? Date()
        )
    }
    
    /// Export budget history data
    func exportData(format: CSVExport.ExportConfiguration.ExportType = .budgetEntries) async throws -> URL {
        let startTime = Date()
        
        do {
            // Convert budget history data to exportable format
            let exportData = budgetData.map { data in
                [
                    "Category": data.category,
                    "Budgeted Amount": String(data.budgetedAmount),
                    "Amount Spent": String(data.amountSpent),
                    "Remaining Amount": String(data.remainingAmount),
                    "Percentage Spent": String(format: "%.2f", data.percentageSpent),
                    "Is Over Budget": data.isOverBudget ? "Yes" : "No",
                    "Export Date": ISO8601DateFormatter().string(from: Date())
                ]
            }
            
            // Create temporary CSV content
            var csvContent = "Category,Budgeted Amount,Amount Spent,Remaining Amount,Percentage Spent,Is Over Budget,Export Date\n"
            
            for row in exportData {
                let csvRow = [
                    row["Category"] ?? "",
                    row["Budgeted Amount"] ?? "",
                    row["Amount Spent"] ?? "",
                    row["Remaining Amount"] ?? "",
                    row["Percentage Spent"] ?? "",
                    row["Is Over Budget"] ?? "",
                    row["Export Date"] ?? ""
                ].joined(separator: ",")
                csvContent += csvRow + "\n"
            }
            
            // Write to temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "budget_history_\(DateFormatter.fileTimestamp.string(from: Date())).csv"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            recordMetric("exportData", duration: Date().timeIntervalSince(startTime))
            return fileURL
            
        } catch {
            throw AppError.csvExport(underlying: error)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateBudgetHistoryData(
        budgetManager: BudgetManager,
        timePeriod: TimePeriod
    ) async throws -> [BudgetHistoryData] {
        let startTime = Date()
        
        // Get date interval for the selected period
        let dateInterval = timePeriod.dateInterval()
        
        // Get budget entries for the time period
        let entries = try await budgetManager.getEntries(for: timePeriod)
        
        // Get monthly budgets for the time period
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month], from: dateInterval.start)
        let endComponents = calendar.dateComponents([.year, .month], from: dateInterval.end)
        
        var allBudgets: [MonthlyBudget] = []
        
        // Collect budgets for all months in the period
        if let startYear = startComponents.year,
           let startMonth = startComponents.month,
           let endYear = endComponents.year,
           let endMonth = endComponents.month {
            
            var currentYear = startYear
            var currentMonth = startMonth
            
            while (currentYear < endYear) || (currentYear == endYear && currentMonth <= endMonth) {
                let monthlyBudgets = budgetManager.getMonthlyBudgets(for: currentMonth, year: currentYear)
                allBudgets.append(contentsOf: monthlyBudgets)
                
                // Move to next month
                currentMonth += 1
                if currentMonth > 12 {
                    currentMonth = 1
                    currentYear += 1
                }
            }
        }
        
        // Group entries by category
        let entriesByCategory = Dictionary(grouping: entries) { $0.category }
        
        // Group budgets by category and sum amounts
        let budgetsByCategory = Dictionary(grouping: allBudgets) { $0.category }
            .mapValues { budgets in
                budgets.reduce(0) { $0 + $1.amount }
            }
        
        // Create a set of all categories
        let allCategories = Set(entriesByCategory.keys).union(Set(budgetsByCategory.keys))
        
        // Create budget history data for each category
        var budgetHistoryData: [BudgetHistoryData] = []
        
        for category in allCategories {
            let categoryEntries = entriesByCategory[category] ?? []
            let amountSpent = categoryEntries.reduce(0) { $0 + $1.amount }
            let budgetedAmount = budgetsByCategory[category] ?? 0
            
            let data = BudgetHistoryData(
                category: category,
                budgetedAmount: budgetedAmount,
                amountSpent: amountSpent
            )
            
            budgetHistoryData.append(data)
        }
        
        // Cache the result
        let cacheKey = getCacheKey(for: timePeriod)
        cacheData(budgetHistoryData, for: cacheKey)
        
        recordMetric("calculateBudgetHistoryData", duration: Date().timeIntervalSince(startTime))
        return budgetHistoryData
    }
    
    private func handleError(_ error: Error, context: String) {
        let appError = AppError.from(error)
        errorHandler.handle(appError, context: context)
    }
    
    // MARK: - Cache Management
    
    private func getCacheKey(for timePeriod: TimePeriod) -> String {
        switch timePeriod {
        case .today:
            return "today"
        case .yesterday:
            return "yesterday"
        case .thisWeek:
            return "thisWeek"
        case .lastWeek:
            return "lastWeek"
        case .thisMonth:
            return "thisMonth"
        case .lastMonth:
            return "lastMonth"
        case .thisYear:
            return "thisYear"
        case .lastYear:
            return "lastYear"
        case .last7Days:
            return "last7Days"
        case .last30Days:
            return "last30Days"
        case .last90Days:
            return "last90Days"
        case .allTime:
            return "allTime"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            return "custom_\(formatter.string(from: start))_\(formatter.string(from: end))"
        default:
            return "unknown"
        }
    }
    
    private func getCachedData(for key: String) -> [BudgetHistoryData]? {
        guard let lastUpdate = lastCacheUpdate[key],
              Date().timeIntervalSince(lastUpdate) < cacheValidityDuration,
              let data = dataCache[key] else {
            return nil
        }
        return data
    }
    
    private func cacheData(_ data: [BudgetHistoryData], for key: String) {
        dataCache[key] = data
        lastCacheUpdate[key] = Date()
    }
    
    private func clearCache() {
        dataCache.removeAll()
        lastCacheUpdate.removeAll()
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        operationMetrics[operation] = duration
        
        #if DEBUG
        if duration > 1.0 {
            print("⚠️ HistoryViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
        }
        #endif
    }
    
    // MARK: - Data Validation
    
    private func validateBudgetData(_ data: [BudgetHistoryData]) -> Bool {
        // Check for valid data structure
        guard !data.isEmpty else { return true } // Empty is valid
        
        // Check for duplicate categories
        let categories = data.map { $0.category }
        let uniqueCategories = Set(categories)
        guard categories.count == uniqueCategories.count else {
            print("⚠️ HistoryViewModel: Duplicate categories found")
            return false
        }
        
        // Check for negative values
        for item in data {
            guard item.budgetedAmount >= 0 && item.amountSpent >= 0 else {
                print("⚠️ HistoryViewModel: Negative amounts found in \(item.category)")
                return false
            }
        }
        
        return true
    }
}

// MARK: - Supporting Types

struct HistorySummary {
    let totalCategories: Int
    let totalBudget: Double
    let totalSpent: Double
    let remainingBudget: Double
    let percentageUsed: Double
    let categoriesOverBudget: Int
    let topSpendingCategory: String?
    let averageSpendingPerCategory: Double
    let lastUpdated: Date
    
    var isOverBudget: Bool {
        totalSpent > totalBudget
    }
    
    var budgetUtilization: BudgetUtilization {
        if percentageUsed > 100 {
            return .overBudget
        } else if percentageUsed > 90 {
            return .nearLimit
        } else if percentageUsed > 50 {
            return .moderate
        } else {
            return .conservative
        }
    }
    
    enum BudgetUtilization: String, CaseIterable {
        case conservative = "Conservative"
        case moderate = "Moderate"
        case nearLimit = "Near Limit"
        case overBudget = "Over Budget"
        
        var color: Color {
            switch self {
            case .conservative: return .green
            case .moderate: return .blue
            case .nearLimit: return .orange
            case .overBudget: return .red
            }
        }
        
        var systemImageName: String {
            switch self {
            case .conservative: return "checkmark.circle.fill"
            case .moderate: return "minus.circle.fill"
            case .nearLimit: return "exclamationmark.triangle.fill"
            case .overBudget: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - ExportOptionsView

struct ExportOptionsView: View {
    let data: [BudgetHistoryData]
    let timePeriod: TimePeriod
    let onDismiss: () -> Void
    
    @StateObject private var viewModel = ExportOptionsViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    exportFormatSection
                    includeBudgetDataToggle
                    includeMetadataToggle
                }
                
                Section("Preview") {
                    exportPreview
                }
                
                Section {
                    exportButton
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var exportFormatSection: some View {
        Picker("Format", selection: $viewModel.selectedFormat) {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Label {
                    VStack(alignment: .leading) {
                        Text(format.displayName)
                        Text(format.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: format.systemImageName)
                }
                .tag(format)
            }
        }
        .pickerStyle(.automatic)
    }
    
    private var includeBudgetDataToggle: some View {
        Toggle("Include Budget Data", isOn: $viewModel.includeBudgetData)
    }
    
    private var includeMetadataToggle: some View {
        Toggle("Include Metadata", isOn: $viewModel.includeMetadata)
    }
    
    private var exportPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export will include:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Label("\(data.count) categories", systemImage: "folder.fill")
                .font(.caption)
            
            Label("Time period: \(timePeriod.displayName)", systemImage: "calendar")
                .font(.caption)
            
            if viewModel.includeBudgetData {
                Label("Budget vs actual data", systemImage: "dollarsign.circle")
                    .font(.caption)
            }
            
            if viewModel.includeMetadata {
                Label("Export metadata", systemImage: "info.circle")
                    .font(.caption)
            }
        }
        .foregroundColor(.secondary)
    }
    
    private var exportButton: some View {
        Button {
            Task<Void, Never>{
                await viewModel.performExport(data: data, timePeriod: timePeriod)
                onDismiss()
            }
        } label: {
            if viewModel.isExporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Exporting...")
                }
            } else {
                Text("Export Data")
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isExporting)
    }
}

// MARK: - ExportOptionsViewModel

@MainActor
class ExportOptionsViewModel: ObservableObject {
    @Published var selectedFormat: ExportFormat = .csv
    @Published var includeBudgetData = true
    @Published var includeMetadata = true
    @Published var isExporting = false
    
    func performExport(data: [BudgetHistoryData], timePeriod: TimePeriod) async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let exportURL: URL
            
            switch selectedFormat {
            case .csv:
                exportURL = try await exportAsCSV(data: data, timePeriod: timePeriod)
            case .json:
                exportURL = try await exportAsJSON(data: data, timePeriod: timePeriod)
            case .pdf:
                exportURL = try await exportAsPDF(data: data, timePeriod: timePeriod)
            }
            
            // Present share sheet
            await presentShareSheet(for: exportURL)
            
        } catch {
            ErrorHandler.shared.handle(
                AppError.from(error),
                context: "Exporting budget history data"
            )
        }
    }
    
    private func exportAsCSV(data: [BudgetHistoryData], timePeriod: TimePeriod) async throws -> URL {
        var csvContent = "Category,Budgeted Amount,Amount Spent,Remaining Amount,Percentage Spent,Is Over Budget"
        
        if includeMetadata {
            csvContent += ",Export Date,Time Period"
        }
        
        csvContent += "\n"
        
        for item in data {
            var row = [
                item.category,
                String(item.budgetedAmount),
                String(item.amountSpent),
                String(item.remainingAmount),
                String(format: "%.2f", item.percentageSpent),
                item.isOverBudget ? "Yes" : "No"
            ]
            
            if includeMetadata {
                row.append(ISO8601DateFormatter().string(from: Date()))
                row.append(timePeriod.displayName)
            }
            
            csvContent += row.joined(separator: ",") + "\n"
        }
        
        return try await writeToFile(content: csvContent, extension: "csv")
    }
    
    private func exportAsJSON(data: [BudgetHistoryData], timePeriod: TimePeriod) async throws -> URL {
        var exportData: [String: Any] = [
            "categories": data.map { item in
                [
                    "category": item.category,
                    "budgetedAmount": item.budgetedAmount,
                    "amountSpent": item.amountSpent,
                    "remainingAmount": item.remainingAmount,
                    "percentageSpent": item.percentageSpent,
                    "isOverBudget": item.isOverBudget
                ]
            }
        ]
        
        if includeMetadata {
            exportData["metadata"] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "timePeriod": timePeriod.displayName,
                "totalCategories": data.count,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        
        return try await writeToFile(content: jsonString, extension: "json")
    }
    
    private func exportAsPDF(data: [BudgetHistoryData], timePeriod: TimePeriod) async throws -> URL {
        // For now, return CSV as PDF isn't implemented
        // In a full implementation, you would use PDFKit to create a formatted PDF
        return try await exportAsCSV(data: data, timePeriod: timePeriod)
    }
    
    private func writeToFile(content: String, extension: String) async throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "budget_history_\(DateFormatter.fileTimestamp.string(from: Date())).\(`extension`)"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func presentShareSheet(for url: URL) async {
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .csv: return "Comma-separated values"
        case .json: return "JavaScript Object Notation"
        case .pdf: return "Portable Document Format"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "doc.text"
        case .pdf: return "doc.richtext"
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Preview Provider

#if DEBUG
struct BudgetHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BudgetHistoryView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
        }
        
        NavigationView {
            BudgetHistoryView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
        }
        .previewDisplayName("Dark Mode")
    }
}
#endif
