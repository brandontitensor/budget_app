//
//  ChartLegend.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI

/// A reusable legend component for chart visualizations
struct ChartLegend: View {
    // MARK: - Properties
    let data: BudgetHistoryData
    let color: Color
    
    // MARK: - Computed Properties
    private var formattedPercentage: String {
        data.percentageSpent.formatted(.percent.precision(.fractionLength(1)))
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            // Color Indicator
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 12)
                .cornerRadius(2)
            
            // Category Name
            Text(data.category)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            // Percentage
            Text(formattedPercentage)
                .font(.caption)
                .foregroundColor(data.isOverBudget ? .red : .green)
                .bold()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.category): \(formattedPercentage) of budget spent")
    }
}

/// A group of chart legends with header
struct ChartLegendGroup: View {
    // MARK: - Properties
    let data: [BudgetHistoryData]
    let colors: [Color]
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("Categories")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Legend Items
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                ChartLegend(
                    data: item,
                    color: colors[index % colors.count]
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chart legend showing spending percentages for each category")
    }
    
    // MARK: - Computed Properties
    private var totalSpent: Double {
        data.reduce(0) { $0 + $1.amountSpent }
    }
    
    private var totalBudget: Double {
        data.reduce(0) { $0 + $1.budgetedAmount }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ChartLegend_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Single Legend Preview
            ChartLegend(
                data: BudgetHistoryData(
                    category: "Groceries",
                    budgetedAmount: 500,
                    amountSpent: 450
                ),
                color: .blue
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Single Legend")
            
            // Legend Group Preview
            ChartLegendGroup(
                data: [
                    BudgetHistoryData(
                        category: "Groceries",
                        budgetedAmount: 500,
                        amountSpent: 450
                    ),
                    BudgetHistoryData(
                        category: "Entertainment",
                        budgetedAmount: 200,
                        amountSpent: 250
                    ),
                    BudgetHistoryData(
                        category: "Transport",
                        budgetedAmount: 300,
                        amountSpent: 280
                    )
                ],
                colors: [.blue, .green, .orange]
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Legend Group")
            
            // Dark Mode Preview
            ChartLegendGroup(
                data: [
                    BudgetHistoryData(
                        category: "Groceries",
                        budgetedAmount: 500,
                        amountSpent: 450
                    ),
                    BudgetHistoryData(
                        category: "Entertainment",
                        budgetedAmount: 200,
                        amountSpent: 250
                    )
                ],
                colors: [.blue, .green]
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // Long Category Names
            ChartLegendGroup(
                data: [
                    BudgetHistoryData(
                        category: "Very Long Category Name That Should Truncate",
                        budgetedAmount: 500,
                        amountSpent: 450
                    ),
                    BudgetHistoryData(
                        category: "Another Long Category Name Here",
                        budgetedAmount: 200,
                        amountSpent: 250
                    )
                ],
                colors: [.blue, .green]
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Long Categories")
        }
    }
}
#endif
