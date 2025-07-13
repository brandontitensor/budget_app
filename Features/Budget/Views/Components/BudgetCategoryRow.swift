//
//  BudgetCategoryRow.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI
import Foundation

/// A reusable row component for displaying budget category information
struct BudgetCategoryRow: View {
    // MARK: - Properties
    let category: String
    let amount: Double
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Private Properties
    private var formattedAmount: String {
        amount.asCurrency
    }
    
    private var progressPercentage: Double {
        // Since we don't have spent amount data in this component,
        // we'll use a placeholder calculation based on amount relative to a common budget
        // This could be enhanced by passing spent amount as a parameter
        let normalizedProgress = min(amount / 1000.0, 1.0) // Assume $1000 as reference
        return max(0.1, normalizedProgress) // Minimum 10% for visual consistency
    }
    
    // MARK: - Body
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Category and Amount Row
                HStack {
                    categoryLabel
                    Spacer()
                    amountLabel
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    progressBar(width: geometry.size.width)
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category) category, budgeted amount \(formattedAmount)")
        .accessibilityHint("Double tap to edit category")
    }
    
    // MARK: - View Components
    private var categoryLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(themeManager.colorForCategory(category))
                .frame(width: 10, height: 10)
            
            Text(category)
                .font(.headline)
                .lineLimit(1)
        }
    }
    
    private var amountLabel: some View {
        Text(formattedAmount)
            .font(.headline)
            .foregroundColor(themeManager.primaryColor)
            .fontWeight(.semibold)
    }
    
    private func progressBar(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(themeManager.primaryColor.opacity(0.2))
                .frame(height: 8)
                .cornerRadius(4)
            
            // Foreground
            Rectangle()
                .fill(themeManager.primaryColor)
                .frame(width: width * progressPercentage)
                .cornerRadius(4)
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetCategoryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Preview
            BudgetCategoryRow(
                category: "Groceries",
                amount: 500.00
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            
            // Long Category Name Preview
            BudgetCategoryRow(
                category: "Very Long Category Name That Should Truncate",
                amount: 1234.56
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            
            // Dark Mode Preview
            BudgetCategoryRow(
                category: "Entertainment",
                amount: 150.00
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            
            // Zero Amount Preview
            BudgetCategoryRow(
                category: "New Category",
                amount: 0.00
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif
