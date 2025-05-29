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
    let importedData: [CSVImport.PurchaseImportData]
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
            categoryMappings[category] != nil
        }
    }
    
    private var totalImportAmount: Double {
        importedData.reduce(0) { $0 + $1.amount }
    }
    
    private var categoriesWithCounts: [(category: String, count: Int, totalAmount: Double)] {
        let groupedData = Dictionary(grouping: importedData) { $0.category }
        return categories.map { category in
            let transactions = groupedData[category] ?? []
            let totalAmount = transactions.reduce(0) { $0 + $1.amount }
            return (category: category, count: transactions.count, totalAmount: totalAmount)
        }.sorted { $0.category < $1.category }
    }
    
    // MARK: - Initialization
    init(
        categories: Set<String>,
        importedData: [CSVImport.PurchaseImportData],
        onComplete: @escaping ([String: String]) -> Void
    ) {
        self.categories = categories
        self.importedData = importedData
        self.onComplete = onComplete
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
                        importSummarySection
                        
                        if !existingCategories.isEmpty {
                            mappingSection
                        }
                        
                        newCategoriesSection
                        previewSection
                    }
                }
            }
            .navigationTitle("Map Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        completeMapping()
                    }
                    .disabled(!isMappingComplete || isProcessing)
                    .fontWeight(.semibold)
                }
            }
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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(themeManager.primaryColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category Mapping")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(existingCategories.isEmpty ?
                        "Create categories for your imported data" :
                        "Map imported categories to existing ones or create new categories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            if !isMappingComplete {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("All categories must be mapped before importing")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Processing categories...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var importSummarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Summary")
                            .font(.headline)
                        Text("\(importedData.count) transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(totalImportAmount.asCurrency)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryColor)
                        Text("Total Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(categoriesWithCounts, id: \.category) { item in
                        HStack {
                            Text(item.category)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(item.totalAmount.asCurrency)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var mappingSection: some View {
        Section(header: Text("Map to Existing Categories")) {
            ForEach(Array(categories).sorted(), id: \.self) { category in
                if categoryMappings[category] == nil {
                    mappingRow(for: category)
                }
            }
        }
    }
    
    private var newCategoriesSection: some View {
        Section(header: Text("Create New Categories")) {
            ForEach(Array(categories).sorted(), id: \.self) { category in
                if categoryMappings[category] == nil {
                    Button(action: {
                        selectedCategoryToCreate = category
                        newCategoryAmount = estimateBudgetAmount(for: category)
                        showingNewCategorySheet = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category)
                                    .foregroundColor(.primary)
                                
                                if let categoryData = categoriesWithCounts.first(where: { $0.category == category }) {
                                    Text("\(categoryData.count) transactions • \(categoryData.totalAmount.asCurrency)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("Create New")
                                .font(.subheadline)
                                .foregroundColor(themeManager.primaryColor)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        Section(header: Text("Mapping Preview")) {
            ForEach(Array(categoryMappings.keys).sorted(), id: \.self) { originalCategory in
                if let mappedCategory = categoryMappings[originalCategory] {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(originalCategory)
                                .font(.subheadline)
                                .strikethrough(originalCategory != mappedCategory)
                                .foregroundColor(originalCategory != mappedCategory ? .secondary : .primary)
                            
                            if originalCategory != mappedCategory {
                                Text("→ \(mappedCategory)")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.primaryColor)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Change") {
                            categoryMappings[originalCategory] = nil
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func mappingRow(for category: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.subheadline)
                
                if let categoryData = categoriesWithCounts.first(where: { $0.category == category }) {
                    Text("\(categoryData.count) transactions • \(categoryData.totalAmount.asCurrency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                ForEach(existingCategories, id: \.self) { existingCategory in
                    Button(existingCategory) {
                        categoryMappings[category] = existingCategory
                    }
                }
            } label: {
                HStack {
                    Text("Select Category")
                        .foregroundColor(themeManager.primaryColor)
                    Image(systemName: "chevron.down")
                        .foregroundColor(themeManager.primaryColor)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var createNewCategorySheet: some View {
        NavigationView {
            Form {
                Section(header: Text("New Category Details")) {
                    if let category = selectedCategoryToCreate {
                        HStack {
                            Text("Category Name")
                            Spacer()
                            Text(category)
                                .foregroundColor(.secondary)
                        }
                        
                        if let categoryData = categoriesWithCounts.first(where: { $0.category == category }) {
                            HStack {
                                Text("Import Data")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(categoryData.count) transactions")
                                        .font(.subheadline)
                                    Text(categoryData.totalAmount.asCurrency)
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text("Budget Amount")
                        Spacer()
                        Button(newCategoryAmount.asCurrency) {
                            showingCalculator = true
                        }
                        .foregroundColor(themeManager.primaryColor)
                    }
                }
                
                Section(
                    header: Text("Budget Settings"),
                    footer: Text("This budget will apply starting from the current month (\(Calendar.current.monthSymbols[currentMonth - 1]) \(currentYear))")
                ) {
                    Text("The category will be created and added to your budget categories with the specified amount.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNewCategorySheet = false
                        selectedCategoryToCreate = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        showingFutureMonthsAlert = true
                    }
                    .disabled(newCategoryAmount <= 0)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func estimateBudgetAmount(for category: String) -> Double {
        guard let categoryData = categoriesWithCounts.first(where: { $0.category == category }) else {
            return 100.0 // Default amount
        }
        
        // Estimate monthly budget as 1.2x the imported amount (20% buffer)
        let estimatedAmount = categoryData.totalAmount * 1.2
        
        // Round to nearest 50 for cleaner amounts
        return (estimatedAmount / 50).rounded() * 50
    }
    
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
        
        isProcessing = true
        
        Task {
            let importResults = CSVImport.ImportResults(
                data: importedData,
                categories: categories,
                existingCategories: Set(budgetManager.getAvailableCategories()).intersection(categories),
                newCategories: categories.subtracting(Set(budgetManager.getAvailableCategories())),
                totalAmount: totalImportAmount
            )
            
            do {
                try await budgetManager.processImportedPurchases(importResults, categoryMappings: categoryMappings)
                
                await MainActor.run {
                    onComplete(categoryMappings)
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

// MARK: - Preview Provider
#if DEBUG
struct CategoryMappingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With existing categories
            CategoryMappingView(
                categories: ["Groceries", "Entertainment", "Transportation", "Dining Out"],
                importedData: [
                    CSVImport.PurchaseImportData(date: "2024-01-01", amount: 50.0, category: "Groceries", note: "Weekly shopping"),
                    CSVImport.PurchaseImportData(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: "Movie tickets"),
                    CSVImport.PurchaseImportData(date: "2024-01-03", amount: 25.0, category: "Transportation", note: "Gas"),
                    CSVImport.PurchaseImportData(date: "2024-01-04", amount: 45.0, category: "Dining Out", note: "Restaurant")
                ],
                onComplete: { _ in }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .previewDisplayName("With Existing Categories")
            
            // Dark mode
            CategoryMappingView(
                categories: ["Groceries", "Entertainment"],
                importedData: [
                    CSVImport.PurchaseImportData(date: "2024-01-01", amount: 50.0, category: "Groceries", note: nil),
                    CSVImport.PurchaseImportData(date: "2024-01-02", amount: 30.0, category: "Entertainment", note: nil)
                ],
                onComplete: { _ in }
            )
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
