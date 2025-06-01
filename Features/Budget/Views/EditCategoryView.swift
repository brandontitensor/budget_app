//
//  EditCategoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling and improved UX
//
import SwiftUI

/// View for editing budget categories with enhanced validation, error handling, and user experience
struct EditCategoryView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    // MARK: - Properties
    let monthlyBudgets: [Int: [String: Double]]
    let initialCategory: String
    let month: Int
    let year: Int
    let onUpdate: (String, String, Double) -> Void
    
    // MARK: - State
    @State private var categoryName: String
    @State private var amount: Double
    @State private var showingDeleteConfirmation = false
    @State private var showingFutureDeleteOptions = false
    @State private var showingCalculator = false
    @State private var isProcessing = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardChangesAlert = false
    
    // MARK: - Derived State
    private var isValidInput: Bool {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
               amount > 0 &&
               amount <= AppConstants.Validation.maximumTransactionAmount &&
               (trimmedName == initialCategory || !categoryAlreadyExists(trimmedName))
    }
    
    private var canDelete: Bool {
        !AppConstants.DefaultCategories.required.contains(initialCategory)
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date)
    }
    
    // MARK: - Initialization
    init(
        monthlyBudgets: [Int: [String: Double]],
        initialCategory: String,
        month: Int,
        year: Int,
        onUpdate: @escaping (String, String, Double) -> Void
    ) {
        self.monthlyBudgets = monthlyBudgets
        self.initialCategory = initialCategory
        self.month = month
        self.year = year
        self.onUpdate = onUpdate
        
        // Initialize state
        _categoryName = State(initialValue: initialCategory)
        _amount = State(initialValue: monthlyBudgets[month]?[initialCategory] ?? 0)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    categoryDetailsSection
                    categoryInfoSection
                    if canDelete {
                        deleteSection
                    }
                }
                .navigationTitle("Edit Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            handleCancelAction()
                        }
                        .disabled(isProcessing)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            handleSaveAction()
                        }
                        .disabled(!isValidInput || isProcessing || !hasChangesToSave)
                        .fontWeight(.semibold)
                    }
                }
                .onChange(of: categoryName) { _, _ in
                    updateChangeStatus()
                }
                .onChange(of: amount) { _, _ in
                    updateChangeStatus()
                }
                .sheet(isPresented: $showingCalculator) {
                    MoneyCalculatorView(amount: $amount)
                }
                .confirmationDialog(
                    "Delete Category",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        showingFutureDeleteOptions = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete '\(initialCategory)'? All purchases in this category will be moved to 'Uncategorized'.")
                }
                .confirmationDialog(
                    "Delete Future Months?",
                    isPresented: $showingFutureDeleteOptions,
                    titleVisibility: .visible
                ) {
                    Button("This month only") {
                        handleDelete(includeFutureMonths: false)
                    }
                    Button("All future months", role: .destructive) {
                        handleDelete(includeFutureMonths: true)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Do you want to delete this category for future months as well?")
                }
                .alert(
                    "Discard Changes?",
                    isPresented: $showingDiscardChangesAlert
                ) {
                    Button("Discard", role: .destructive) {
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You have unsaved changes. Are you sure you want to discard them?")
                }
                .errorAlert(onRetry: {
                    // Retry the last failed operation
                    Task { await retryLastOperation() }
                })
                
                // Loading overlay
                if isProcessing {
                    loadingOverlay
                }
            }
        }
        .handleErrors(context: "Edit Category")
        .interactiveDismissDisabled(hasUnsavedChanges)
    }
    
    // MARK: - View Components
    private var categoryDetailsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Category Name Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter category name", text: $categoryName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .onChange(of: categoryName) { oldValue, newValue in
                            if newValue.count > AppConstants.Validation.maxCategoryNameLength {
                                categoryName = String(newValue.prefix(AppConstants.Validation.maxCategoryNameLength))
                            }
                        }
                        .accessibilityLabel("Category name")
                    
                    if categoryAlreadyExists(categoryName) && categoryName != initialCategory {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("A category with this name already exists")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Amount Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Budget Amount")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(amount.asCurrency)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(amount > 0 ? themeManager.primaryColor : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Edit") {
                            showingCalculator = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(themeManager.primaryColor)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Budget amount: \(amount.asCurrency)")
                    .accessibilityHint("Double tap to edit amount")
                }
                
                // Validation Messages
                if !isValidInput && amount > 0 && !categoryName.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if amount > AppConstants.Validation.maximumTransactionAmount {
                            validationMessage(
                                icon: "exclamationmark.triangle.fill",
                                text: "Amount exceeds maximum limit of \(AppConstants.Validation.maximumTransactionAmount.asCurrency)",
                                color: .red
                            )
                        }
                        
                        if categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            validationMessage(
                                icon: "exclamationmark.circle.fill",
                                text: "Category name is required",
                                color: .red
                            )
                        }
                    }
                }
            }
        } header: {
            Text("Category Details")
        } footer: {
            Text("Changes will apply to \(monthYearText) and can optionally be applied to future months.")
        }
    }
    
    private var categoryInfoSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Month")
                        .font(.subheadline.weight(.medium))
                    Text(monthYearText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.subheadline.weight(.medium))
                    Text(hasChangesToSave ? "Modified" : "Saved")
                        .font(.caption)
                        .foregroundColor(hasChangesToSave ? .orange : .green)
                }
            }
            .padding(.vertical, 4)
            
            if !canDelete {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                    Text("This is a required category and cannot be deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Information")
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Category")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isProcessing)
            .accessibilityLabel("Delete category")
        } footer: {
            Text("Deleting this category will move all associated purchases to 'Uncategorized'. This action cannot be undone.")
        }
    }
    
    private func validationMessage(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(themeManager.primaryColor)
                
                Text("Saving changes...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Helper Methods
    private var hasChangesToSave: Bool {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalAmount = monthlyBudgets[month]?[initialCategory] ?? 0
        
        return trimmedName != initialCategory || amount != originalAmount
    }
    
    private func updateChangeStatus() {
        hasUnsavedChanges = hasChangesToSave
    }
    
    private func categoryAlreadyExists(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return monthlyBudgets[month]?.keys.contains(trimmedName) == true
    }
    
    private func handleCancelAction() {
        if hasUnsavedChanges {
            showingDiscardChangesAlert = true
        } else {
            dismiss()
        }
    }
    
    private func handleSaveAction() {
        Task {
            await saveChanges()
        }
    }
    
    // MARK: - Data Operations
    
    @MainActor
    private func saveChanges() async {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Final validation
        guard !trimmedName.isEmpty else {
            errorHandler.handle(.validation(message: "Please enter a category name"), context: "Saving category")
            return
        }
        
        guard amount > 0 else {
            errorHandler.handle(.validation(message: "Please enter a valid amount"), context: "Saving category")
            return
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            errorHandler.handle(.validation(message: "Amount exceeds maximum limit"), context: "Saving category")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let result = await AsyncErrorHandler.execute(
            context: "Saving category changes"
        ) {
            try await validateCategoryName(trimmedName)
            return true
        }
        
        if result != nil {
            onUpdate(initialCategory, trimmedName, amount)
            dismiss()
        }
    }
    
    private func validateCategoryName(_ name: String) async throws {
        // Validate that the new name doesn't conflict with existing categories
        if name != initialCategory && categoryAlreadyExists(name) {
            throw AppError.validation(message: "A category with this name already exists")
        }
    }
    
    @MainActor
    private func handleDelete(includeFutureMonths: Bool) {
        isProcessing = true
        
        Task {
            defer {
                Task { @MainActor in
                    isProcessing = false
                }
            }
            
            let result = await AsyncErrorHandler.execute(
                context: "Deleting budget category"
            ) {
                try await budgetManager.deleteMonthlyBudget(
                    category: initialCategory,
                    fromMonth: month,
                    year: year,
                    includeFutureMonths: includeFutureMonths
                )
                return true
            }
            
            if result != nil {
                await MainActor.run {
                    onUpdate(initialCategory, initialCategory, 0)
                    dismiss()
                }
            }
        }
    }
    
    private func retryLastOperation() async {
        // This would retry the last failed operation
        // Could be implemented based on the specific error context
        print("Retrying last operation...")
    }
}

// MARK: - Preview Provider
#if DEBUG
struct EditCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Regular category
            NavigationView {
                EditCategoryView(
                    monthlyBudgets: [
                        1: ["Groceries": 500.0, "Entertainment": 200.0]
                    ],
                    initialCategory: "Groceries",
                    month: 1,
                    year: 2024,
                    onUpdate: { _, _, _ in }
                )
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
            }
            .previewDisplayName("Regular Category")
            
            // Required category (can't delete)
            NavigationView {
                EditCategoryView(
                    monthlyBudgets: [
                        1: ["Housing": 1200.0, "Food": 400.0]
                    ],
                    initialCategory: "Housing",
                    month: 1,
                    year: 2024,
                    onUpdate: { _, _, _ in }
                )
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
            }
            .previewDisplayName("Required Category")
            
            // Dark mode
            NavigationView {
                EditCategoryView(
                    monthlyBudgets: [
                        1: ["Groceries": 500.0, "Entertainment": 200.0]
                    ],
                    initialCategory: "Groceries",
                    month: 1,
                    year: 2024,
                    onUpdate: { _, _, _ in }
                )
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
