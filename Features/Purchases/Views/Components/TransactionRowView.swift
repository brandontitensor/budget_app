//
//  TransactionRowView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

/// A view component for displaying transaction entries in a list
struct TransactionRowView: View {
    // MARK: - Properties
    let entry: BudgetEntry
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Computed Properties
    private var formattedAmount: String {
        entry.amount.asCurrency
    }
    
    private var iconLetter: String {
        String(entry.category.prefix(1).uppercased())
    }
    
    private var formattedDate: String {
        entry.date.formatted(date: .abbreviated, time: .omitted)
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            categoryBadge
            
            VStack(alignment: .leading, spacing: 4) {
                categoryAndAmount
                dateAndNote
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createAccessibilityLabel())
        .accessibilityHint("Double tap to edit transaction")
    }
    
    // MARK: - View Components
    private var categoryBadge: some View {
        ZStack {
            Circle()
                .fill(themeManager.primaryColor.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Text(iconLetter)
                .font(.headline)
                .foregroundColor(themeManager.primaryColor)
        }
        .accessibilityHidden(true)
    }
    
    private var categoryAndAmount: some View {
        HStack {
            Text(entry.category)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Text(formattedAmount)
                .font(.headline)
                .foregroundColor(themeManager.primaryColor)
        }
    }
    
    private var dateAndNote: some View {
        HStack {
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let note = entry.note {
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
        var label = "\(entry.category) transaction for \(formattedAmount) on \(formattedDate)"
        if let note = entry.note {
            label += ". Note: \(note)"
        }
        return label
    }
}

// MARK: - Preview Provider
#if DEBUG
struct TransactionRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Entry
            TransactionRowView(
                entry: BudgetEntry.mock(
                    amount: 42.50,
                    category: "Groceries",
                    date: Date(),
                    note: "Weekly shopping"
                )
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Standard Entry")
            
            // Entry without Note
            TransactionRowView(
                entry: BudgetEntry.mock(
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
            TransactionRowView(
                entry: BudgetEntry.mock(
                    amount: 150.00,
                    category: "Very Long Category Name That Should Truncate",
                    date: Date(),
                    note: "This is a very long note that should be truncated after a certain length"
                )
            )
            .environmentObject(ThemeManager.shared)
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Long Content")
            
            // Dark Mode
            TransactionRowView(
                entry: BudgetEntry.mock(
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
            
            // List Context
            List {
                TransactionRowView(
                    entry: BudgetEntry.mock(
                        amount: 42.50,
                        category: "Groceries",
                        date: Date(),
                        note: "Weekly shopping"
                    )
                )
                TransactionRowView(
                    entry: BudgetEntry.mock(
                        amount: 99.99,
                        category: "Entertainment",
                        date: Date()
                    )
                )
            }
            .environmentObject(ThemeManager.shared)
            .previewDisplayName("List Context")
        }
    }
}
#endif
