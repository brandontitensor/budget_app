//
//  UpdatePurchaseView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import Combine

/// Enhanced purchase update view with comprehensive error handling and improved user experience
struct UpdatePurchaseView: View {
    // MARK: - Properties
    let entry: BudgetEntry
    
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var amount: String
    @State private var selectedCategory: String
    @State private var selectedDate: Date
    @State private var note: String
    @State private var isSubmitting = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingDeleteAlert = false
    
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
    
    // MARK: - Original Values (for change detection)
    private let originalAmount: String
    private let originalCategory: String
    private let originalDate: Date
    private let originalNote: String
    
    // MARK: - Types
    private struct ValidationError: Identifiable {
        let id = UUID()
        let field: String
        let message: String
    }
    
    // MARK: - Initialization
    init(entry: BudgetEntry) {
        self.entry = entry
        self.originalAmount = String(entry.amount)
        self.originalCategory = entry.category
        self.originalDate = entry.date
        self.originalNote = entry.note ?? ""
        
        // Initialize state
        self._amount = State(initialValue: String(entry.amount))
        self._selectedCategory = State(initialValue: entry.category)
        self._selectedDate = State(initialValue: entry.date)
        self._note = State(initialValue: entry.note ?? "")
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return validationErrors.isEmpty && !amount.isEmpty && !selectedCategory.isEmpty
    }
    
    private var canSubmit: Bool {
        return isFormValid && hasUnsavedChanges && !isSubmitting
    }
    
    private var formattedAmount: String {
        guard let value = Double(amount), value > 0 else { return "" }
        return NumberFormatter.formatCurrency(value)
    }
    
    private var hasValidationErrors: Bool {
        return !validationErrors.isEmpty
    }
    
    private var shouldShowDiscardAlert: Bool {
        return hasUnsavedChanges
    }
    
