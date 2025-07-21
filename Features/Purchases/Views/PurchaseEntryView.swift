//
//  PurchaseEntryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import Combine

/// Enhanced purchase entry view with comprehensive error handling and improved user experience
struct PurchaseEntryView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var amount = ""
    @State private var selectedCategory = ""
    @State private var selectedDate = Date()
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    
    // MARK: - Error State
    @State private var validationErrors: [ValidationError] = []
    @State private var submissionError: AppError?
    @State private var showingErrorDetails = false
    @State private var retryCount = 0
    private let maxRetries = 3
    
    // MARK: - Category Management
    @State private var availableCategories: [String] = []
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var isLoadingCategories = false
    @State private var categoryError: AppError?
    
    // MARK: - Focus State
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let successFeedback = UINotificationFeedbackGenerator()
    private let errorFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Types
    private struct ValidationError: Identifiable {
        let id = UUID()
        let field: String
        let message: String
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return validationErrors.isEmpty && !amount.isEmpty && !selectedCategory.isEmpty
    }
    
    private var canSubmit: Bool {
        return isFormValid && !isSubmitting
    }
    
    private var formattedAmount: String {
        guard let value = Double(amount), value > 0 else { return "" }
        return NumberFormatter.formatCurrency(value)
    }
    
    private var hasValidationErrors: Bool {
        return !validationErrors.isEmpty
    }
    
    private var shouldShowDiscardAlert: Bool {
        return hasUnsavedChanges && (!amount.isEmpty || !selectedCategory.isEmpty || !note.isEmpty)
    }
    
    // MARK: - Body
    
    private var contentView: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if isSubmitting {
                submittingOverlay
            } else {
                mainContent
            }
        }
    }
    
    var body: some View {
        NavigationView {
            contentView
            .navigationTitle("Add Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancelAction()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                       Task<Void, Never>{
                            await submitPurchase()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Purchase Error", isPresented: $showingErrorDetails, presenting: submissionError) { error in
                if error.isRetryable && retryCount < maxRetries {
                    Button("Retry") {
                       Task<Void, Never>{
                            await submitPurchase()
                        }
                    }
                }
                Button("OK", role: .cancel) {
                    clearSubmissionError()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.errorDescription ?? "Failed to add purchase")
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
            .alert("Add Category", isPresented: $showingNewCategoryAlert) {
                TextField("Category name", text: $newCategoryName)
                Button("Add") {
                    addNewCategory()
                }
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text("Enter a name for the new category")
            }
        }
    }
    
    // MARK: - View Components
    
    private var submittingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text("Adding Purchase...")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount input section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("0.00", text: $amount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                }
                
                // Category selection section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Select category", text: $selectedCategory)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Date selection section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    DatePicker("Purchase Date", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
                
                // Note section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (Optional)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Add a note...", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .focused($isNoteFocused)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func addNewCategory() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        Task<Void, Never>{
            try? await budgetManager.addCategory(
                name: newCategoryName,
                amount: 0,
                month: currentMonth,
                year: currentYear
            )
        }
        newCategoryName = ""
        showingNewCategoryAlert = false
    }
    
    private func handleCancelAction() {
        if shouldShowDiscardAlert {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func submitPurchase() async {
        guard isFormValid else { return }
        
        await MainActor.run {
            isSubmitting = true
            hasUnsavedChanges = false
            validationErrors.removeAll()
        }
        
        do {
            guard let amountValue = Double(amount) else {
                throw AppError.validation(message: "Invalid amount entered")
            }
            
            let entry = try BudgetEntry(
                amount: amountValue,
                category: selectedCategory,
                date: selectedDate,
                note: note.isEmpty ? nil : note
            )
            
            try await budgetManager.addEntry(entry)
            
            await MainActor.run {
                successFeedback.notificationOccurred(.success)
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                submissionError = AppError.from(error)
                showingErrorDetails = true
                retryCount += 1
                isSubmitting = false
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    private func clearSubmissionError() {
        submissionError = nil
        showingErrorDetails = false
    }
}
