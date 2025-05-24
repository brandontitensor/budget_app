//
//  BudgetHistoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//

import SwiftUI
import Charts

/// View for displaying and analyzing budget history
struct BudgetHistoryView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - State
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var sortOption: BudgetSortOption = .category
    @State private var sortAscending = true
    @State private var showingFilterMenu = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDataPoint: BudgetHistoryData?
    
    // MARK: - Chart Colors
    private let chartColors: [Color] = [
        Color(r: 0.12, g: 0.58, b: 0.95), // Blue
        Color(r: 0.99, g: 0.85, b: 0.21), // Yellow
        Color(r: 0.18, g: 0.80, b: 0.44), // Green
        Color(r: 0.61, g: 0.35, b: 0.71), // Purple
        Color(r: 1.00, g: 0.60, b: 0.00), // Orange
        Color(r: 0.20, g: 0.60, b: 0.86), // Sky Blue
        Color(r: 0.95, g: 0.27, b: 0.57)  // Pink
    ]
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            filterSortButton
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                if filteredAndSortedBudgetData.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summaryCards
                            Divider()
                            budgetBarChart
                            Divider()
                            budgetList
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
        }
        .navigationTitle("Budget History")
        .sheet(isPresented: $showingFilterMenu) {
            FilterSortView(
                selectedTimePeriod: $selectedTimePeriod,
                sortOption: $sortOption,
                sortAscending: $sortAscending,
                onDismiss: filterAndSortEntries
            )
        }
        .onAppear {
            Task {
                await loadInitialData()
            }
        }
    }
    
    // MARK: - View Components
    private var filterSortButton: some View {
        Button(action: { showingFilterMenu = true }) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("Filter & Sort")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .accessibilityLabel("Open filter and sort options")
    }
    
    private var loadingView: some View {
        ProgressView("Loading budget data...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No data available for the selected period")
                .font(.headline)
            Text("Try selecting a different time period")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await loadInitialData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var summaryCards: some View {
        HStack {
            BudgetSummaryCard(
                budgeted: totalBudget(),
                spent: totalSpent(),
                primaryColor: themeManager.primaryColor
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total budgeted: \(totalBudget().asCurrency), Total spent: \(totalSpent().asCurrency)")
            
            BudgetSummaryCard(
                budgeted: totalBudget(),
                spent: totalSpent(),
                primaryColor: totalSpent() > totalBudget() ? .red : .green
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Budget status: \(totalSpent() > totalBudget() ? "Over budget" : "Under budget")")
        }
    }
    
    private var budgetBarChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget Overview")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart {
                ForEach(Array(filteredAndSortedBudgetData.enumerated()), id: \.element.id) { index, data in
                    BarMark(
                        x: .value("Category", "\(index + 1)"),
                        y: .value("Amount", data.amountSpent)
                    )
                    .foregroundStyle(chartColors[index % chartColors.count])
                    .annotation(position: .top) {
                        Text(data.percentageSpent.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption2)
                            .foregroundColor(data.isOverBudget ? .red : .primary)
                    }
                    
                    if data.amountSpent <= data.budgetedAmount {
                        BarMark(
                            x: .value("Category", "\(index + 1)"),
                            y: .value("Amount", data.budgetedAmount)
                        )
                        .foregroundStyle(chartColors[index % chartColors.count].opacity(0.3))
                    }
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel("")
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.asCurrency)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Budget overview chart")
            .accessibilityHint("Bar chart showing spent versus budgeted amounts for each category")
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(filteredAndSortedBudgetData.enumerated()), id: \.element.id) { index, data in
                    HStack {
                        Rectangle()
                            .fill(chartColors[index % chartColors.count])
                            .frame(width: 20, height: 10)
                        Text(data.category)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(data.percentageSpent.formatted(.percent.precision(.fractionLength(1))))
                            .font(.caption2)
                            .foregroundColor(data.isOverBudget ? .red : .green)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(data.category): \(data.percentageSpent.formatted(.percent.precision(.fractionLength(1)))) spent")
                }
            }
        }
    }
    
    private var budgetList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Budget Details")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(filteredAndSortedBudgetData) { data in
                BudgetHistoryRow(data: data, color: themeManager.primaryColor)
            }
        }
    }
    
    // MARK: - Helper Methods
    private var filteredAndSortedBudgetData: [BudgetHistoryData] {
        calculateBudgetHistoryDataSync().sorted { a, b in
            let result: Bool
            switch sortOption {
            case .category:
                result = a.category < b.category
            case .budgetedAmount:
                result = a.budgetedAmount < b.budgetedAmount
            case .amountSpent:
                result = a.amountSpent < b.amountSpent
            case .date:
                result = false // Date sorting not applicable for budget history
            case .amount:
                result = a.amountSpent < b.amountSpent
            }
            return sortAscending ? result : !result
        }
    }
    
    private func calculateBudgetHistoryDataSync() -> [BudgetHistoryData] {
        let dateInterval = selectedTimePeriod.dateInterval()
        // Use the synchronous entries property instead of the async method
        let filteredEntries = budgetManager.entries.filter { entry in
            entry.date >= dateInterval.start && entry.date <= dateInterval.end
        }
        let month = Calendar.current.component(.month, from: dateInterval.start)
        let year = Calendar.current.component(.year, from: dateInterval.start)
        let budgets = budgetManager.getMonthlyBudgets(for: month, year: year)
        
        var budgetDataDict: [String: BudgetHistoryData] = [:]
        
        // Process budgets
        for budget in budgets {
            let category = budget.category
            budgetDataDict[category] = BudgetHistoryData(
                category: category,
                budgetedAmount: budget.amount,
                amountSpent: 0
            )
        }
        
        // Process entries
        for entry in filteredEntries {
            let category = entry.category
            if let existingData = budgetDataDict[category] {
                budgetDataDict[category] = BudgetHistoryData(
                    category: category,
                    budgetedAmount: existingData.budgetedAmount,
                    amountSpent: existingData.amountSpent + entry.amount
                )
            } else {
                budgetDataDict[category] = BudgetHistoryData(
                    category: category,
                    budgetedAmount: 0,
                    amountSpent: entry.amount
                )
            }
        }
        
        return Array(budgetDataDict.values)
    }
    
    private func totalBudget() -> Double {
        filteredAndSortedBudgetData.reduce(0) { $0 + $1.budgetedAmount }
    }
    
    private func totalSpent() -> Double {
        filteredAndSortedBudgetData.reduce(0) { $0 + $1.amountSpent }
    }
    
    private func filterAndSortEntries() {
        isLoading = true
        // Add a slight delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isLoading = false
        }
    }
    
    private func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        // Since budgetManager.loadData() is not async and doesn't throw, we just call it
        budgetManager.loadData()
        filterAndSortEntries()
        
        isLoading = false
    }
    
    private func refreshData() async {
        await loadInitialData()
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
        
        NavigationView {
            BudgetHistoryView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