    private var canDelete: Bool {
        return !isSubmitting
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
            .navigationTitle("Edit Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancelAction()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(!canDelete)
                    
                    Button("Save") {
                       Task<Void, Never>{
                            await updatePurchase()
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
            .alert("Delete Purchase", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                   Task<Void, Never>{
                        await deletePurchase()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this purchase? This action cannot be undone.")
            }
            .alert("Purchase Error", isPresented: $showingErrorDetails, presenting: submissionError) { error in
                if error.isRetryable && retryCount < maxRetries {
                    Button("Retry") {
                       Task<Void, Never>{
                            await updatePurchase()
                        }
                    }
                }
                Button("OK", role: .cancel) {
                    clearSubmissionError()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.errorDescription ?? "Failed to update purchase")
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
            .onAppear {
                setupView()
            }
            .onChange(of: amount) { _, _ in
                validateAmount()
                updateUnsavedChangesState()
            }
            .onChange(of: selectedCategory) { _, _ in
                validateCategory()
                updateUnsavedChangesState()
            }
            .onChange(of: selectedDate) { _, _ in
                updateUnsavedChangesState()
            }
            .onChange(of: note) { _, _ in
                validateNote()
                updateUnsavedChangesState()
            }
            .errorAlert(onRetry: {
               Task<Void, Never>{
                    await retryLastOperation()
                }
            })
        }
    }
    
    // MARK: - View Components
    
    private var submittingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text("Updating Purchase...")
                .font(.headline)
                .foregroundColor(.primary)
            
            if retryCount > 0 {
                Text("Retry attempt \(retryCount) of \(maxRetries)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).opacity(0.8))
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Original purchase info
                originalPurchaseInfo
                
                // Error banner
                if let error = submissionError {
                    InlineErrorView(
                        error: error,
                        onDismiss: { clearSubmissionError() },
                        onRetry: error.isRetryable ? {
                           Task<Void, Never>{ await updatePurchase() }
                        } : nil
                    )
                    .padding(.horizontal)
                }
                
                // Form sections
                VStack(spacing: 16) {
                    amountSection
                    categorySection
                    dateSection
                    noteSection
                }
                .padding(.horizontal)
                
                // Validation errors
                if hasValidationErrors {
                    validationErrorsSection
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var originalPurchaseInfo: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Original Purchase")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Category icon
                Circle()
                    .fill(themeManager.colorForCategory(entry.category))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: categoryIcon(for: entry.category))
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .semibold))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let originalNote = entry.note, !originalNote.isEmpty {
                        Text(originalNote)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.formattedAmount)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryColor)
                    
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Amount")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !formattedAmount.isEmpty {
                    Text(formattedAmount)
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.semibold)
                }
            }
            
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isAmountFocused)
                .font(.title2)
                .multilineTextAlignment(.center)
                .onReceive(Just(amount)) { _ in
                    formatAmountInput()
                }
            
            if let error = validationErrors.first(where: { $0.field == "amount" }) {
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoadingCategories {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button("New") {
                    showingNewCategoryAlert = true
                }
                .font(.subheadline)
                .foregroundColor(themeManager.primaryColor)
            }
            
            if categoryError != nil {
                Text("Failed to load categories")
                    .font(.subheadline)
                    .foregroundColor(.red)
            } else if availableCategories.isEmpty {
                Text("No categories available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        HStack {
                            Image(systemName: categoryIcon(for: category))
                                .foregroundColor(themeManager.colorForCategory(category))
                            Text(category)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.primaryColor)
            }
            
            if let error = validationErrors.first(where: { $0.field == "category" }) {
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.headline)
                .foregroundColor(.primary)
            
            DatePicker(
                "Purchase Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .tint(themeManager.primaryColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (Optional)")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Add a note about this purchase...", text: $note, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isNoteFocused)
                .lineLimit(3...6)
            
            if let error = validationErrors.first(where: { $0.field == "note" }) {
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var validationErrorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Please fix the following issues:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            ForEach(validationErrors) { error in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "minus")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Setup and Lifecycle
    
    private func setupView() {
        loadCategories()
        updateUnsavedChangesState()
    }
    
    private func loadCategories() {
        isLoadingCategories = true
        categoryError = nil
        
        // Simulate async loading with slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                let categories = budgetManager.getAvailableCategories()
                availableCategories = categories.isEmpty ? AppConstants.DefaultCategories.all : categories
                isLoadingCategories = false
                
                // Ensure current category is in the list
                if !availableCategories.contains(selectedCategory) {
                    availableCategories.append(selectedCategory)
                    availableCategories.sort()
                }
            } catch {
                categoryError = AppError.from(error)
                isLoadingCategories = false
                
                // Fallback to default categories plus current category
                availableCategories = AppConstants.DefaultCategories.all
                if !availableCategories.contains(selectedCategory) {
                    availableCategories.append(selectedCategory)
                    availableCategories.sort()
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private func validateForm() {
        validationErrors.removeAll()
        
        validateAmount()
        validateCategory()
        validateNote()
    }
    
    private func validateAmount() {
        validationErrors.removeAll { $0.field == "amount" }
        
        guard !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrors.append(ValidationError(field: "amount", message: "Amount is required"))
            return
        }
        
        guard let value = Double(amount) else {
            validationErrors.append(ValidationError(field: "amount", message: "Please enter a valid amount"))
            return
        }
        
        guard value > 0 else {
            validationErrors.append(ValidationError(field: "amount", message: "Amount must be greater than zero"))
            return
        }
        
        guard value <= AppConstants.Validation.maximumTransactionAmount else {
            validationErrors.append(ValidationError(field: "amount", message: "Amount exceeds maximum allowed (\(AppConstants.Validation.maximumTransactionAmount.asCurrency))"))
            return
        }
    }
    
    private func validateCategory() {
        validationErrors.removeAll { $0.field == "category" }
        
        guard !selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrors.append(ValidationError(field: "category", message: "Please select a category"))
            return
        }
    }
    
    private func validateNote() {
        validationErrors.removeAll { $0.field == "note" }
        
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedNote.count > AppConstants.Data.maxTransactionNoteLength {
            validationErrors.append(ValidationError(field: "note", message: "Note is too long (max \(AppConstants.Data.maxTransactionNoteLength) characters)"))
        }
    }
    
    // MARK: - Input Formatting
    
    private func formatAmountInput() {
        // Remove any non-numeric characters except decimal point
        let filtered = amount.filter { "0123456789.".contains($0) }
        
        // Ensure only one decimal point
        let components = filtered.components(separatedBy: ".")
        if components.count > 2 {
            amount = components[0] + "." + components[1...].joined()
        } else {
            amount = filtered
        }
        
        // Limit decimal places to 2
        if let decimalIndex = amount.firstIndex(of: ".") {
            let afterDecimal = amount[amount.index(after: decimalIndex)...]
            if afterDecimal.count > 2 {
                let validDecimal = String(afterDecimal.prefix(2))
                amount = String(amount[...decimalIndex]) + validDecimal
            }
        }
        
        // Limit total length
        if amount.count > 10 {
            amount = String(amount.prefix(10))
        }
    }
    
    // MARK: - Change Detection
    
    private func updateUnsavedChangesState() {
        let currentNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalNoteForComparison = originalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        
        hasUnsavedChanges = (
            amount != originalAmount ||
            selectedCategory != originalCategory ||
            !Calendar.current.isDate(selectedDate, inSameDayAs: originalDate) ||
            currentNote != originalNoteForComparison
        )
    }
    
    // MARK: - Actions
    
    private func handleCancelAction() {
        if shouldShowDiscardAlert {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func updatePurchase() async {
        // Validate form first
        validateForm()
        
        guard isFormValid else {
            if settingsManager.enableHapticFeedback {
                errorFeedback.notificationOccurred(.error)
            }
            return
        }
        
        await MainActor.run {
            isSubmitting = true
            clearSubmissionError()
        }
        
        do {
            guard let amountValue = Double(amount) else {
                throw AppError.validation(message: "Invalid amount format")
            }
            
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalNote = trimmedNote.isEmpty ? nil : trimmedNote
            
            let updatedEntry = try BudgetEntry(
                id: entry.id,
                amount: amountValue,
                category: selectedCategory,
                date: selectedDate,
                note: finalNote
            )
            
            try await budgetManager.updateEntry(updatedEntry)
            
            await MainActor.run {
                // Success feedback
                if settingsManager.enableHapticFeedback {
                    successFeedback.notificationOccurred(.success)
                }
                
                // Reset retry count
                retryCount = 0
                
                // Dismiss view
                dismiss()
            }
            
        } catch {
            await handleSubmissionError(AppError.from(error))
        }
    }
    
    private func deletePurchase() async {
        await MainActor.run {
            isSubmitting = true
            clearSubmissionError()
        }
        
        do {
            try await budgetManager.deleteEntry(entry)
            
            await MainActor.run {
                // Success feedback
                if settingsManager.enableHapticFeedback {
                    successFeedback.notificationOccurred(.success)
                }
                
                // Reset retry count
                retryCount = 0
                
                // Dismiss view
                dismiss()
            }
            
        } catch {
            await handleSubmissionError(AppError.from(error))
        }
    }
    
    private func handleSubmissionError(_ error: AppError) async {
        await MainActor.run {
            isSubmitting = false
            submissionError = error
            showingErrorDetails = true
            retryCount += 1
            
            if settingsManager.enableHapticFeedback {
                errorFeedback.notificationOccurred(.error)
            }
            
            // Also report to global error handler
            errorHandler.handle(error, context: "Updating purchase")
        }
    }
    
    private func clearSubmissionError() {
        submissionError = nil
    }
    
    private func retryLastOperation() async {
        await updatePurchase()
    }
    
    private func addNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        guard trimmedName.count <= AppConstants.Validation.maxCategoryNameLength else { return }
        guard !availableCategories.contains(trimmedName) else { return }
        
        availableCategories.append(trimmedName)
        availableCategories.sort()
        selectedCategory = trimmedName
        newCategoryName = ""
        
        // Mark as having unsaved changes
        updateUnsavedChangesState()
        
        if settingsManager.enableHapticFeedback {
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Helper Methods
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "groceries", "food": return "cart.fill"
        case "transportation", "transport": return "car.fill"
        case "entertainment": return "gamecontroller.fill"
        case "utilities": return "bolt.fill"
        case "healthcare", "medical": return "cross.fill"
        case "shopping": return "bag.fill"
        case "dining", "restaurant": return "fork.knife"
        case "education": return "book.fill"
        case "savings": return "banknote.fill"
        case "housing": return "house.fill"
        case "insurance": return "shield.fill"
        case "personal care": return "figure.walk"
        default: return "creditcard.fill"
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct UpdatePurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = try! BudgetEntry(
            amount: 45.67,
            category: "Groceries",
            date: Date(),
            note: "Weekly shopping at the local grocery store"
        )
        
        Group {
            // Normal state
            UpdatePurchaseView(entry: sampleEntry)
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Normal State")
            
            // Dark mode
            UpdatePurchaseView(entry: sampleEntry)
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Entry without note
            UpdatePurchaseView(entry: try! BudgetEntry(
                amount: 25.00,
                category: "Transportation",
                date: Date(),
                note: nil
            ))
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("No Note")
        }
    }
}
#endif
