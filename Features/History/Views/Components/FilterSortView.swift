//
//  FilterSortView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import Foundation

/// A view for configuring filtering and sorting options
struct FilterSortView: View {
    // MARK: - Properties
    @Binding var selectedTimePeriod: TimePeriod
    @Binding var sortOption: BudgetSortOption
    @Binding var sortAscending: Bool
    let onDismiss: () -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                timePeriodSection
                sortingSection
                if case .custom = selectedTimePeriod {
                    customDateSection
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarItems(
                trailing: Button("Done") {
                    onDismiss()
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - View Components
    private var timePeriodSection: some View {
        Section(header: Text("Time Period")) {
            Picker("Time Period", selection: $selectedTimePeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                }
            }
            .accessibilityLabel("Select time period")
        }
    }
    
    private var sortingSection: some View {
        Section(header: Text("Sort By")) {
            Picker("Sort by", selection: $sortOption) {
                ForEach(BudgetSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue)
                        .tag(option)
                }
            }
            .accessibilityLabel("Select sort criteria")
            
            Toggle("Ascending Order", isOn: $sortAscending)
                .accessibilityHint("Toggle between ascending and descending order")
        }
    }
    
    private var customDateSection: some View {
        Section(header: Text("Custom Date Range")) {
            DatePicker(
                "Start Date",
                selection: $customStartDate,
                in: ...customEndDate,
                displayedComponents: .date
            )
            .onChange(of: customStartDate) { newValue in
                updateCustomDateRange()
            }
            
            DatePicker(
                "End Date",
                selection: $customEndDate,
                in: customStartDate...,
                displayedComponents: .date
            )
            .onChange(of: customEndDate) { newValue in
                updateCustomDateRange()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateCustomDateRange() {
        selectedTimePeriod = .custom(customStartDate, customEndDate)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct FilterSortView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default State
            FilterSortView(
                selectedTimePeriod: .constant(.thisMonth),
                sortOption: .constant(.date),
                sortAscending: .constant(true),
                onDismiss: {}
            )
            .previewDisplayName("Default State")
            
            // Custom Date Range
            FilterSortView(
                selectedTimePeriod: .constant(.custom(Date(), Date())),
                sortOption: .constant(.amount),
                sortAscending: .constant(false),
                onDismiss: {}
            )
            .previewDisplayName("Custom Date Range")
            
            // Dark Mode
            FilterSortView(
                selectedTimePeriod: .constant(.thisMonth),
                sortOption: .constant(.category),
                sortAscending: .constant(true),
                onDismiss: {}
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
