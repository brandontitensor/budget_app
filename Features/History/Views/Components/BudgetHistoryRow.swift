//
//  BudgetHistoryRow.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

/// A view component for displaying budget history entries
struct BudgetHistoryRow: View {
    // MARK: - Properties
    let data: BudgetHistoryData
    let color: Color
    
    // MARK: - Computed Properties
    private var formattedBudget: String {
        data.budgetedAmount.asCurrency
    }
    
    private var formattedSpent: String {
        data.amountSpent.asCurrency
    }
    
    private var formattedRemaining: String {
        data.remainingAmount.asCurrency
    }
    
    private var formattedPercentage: String {
        data.percentageSpent.formatted(.percent.precision(.fractionLength(1)))
    }
    
    private var progressWidth: CGFloat {
        CGFloat(min(data.percentageSpent / 100.0, 1.0))
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryAndAmounts
            progressBar
            footerInfo
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    // MARK: - View Components
    private var categoryAndAmounts: some View {
        HStack {
            Text(data.category)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing) {
                Text("Budget: \(formattedBudget)")
                    .font(.subheadline)
                Text("Spent: \(formattedSpent)")
                    .font(.subheadline)
                    .foregroundColor(data.isOverBudget ? .red : .green)
            }
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(color.opacity(0.2))
                    .frame(height: 8)
                
                // Progress
                Rectangle()
                    .fill(data.isOverBudget ? .red : color)
                    .frame(
                        width: geometry.size.width * progressWidth,
                        height: 8
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
    
    private var footerInfo: some View {
        HStack {
            Text("Remaining: \(formattedRemaining)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(formattedPercentage) used")
                .font(.caption)
                .foregroundColor(data.isOverBudget ? .red : .green)
        }
    }
    
    // MARK: - Helper Methods
    private func createAccessibilityLabel() -> String {
        let status = data.isOverBudget ? "Over budget" : "Under budget"
        return """
        \(data.category) category. \
        Budgeted: \(formattedBudget), \
        Spent: \(formattedSpent), \
        Remaining: \(formattedRemaining). \
        \(formattedPercentage) of budget used. \
        Status: \(status)
        """
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetHistoryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Under Budget
            BudgetHistoryRow(
                data: BudgetHistoryData(
                    category: "Groceries",
                    budgetedAmount: 500,
                    amountSpent: 350
                ),
                color: .blue
            )
            .padding()
            .previewDisplayName("Under Budget")
            
            // Over Budget
            BudgetHistoryRow(
                data: BudgetHistoryData(
                    category: "Entertainment",
                    budgetedAmount: 200,
                    amountSpent: 250
                ),
                color: .blue
            )
            .padding()
            .previewDisplayName("Over Budget")
            
            // Zero Budget
            BudgetHistoryRow(
                data: BudgetHistoryData(
                    category: "New Category",
                    budgetedAmount: 0,
                    amountSpent: 0
                ),
                color: .blue
            )
            .padding()
            .previewDisplayName("Zero Budget")
            
            // Long Category Name
            BudgetHistoryRow(
                data: BudgetHistoryData(
                    category: "Very Long Category Name That Should be Handled Properly",
                    budgetedAmount: 1000,
                    amountSpent: 750
                ),
                color: .blue
            )
            .padding()
            .previewDisplayName("Long Category Name")
            
            // Dark Mode
            BudgetHistoryRow(
                data: BudgetHistoryData(
                    category: "Groceries",
                    budgetedAmount: 500,
                    amountSpent: 350
                ),
                color: .blue
            )
            .preferredColorScheme(.dark)
            .padding()
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
