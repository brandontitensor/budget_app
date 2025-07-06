//
//  ImportOptionsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved architecture, and better user experience
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
    private enum ImportType {
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
    
    private struct RecentImport {
        let id = UUID()
        let fileName: String
        let type: ImportType
        let recordCount: Int
        let date: Date
        let success: Bool
    }
    
    // MARK: - Constants
    private let maxFileSize = AppConstants.Data.maxImportFileSize
    private let supportedFormats = AppConstants.Data.supportedImportFormats
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                if isValidatingFile {
                    loadingView
                } else {
                    mainContent
                }
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Import Guide") {
                        showingImportGuide = true
                    }
                    
                    Button("Download Templates") {
                        showingTemplateDownload = true
                    }
                    
                    Button("Advanced Options") {
                        showingAdvancedOptions = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(themeManager.primaryColor)
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingImportGuide) {
            ImportGuideView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingTemplateDownload) {
            TemplateDownloadView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAdvancedOptions) {
            AdvancedImportOptionsView(configuration: $importConfiguration)
                .environmentObject(themeManager)
        }
        .alert(
            "Import Error",
            isPresented: .constant(currentError != nil),
            presenting: currentError
        ) { error in
            Button("OK", role: .cancel) {
                currentError = nil
            }
            
            if error.isRetryable {
                Button("Retry") {
                    // Handle retry logic
                    currentError = nil
                }
            }
        } message: { error in
            VStack(alignment: .leading, spacing: 8) {
                Text(error.errorDescription ?? "Unknown error")
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
        .errorAlert()
        .onAppear {
            loadRecentImports()
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
                        // Handle retry based on error context
                        currentError = nil
                    }
                )
                .listRowBackground(Color.clear)
            }
            
            quickStartSection
            formatSection
            importOptionsSection
            advancedSection
            recentImportsSection
            notesSection
        }
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text("Validating File...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Please wait while we analyze your import file.")
                .font(.caption)
                .foregroundColor(.tertiary)
                .multilineTextAlignment(.center)
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
            footer: Text("Select the type of data you want to import.")
        ) {
            Button {
                selectedImportType = .budget
                handleImport(.budget)
            } label: {
                ImportOptionRow(
                    title: "Import Budget Data",
                    subtitle: "Import your budget categories and amounts",
                    iconName: "chart.pie.fill",
                    isLoading: isValidatingFile && selectedImportType == .budget
                )
            }
            .disabled(isValidatingFile)
            
            Button {
                selectedImportType = .purchases
                handleImport(.purchases)
            } label: {
                ImportOptionRow(
                    title: "Import Purchase Data",
                    subtitle: "Import your transaction history",
                    iconName: "cart.fill",
                    isLoading: isValidatingFile && selectedImportType == .purchases
                )
            }
            .disabled(isValidatingFile)
            
            Button {
                selectedImportType = .autoDetect
                handleImport(.autoDetect)
            } label: {
                ImportOptionRow(
                    title: "Auto-Detect Format",
                    subtitle: "Let the app determine your file type",
                    iconName: "doc.text.magnifyingglass",
                    isLoading: isValidatingFile && selectedImportType == .autoDetect
                )
            }
            .disabled(isValidatingFile)
        }
    }
    
    private var advancedSection: some View {
        Section(
            header: sectionHeader("Advanced", systemImage: "gearshape.2"),
            footer: Text("Configure advanced import settings and validation options.")
        ) {
            Button {
                showingAdvancedOptions = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Advanced Options")
                            .font(.subheadline)
                        
                        Text(advancedOptionsSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Button {
                showingImportGuide = true
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Guide")
                            .font(.subheadline)
                        
                        Text("Step-by-step instructions for importing data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Button {
                showingTemplateDownload = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download Templates")
                            .font(.subheadline)
                        
                        Text("Get properly formatted CSV templates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var recentImportsSection: some View {
        Group {
            if !recentImports.isEmpty {
                Section(
                    header: sectionHeader("Recent Imports", systemImage: "clock"),
                    footer: Text("Your recent import activity.")
                ) {
                    ForEach(recentImports.prefix(5), id: \.id) { importItem in
                        RecentImportRow(import: importItem)
                            .environmentObject(themeManager)
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section(
            header: sectionHeader("Important Notes", systemImage: "exclamationmark.triangle"),
            footer: Text("Make sure your CSV file matches the expected format exactly.")
        ) {
            ImportNoteRow(
                icon: "checkmark.shield",
                text: "Existing data will not be overwritten",
                color: .green
            )
            ImportNoteRow(
                icon: "arrow.up.doc",
                text: "Maximum file size: \(formatFileSize(maxFileSize))",
                color: .blue
            )
            ImportNoteRow(
                icon: "textformat.abc",
                text: "UTF-8 encoding required",
                color: .orange
            )
            ImportNoteRow(
                icon: "eye",
                text: "You'll review data before final import",
                color: .purple
            )
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
    
    // MARK: - Computed Properties
    
    private var advancedOptionsSummary: String {
        var options: [String] = []
        
        if importConfiguration.validateDuplicates {
            options.append("Validate duplicates")
        }
        
        if importConfiguration.skipInvalidRows {
            options.append("Skip invalid rows")
        }
        
        if importConfiguration.strictValidation {
            options.append("Strict validation")
        }
        
        return options.isEmpty ? "Default settings" : options.joined(separator: ", ")
    }
    
    // MARK: - Helper Methods
    
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
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.primaryColor)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FormatInfoRow: View {
    let title: String
    @Binding var isExpanded: Bool
    let type: ImportOptionsView.ImportType
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expected Format:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(type.expectedFormat)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                    
                    Text("Sample Data:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(type.sampleData)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ImportOptionRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            if !isLoading {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

struct ImportNoteRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct RecentImportRow: View {
    let `import`: ImportOptionsView.RecentImport
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: `import`.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(`import`.success ? .green : .red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(`import`.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack {
                    Text(`import`.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if `import`.success {
                        Text("• \(`import`.recordCount) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(`import`.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Additional Views

struct ImportGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.primaryColor)
                        
                        Text("Import Guide")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Step-by-step instructions for importing your data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        GuideStep(
                            number: 1,
                            title: "Prepare Your Data",
                            description: "Export your data from your current app or create a CSV file with the correct format."
                        )
                        
                        GuideStep(
                            number: 2,
                            title: "Check Format",
                            description: "Ensure your CSV file has the correct headers and data format. Download our templates if needed."
                        )
                        
                        GuideStep(
                            number: 3,
                            title: "Choose Import Type",
                            description: "Select Budget Data for monthly budgets or Purchase Data for transactions. Use Auto-Detect if unsure."
                        )
                        
                        GuideStep(
                            number: 4,
                            title: "Select File",
                            description: "Tap your chosen import option and select your CSV file from Files, iCloud, or other locations."
                        )
                        
                        GuideStep(
                            number: 5,
                            title: "Review Data",
                            description: "Check the preview of your data. Map any new categories to existing ones or create new categories."
                        )
                        
                        GuideStep(
                            number: 6,
                            title: "Complete Import",
                            description: "Confirm the import to add your data to the app. Your existing data will not be overwritten."
                        )
                    }
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("💡 Pro Tips")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TipRow(
                                icon: "checkmark.circle",
                                tip: "Use UTF-8 encoding when saving your CSV file"
                            )
                            
                            TipRow(
                                icon: "calendar",
                                tip: "Date format should be YYYY-MM-DD (e.g., 2024-07-15)"
                            )
                            
                            TipRow(
                                icon: "dollarsign.circle",
                                tip: "Amount should be numbers only (no currency symbols)"
                            )
                            
                            TipRow(
                                icon: "text.alignleft",
                                tip: "Category names should be consistent and descriptive"
                            )
                            
                            TipRow(
                                icon: "eye",
                                tip: "Preview your data before importing to catch any issues"
                            )
                        }
                    }
                    
                    // Common Issues Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("⚠️ Common Issues")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            IssueRow(
                                issue: "Missing headers",
                                solution: "Make sure your CSV file has the correct column headers"
                            )
                            
                            IssueRow(
                                issue: "Wrong date format",
                                solution: "Use YYYY-MM-DD format for all dates"
                            )
                            
                            IssueRow(
                                issue: "Special characters in amounts",
                                solution: "Remove currency symbols and use only numbers with decimal points"
                            )
                            
                            IssueRow(
                                issue: "Empty rows",
                                solution: "Remove any empty rows from your CSV file"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Import Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GuideStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct TipRow: View {
    let icon: String
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(tip)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct IssueRow: View {
    let issue: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .frame(width: 16)
                
                Text(issue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
    }
}

struct TemplateDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingShareSheet = false
    @State private var templateURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.primaryColor)
                    
                    Text("Download Templates")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Get properly formatted CSV templates to ensure successful imports")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Template Options
                VStack(spacing: 16) {
                    TemplateCard(
                        title: "Budget Template",
                        description: "Template for importing budget categories and amounts",
                        icon: "chart.pie.fill",
                        onDownload: {
                            downloadBudgetTemplate()
                        }
                    )
                    .environmentObject(themeManager)
                    
                    TemplateCard(
                        title: "Purchase Template",
                        description: "Template for importing transaction history",
                        icon: "cart.fill",
                        onDownload: {
                            downloadPurchaseTemplate()
                        }
                    )
                    .environmentObject(themeManager)
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to use templates:")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionStep(
                            number: 1,
                            text: "Download the template for your data type"
                        )
                        
                        InstructionStep(
                            number: 2,
                            text: "Open the template in your spreadsheet app"
                        )
                        
                        InstructionStep(
                            number: 3,
                            text: "Replace the sample data with your actual data"
                        )
                        
                        InstructionStep(
                            number: 4,
                            text: "Save as CSV and import into the app"
                        )
                    }
                }
            }
            .padding()
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = templateURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func downloadBudgetTemplate() {
        let csvContent = """
        Year,Month,Category,Amount,IsHistorical
        2024,7,Groceries,500.00,false
        2024,7,Transportation,200.00,false
        2024,7,Entertainment,150.00,false
        2024,7,Utilities,300.00,false
        2024,7,Dining,250.00,false
        """
        
        saveAndShareTemplate(content: csvContent, filename: "budget_template.csv")
    }
    
    private func downloadPurchaseTemplate() {
        let csvContent = """
        Date,Amount,Category,Note
        2024-07-01,45.67,Groceries,Weekly shopping
        2024-07-02,15.00,Transportation,Bus fare
        2024-07-03,89.99,Entertainment,Movie tickets
        2024-07-04,25.50,Dining,Lunch with friends
        2024-07-05,120.00,Utilities,Electric bill
        """
        
        saveAndShareTemplate(content: csvContent, filename: "purchase_template.csv")
    }
    
    private func saveAndShareTemplate(content: String, filename: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            templateURL = fileURL
            showingShareSheet = true
        } catch {
            print("Failed to save template: \(error)")
        }
    }
}

struct TemplateCard: View {
    let title: String
    let description: String
    let icon: String
    let onDownload: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onDownload) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(themeManager.primaryColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .foregroundColor(themeManager.primaryColor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct AdvancedImportOptionsView: View {
    @Binding var configuration: CSVImport.ImportConfiguration
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Validation Options"),
                    footer: Text("Configure how strictly the import process validates your data.")
                ) {
                    Toggle("Validate Duplicates", isOn: $configuration.validateDuplicates)
                    Toggle("Skip Invalid Rows", isOn: $configuration.skipInvalidRows)
                    Toggle("Strict Validation", isOn: $configuration.strictValidation)
                }
                
                Section(
                    header: Text("File Limits"),
                    footer: Text("Set limits for file size and number of records.")
                ) {
                    HStack {
                        Text("Max File Size")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: configuration.maxFileSize, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Row Count")
                        Spacer()
                        Text("\(configuration.maxRowCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(
                    header: Text("Date Formats"),
                    footer: Text("Supported date formats for import parsing.")
                ) {
                    ForEach(configuration.dateFormats, id: \.self) { format in
                        HStack {
                            Text(format)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text("e.g., \(exampleDate(for: format))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(
                    header: Text("Encoding & Delimiter"),
                    footer: Text("Technical settings for CSV parsing.")
                ) {
                    HStack {
                        Text("Encoding")
                        Spacer()
                        Text(configuration.encoding.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Delimiter")
                        Spacer()
                        Text("'\(configuration.delimiter)'")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        configuration = CSVImport.ImportConfiguration.default
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Advanced Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exampleDate(for format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: Date())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - String Extension

extension String.Encoding {
    var description: String {
        switch self {
        case .utf8: return "UTF-8"
        case .ascii: return "ASCII"
        case .utf16: return "UTF-16"
        default: return "Other"
        }
    }
}

// MARK: - Error Handling Extension


private struct ErrorHandlingModifier: ViewModifier {
    let context: String
    let showInline: Bool
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
                if let error = notification.object as? Error {
                    ErrorHandler.shared.handle(error, context: context)
                }
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ImportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Main Import Options View
            ImportOptionsView(
                showingImportBudgetPicker: .constant(false),
                showingImportPurchasePicker: .constant(false)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(BudgetManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ErrorHandler.shared)
            .previewDisplayName("Import Options - Light")
            
            // Dark Mode
            ImportOptionsView(
                showingImportBudgetPicker: .constant(false),
                showingImportPurchasePicker: .constant(false)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(BudgetManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ErrorHandler.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Import Options - Dark")
            
            // Import Guide
            ImportGuideView()
                .environmentObject(ThemeManager.shared)
                .previewDisplayName("Import Guide")
            
            // Template Download
            TemplateDownloadView()
                .environmentObject(ThemeManager.shared)
                .previewDisplayName("Template Download")
            
            // Advanced Options
            AdvancedImportOptionsView(
                configuration: .constant(CSVImport.ImportConfiguration.default)
            )
            .environmentObject(ThemeManager.shared)
            .previewDisplayName("Advanced Options")
        }
    }
}

// Preview helper for testing with mock data
struct MockImportOptionsView: View {
    @State private var showingBudgetPicker = false
    @State private var showingPurchasePicker = false
    
    var body: some View {
        ImportOptionsView(
            showingImportBudgetPicker: $showingBudgetPicker,
            showingImportPurchasePicker: $showingPurchasePicker
        )
        .environmentObject(ThemeManager.shared)
        .environmentObject(BudgetManager.shared)
        .environmentObject(SettingsManager.shared)
        .environmentObject(ErrorHandler.shared)
    }
}
#endif
