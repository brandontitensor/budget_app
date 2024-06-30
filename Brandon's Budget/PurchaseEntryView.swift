//
//  DataEntryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

struct PurchaseEntryView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var amount: Double = 0
    @State private var category: String = ""
    @State private var date = Date()
    @State private var note: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
            }
            .navigationTitle("Add Purchase")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { savePurchase() }
                    .disabled(!isValidInput)
            )
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var amountSection: some View {
        Section(header: Text("Amount")) {
            HStack {
                Text("$")
                TextField("0.00", value: $amount, formatter: numberFormatter)
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    private var categorySection: some View {
        Section(header: Text("Category")) {
            Picker("Category", selection: $category) {
                ForEach(availableCategories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section(header: Text("Date")) {
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    }
    
    private var noteSection: some View {
        Section(header: Text("Note")) {
            TextField("Optional note", text: $note)
        }
    }
    
    private var availableCategories: [String] {
        let categories = budgetManager.getAvailableCategories()
        return categories.isEmpty ? ["Uncategorized"] : categories
    }
    
    private var isValidInput: Bool {
        amount > 0 
    }
    
    private func savePurchase() {
        guard isValidInput else {
            alertMessage = "Please enter a valid amount and category."
            showingAlert = true
            return
        }
        
        let newEntry = BudgetEntry(
            amount: amount,
            category: category,
            date: date,
            note: note.isEmpty ? nil : note
        )
        
        budgetManager.addEntry(newEntry)
        dismiss()
    }
}

struct PurchaseEntryView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseEntryView()
            .environmentObject(BudgetManager())
            .environmentObject(ThemeManager())
    }
}
