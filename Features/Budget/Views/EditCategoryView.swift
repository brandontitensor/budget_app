//
//  EditCategoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

/// View for editing budget categories with validation and error handling
struct EditCategoryView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Properties
    let monthlyBudgets: [Int: [String: Double]]
    let initialCategory: String
    let month: Int
    let year: Int
    let onUpdate: (String, String, Double) -> Void
    
    // MARK: - State
    @State private var categoryName: String
    @State private var amount: Double
    @State private var showingDeleteAlert = false
    @State private var showingFutureDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingCalculator = false
    @State private var isProcessing = false
    
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
    
    // MARK: - Computed Properties
    private var isValidInput: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        amount > 0 &&
        amount <= AppConstants.Validation.maximumTransactionAmount
    }
    
    // MARK: - Body
    var body: some View {
        Form {
            categoryDetailsSection
            deleteSection
        }
        .navigationTitle("Edit Category")
        .navigationBarItems(
            trailing: Button("Save") {
                saveChanges()
            }
            .disabled(!isValidInput || isProcessing)
        )
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .actionSheet(isPresented: $showingDeleteAlert) {
            deleteConfirmationSheet
        }
        .alert("Delete Future Months?", isPresented: $showingFutureDeleteAlert) {
            Button("This month only") {
                handleDelete(includeFutureMonths: false)
            }
            Button("All future months") {
                handleDelete(includeFutureMonths: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to delete this category for future months as well?")
        }
        .sheet(isPresented: $showingCalculator) {
            MoneyCalculatorView(amount: $amount)
        }
        .overlay {
            if isProcessing {
                loadingOverlay
            }
        }
    }
    
    // MARK: - View Components
    private var categoryDetailsSection: some View {
        Section(header: Text("Category Details")) {
            TextField("Category Name", text: $categoryName)
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .onChange(of: categoryName) { oldValue, newValue in
                    if newValue.count > AppConstants.Validation.maxCategoryNameLength {
                        categoryName = String(newValue.prefix(AppConstants.Validation.maxCategoryNameLength))
                    }
                }
                .accessibilityLabel("Category name")
            
            HStack {
                Text(amount.asCurrency)
                    .foregroundColor(amount > 0 ? .primary : .secondary)
                Spacer()
                Button("Edit") {
                    showingCalculator = true
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Category amount: \(amount.asCurrency)")
            .accessibilityHint("Double tap to edit amount")
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Category")
                    Spacer()
                }
            }
            .accessibilityLabel("Delete category")
        }
    }
    
    private var deleteConfirmationSheet: ActionSheet {
        ActionSheet(
            title: Text("Delete Category"),
            message: Text("Are you sure you want to delete this category? All purchases in this category will be moved to 'Uncategorized'."),
            buttons: [
                .destructive(Text("Delete")) {
                    showingFutureDeleteAlert = true
                },
                .cancel()
            ]
        )
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
            ProgressView("Saving changes...")
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    private func saveChanges() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a category name"
            showingAlert = true
            return
        }
        
        guard amount > 0 else {
            alertMessage = "Please enter a valid amount"
            showingAlert = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                try await validateCategory(trimmedName)
                await MainActor.run {
                    onUpdate(initialCategory, trimmedName, amount)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func validateCategory(_ name: String) async throws {
        // Validate that the new name doesn't conflict with existing categories
        if name != initialCategory && monthlyBudgets[month]?.keys.contains(name) == true {
            throw ValidationError.duplicateCategory
        }
    }
    
    private func handleDelete(includeFutureMonths: Bool) {
        isProcessing = true
        
        Task {
            do {
                try await budgetManager.deleteMonthlyBudget(
                    category: initialCategory,
                    fromMonth: month,
                    year: year,
                    includeFutureMonths: includeFutureMonths
                )
                await MainActor.run {
                    onUpdate(initialCategory, initialCategory, 0)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Supporting Types
private enum ValidationError: LocalizedError {
    case duplicateCategory
    
    var errorDescription: String? {
        switch self {
        case .duplicateCategory:
            return "A category with this name already exists"
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct EditCategoryView_Previews: PreviewProvider {
    static var previews: some View {
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
        }
        .previewDisplayName("Light Mode")
        
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
            .preferredColorScheme(.dark)
        }
        .previewDisplayName("Dark Mode")
    }
}
#endif
