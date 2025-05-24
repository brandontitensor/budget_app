//
//  TransactionRow.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import Foundation

/// A reusable row component for displaying transaction information
struct TransactionRow: View {
    // MARK: - Properties
    let transaction: BudgetEntry
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Computed Properties
    private var formattedDate: String {
        transaction.date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var formattedAmount: String {
        transaction.amount.asCurrency
    }
    
    // MARK: - Body
    var body: some View {
        HStack {
            categoryIcon
            
            VStack(alignment: .leading, spacing: 4) {
                categoryAndAmountRow
                
                if let note = transaction.note {
                    noteRow(note: note)
                }
                
                dateRow
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel())
    }
    
    // MARK: - View Components
    private var categoryIcon: some View {
        Circle()
            .fill(themeManager.primaryColor.opacity(0.1))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(transaction.category.prefix(1)))
                    .font(.headline)
                    .foregroundColor(themeManager.primaryColor)
            )
    }
    
    private var categoryAndAmountRow: some View {
        HStack {
            Text(transaction.category)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryColor)
        }
    }
    
    private func noteRow(note: String) -> some View {
        Text(note)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
    
    private var dateRow: some View {
        HStack {
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let note = transaction.note {
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createAccessibilityLabel() -> String {
        var label = "\(transaction.category) transaction for \(formattedAmount) on \(formattedDate)"
        if let note = transaction.note {
            label += ". Note: \(note)"
        }
        return label
    }
}

// MARK: - Preview Provider
#if DEBUG
struct TransactionRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Transaction
            TransactionRow(
                transaction: BudgetEntry.mock(
                    amount: 42.50,
                    category: "Groceries",
                    date: Date(),
                    note: "Weekly shopping"
                )
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Standard Transaction")
            
            // No Note
            TransactionRow(
                transaction: BudgetEntry.mock(
                    amount: 99.99,
                    category: "Entertainment",
                    date: Date()
                )
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("No Note")
            
            // Long Category and Note
            TransactionRow(
                transaction: BudgetEntry.mock(
                    amount: 150.00,
                    category: "Very Long Category Name That Should Truncate",
                    date: Date(),
                    note: "This is a very long note that should be truncated after a certain length to prevent it from taking up too much space"
                )
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Long Content")
            
            // Dark Mode
            TransactionRow(
                transaction: BudgetEntry.mock(
                    amount: 75.00,
                    category: "Transportation",
                    date: Date(),
                    note: "Bus fare"
                )
            )
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
