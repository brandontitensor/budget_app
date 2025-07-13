//
//  ImportOptionsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for handling data import options and configuration with enhanced error handling and validation
struct ImportOptionsView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    // MARK: - Bindings
    @Binding var showingImportBudgetPicker: Bool
    @Binding var showingImportPurchasePicker: Bool
    
    // MARK: - State
    @State private var showingBudgetFormat = false
    @State private var showingPurchaseFormat = false
    @State private var selectedImportType: ImportType?
    @State private var showingAdvancedOptions = false
    @State private var importConfiguration = CSVImport.ImportConfiguration.default
    @State private var currentError: AppError?
    @State private var isValidatingFile = false
    @State private var showingImportGuide = false
    @State private var showingTemplateDownload = false
    @State private var recentImports: [RecentImport] = []
    
    // MARK: - Types
    public enum ImportType: CaseIterable {
        case budget
        case purchases
        case autoDetect
        
        var displayName: String {
            switch self {
            case .budget: return "Budget Data"
            case .purchases: return "Purchase Data"
            case .autoDetect: return "Auto-Detect"
            }
        }
        
        var description: String {
            switch self {
            case .budget: return "Import your budget categories and amounts"
            case .purchases: return "Import your transaction history"
            case .autoDetect: return "Automatically detect the file type"
            }
        }
        
        var icon: String {
            switch self {
            case .budget: return "chart.pie.fill"
            case .purchases: return "cart.fill"
            case .autoDetect: return "doc.text.magnifyingglass"
            }
        }
        
        var expectedFormat: String {
            switch self {
            case .budget: return "Year,Month,Category,Amount,IsHistorical"
            case .purchases: return "Date,Amount,Category,Note"
            case .autoDetect: return "CSV file with proper headers"
            }
        }
        
        var sampleData: String {
            switch self {
            case .budget:
                return """
                Year,Month,Category,Amount,IsHistorical
                2024,7,Groceries,500.00,false
                2024,7,Rent,1200.00,false
                2024,7,Transportation,200.00,false
                """
            case .purchases:
                return """
                Date,Amount,Category,Note
                2024-07-01,45.67,Groceries,Weekly shopping
                2024-07-02,15.00,Transportation,Bus fare
                2024-07-03,89.99,Entertainment,Movie tickets
                """
            case .autoDetect:
                return "The app will automatically detect whether your file contains budget or purchase data based on the column headers."
            }
        }
    }
    
    public struct RecentImport: Identifiable {
        public let id = UUID()
        let fileName: String
        let type: ImportType
        let recordCount: Int
        let date: Date
        let success: Bool
        
        var statusIcon: String {
            success ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        
        var statusColor: Color {
            success ? .green : .red
        }
        
        var formattedDate: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                if recentImports.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Help") {
                        showingImportGuide = true
                    }
                }
            }
            .onAppear {
                loadRecentImports()
            }
            .sheet(isPresented: $showingAdvancedOptions) {
                advancedOptionsSheet
            }
            .sheet(isPresented: $showingImportGuide) {
                importGuideSheet
            }
            .sheet(isPresented: $showingTemplateDownload) {
                templateDownloadSheet
            }
        }
    }
    
    // MARK: - Main Views
    
    private var mainContentView: some View {
        List {
            quickStartSection
            formatSection
            importOptionsSection
            if showingAdvancedOptions {
                advancedOptionsSection
            }
            recentImportsSection
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 64))
                .foregroundColor(themeManager.primaryColor.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Import Your Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Import your budget categories and transaction history from CSV files.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                CommonComponents.PrimaryButton(
                    title: "Import Purchases",
                    action: {
                        selectedImportType = .purchases
                        handleImport(.purchases)
                    }
                )
                
                CommonComponents.SecondaryButton(
                    title: "Import Budget",
                    action: {
                        selectedImportType = .budget
                        handleImport(.budget)
                    }
                )
                
                Button("Download Template") {
                    showingTemplateDownload = true
                }
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.semanticColors.backgroundPrimary.opacity(0.8))
    }
    
    // MARK: - View Sections
    
    private var quickStartSection: some View {
        Section(
            header: sectionHeader("Quick Start", systemImage: "bolt.fill"),
            footer: Text("Choose what type of data you want to import.")
        ) {
            ImportOptionButton(
                type: .autoDetect,
                isSelected: selectedImportType == .autoDetect,
                onTap: {
                    selectedImportType = .autoDetect
                    handleImport(.autoDetect)
                }
            )
            .environmentObject(themeManager)
            
            ImportOptionButton(
                type: .purchases,
                isSelected: selectedImportType == .purchases,
                onTap: {
                    selectedImportType = .purchases
                    handleImport(.purchases)
                }
            )
            .environmentObject(themeManager)
            
            ImportOptionButton(
                type: .budget,
                isSelected: selectedImportType == .budget,
                onTap: {
                    selectedImportType = .budget
                    handleImport(.budget)
                }
            )
            .environmentObject(themeManager)
        }
    }
    
    private var formatSection: some View {
        Section(
            header: sectionHeader("CSV Format Information", systemImage: "doc.text"),
            footer: Text("Your CSV file must match one of these formats exactly.")
        ) {
            FormatInfoRow(
                title: "Budget Data Format",
                isExpanded: $showingBudgetFormat,
                type: .budget
            )
            .environmentObject(themeManager)
            
            FormatInfoRow(
                title: "Purchase Data Format",
                isExpanded: $showingPurchaseFormat,
                type: .purchases
            )
            .environmentObject(themeManager)
        }
    }
    
    private var importOptionsSection: some View {
        Section(
            header: sectionHeader("Import Options", systemImage: "square.and.arrow.down"),
            footer: Text("Configure how your data should be imported.")
        ) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Validate Duplicates")
                
                Spacer()
                
                Toggle("", isOn: createBinding(for: \.validateDuplicates))
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Skip Invalid Rows")
                
                Spacer()
                
                Toggle("", isOn: createBinding(for: \.skipInvalidRows))
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Strict Validation")
                
                Spacer()
                
                Toggle("", isOn: createBinding(for: \.strictValidation))
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var advancedOptionsSection: some View {
        Section(
            header: sectionHeader("Advanced Options", systemImage: "gear"),
            footer: Text("Additional configuration options for import processing.")
        ) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Import Guide")
                
                Spacer()
                
                Button("View") {
                    showingImportGuide = true
                }
                .font(.caption)
                .foregroundColor(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Template Files")
                
                Spacer()
                
                Button("Download") {
                    showingTemplateDownload = true
                }
                .font(.caption)
                .foregroundColor(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var recentImportsSection: some View {
        Section(
            header: sectionHeader("Recent Imports", systemImage: "clock"),
            footer: Text("Your recent import attempts and their results.")
        ) {
            ForEach(recentImports) { importItem in
                RecentImportRow(import: importItem) {
                    // Handle re-import
                    selectedImportType = importItem.type
                    handleImport(importItem.type)
                }
                .environmentObject(themeManager)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(themeManager.primaryColor)
                .font(.caption)
            
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sheet Views
    
    private var advancedOptionsSheet: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Import Configuration"),
                    footer: Text("Configure detailed import settings and validation rules.")
                ) {
                    Picker("Import Type", selection: createBinding(for: \.importType)) {
                        Text("Auto-Detect").tag(CSVImport.ImportType.autoDetect)
                        Text("Budget Entries").tag(CSVImport.ImportType.budgetEntries)
                        Text("Monthly Budgets").tag(CSVImport.ImportType.monthlyBudgets)
                    }
                    
                    Stepper(
                        "Max File Size: \(formatFileSize(importConfiguration.maxFileSize))",
                        value: createBinding(for: \.maxFileSize),
                        in: (1024 * 1024)...(50 * 1024 * 1024),
                        step: 1024 * 1024
                    )
                    
                    Stepper(
                        "Max Rows: \(importConfiguration.maxRowCount)",
                        value: createBinding(for: \.maxRowCount),
                        in: 100...50000,
                        step: 100
                    )
                }
                
                Section(
                    header: Text("Validation Settings"),
                    footer: Text("Control how strictly data is validated during import.")
                ) {
                    Toggle("Validate Duplicates", isOn: createBinding(for: \.validateDuplicates))
                    Toggle("Skip Invalid Rows", isOn: createBinding(for: \.skipInvalidRows))
                    Toggle("Strict Validation", isOn: createBinding(for: \.strictValidation))
                }
            }
            .navigationTitle("Advanced Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAdvancedOptions = false
                    }
                }
            }
        }
    }
    
    private var importGuideSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step-by-step guide content
                    Text("Import Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Follow these steps to successfully import your data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Add more guide content here
                }
                .padding()
            }
            .navigationTitle("Import Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingImportGuide = false
                    }
                }
            }
        }
    }
    
    private var templateDownloadSheet: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Available Templates"),
                    footer: Text("Download these templates to get started with the correct format.")
                ) {
                    ForEach(ImportType.allCases.filter { $0 != .autoDetect }, id: \.displayName) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(themeManager.primaryColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(.headline)
                                
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Download") {
                                downloadTemplate(for: type)
                            }
                            .font(.caption)
                            .foregroundColor(themeManager.primaryColor)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingTemplateDownload = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createBinding<T>(for keyPath: WritableKeyPath<CSVImport.ImportConfiguration, T>) -> Binding<T> {
        Binding(
            get: { importConfiguration[keyPath: keyPath] },
            set: { newValue in
                var config = importConfiguration
                config[keyPath: keyPath] = newValue
                importConfiguration = config
            }
        )
    }
    
    private func handleImport(_ type: ImportType) {
        selectedImportType = type
        
        switch type {
        case .budget:
            triggerBudgetImport()
        case .purchases:
            triggerPurchaseImport()
        case .autoDetect:
            triggerAutoDetectImport()
        }
    }
    
    private func triggerBudgetImport() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingImportBudgetPicker = true
        }
    }
    
    private func triggerPurchaseImport() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingImportPurchasePicker = true
        }
    }
    
    private func triggerAutoDetectImport() {
        // For auto-detect, we'll show the purchase picker first
        // as it's more commonly used
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingImportPurchasePicker = true
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func downloadTemplate(for type: ImportType) {
        // Implementation for template download
        // This would generate and share a template file
        print("Downloading template for \(type.displayName)")
    }
    
    private func loadRecentImports() {
        // This would typically load from UserDefaults or Core Data
        // For now, we'll use mock data
        recentImports = [
            RecentImport(
                fileName: "transactions_2024.csv",
                type: .purchases,
                recordCount: 245,
                date: Date().addingTimeInterval(-86400),
                success: true
            ),
            RecentImport(
                fileName: "budget_jan_2024.csv",
                type: .budget,
                recordCount: 12,
                date: Date().addingTimeInterval(-172800),
                success: true
            ),
            RecentImport(
                fileName: "expenses.csv",
                type: .purchases,
                recordCount: 0,
                date: Date().addingTimeInterval(-259200),
                success: false
            )
        ]
    }
}

