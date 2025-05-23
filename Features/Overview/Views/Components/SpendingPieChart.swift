//
//  SpendingPieChart.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import Charts

/// A view component for displaying spending data in a pie chart format
struct SpendingPieChart: View {
    // MARK: - Properties
    let spendingData: [SpendingData]
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - State
    @State private var selectedSlice: SpendingData?
    @State private var highlightedValue: Double?
    
    // MARK: - Computed Properties
    private var totalSpending: Double {
        spendingData.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleSection
            
            if spendingData.isEmpty {
                emptyStateView
            } else {
                chartSection
                legendSection
            }
        }
    }
    
    // MARK: - View Components
    private var titleSection: some View {
        Text("Spending by Category")
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No spending data available")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .contentShape(Rectangle())
    }
    
    private var chartSection: some View {
        VStack {
            Chart {
                ForEach(spendingData) { data in
                    SectorMark(
                        angle: .value("Amount", data.amount),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(data.color)
                    .opacity(selectedSlice == nil || selectedSlice == data ? 1.0 : 0.3)
                }
            }
            .frame(height: 200)
            .chartBackground { proxy in
                Color.clear
                    .onTapGesture { location in
                        if let slice = findSlice(at: location, proxy: proxy) {
                            withAnimation {
                                selectedSlice = selectedSlice == slice ? nil : slice
                            }
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending pie chart")
        .accessibilityValue(createChartAccessibilityValue())
    }
    
    private var legendSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            ForEach(spendingData) { data in
                legendItem(for: data)
            }
        }
        .padding(.horizontal)
    }
    
    private func legendItem(for data: SpendingData) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(data.color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(data.category)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(data.amount.asCurrency)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(data.percentage.formatted(.percent.precision(.fractionLength(1))))
                .font(.caption)
                .bold()
                .foregroundColor(themeManager.primaryColor)
        }
        .padding(.vertical, 4)
        .opacity(selectedSlice == nil || selectedSlice == data ? 1.0 : 0.3)
        .onTapGesture {
            withAnimation {
                selectedSlice = selectedSlice == data ? nil : data
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.category): \(data.amount.asCurrency), \(data.percentage.formatted(.percent.precision(.fractionLength(1)))) of total spending")
    }
    
    // MARK: - Helper Methods
    private func findSlice(at location: CGPoint, proxy: ChartProxy) -> SpendingData? {
        // Implementation for finding the clicked slice
        // This would involve calculating angles and matching to data
        return nil // Placeholder
    }
    
    private func createChartAccessibilityValue() -> String {
        let items = spendingData.map { data in
            "\(data.category): \(data.amount.asCurrency) (\(data.percentage.formatted(.percent.precision(.fractionLength(1)))))"
        }
        return "Total spending: \(totalSpending.asCurrency). Categories: " + items.joined(separator: ", ")
    }
}

// MARK: - Preview Provider
#if DEBUG
struct SpendingPieChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With Data
            SpendingPieChart(
                spendingData: [
                    SpendingData(category: "Groceries", amount: 500, percentage: 50, color: .blue),
                    SpendingData(category: "Entertainment", amount: 300, percentage: 30, color: .green),
                    SpendingData(category: "Transport", amount: 200, percentage: 20, color: .orange)
                ]
            )
            .environmentObject(ThemeManager.shared)
            .padding()
            .previewDisplayName("With Data")
            
            // Empty State
            SpendingPieChart(spendingData: [])
                .environmentObject(ThemeManager.shared)
                .padding()
                .previewDisplayName("Empty State")
            
            // Dark Mode
            SpendingPieChart(
                spendingData: [
                    SpendingData(category: "Groceries", amount: 500, percentage: 50, color: .blue),
                    SpendingData(category: "Entertainment", amount: 300, percentage: 30, color: .green)
                ]
            )
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
            .padding()
            .previewDisplayName("Dark Mode")
            
            // Many Categories
            SpendingPieChart(
                spendingData: (1...8).map { index in
                    SpendingData(
                        category: "Category \(index)",
                        amount: Double(100 * index),
                        percentage: Double(index) * 10,
                        color: .blue
                    )
                }
            )
            .environmentObject(ThemeManager.shared)
            .padding()
            .previewDisplayName("Many Categories")
        }
    }
}
#endif
