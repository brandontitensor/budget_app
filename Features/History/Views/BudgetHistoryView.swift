//
//  BudgetHistoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
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
        Color(red: 0.12, green: 0.58, blue: 0.95), // Blue
        Color(red: 0.99, green: 0.85, blue: 0.21), // Yellow
        Color(red: 0.18, green: 0.80, blue: 0.44), // Green
        Color(red: 0.61, green: 0.35, blue: 0.71), // Purple
        Color(red: 1.00, green: 0.60, blue: 0.00), // Orange
        Color(red: 0.20, green: 0.60, blue: 0.86), // Sky Blue
        Color(red: 0.95, green: 0.27, blue: 0.57)  // Pink
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
            if !viewModel.filteredData.isEmpty {
                BudgetSummaryCards(
                    totalBudget: viewModel.totalFilteredAmount,
                    totalSpent: viewModel.totalFilteredAmount,
                    isOverBudget: false, // TODO: Add budget comparison logic
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
                if viewModel.filteredData.isEmpty {
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
        Chart(sortedBudgetData, id: \.id) { data in
            BarMark(
                x: .value("Category", data.category),
                y: .value("Amount", data.amountSpent)
            )
            .foregroundStyle(themeManager.primaryColor.gradient)
        }
        .frame(height: 300)
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
                .disabled(viewModel.filteredData.isEmpty)
            }
        }
    }
    
    // MARK: - Sheet Content
    
    private var filterMenuSheet: some View {
        NavigationView {
            VStack {
                Text("Filter & Sort")
                    .font(.title2)
                    .padding()
                
                // TODO: Implement FilterSortView
                Button("Close") {
                    showingFilterMenu = false
                }
                .padding()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var exportOptionsSheet: some View {
        NavigationView {
            ExportOptionsView(
                exportTimePeriod: $selectedTimePeriod,
                onExport: {
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
               let data = viewModel.filteredData.first(where: { $0.category == category }) {
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
        let limited = Array(viewModel.filteredData.prefix(maxDataPoints))
        
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
            await viewModel.loadInitialData()
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
        .previewDisplayName("Light Mode")
        
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
