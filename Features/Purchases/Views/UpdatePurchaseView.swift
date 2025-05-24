//
//  UpdatePurchaseView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//
import SwiftUI

/// View for updating existing purchase transactions
struct UpdatePurchaseView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Properties
    private let originalEntry: BudgetEntry
    private let onUpdate: (BudgetEntry) -> Void
    private let onDelete: () -> Void
    
    // MARK: - State
    @State private var editedEntry: EditableBudgetEntry
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingCalculator = false
    @State private var isProcessing = false
    
    // MARK: - Private Properties
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private var isValidInput: Bool {
        editedEntry.amount > 0 &&
        !editedEntry.category.isEmpty &&
        editedEntry.note.count <= AppConstants.Data.maxTransactionNoteLength
    }
    
    // MARK: - Initialization
    init(
        transaction: BudgetEntry,
        onUpdate: @escaping (BudgetEntry) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.originalEntry = transaction
        self._editedEntry = State(initialValue: EditableBudgetEntry(entry: transaction))
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                amountSection
                categorySection
                dateSection
                noteSection
                deleteSection
            }
            .navigationTitle("Edit Purchase")
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .actionSheet(isPresented: $showingDeleteConfirmation) {
                deleteConfirmationSheet
            }
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $editedEntry.amount)
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - View Components
    private var amountSection: some View {
        Section(header: Text("Amount")) {
            HStack {
                Text(currencyFormatter.string(from: NSNumber(value: editedEntry.amount)) ?? "$0.00")
                    .foregroundColor(editedEntry.amount > 0 ? .primary : .secondary)
                Spacer()
                Button("Edit") {
                    showingCalculator = true
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Amount: \(currencyFormatter.string(from: NSNumber(value: editedEntry.amount)) ?? "$0.00")")
            .accessibilityHint("Double tap to edit amount")
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("Category")) {
            Picker("Category", selection: $editedEntry.category) {
                ForEach(availableCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .accessibilityLabel("Select category")
        }
    }
    
    private var dateSection: some View {
        Section(header: Text("Date")) {
            DatePicker(
                "Date",
                selection: $editedEntry.date,
                in: ...Date(),
                displayedComponents: .date
            )
            .accessibilityLabel("Select date")
        }
    }
    
    private var noteSection: some View {
        Section(
            header: Text("Note"),
            footer: Group {
                if !editedEntry.note.isEmpty {
                    Text("\(editedEntry.note.count)/\(AppConstants.Data.maxTransactionNoteLength) characters")
                }
            }
        ) {
            TextField("Optional note", text: $editedEntry.note)
                .onChange(of: editedEntry.note) { oldValue, newValue in
                    if newValue.count > AppConstants.Data.maxTransactionNoteLength {
                        editedEntry.note = String(newValue.prefix(AppConstants.Data.maxTransactionNoteLength))
                    }
                }
                .accessibilityLabel("Add note (optional)")
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Purchase")
                    Spacer()
                }
            }
            .accessibilityLabel("Delete purchase")
        }
    }
    
    private var deleteConfirmationSheet: ActionSheet {
        ActionSheet(
            title: Text("Delete Purchase"),
            message: Text("Are you sure you want to delete this purchase? This action cannot be undone."),
            buttons: [
                .destructive(Text("Delete")) {
                    Task {
                        await deletePurchase()
                    }
                },
                .cancel()
            ]
        )
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .accessibilityLabel("Cancel editing purchase")
    }
    
    private var saveButton: some View {
        Button("Save") {
            Task {
                await updatePurchase()
            }
        }
        .disabled(!isValidInput || isProcessing)
        .accessibilityLabel("Save changes")
        .accessibilityHint(isValidInput ? "Double tap to save" : "Form is incomplete")
    }
    
    // MARK: - Helper Properties
    private var availableCategories: [String] {
        let categories = budgetManager.getAvailableCategories()
        return categories.isEmpty ? ["Uncategorized"] : categories
    }
    
    // MARK: - Helper Methods
    private func updatePurchase() async {
        guard isValidInput else {
            alertMessage = "Please enter a valid amount and category."
            showingAlert = true
            return
        }
        
        isProcessing = true
        
        do {
            let updatedEntry = try BudgetEntry(
                id: originalEntry.id,
                amount: editedEntry.amount,
                category: editedEntry.category,
                date: editedEntry.date,
                note: editedEntry.note.isEmpty ? nil : editedEntry.note
            )
            
            try await budgetManager.updateEntry(updatedEntry)
            onUpdate(updatedEntry)
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isProcessing = false
    }
    
    private func deletePurchase() async {
        isProcessing = true
        
        do {
            try await budgetManager.deleteEntry(originalEntry)
            onDelete()
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isProcessing = false
    }
}

// MARK: - Supporting Types
struct EditableBudgetEntry {
    var amount: Double
    var category: String
    var date: Date
    var note: String
    
    init(entry: BudgetEntry) {
        self.amount = entry.amount
        self.category = entry.category
        self.date = entry.date
        self.note = entry.note ?? "" 
    }
}
// MARK: - Preview Provider
#if DEBUG
struct UpdatePurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        UpdatePurchaseView(
            transaction: BudgetEntry.mock(
                amount: 42.50,
                category: "Groceries",
                date: Date(),
                note: "Weekly shopping"
            ),
            onUpdate: { _ in },
            onDelete: { }
        )
        .environmentObject(BudgetManager.shared)
        .environmentObject(ThemeManager.shared)
        
        UpdatePurchaseView(
            transaction: BudgetEntry.mock(
                amount: 99.99,
                category: "Entertainment",
                date: Date()
            ),
            onUpdate: { _ in },
            onDelete: { }
        )
        .environmentObject(BudgetManager.shared)
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
    }
}
#endif
