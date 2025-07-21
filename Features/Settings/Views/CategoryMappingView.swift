//
//  CategoryMappingView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/29/24.
//

import SwiftUI
import Foundation

/// View for mapping imported categories to existing categories or creating new ones with enhanced error handling
struct CategoryMappingView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    // MARK: - Properties
    let categories: Set<String>
    let importedData: [CSVImport.PurchaseImportData]
    let onComplete: ([String: String]) -> Void
    
    // MARK: - State
    @State private var categoryMappings: [String: String] = [:]
    @State private var selectedCategoryToCreate: String?
    @State private var newCategoryAmount: Double = 0
    @State private var showingCalculator = false
    @State private var showingNewCategorySheet = false
    @State private var showingFutureMonthsAlert = false
    @State private var isProcessing = false
    @State private var validationErrors: [String: String] = [:]
    @State private var showingValidationSummary = false
    @State private var processedCategories: Set<String> = []
    @State private var showingProgressView = false
    @State private var progressMessage = ""
    @State private var completionPercentage: Double = 0
    
    // MARK: - Computed Properties
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var existingCategories: [String] {
        budgetManager.getAvailableCategories()
    }
    
    private var isMappingComplete: Bool {
        categories.allSatisfy { category in
            categoryMappings[category] != nil
        }
    }
    
    private var totalImportAmount: Double {
        importedData.reduce(0) { $0 + $1.amount }
    }
    
    private var categoriesWithCounts: [(category: String, count: Int, totalAmount: Double)] {
        let groupedData = Dictionary(grouping: importedData) { $0.category }
        return categories.map { category in
            let transactions = groupedData[category] ?? []
            let totalAmount = transactions.reduce(0) { $0 + $1.amount }
            return (category: category, count: transactions.count, totalAmount: totalAmount)
        }.sorted { $0.category < $1.category }
    }
    
    private var unmappedCategories: [String] {
        categories.filter { categoryMappings[$0] == nil }.sorted()
    }
    
    private var mappedCategories: [String] {
        categories.filter { categoryMappings[$0] != nil }.sorted()
    }
    
    private var hasValidationErrors: Bool {
        !validationErrors.isEmpty
    }
    
    private var canProceed: Bool {
        isMappingComplete && !hasValidationErrors && !isProcessing
    }
    
    // MARK: - Initialization
    init(
        categories: Set<String>,
        importedData: [CSVImport.PurchaseImportData],
        onComplete: @escaping ([String: String]) -> Void
    ) {
        self.categories = categories
        self.importedData = importedData
        self.onComplete = onComplete
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                if showingProgressView {
                    progressOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("Map Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancellation()
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        handleImportAction()
                    }
                    .disabled(!canProceed)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingNewCategorySheet) {
                createNewCategorySheet
            }
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $newCategoryAmount)
            }
            .alert("Add to Future Months?", isPresented: $showingFutureMonthsAlert) {
                Button("This month only") {
                    createNewCategory(includeFutureMonths: false)
                }
                Button("All future months") {
                    createNewCategory(includeFutureMonths: true)
                }
                Button("Cancel", role: .cancel) {
                    showingFutureMonthsAlert = false
                }
            } message: {
                Text("Do you want to add this category to future months as well?")
            }
            .alert("Validation Issues", isPresented: $showingValidationSummary) {
                Button("Review", role: .cancel) { }
            } message: {
                Text(getValidationSummary())
            }
            .errorAlert(onRetry: {
               Task<Void, Never>{
                    await retryFailedOperations()
                }
            })
            .onAppear {
                validateInitialState()
            }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            instructionsHeader
            
            List {
                importSummarySection
                
                if !unmappedCategories.isEmpty {
                    unmappedCategoriesSection
                }
                
                if !mappedCategories.isEmpty {
                    mappedCategoriesSection
                }
                
                if hasValidationErrors {
                    validationErrorsSection
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - Progress Overlay
    private var progressOverlay: some View {
        VStack(spacing: 24) {
            ProgressView(value: completionPercentage, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(1.2)
            
            VStack(spacing: 8) {
                Text("Processing Categories")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(progressMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(completionPercentage * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isProcessing {
                Button("Cancel") {
                    cancelProcessing()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - View Components
    private var instructionsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(themeManager.primaryColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category Mapping")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(getInstructionText())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Supporting Views

struct ValidationErrorRow: View {
    let category: String
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusIndicator: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if total > 0 {
                ProgressView(value: Double(count), total: Double(total))
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(0.8)
                    .tint(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryMappingSectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
            Text(title)
        }
    }
}

struct CategorySummaryCard: View {
    let category: String
    let count: Int
    let amount: Double
    let isProcessed: Bool
    let hasError: Bool
    let themeColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(count) transactions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.asCurrency)
                    .font(.caption)
                    .fontWeight(.medium)
                
                statusIndicator
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        if hasError {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption2)
        } else if isProcessed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption2)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.caption2)
        }
    }
}

struct UnmappedCategoryRow: View {
    let category: String
    let categoryData: (category: String, count: Int, totalAmount: Double)?
    let existingCategories: [String]
    let onMap: (String) -> Void
    let onCreateNew: () -> Void
    let validationError: String?
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let data = categoryData {
                        Text("\(data.count) transactions • \(data.totalAmount.asCurrency)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !existingCategories.isEmpty {
                    Menu {
                        ForEach(existingCategories, id: \.self) { existingCategory in
                            Button(existingCategory) {
                                onMap(existingCategory)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Map to Existing")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(themeColor)
                    }
                }
            }
            
            HStack {
                Button("Create New Category") {
                    onCreateNew()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            
            if let error = validationError {
                InlineErrorView(
                    error: AppError.validation(message: error),
                    onDismiss: nil,
                    onRetry: nil
                )
            }
        }
        .padding(.vertical, 4)
    }
}

struct MappedCategoryRow: View {
    let originalCategory: String
    let mappedCategory: String
    let categoryData: (category: String, count: Int, totalAmount: Double)?
    let onUnmap: () -> Void
    let themeColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if originalCategory != mappedCategory {
                    Text(originalCategory)
                        .font(.subheadline)
                        .strikethrough()
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "arrow.right")
                            .foregroundColor(themeColor)
                            .font(.caption)
                        Text(mappedCategory)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeColor)
                    }
                } else {
                    Text(mappedCategory)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let data = categoryData {
                    Text("\(data.count) transactions • \(data.totalAmount.asCurrency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Change") {
                onUnmap()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

private struct CategoryStatusView: View {
    let mappedCategories: [String]
    let unmappedCategories: [String] 
    let categories: [String]
    let validationErrors: [String: String]
    let hasValidationErrors: Bool
    
    var body: some View {
        // Status indicators
        HStack(spacing: 16) {
            StatusIndicator(
                title: "Mapped",
                count: mappedCategories.count,
                total: categories.count,
                color: .green
            )
            
            StatusIndicator(
                title: "Remaining",
                count: unmappedCategories.count,
                total: categories.count,
                color: .orange
            )
            
            if hasValidationErrors {
                StatusIndicator(
                    title: "Errors",
                    count: validationErrors.count,
                    total: categories.count,
                    color: .red
                )
            }
        }
        .padding()
    }
}

// MARK: - CategoryMappingView Extension

extension CategoryMappingView {
    // MARK: - Error Handling Methods
    
    /// Handle specific errors during category operations
    private func handleCategoryError(_ error: Error, context: String) {
        let appError = AppError.from(error)
        
        // Add context-specific error handling
        switch appError {
        case .validation(let message):
            // For validation errors, show inline feedback
            if let category = selectedCategoryToCreate {
                validationErrors[category] = message
            }
        case .dataSave:
            // For data save errors, show retry option
            errorHandler.handle(appError, context: "Saving category data")
        default:
            // For other errors, use global error handler
            errorHandler.handle(appError, context: context)
        }
    }
    
    /// Validate all current mappings and return any errors found
    private func validateAllMappings() -> [String: String] {
        var errors: [String: String] = [:]
        
        for (original, mapped) in categoryMappings {
            if let error = validateCategory(mapped) {
                errors[original] = error
            }
        }
        
        return errors
    }
    
    /// Check if the current state allows proceeding with import
    private func canProceedWithImport() -> (canProceed: Bool, reason: String?) {
        if !isMappingComplete {
            return (false, "All categories must be mapped before importing")
        }
        
        if hasValidationErrors {
            return (false, "Fix validation errors before proceeding")
        }
        
        if isProcessing {
            return (false, "Please wait for current operation to complete")
        }
        
        if importedData.isEmpty {
            return (false, "No data to import")
        }
        
        return (true, nil)
    }
    
    /// Perform comprehensive validation before import
    private func performPreImportValidation() async throws {
        // Validate mappings
        let mappingErrors = validateAllMappings()
        if !mappingErrors.isEmpty {
            await MainActor.run {
                validationErrors = mappingErrors
            }
            throw AppError.validation(message: "Invalid category mappings found")
        }
        
        // Validate import data
        for data in importedData {
            if data.amount <= 0 {
                throw AppError.validation(message: "Invalid transaction amount in \(data.category)")
            }
            
            if data.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AppError.validation(message: "Empty category name found")
            }
        }
        
        // Validate we have necessary permissions
        let hasCategories = !budgetManager.getAvailableCategories().isEmpty || !categoryMappings.isEmpty
        if !hasCategories {
            throw AppError.validation(message: "No categories available for mapping")
        }
    }
    
    /// Safely update progress with error handling
    private func updateProgress(percentage: Double, message: String) async {
        await MainActor.run {
            completionPercentage = min(1.0, max(0.0, percentage))
            progressMessage = message
        }
    }
    
    /// Create a detailed error context for better debugging
    private func createErrorContext(operation: String, category: String? = nil) -> String {
        var context = "CategoryMappingView: \(operation)"
        
        if let category = category {
            context += " for category '\(category)'"
        }
        
        context += " - \(mappedCategories.count)/\(categories.count) categories mapped"
        
        if hasValidationErrors {
            context += ", \(validationErrors.count) validation errors"
        }
        
        return context
    }

    // MARK: - Accessibility
    
    /// Add accessibility improvements
    private func setupAccessibility() {
        // This would be called in onAppear if needed
        // Add VoiceOver hints and labels for better accessibility
    }

    // MARK: - Analytics and Logging
    
    /// Log important user actions for analytics
    private func logUserAction(_ action: String, category: String? = nil) {
        var logMessage = "CategoryMapping: \(action)"
        if let category = category {
            logMessage += " for '\(category)'"
        }
        
        #if DEBUG
        print("📊 \(logMessage)")
        #endif
        
        // Here you could send to analytics service
        // AnalyticsManager.shared.track(event: action, properties: [...])
    }
    
    /// Log mapping completion statistics
    private func logMappingCompletion() {
        let stats: [String: Any] = [
            "totalCategories": categories.count,
            "mappedToExisting": categoryMappings.values.filter { existingCategories.contains($0) }.count,
            "newCategoriesCreated": categoryMappings.values.filter { !existingCategories.contains($0) }.count,
            "totalTransactions": importedData.count,
            "totalAmount": totalImportAmount,
            "hadValidationErrors": !validationErrors.isEmpty
        ]
        
        #if DEBUG
        print("📊 CategoryMapping completed with stats: \(stats)")
        #endif
    }

    // MARK: - Performance Optimizations
    
    /// Optimize category data calculations
    private func optimizedCategoriesWithCounts() -> [(category: String, count: Int, totalAmount: Double)] {
        // Cache this calculation if it becomes expensive
        return categoriesWithCounts
    }
    
    /// Debounced validation to avoid excessive computation
    private func debouncedValidation(for category: String) {
        // Implement debouncing if validation becomes expensive
        // For now, direct validation is fine
        if let error = validateCategory(category) {
            validationErrors[category] = error
        } else {
            validationErrors.removeValue(forKey: category)
        }
    }
}

// MARK: - CategoryMappingView View Components Extension

extension CategoryMappingView {
    // MARK: - View Components
    
    private var importSummarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Summary")
                            .font(.headline)
                        Text("\(importedData.count) transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(totalImportAmount.asCurrency)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryColor)
                        Text("Total Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(categoriesWithCounts, id: \.category) { item in
                        CategorySummaryCard(
                            category: item.category,
                            count: item.count,
                            amount: item.totalAmount,
                            isProcessed: processedCategories.contains(item.category),
                            hasError: validationErrors[item.category] != nil,
                            themeColor: themeManager.primaryColor
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var unmappedCategoriesSection: some View {
        Section(header: CategoryMappingSectionHeader(title: "Unmapped Categories", systemImage: "questionmark.circle")) {
            ForEach(unmappedCategories, id: \.self) { category in
                UnmappedCategoryRow(
                    category: category,
                    categoryData: categoriesWithCounts.first { $0.category == category },
                    existingCategories: existingCategories,
                    onMap: { existingCategory in
                        mapCategory(category, to: existingCategory)
                    },
                    onCreateNew: {
                        prepareToCreateNewCategory(category)
                    },
                    validationError: validationErrors[category],
                    themeColor: themeManager.primaryColor
                )
            }
        }
    }
    
    private var mappedCategoriesSection: some View {
        Section(header: CategoryMappingSectionHeader(title: "Mapped Categories", systemImage: "checkmark.circle")) {
            ForEach(mappedCategories, id: \.self) { originalCategory in
                if let mappedCategory = categoryMappings[originalCategory] {
                    MappedCategoryRow(
                        originalCategory: originalCategory,
                        mappedCategory: mappedCategory,
                        categoryData: categoriesWithCounts.first { $0.category == originalCategory },
                        onUnmap: {
                            unmapCategory(originalCategory)
                        },
                        themeColor: themeManager.primaryColor
                    )
                }
            }
        }
    }
    
    private var validationErrorsSection: some View {
        Section(header: CategoryMappingSectionHeader(title: "Validation Errors", systemImage: "exclamationmark.triangle.fill")) {
            ForEach(Array(validationErrors.keys).sorted(), id: \.self) { category in
                if let error = validationErrors[category] {
                    ValidationErrorRow(
                        category: category,
                        error: error,
                        onRetry: {
                            retryValidation(for: category)
                        }
                    )
                }
            }
            
            if validationErrors.count > 1 {
                Button("Fix All Errors") {
                    showingValidationSummary = true
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var createNewCategorySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("New Category Details")) {
                    if let category = selectedCategoryToCreate {
                        LabeledContent("Category Name", value: category)
                        
                        if let categoryData = categoriesWithCounts.first(where: { $0.category == category }) {
                            LabeledContent("Transactions", value: "\(categoryData.count)")
                            LabeledContent("Total Amount", value: categoryData.totalAmount.asCurrency)
                        }
                        
                        HStack {
                            Text("Budget Amount")
                            Spacer()
                            Button(newCategoryAmount.asCurrency) {
                                showingCalculator = true
                            }
                            .foregroundColor(themeManager.primaryColor)
                        }
                    }
                }
                
                Section(
                    header: Text("Budget Settings"),
                    footer: Text("This budget will apply starting from the current month (\(Calendar.current.monthSymbols[currentMonth - 1]) \(currentYear))")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The category will be created and added to your budget categories with the specified amount.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if newCategoryAmount > 0 {
                            Text("Recommended based on import data: \(estimatedBudgetAmount().asCurrency)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if newCategoryAmount <= 0 {
                    Section {
                        InlineErrorView(
                            error: AppError.validation(message: "Budget amount must be greater than zero"),
                            onDismiss: nil,
                            onRetry: {
                                newCategoryAmount = estimatedBudgetAmount()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Create Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelNewCategoryCreation()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        showingFutureMonthsAlert = true
                    }
                    .disabled(newCategoryAmount <= 0)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getInstructionText() -> String {
        if existingCategories.isEmpty {
            return "Create categories for your imported data"
        } else {
            return "Map imported categories to existing ones or create new categories"
        }
    }
    
    private func getBlockingMessage() -> String {
        if !isMappingComplete {
            return "All categories must be mapped before importing"
        } else if hasValidationErrors {
            return "Fix validation errors before proceeding"
        } else {
            return ""
        }
    }
    
    private func getValidationSummary() -> String {
        let errors = validationErrors.values.joined(separator: "\n• ")
        return "Please fix these issues:\n• \(errors)"
    }
    
    private func estimatedBudgetAmount() -> Double {
        guard let category = selectedCategoryToCreate,
              let categoryData = categoriesWithCounts.first(where: { $0.category == category }) else {
            return 100.0
        }
        
        // Estimate monthly budget as 1.2x the imported amount (20% buffer)
        let estimatedAmount = categoryData.totalAmount * 1.2
        
        // Round to nearest 50 for cleaner amounts
        return max(50.0, (estimatedAmount / 50).rounded() * 50)
    }
    
    private func validateInitialState() {
        // Validate import data
        for data in importedData {
            if data.amount <= 0 {
                validationErrors[data.category] = "Invalid transaction amount"
            }
            if data.category.isEmpty {
                validationErrors[data.category] = "Empty category name"
            }
        }
    }
    
    private func validateCategory(_ category: String) -> String? {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCategory.isEmpty {
            return "Category name cannot be empty"
        }
        
        if trimmedCategory.count > AppConstants.Validation.maxCategoryNameLength {
            return "Category name is too long"
        }
        
        // Check for special characters
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        if trimmedCategory.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return "Category name contains invalid characters"
        }
        
        return nil
    }
    
    private func mapCategory(_ category: String, to existingCategory: String) {
        // Clear any validation error
        validationErrors.removeValue(forKey: category)
        
        // Validate the mapping
        if let error = validateCategory(existingCategory) {
            validationErrors[category] = error
            return
        }
        
        categoryMappings[category] = existingCategory
        processedCategories.insert(category)
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func unmapCategory(_ category: String) {
        categoryMappings.removeValue(forKey: category)
        processedCategories.remove(category)
        validationErrors.removeValue(forKey: category)
    }
    
    private func prepareToCreateNewCategory(_ category: String) {
        selectedCategoryToCreate = category
        newCategoryAmount = estimatedBudgetAmount()
        showingNewCategorySheet = true
    }
    
    private func cancelNewCategoryCreation() {
        selectedCategoryToCreate = nil
        newCategoryAmount = 0
        showingNewCategorySheet = false
    }
    
    private func createNewCategory(includeFutureMonths: Bool) {
        guard let category = selectedCategoryToCreate else { return }
        
       Task<Void, Never>{
            await performCategoryCreation(category: category, includeFutureMonths: includeFutureMonths)
        }
    }
    
    private func performCategoryCreation(category: String, includeFutureMonths: Bool) async {
        isProcessing = true
        progressMessage = "Creating category '\(category)'..."
        showingProgressView = true
        completionPercentage = 0.0
        
        do {
            // Validate category
            if let error = validateCategory(category) {
                throw AppError.validation(message: error)
            }
            
            completionPercentage = 0.3
            
            // Create the category
            try await budgetManager.addCategory(
                name: category,
                amount: newCategoryAmount,
                month: currentMonth,
                year: currentYear
            )
            
            completionPercentage = 0.8
            progressMessage = "Mapping category..."
            
            await MainActor.run {
                categoryMappings[category] = category
                processedCategories.insert(category)
                selectedCategoryToCreate = nil
                newCategoryAmount = 0
                validationErrors.removeValue(forKey: category)
                completionPercentage = 1.0
            }
            
            // Delay to show completion
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                showingNewCategorySheet = false
                showingProgressView = false
                isProcessing = false
            }
            
        } catch {
            await MainActor.run {
                validationErrors[category] = error.localizedDescription
                showingProgressView = false
                isProcessing = false
                
                errorHandler.handle(
                    AppError.from(error),
                    context: "Creating new category '\(category)'"
                )
            }
        }
    }
    
    private func retryValidation(for category: String) {
        validationErrors.removeValue(forKey: category)
        
        // Re-validate the category mapping if it exists
        if let mappedCategory = categoryMappings[category] {
            if let error = validateCategory(mappedCategory) {
                validationErrors[category] = error
            }
        }
    }
    
    private func handleCancellation() {
        if isProcessing {
            cancelProcessing()
        } else {
            dismiss()
        }
    }
    
    private func cancelProcessing() {
        isProcessing = false
        showingProgressView = false
        progressMessage = ""
        completionPercentage = 0.0
    }
    
    private func handleImportAction() {
        guard canProceed else { return }
        
       Task<Void, Never>{
            await performImport()
        }
    }
    
    private func performImport() async {
        isProcessing = true
        progressMessage = "Preparing import..."
        showingProgressView = true
        completionPercentage = 0.0
        
        do {
            // Final validation
            guard isMappingComplete else {
                throw AppError.validation(message: "All categories must be mapped before importing")
            }
            
            completionPercentage = 0.2
            progressMessage = "Validating mappings..."
            
            // Validate all mappings
            for (original, mapped) in categoryMappings {
                if let error = validateCategory(mapped) {
                    throw AppError.validation(message: "Invalid mapping for '\(original)': \(error)")
                }
            }
            
            completionPercentage = 0.5
            progressMessage = "Processing import..."
            
            // Create import results
            let importResults = CSVImport.ImportResults(
                data: importedData,
                categories: categories,
                existingCategories: Set(budgetManager.getAvailableCategories()).intersection(categories),
                newCategories: categories.subtracting(Set(budgetManager.getAvailableCategories())),
                totalAmount: totalImportAmount
            )
            
            completionPercentage = 0.8
            progressMessage = "Saving data..."
            
            // Process the import
            try await budgetManager.processImportedPurchases(importResults, categoryMappings: categoryMappings)
            
            completionPercentage = 1.0
            progressMessage = "Import complete!"
            
            // Delay to show completion
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                onComplete(categoryMappings)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                showingProgressView = false
                isProcessing = false
                
                errorHandler.handle(
                    AppError.from(error),
                    context: "Completing category mapping import"
                )
            }
        }
    }
    
    private func refreshData() async {
        // Refresh available categories from budget manager
        // This could be useful if categories were added externally
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func retryFailedOperations() async {
        // Clear errors and retry any failed operations
        await MainActor.run {
            validationErrors.removeAll()
            isProcessing = false
            showingProgressView = false
        }
        
        // Re-validate all current mappings
        for (original, mapped) in categoryMappings {
            if let error = validateCategory(mapped) {
                validationErrors[original] = error
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CategoryMappingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal case with existing categories
            CategoryMappingView(
                categories: ["Groceries", "Entertainment", "Transportation", "Dining Out"],
                importedData: [
                    CSVImport.PurchaseImportData(date: "2024-01-01", amount: 50.0, category: "Groceries", note: "Weekly shopping"),
                    CSVImport.PurchaseImportData(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: "Movie tickets"),
                    CSVImport.PurchaseImportData(date: "2024-01-03", amount: 25.0, category: "Transportation", note: "Gas"),
                    CSVImport.PurchaseImportData(date: "2024-01-04", amount: 45.0, category: "Dining Out", note: "Restaurant")
                ],
                onComplete: { mappings in
                    print("Preview: Completed with mappings: \(mappings)")
                }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .previewDisplayName("With Existing Categories")
            
            // No existing categories case
            CategoryMappingView(
                categories: ["New Category 1", "New Category 2"],
                importedData: [
                    CSVImport.PurchaseImportData(date: "2024-01-01", amount: 100.0, category: "New Category 1", note: nil),
                    CSVImport.PurchaseImportData(date: "2024-01-02", amount: 75.0, category: "New Category 2", note: nil)
                ],
                onComplete: { _ in }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .previewDisplayName("No Existing Categories")
            
            // Dark mode
            CategoryMappingView(
                categories: ["Groceries", "Entertainment"],
                importedData: [
                    CSVImport.PurchaseImportData(date: "2024-01-01", amount: 50.0, category: "Groceries", note: nil),
                    CSVImport.PurchaseImportData(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: nil)
                ],
                onComplete: { _ in }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // Large dataset
            CategoryMappingView(
                categories: Set((1...10).map { "Category \($0)" }),
                importedData: (1...50).map { index in
                    CSVImport.PurchaseImportData(
                        date: "2024-01-\(String(format: "%02d", (index % 28) + 1))",
                        amount: Double.random(in: 10...200),
                        category: "Category \((index % 10) + 1)",
                        note: "Transaction \(index)"
                    )
                },
                onComplete: { _ in }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .previewDisplayName("Large Dataset")
        }
    }
}

// MARK: - Mock Data for Previews

extension BudgetManager {
    static func createMockForPreviews() -> BudgetManager {
        let manager = BudgetManager.shared
        // In a real implementation, you might want to inject test data
        return manager
    }
}
#endif

extension ThemeManager {
    static func createMockForPreviews() -> ThemeManager {
        return ThemeManager.shared
    }
}

// MARK: - Testing Support

#if DEBUG
extension CategoryMappingView {
    /// Create test instance with mock data
    static func createTestInstance() -> CategoryMappingView {
        return CategoryMappingView(
            categories: ["Test Category 1", "Test Category 2"],
            importedData: [
                CSVImport.PurchaseImportData(date: "2024-01-01", amount: 100.0, category: "Test Category 1", note: "Test"),
                CSVImport.PurchaseImportData(date: "2024-01-02", amount: 50.0, category: "Test Category 2", note: "Test")
            ],
            onComplete: { mappings in
                print("Test: Completed with \(mappings.count) mappings")
            }
        )
    }
    
    /// Simulate error states for testing
    func simulateErrorState() {
        validationErrors = [
            "Test Category": "Test validation error",
            "Another Category": "Another test error"
        ]
    }
    
    /// Simulate processing state for testing
    func simulateProcessingState() {
        isProcessing = true
        showingProgressView = true
        progressMessage = "Test processing..."
        completionPercentage = 0.5
    }
    
    /// Get current state for testing validation
    func getCurrentStateForTesting() -> (
        mappedCount: Int,
        unmappedCount: Int,
        errorCount: Int,
        canProceed: Bool,
        isProcessing: Bool
    ) {
        return (
            mappedCount: mappedCategories.count,
            unmappedCount: unmappedCategories.count,
            errorCount: validationErrors.count,
            canProceed: canProceed,
            isProcessing: isProcessing
        )
    }
}
#endif