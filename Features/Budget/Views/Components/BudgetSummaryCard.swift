//
//  BudgetSummaryCard.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

/// A reusable card component for displaying budget summary information
struct BudgetSummaryCard: View {
    // MARK: - Properties
    let budgeted: Double
    let spent: Double
    let primaryColor: Color
    
    // MARK: - Computed Properties
    private var progress: Double {
        guard budgeted > 0 else { return 0 }
        return min(spent / budgeted, 1.0)
    }
    
    private var percentage: Double {
        progress * 100
    }
    
    private var isOverBudget: Bool {
        spent > budgeted
    }
    
    private var formattedBudgeted: String {
        budgeted.asCurrency
    }
    
    private var formattedSpent: String {
        spent.asCurrency
    }
    
    private var statusColor: Color {
        isOverBudget ? .red : .green
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            summarySection
            progressBar
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    // MARK: - View Components
    private var summarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                budgetRow
                spentRow
            }
            Spacer()
            percentageCircle
        }
    }
    
    private var budgetRow: some View {
        HStack {
            Text("Budget")
                .foregroundColor(.secondary)
            Text(formattedBudgeted)
                .foregroundColor(primaryColor)
                .fontWeight(.semibold)
        }
    }
    
    private var spentRow: some View {
        HStack {
            Text("Spent")
                .foregroundColor(.secondary)
            Text(formattedSpent)
                .foregroundColor(statusColor)
                .fontWeight(.semibold)
        }
    }
    
    private var percentageCircle: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOverBudget ? .red : primaryColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            // Percentage Text
            Text("\(Int(percentage))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isOverBudget ? .red : primaryColor)
        }
        .frame(width: 60, height: 60)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Bar
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                // Progress Bar
                Rectangle()
                    .fill(isOverBudget ? .red : primaryColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 8)
        .cornerRadius(4)
        .animation(.easeInOut, value: progress)
    }
    
    // MARK: - Helper Methods
    private func createAccessibilityLabel() -> String {
        let status = isOverBudget ? "Over budget" : "Under budget"
        let percentageText = "\(Int(percentage))% of budget used"
        return "Budget summary: Budgeted \(formattedBudgeted), Spent \(formattedSpent). \(status). \(percentageText)"
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Under Budget
            BudgetSummaryCard(
                budgeted: 1000,
                spent: 750,
                primaryColor: .blue
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Under Budget")
            
            // Over Budget
            BudgetSummaryCard(
                budgeted: 1000,
                spent: 1200,
                primaryColor: .blue
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Over Budget")
            
            // Zero Budget
            BudgetSummaryCard(
                budgeted: 0,
                spent: 0,
                primaryColor: .blue
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Zero Budget")
            
            // Dark Mode
            BudgetSummaryCard(
                budgeted: 1000,
                spent: 800,
                primaryColor: .blue
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
