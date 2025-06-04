//
//  ExportOptionsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved architecture, and better user experience
//

import SwiftUI

/// View for configuring and handling data export options with enhanced error handling and validation
struct ExportOptionsView: View {
    // MARK: - Properties
    @Binding var exportTimePeriod: TimePeriod
    let onExport: () -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    // MARK: - State
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Invalid Selection"
    @State private var selectedExportType: CSVExport.ExportType = .budgetEntries
    @State private var includeCurrency = true
    @State private var includeHeaders = true
    @State private var decimalPlaces = 2
    @State private var isValidating = false
    @State private var currentError: AppError?
    @State private var showingPreview = false
    @State private var previewData: ExportPreview?
    @State private var exportConfiguration: CSVExport.ExportConfiguration?
    
    // MARK: - Types
    private struct ExportPreview {
        let recordCount: Int
        let estimatedSize: String
        let dateRange: String
        let categories: [String]
        let totalAmount: Double
        let sampleData: String
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                if isValidating {
                    loadingView
                } else {
                    mainContent
                }
            }
        }
        .navigationTitle("Export Options")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                exportButton
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            ExportPreviewView(
                preview: previewData,
                configuration: exportConfiguration,
                onConfirm: {
                    showingPreview = false
                    performExport()
                },
                onCancel: {
                    showingPreview = false
                }
            )
            .environmentObject(themeManager)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .errorAlert()
        .onAppear {
            setupInitialValues()
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        Form {
            if let error = currentError {
                InlineErrorView(
                    error: error,
                    onDismiss: {
                        currentError = nil
                    },
                    onRetry: {
                        validateAndPrepareExport()
                    }
                )
                .listRowBackground(Color.clear)
            }
            
            exportTypeSection
            timePeriodSection
            customDateSection
            formatOptionsSection
            previewSection
            exportDetailsSection
        }
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text("Preparing Export...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Analyzing your data and preparing the export configuration.")
                .font(.caption)
                .foregroundColor(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.semanticColors.backgroundPrimary.opacity(0.8))
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button("Export") {
            validateAndPrepareExport()
        }
        .fontWeight(.semibold)
        .disabled(isValidating || !isConfigurationValid)
    }
    
    // MARK: - View Sections
    
    private var exportTypeSection: some View {
        Section(
            header: sectionHeader("Export Type", systemImage: "doc.text.fill"),
            footer: Text("Choose what type of data to export.")
        ) {
            ForEach(CSVExport.ExportType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: iconForExportType(type))
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayNameForExportType(type))
                            .font(.subheadline)
                        
                        Text(descriptionForExportType(type))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if selectedExportType == type {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeManager.primaryColor)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedExportType = type
                        updatePreviewIfNeeded()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var timePeriodSection: some View {
        Section(
            header: sectionHeader("Time Period", systemImage: "calendar"),
            footer: timePeriodFooter
        ) {
            ForEach(TimePeriod.commonPeriods, id: \.self) { period in
                HStack {
                    Image(systemName: period.systemImageName)
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(period.displayName)
                            .font(.subheadline)
                        
                        Text(period.formattedDateRange())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if exportTimePeriod == period {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeManager.primaryColor)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        exportTimePeriod = period
                        updatePreviewIfNeeded()
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Custom period option
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Range")
                        .font(.subheadline)
                    
                    if case .custom = exportTimePeriod {
                        Text(exportTimePeriod.formattedDateRange())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select custom date range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if case .custom = exportTimePeriod {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.primaryColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    exportTimePeriod = .custom(customStartDate, customEndDate)
                    updatePreviewIfNeeded()
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var customDateSection: some View {
        Group {
            if case .custom = exportTimePeriod {
                Section(
                    header: sectionHeader("Custom Date Range", systemImage: "calendar.badge.exclamationmark"),
                    footer: Text("Select the exact date range for your export.")
                ) {
                    DatePicker(
                        "Start Date",
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )
                    .onChange(of: customStartDate) { oldValue, newValue in
                        updateCustomDateRange()
                    }
                    
                    DatePicker(
                        "End Date",
                        selection: $customEndDate,
                        in: customStartDate...,
                        displayedComponents: .date
                    )
                    .onChange(of: customEndDate) { oldValue, newValue in
                        updateCustomDateRange()
                    }
                    
                    // Date range summary
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(themeManager.primaryColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(daysBetween(customStartDate, customEndDate)) days")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
    }
    
    private var formatOptionsSection: some View {
        Section(
            header: sectionHeader("Format Options", systemImage: "gearshape"),
            footer: Text("Customize how your data will be formatted in the export.")
        ) {
            Toggle(isOn: $includeCurrency) {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Currency Symbol")
                            .font(.subheadline)
                        
                        Text("Add \(settingsManager.defaultCurrency) symbol to amounts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(themeManager.primaryColor)
            .onChange(of: includeCurrency) { _, _ in
                updatePreviewIfNeeded()
            }
            
            Toggle(isOn: $includeHeaders) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Column Headers")
                            .font(.subheadline)
                        
                        Text("Add descriptive headers to columns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(themeManager.primaryColor)
            .onChange(of: includeHeaders) { _, _ in
                updatePreviewIfNeeded()
            }
            
            Stepper(value: $decimalPlaces, in: 0...4) {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Decimal Places")
                            .font(.subheadline)
                        
                        Text("\(decimalPlaces) decimal places")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: decimalPlaces) { _, _ in
                updatePreviewIfNeeded()
            }
        }
    }
    
    private var previewSection: some View {
        Section(
            header: sectionHeader("Export Preview", systemImage: "eye"),
            footer: Text("Preview your export before generating the file.")
        ) {
            if let preview = previewData {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(preview.recordCount)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryColor)
                            Text("Records")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(preview.estimatedSize)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryColor)
                            Text("Estimated Size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if preview.recordCount > 0 {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Date Range:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(preview.dateRange)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Total Amount:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(NumberFormatter.formatCurrency(preview.totalAmount))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.primaryColor)
                            }
                            
                            if !preview.categories.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Categories (\(preview.categories.count)):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(preview.categories.prefix(5).joined(separator: ", "))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    
                                    if preview.categories.count > 5 {
                                        Text("and \(preview.categories.count - 5) more...")
                                            .font(.caption2)
                                            .foregroundColor(.tertiary)
                                    }
                                }
                            }
                        }
                        
                        Button("View Full Preview") {
                            showingPreview = true
                        }
                        .font(.caption)
                        .foregroundColor(themeManager.primaryColor)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            Text("No Data Found")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("No data available for the selected criteria. Try adjusting your time period or export type.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var exportDetailsSection: some View {
        Section(
            header: sectionHeader("Export Details", systemImage: "info.circle"),
            footer: Text("Your data will be exported as a CSV file that can be opened in spreadsheet applications.")
        ) {
            exportDetailRow(
                title: "File Format",
                value: "CSV (Comma Separated Values)",
                icon: "doc.text"
            )
            
            exportDetailRow(
                title: "Encoding",
                value: "UTF-8",
                icon: "textformat.abc"
            )
            
            exportDetailRow(
                title: "Compatibility",
                value: "Excel, Numbers, Google Sheets",
                icon: "square.grid.3x3"
            )
            
            if selectedExportType == .budgetEntries {
                exportDetailRow(
                    title: "Included Fields",
                    value: "Date, Amount, Category, Note",
                    icon: "list.bullet"
                )
            } else if selectedExportType == .monthlyBudgets {
                exportDetailRow(
                    title: "Included Fields",
                    value: "Year, Month, Category, Amount, Historical",
                    icon: "list.bullet"
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(themeManager.primaryColor)
                .font(.caption)
            Text(title)
        }
    }
    
    private func exportDetailRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Computed Properties
    
    private var isConfigurationValid: Bool {
        guard previewData?.recordCount ?? 0 > 0 else { return false }
        
        if case .custom(let start, let end) = exportTimePeriod {
            return start <= end && end <= Date()
        }
        
        return true
    }
    
    private var timePeriodFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select the time range for your export data.")
            
            if case .custom(let start, let end) = exportTimePeriod {
                let days = daysBetween(start, end)
                if days > 365 {
                    Text("⚠️ Large date ranges may result in very large files.")
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        // Set initial custom dates
        customEndDate = Date()
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: customEndDate) ?? Date()
        
        // Load user preferences
        includeCurrency = settingsManager.defaultCurrency != "USD" // Show currency for non-USD
        decimalPlaces = settingsManager.showDecimalPlaces ? 2 : 0
        
        // Generate initial preview
        updatePreviewIfNeeded()
    }
    
    private func updateCustomDateRange() {
        if case .custom = exportTimePeriod {
            exportTimePeriod = .custom(customStartDate, customEndDate)
            updatePreviewIfNeeded()
        }
    }
    
    private func updatePreviewIfNeeded() {
        Task {
            await generatePreview()
        }
    }
    
    private func generatePreview() async {
        await MainActor.run {
            previewData = nil
        }
        
        do {
            let entries = try await budgetManager.getEntries(
                for: exportTimePeriod,
                sortedBy: .date,
                ascending: false
            )
            
            let budgets = budgetManager.getMonthlyBudgets(
                for: Calendar.current.component(.month, from: Date()),
                year: Calendar.current.component(.year, from: Date())
            )
            
            let relevantData: [Any]
            let totalAmount: Double
            let categories: [String]
            
            switch selectedExportType {
            case .budgetEntries:
                relevantData = entries
                totalAmount = entries.reduce(0) { $0 + $1.amount }
                categories = Array(Set(entries.map { $0.category })).sorted()
                
            case .monthlyBudgets:
                relevantData = budgets
                totalAmount = budgets.reduce(0) { $0 + $1.amount }
                categories = Array(Set(budgets.map { $0.category })).sorted()
                
            case .combined:
                relevantData = entries + budgets
                totalAmount = entries.reduce(0) { $0 + $1.amount } + budgets.reduce(0) { $0 + $1.amount }
                let entryCategories = Set(entries.map { $0.category })
                let budgetCategories = Set(budgets.map { $0.category })
                categories = Array(entryCategories.union(budgetCategories)).sorted()
            }
            
            let estimatedSize = estimateFileSize(recordCount: relevantData.count)
            let dateRange = exportTimePeriod.formattedDateRange(style: .abbreviated)
            
            // Generate sample data
            let sampleData = generateSampleData(for: selectedExportType, from: relevantData)
            
            let preview = ExportPreview(
                recordCount: relevantData.count,
                estimatedSize: estimatedSize,
                dateRange: dateRange,
                categories: categories,
                totalAmount: totalAmount,
                sampleData: sampleData
            )
            
            await MainActor.run {
                self.previewData = preview
                self.currentError = nil
            }
            
        } catch {
            await MainActor.run {
                let appError = AppError.from(error)
                self.currentError = appError
                self.previewData = ExportPreview(
                    recordCount: 0,
                    estimatedSize: "0 KB",
                    dateRange: "No data",
                    categories: [],
                    totalAmount: 0,
                    sampleData: ""
                )
                errorHandler.handle(appError, context: "Generating export preview")
            }
        }
    }
    
    private func validateAndPrepareExport() {
        guard isConfigurationValid else {
            showValidationError()
            return
        }
        
        // Create export configuration
        exportConfiguration = CSVExport.ExportConfiguration(
            timePeriod: exportTimePeriod,
            exportType: selectedExportType,
            includeCurrency: includeCurrency,
            dateFormat: "yyyy-MM-dd",
            decimalPlaces: decimalPlaces,
            includeHeaders: includeHeaders,
            encoding: .utf8
        )
        
        if previewData?.recordCount ?? 0 > 1000 {
            // Show preview for large exports
            showingPreview = true
        } else {
            // Export directly for smaller exports
            performExport()
        }
    }
    
    private func performExport() {
        dismiss()
        onExport()
    }
    
    private func showValidationError() {
        if case .custom(let start, let end) = exportTimePeriod {
            if end < start {
                alertTitle = "Invalid Date Range"
                alertMessage = "End date must be after start date."
            } else if start > Date() || end > Date() {
                alertTitle = "Invalid Date Range"
                alertMessage = "Date range cannot be in the future."
            } else if daysBetween(start, end) > 365 {
                alertTitle = "Date Range Too Large"
                alertMessage = "Date range cannot exceed one year. Please select a smaller range."
            }
        } else if previewData?.recordCount ?? 0 == 0 {
            alertTitle = "No Data Available"
            alertMessage = "No data available for the selected criteria. Try adjusting your time period or export type."
        } else {
            alertTitle = "Invalid Configuration"
            alertMessage = "Please check your export settings and try again."
        }
        
        showingAlert = true
    }
    
    // MARK: - Utility Methods
    
    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
    
    private func estimateFileSize(recordCount: Int) -> String {
        let bytesPerRecord = selectedExportType == .budgetEntries ? 80 : 60 // Estimated
        let totalBytes = recordCount * bytesPerRecord
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }
    
    private func generateSampleData(for type: CSVExport.ExportType, from data: [Any]) -> String {
        switch type {
        case .budgetEntries:
            return "Date,Amount,Category,Note\n2024-01-15,45.67,Groceries,Weekly shopping\n2024-01-16,12.50,Transportation,Bus fare"
        case .monthlyBudgets:
            return "Year,Month,Category,Amount,IsHistorical\n2024,1,Groceries,500.00,false\n2024,1,Transportation,200.00,false"
        case .combined:
            return "# Budget Entries\nDate,Amount,Category,Note\n2024-01-15,45.67,Groceries,Weekly shopping\n\n# Monthly Budgets\nYear,Month,Category,Amount,IsHistorical\n2024,1,Groceries,500.00,false"
        }
    }
    
    private func iconForExportType(_ type: CSVExport.ExportType) -> String {
        switch type {
        case .budgetEntries: return "list.bullet.clipboard"
        case .monthlyBudgets: return "calendar.badge.clock"
        case .combined: return "doc.on.doc"
        }
    }
    
    private func displayNameForExportType(_ type: CSVExport.ExportType) -> String {
        switch type {
        case .budgetEntries: return "Budget Entries"
        case .monthlyBudgets: return "Monthly Budgets"
        case .combined: return "Combined Data"
        }
    }
    
    private func descriptionForExportType(_ type: CSVExport.ExportType) -> String {
        switch type {
        case .budgetEntries: return "Export your transaction history and purchases"
        case .monthlyBudgets: return "Export your budget allocations by month"
        case .combined: return "Export both entries and budgets in one file"
        }
    }
}

// MARK: - Extensions

extension CSVExport.ExportType: CaseIterable {
    public static var allCases: [CSVExport.ExportType] {
        return [.budgetEntries, .monthlyBudgets, .combined]
    }
}

// MARK: - Export Preview View

struct ExportPreviewView: View {
    let preview: ExportOptionsView.ExportPreview?
    let configuration: CSVExport.ExportConfiguration?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let preview = preview {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 48))
                                .foregroundColor(themeManager.primaryColor)
                            
                            Text("Export Preview")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Review your export before generating the file")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Statistics
                        VStack(spacing: 16) {
                            HStack(spacing: 24) {
                                statView(
                                    title: "Records",
                                    value: "\(preview.recordCount)",
                                    icon: "list.number"
                                )
                                
                                statView(
                                    title: "Size",
                                    value: preview.estimatedSize,
                                    icon: "opticaldiscdrive"
                                )
                            }
                            
                            HStack(spacing: 24) {
                                statView(
                                    title: "Total Amount",
                                    value: NumberFormatter.formatCurrency(preview.totalAmount),
                                    icon: "dollarsign.circle"
                                )
                                
                                statView(
                                    title: "Categories",
                                    value: "\(preview.categories.count)",
                                    icon: "folder"
                                )
                            }
                        }
                        .padding()
                        .background(themeManager.semanticColors.backgroundSecondary)
                        .cornerRadius(12)
                        
                        // Sample Data
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sample Data")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(preview.sampleData)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Configuration Details
                        if let config = configuration {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Export Configuration")
                                    .font(.headline)
                                
                                VStack(spacing: 8) {
                                    configRow("Export Type", config.exportType.fileName)
                                    configRow("Time Period", config.timePeriod.displayName)
                                    configRow("Include Currency", config.includeCurrency ? "Yes" : "No")
                                    configRow("Include Headers", config.includeHeaders ? "Yes" : "No")
                                    configRow("Decimal Places", "\(config.decimalPlaces)")
                                    configRow("Date Format", config.dateFormat)
                                }
                                .padding()
                                .background(themeManager.semanticColors.backgroundSecondary)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Warnings
                        if preview.recordCount > 5000 {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Large Export Warning")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("This export contains a large amount of data (\(preview.recordCount) records). The file generation may take some time and result in a large file.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                    .disabled(preview?.recordCount == 0)
                }
            }
        }
    }
    
    private func statView(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(themeManager.primaryColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func configRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
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
            .environmentObject(BudgetManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ErrorHandler.shared)
            .previewDisplayName("Light Mode")
            
            ExportOptionsView(
                exportTimePeriod: .constant(.custom(Date(), Date())),
                onExport: {}
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(BudgetManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ErrorHandler.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Custom Date")
        }
    }
}
#endif
