//
//  EditCategoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//
import SwiftUI

struct EditCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var monthlyBudgets: [Int: [String: Double]]
    let initialCategory: String
    let month: Int
    let year: Int
    var onUpdate: (String, String, Double) -> Void
    var onDelete: (String) -> Void
    
    @State private var categoryName: String
    @State private var amount: Double
    @State private var showingDeleteAlert = false

    init(monthlyBudgets: Binding<[Int: [String: Double]]>, initialCategory: String, month: Int, year: Int, onUpdate: @escaping (String, String, Double) -> Void, onDelete: @escaping (String) -> Void) {
        self._monthlyBudgets = monthlyBudgets
        self.initialCategory = initialCategory
        self.month = month
        self.year = year
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        
        _categoryName = State(initialValue: initialCategory)
        _amount = State(initialValue: monthlyBudgets.wrappedValue[month]?[initialCategory] ?? 0)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Category Details")) {
                TextField("Category Name", text: $categoryName)
                HStack {
                    Text("$")
                    TextField("Amount", value: $amount, formatter: NumberFormatter.currency)
                        .keyboardType(.decimalPad)
                }
            }
            
            Section {
                Button("Delete Category") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Category")
        .navigationBarItems(trailing: Button("Save") {
            saveChanges()
        })
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Category"),
                message: Text("Are you sure you want to delete this category?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteCategory()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func saveChanges() {
        onUpdate(initialCategory, categoryName, amount)
        dismiss()
    }
    
    private func deleteCategory() {
        onDelete(initialCategory)
        dismiss()
    }
}

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