// MARK: - Supporting Views

struct ImportOptionButton: View {
    let type: ImportOptionsView.ImportType
    let isSelected: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : themeManager.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.primaryColor)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? themeManager.primaryColor : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct FormatInfoRow: View {
    let title: String
    @Binding var isExpanded: Bool
    let type: ImportOptionsView.ImportType
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expected Format:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(type.expectedFormat)
                        .font(.caption)
                        .fontFamily(.monospaced)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    
                    if type != .autoDetect {
                        Text("Sample Data:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(type.sampleData)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    } else {
                        Text(type.sampleData)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

struct RecentImportRow: View {
    let import: ImportOptionsView.RecentImport
    let onRetry: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: import.statusIcon)
                .foregroundColor(import.statusColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(import.fileName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(import.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if import.success {
                        Text("\(import.recordCount) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(import.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !import.success {
                Button("Retry") {
                    onRetry()
                }
                .font(.caption)
                .foregroundColor(themeManager.primaryColor)
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview Support

#if DEBUG
struct ImportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ImportOptionsView(
            showingImportBudgetPicker: .constant(false),
            showingImportPurchasePicker: .constant(false)
        )
        .environmentObject(ThemeManager.shared)
        .environmentObject(BudgetManager.shared)
        .environmentObject(SettingsManager.shared)
        .environmentObject(ErrorHandler.shared)
    }
}
#endif
