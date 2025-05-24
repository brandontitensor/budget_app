//
//  CategoryMappingView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/29/24.
//
import SwiftUI
import Foundation


/// View for mapping imported categories to existing categories or creating new ones
struct CategoryMappingView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Properties
    let categories: Set<String>
    let importedData: [BudgetManager.PurchaseImportData]
    let onComplete: ([String: String]) -> Void
    
    // MARK: - State
    @State private var categoryMappings: [String: String] = [:]
    @State private var selectedCategoryToCreate: String?
    @State private var newCategoryAmount: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingCalculator = false
    @State private var showingNewCategorySheet = false
    @State private var showingFutureMonthsAlert = false
    @State private var isProcessing = false
    
    // MARK: - Computed Properties
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var existingCategories: [String] {
        budgetManager.getAvailableCategories()
    }
    
    private var isMappingComplete: Bool {
        categories.allSatisfy { category in
            categoryMappings[category] != nil ||
            (selectedCategoryToCreate == category && showingNewCategorySheet)
        }
    }
    
    private var totalImportAmount: Double {
        importedData.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                instructionsHeader
                
                if isProcessing {
                    loadingView
                } else {
                    List {
                        if existingCategories.isEmpty {
                            newCategoriesSection
                        } else {
                            if !categories.isEmpty {
                                mappingSection
                                newCategoriesSection
                            }
                        }
                        
                        previewSection
                    }
                }
            }
            .navigationTitle("Map Categories")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Import") { completeMapping() }
                    .disabled(!isMappingComplete || isProcessing)
            )
            .sheet(isPresented: $showingNewCategorySheet) {
                createNewCategorySheet
            }
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $newCategoryAmount)
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Add to Future Months?", isPresented: $showingFutureMonthsAlert) {
                Button("This month only") {
                    createNewCategory(includeFutureMonths: false)
                }
                Button("All future months") {
                    createNewCategory(includeFutureMonths: true)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to add this category to future months as well?")
            }
        }
    }
    
    // MARK: - View Components
    private var instructionsHeader: some View {
        VStack(spacing: 8) {
            Text(existingCategories.isEmpty ?
                "Create categories for your imported data" :
                "Map your imported categories to existing ones or create new categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !isMappingComplete {
                Text("All categories must be mapped before importing")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var loadingView: some View {
        ProgressView("Processing categories...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mappingSection: some View {
        Section(header: Text("Map to Existing Categories")) {
            ForEach(Array(categories), id: \.self) { category in
                if categoryMappings[category] == nil {
                    mappingRow(for: category)
                }
            }
        }
    }
    
    private var newCategoriesSection: some View {
        Section(header: Text("Create New Categories")) {
            ForEach(Array(categories), id: \.self) { category in
                if categoryMappings[category] == nil {
                    Button(action: {
                        selectedCategoryToCreate = category
                        newCategoryAmount = 0
                        showingNewCategorySheet = true
                    }) {
                        HStack {
                            Text(category)
                            Spacer()
                            Text("Create New")
                                .foregroundColor(themeManager.primaryColor)
                        }
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        Section(header: Text("Import Preview")) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(categories.count) categories to map")
                    .foregroundColor(.secondary)
                Text("\(importedData.count) transactions to import")
                    .foregroundColor(.secondary)
                Text("Total amount: \(NumberFormatter.formatCurrency(totalImportAmount))")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func mappingRow(for category: String) -> some View {
        HStack {
            Text(category)
            Spacer()
            Picker("Select Category", selection: Binding(
                get: { categoryMappings[category] ?? category },
                set: { categoryMappings[category] = $0 }
            )) {
                Text("Select a category").tag(category)
                ForEach(existingCategories, id: \.self) { existingCategory in
                    Text(existingCategory).tag(existingCategory)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var createNewCategorySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("New Category Details")) {
                    if let category = selectedCategoryToCreate {
                        Text("Category Name: \(category)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(newCategoryAmount.asCurrency)
                        Spacer()
                        Button("Edit Amount") {
                            showingCalculator = true
                        }
                    }
                }
                
                Section(
                    header: Text("Note"),
                    footer: Text("This budget will apply starting from the current month")
                ) {
                    Text("The category will be created and added to your budget categories.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Category")
            .navigationBarItems(
                leading: Button("Cancel") { showingNewCategorySheet = false },
                trailing: Button("Create") { showingFutureMonthsAlert = true }
                    .disabled(newCategoryAmount <= 0)
            )
        }
    }
    
    // MARK: - Helper Methods
    private func createNewCategory(includeFutureMonths: Bool) {
        guard let category = selectedCategoryToCreate else { return }
        
        isProcessing = true
        
        Task {
            do {
                try await budgetManager.addCategory(
                    category,
                    amount: newCategoryAmount,
                    month: currentMonth,
                    year: currentYear,
                    includeFutureMonths: includeFutureMonths
                )
                
                await MainActor.run {
                    categoryMappings[category] = category
                    selectedCategoryToCreate = nil
                    newCategoryAmount = 0
                    showingNewCategorySheet = false
                    isProcessing = false
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
    
    private func completeMapping() {
        guard isMappingComplete else {
            alertMessage = "Please map all categories before importing"
            showingAlert = true
            return
        }
        
        onComplete(categoryMappings)
        dismiss()
    }
}

// MARK: - Preview Provider
#if DEBUG
struct CategoryMappingView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryMappingView(
            categories: ["Groceries", "Entertainment", "Transportation"],
            importedData: [
                .init(date: "2024-01-01", amount: 50.0, category: "Groceries", note: nil),
                .init(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: nil)
            ],
            onComplete: { _ in }
        )
        .environmentObject(BudgetManager.shared)
        .environmentObject(ThemeManager.shared)
        .previewDisplayName("Light Mode")
        
        CategoryMappingView(
            categories: ["Groceries", "Entertainment", "Transportation"],
            importedData: [
                .init(date: "2024-01-01", amount: 50.0, category: "Groceries", note: nil),
                .init(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: nil)
            ],
            onComplete: { _ in }
        )
        .environmentObject(BudgetManager.shared)
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
#endif
