//
//  DataEntryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
import Combine

/// View for entering new purchase transactions with validation and error handling
struct PurchaseEntryView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var amount: Double = 0
    @State private var category: String = ""
    @State private var date = Date()
    @State private var note: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
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
        amount > 0 &&
        !category.isEmpty &&
        note.count <= AppConstants.Data.maxTransactionNoteLength
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                amountSection
                categorySection
                dateSection
                noteSection
                
                if isProcessing {
                    ProgressView("Saving purchase...")
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Purchase")
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .disabled(isProcessing)
            .onAppear(perform: setupInitialState)
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $amount)
            }
        }
    }
    
    // MARK: - View Components
    private var amountSection: some View {
        Section(header: Text("Amount")) {
            HStack {
                Text(currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0.00")
                    .foregroundColor(amount > 0 ? .primary : .secondary)
                Spacer()
                Button("Edit") {
                    showingCalculator = true
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Amount: \(currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0.00")")
            .accessibilityHint("Double tap to edit amount")
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("Category")) {
            Picker("Category", selection: $category) {
                ForEach(availableCategories, id: \.self) { category in
                    Text(category)
                        .tag(category)
                }
            }
            .accessibilityLabel("Select category")
        }
    }
    
    private var dateSection: some View {
        Section(header: Text("Date")) {
            DatePicker(
                "Date",
                selection: $date,
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
                if !note.isEmpty {
                    Text("\(note.count)/\(AppConstants.Data.maxTransactionNoteLength) characters")
                }
            }
        ) {
            TextField("Optional note", text: $note)
                .onChange(of: note) { oldValue, newValue in
                    if newValue.count > AppConstants.Data.maxTransactionNoteLength {
                        note = String(newValue.prefix(AppConstants.Data.maxTransactionNoteLength))
                    }
                }
                .accessibilityLabel("Add note (optional)")
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .accessibilityLabel("Cancel adding purchase")
    }
    
    private var saveButton: some View {
        Button("Save") {
            Task {
                await savePurchase()
            }
        }
        .disabled(!isValidInput || isProcessing)
        .accessibilityLabel("Save purchase")
        .accessibilityHint(isValidInput ? "Double tap to save" : "Form is incomplete")
    }
    
    // MARK: - Helper Properties
    private var availableCategories: [String] {
        let categories = budgetManager.getAvailableCategories()
        return categories.isEmpty ? ["Uncategorized"] : categories
    }
    
    // MARK: - Helper Methods
    private func setupInitialState() {
        if let firstCategory = availableCategories.first {
            category = firstCategory
        }
    }
    
    private func savePurchase() async {
        guard isValidInput else {
            alertMessage = "Please enter a valid amount and category."
            showingAlert = true
            return
        }
        
        isProcessing = true
        
        do {
            let entry = try BudgetEntry(
                amount: amount,
                category: category,
                date: date,
                note: note.isEmpty ? nil : note
            )
            
            try await budgetManager.addEntry(entry)
            dismiss()
        } catch BudgetEntry.ValidationError.invalidAmount {
            alertMessage = "Please enter a valid amount."
            showingAlert = true
        } catch BudgetEntry.ValidationError.invalidCategory {
            alertMessage = "Please select a valid category."
            showingAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isProcessing = false
    }
}

// MARK: - Preview Provider
#if DEBUG
struct PurchaseEntryView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseEntryView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
        
        PurchaseEntryView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
