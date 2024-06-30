//
//  UpdatePurchaseView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//
import SwiftUI

struct UpdatePurchaseView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var editedEntry: EditableBudgetEntry
    let originalEntry: BudgetEntry
    let onUpdate: (BudgetEntry) -> Void
    let onDelete: () -> Void
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    
    init(transaction: BudgetEntry, onUpdate: @escaping (BudgetEntry) -> Void, onDelete: @escaping () -> Void) {
        self.originalEntry = transaction
        self._editedEntry = State(initialValue: EditableBudgetEntry(entry: transaction))
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
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
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { updatePurchase() }
                    .disabled(!isValidInput)
            )
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .actionSheet(isPresented: $showingDeleteConfirmation) {
                ActionSheet(
                    title: Text("Delete Purchase"),
                    message: Text("Are you sure you want to delete this purchase? This action cannot be undone."),
                    buttons: [
                        .destructive(Text("Delete")) {
                            onDelete()
                            dismiss()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private var amountSection: some View {
        Section(header: Text("Amount")) {
            HStack {
                Text("$")
                TextField("0.00", value: $editedEntry.amount, formatter: numberFormatter)
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("Category")) {
            Picker("Category", selection: $editedEntry.category) {
                ForEach(availableCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section(header: Text("Date")) {
            DatePicker("Date", selection: $editedEntry.date, displayedComponents: .date)
        }
    }
    
    private var noteSection: some View {
        Section(header: Text("Note")) {
            TextField("Optional note", text: $editedEntry.note)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Text("Delete Purchase")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var availableCategories: [String] {
        let categories = budgetManager.getAvailableCategories()
        return categories.isEmpty ? ["Uncategorized"] : categories
    }
    
    private var isValidInput: Bool {
        editedEntry.amount > 0 && !editedEntry.category.isEmpty
    }
    
    private func updatePurchase() {
        guard isValidInput else {
            alertMessage = "Please enter a valid amount and category."
            showingAlert = true
            return
        }
        
        let updatedEntry = BudgetEntry(
            id: originalEntry.id,
            amount: editedEntry.amount,
            category: editedEntry.category,
            date: editedEntry.date,
            note: editedEntry.note.isEmpty ? nil : editedEntry.note
        )
        
        onUpdate(updatedEntry)
        dismiss()
    }
}

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

struct UpdatePurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = BudgetEntry(amount: 50.0, category: "Groceries", date: Date(), note: "Weekly shopping")
        UpdatePurchaseView(transaction: sampleEntry, onUpdate: {_ in }, onDelete: {})
            .environmentObject(BudgetManager())
            .environmentObject(ThemeManager())
    }
}
