//
//  PurchaseEntryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved validation, and better UX
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
    
    var body: some View {
        NavigationView {
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
                        Task {
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
                        Task {
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
