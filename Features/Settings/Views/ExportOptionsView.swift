//
//  ExportOptionsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI

/// View for configuring and handling data export options
struct ExportOptionsView: View {
    // MARK: - Properties
    @Binding var exportTimePeriod: TimePeriod
    let onExport: () -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - State
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                timePeriodSection
                customDateSection
                exportFormatSection
                exportDetailsSection
            }
            .navigationTitle("Export Options")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        validateAndExport()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Invalid Date Range", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - View Sections
    private var timePeriodSection: some View {
        Section(header: Text("Select Time Period")) {
            Picker("Time Period", selection: $exportTimePeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                }
            }
            .onChange(of: exportTimePeriod) { newValue in
                if case .custom = newValue {
                    resetCustomDates()
                }
            }
        }
    }
    
    private var customDateSection: some View {
        Group {
            if case .custom = exportTimePeriod {
                Section(header: Text("Custom Date Range")) {
                    DatePicker(
                        "Start Date",
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "End Date",
                        selection: $customEndDate,
                        in: customStartDate...,
                        displayedComponents: .date
                    )
                }
            }
        }
    }
    
    private var exportFormatSection: some View {
        Section(header: Text("Export Format")) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(themeManager.primaryColor)
                Text("CSV File")
                    .foregroundColor(.primary)
            }
            
            Text("Data will be exported as a comma-separated values file")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var exportDetailsSection: some View {
        Section(header: Text("Exported Data")) {
            ForEach(exportedFields, id: \.self) { field in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(field)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var exportedFields: [String] {
        [
            "Date",
            "Amount",
            "Category",
            "Notes"
        ]
    }
    
    // MARK: - Helper Methods
    private func validateAndExport() {
        if case .custom = exportTimePeriod {
            guard validateDateRange() else {
                showingAlert = true
                return
            }
            
            exportTimePeriod = .custom(customStartDate, customEndDate)
        }
        
        onExport()
        dismiss()
    }
    
    private func validateDateRange() -> Bool {
        if customEndDate < customStartDate {
            alertMessage = "End date must be after start date"
            return false
        }
        
        if customStartDate > Date() || customEndDate > Date() {
            alertMessage = "Date range cannot be in the future"
            return false
        }
        
        if Calendar.current.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 0 > 365 {
            alertMessage = "Date range cannot exceed one year"
            return false
        }
        
        return true
    }
    
    private func resetCustomDates() {
        let calendar = Calendar.current
        customEndDate = Date()
        customStartDate = calendar.date(byAdding: .month, value: -1, to: customEndDate) ?? Date()
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ExportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ExportOptionsView(
                exportTimePeriod: .constant(.thisMonth),
                onExport: {}
            )
            .environmentObject(ThemeManager.shared)
            .previewDisplayName("Light Mode")
            
            ExportOptionsView(
                exportTimePeriod: .constant(.custom(Date(), Date())),
                onExport: {}
            )
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Custom Date")
        }
    }
}
#endif
