//
//  BudgetCategoryRow.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

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
                .frame(width: width * 0.4) // TODO: Calculate based on spent amount
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
