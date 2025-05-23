//
//  BudgetView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

/// View for managing monthly budgets and categories
struct BudgetView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyBudgets: [Int: [String: Double]] = [:]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryAmount: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingFutureAddAlert = false
    @State private var showingFutureChangeAlert = false
    @State private var showingFutureYearAlert = false
    @State private var changedCategory = ""
    @State private var changedAmount: Double = 0
    @State private var showingYearPicker = false
    @State private var showingCalculator = false
    @State private var isProcessing = false
    
    // MARK: - Properties
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    init() {
        let currentDate = Date()
        let calendar = Calendar.current
        _selectedYear = State(initialValue: calendar.component(.year, from: currentDate))
        _selectedMonth = State(initialValue: calendar.component(.month, from: currentDate))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                yearSection
                monthTabs
                
                if isProcessing {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summarySection
                            categoriesSection
                            addCategoryButton
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Update Budget")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { saveBudgets() }
                    .disabled(isProcessing)
            )
            .onAppear(perform: loadCurrentBudgets)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAddCategory) {
                addCategorySheet
            }
            .alert("Update Future Months?", isPresented: $showingFutureChangeAlert) {
                Button("Yes") { updateFutureMonths() }
                Button("No", role: .cancel) { }
            } message: {
                Text("Do you want to apply this change to future months of the current year?")
            }
            .alert("Load Current Year's Budget?", isPresented: $showingFutureYearAlert) {
                Button("Yes") { loadCurrentYearBudget() }
                Button("No", role: .cancel) { }
            } message: {
                Text("Do you want to load the current year's budget into this future year?")
            }
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $newCategoryAmount)
            }
        }
    }
    
    // MARK: - View Components
    private var yearSection: some View {
        VStack(spacing: 8) {
            Button(action: { showingYearPicker = true }) {
                HStack {
                    Text(String(selectedYear))
                        .font(.title2)
                        .fontWeight(.bold)
                    Image(systemName: "chevron.down")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Text("Total Yearly Budget: \(totalYearlyBudget.asCurrency)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var monthTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(1...12, id: \.self) { month in
                        monthTab(month: month)
                            .id(month)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .center)
            }
        }
    }
    
    private func monthTab(month: Int) -> some View {
        VStack {
            Text(monthName(month))
                .font(.caption)
            Text(totalMonthlyBudget(for: month).asCurrency)
                .font(.caption2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(month == selectedMonth ? themeManager.primaryColor : Color.gray.opacity(0.2))
        .foregroundColor(month == selectedMonth ? .white : .primary)
        .cornerRadius(8)
        .onTapGesture {
            withAnimation {
                selectedMonth = month
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budget Summary")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Monthly Budget")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(totalMonthlyBudget(for: selectedMonth).asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Categories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(monthlyBudgets[selectedMonth]?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var categoriesSection: some View {
        ForEach(Array(monthlyBudgets[selectedMonth, default: [:]]
            .sorted(by: { $0.key < $1.key })), id: \.key) { category, amount in
            NavigationLink(destination: EditCategoryView(
                monthlyBudgets: monthlyBudgets,
                initialCategory: category,
                month: selectedMonth,
                year: selectedYear,
                onUpdate: { oldCategory, newCategory, newAmount in
                    updateCategory(oldCategory: oldCategory, newCategory: newCategory, newAmount: newAmount)
                }
            )) {
                BudgetCategoryRow(category: category, amount: amount)
            }
        }
    }
    
    private var addCategoryButton: some View {
        Button(action: { showingAddCategory = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Category")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.primaryColor.opacity(0.1))
            .foregroundColor(themeManager.primaryColor)
            .cornerRadius(10)
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading budgets...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Add Category Sheet
        private var addCategorySheet: some View {
            NavigationView {
                Form {
                    Section(header: Text("New Category Details")) {
                        TextField("Category Name", text: $newCategoryName)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                            .onChange(of: newCategoryName) { newValue in
                                if newValue.count > AppConstants.Validation.maxCategoryNameLength {
                                    newCategoryName = String(newValue.prefix(AppConstants.Validation.maxCategoryNameLength))
                                }
                            }
                        
                        HStack {
                            Text(newCategoryAmount.asCurrency)
                                .foregroundColor(newCategoryAmount > 0 ? .primary : .secondary)
                            Spacer()
                            Button("Edit") {
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
                .navigationTitle("Add Category")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        resetNewCategoryFields()
                        showingAddCategory = false
                    },
                    trailing: Button("Add") {
                        validateAndAddCategory()
                    }
                    .disabled(!isValidNewCategory)
                )
            }
        }
        
        // MARK: - Helper Methods
        private func monthName(_ month: Int) -> String {
            calendar.monthSymbols[month - 1]
        }
        
        private var totalYearlyBudget: Double {
            monthlyBudgets.values.reduce(0) { total, categoryBudgets in
                total + categoryBudgets.values.reduce(0, +)
            }
        }
        
        private func totalMonthlyBudget(for month: Int) -> Double {
            monthlyBudgets[month, default: [:]].values.reduce(0, +)
        }
        
        private var isValidNewCategory: Bool {
            !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            newCategoryAmount > 0 &&
            newCategoryAmount <= AppConstants.Validation.maximumTransactionAmount
        }
        
        private func loadCurrentBudgets() {
            isProcessing = true
            monthlyBudgets = [:]
            
            for month in 1...12 {
                let budgets = budgetManager.getMonthlyBudgets(for: month, year: selectedYear)
                monthlyBudgets[month] = Dictionary(
                    uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) }
                )
            }
            
            isProcessing = false
        }
        
        private func validateAndAddCategory() {
            let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedName.isEmpty else {
                alertMessage = "Please enter a category name."
                showingAlert = true
                return
            }
            
            guard newCategoryAmount > 0 else {
                alertMessage = "Please enter a valid amount."
                showingAlert = true
                return
            }
            
            if monthlyBudgets[selectedMonth]?[trimmedName] != nil {
                alertMessage = "This category already exists."
                showingAlert = true
                return
            }
            
            showingFutureAddAlert = true
        }
        
        private func addCategory(includeFutureMonths: Bool) async {
            isProcessing = true
            
            do {
                try await budgetManager.addCategory(
                    newCategoryName,
                    amount: newCategoryAmount,
                    month: selectedMonth,
                    year: selectedYear,
                    includeFutureMonths: includeFutureMonths
                )
                
                await MainActor.run {
                    if includeFutureMonths {
                        for month in selectedMonth...12 {
                            monthlyBudgets[month, default: [:]][newCategoryName] = newCategoryAmount
                        }
                    } else {
                        monthlyBudgets[selectedMonth, default: [:]][newCategoryName] = newCategoryAmount
                    }
                    
                    resetNewCategoryFields()
                    showingAddCategory = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
            
            isProcessing = false
        }
        
        private func updateCategory(oldCategory: String, newCategory: String, newAmount: Double) {
            var updatedBudget = monthlyBudgets[selectedMonth] ?? [:]
            updatedBudget[oldCategory] = nil
            updatedBudget[newCategory] = newAmount
            monthlyBudgets[selectedMonth] = updatedBudget
            
            changedCategory = newCategory
            changedAmount = newAmount
            showingFutureChangeAlert = true
        }
        
        private func updateFutureMonths() {
            for month in selectedMonth...12 {
                var updatedBudget = monthlyBudgets[month] ?? [:]
                if changedAmount == 0 {
                    updatedBudget[changedCategory] = nil
                } else {
                    updatedBudget[changedCategory] = changedAmount
                }
                monthlyBudgets[month] = updatedBudget
            }
        }
        
        private func loadCurrentYearBudget() {
            let currentYear = calendar.component(.year, from: Date())
            for month in 1...12 {
                let currentYearBudgets = budgetManager.getMonthlyBudgets(for: month, year: currentYear)
                monthlyBudgets[month] = Dictionary(
                    uniqueKeysWithValues: currentYearBudgets.map { ($0.category, $0.amount) }
                )
            }
        }
        
        private func saveBudgets() {
            isProcessing = true
            
            Task {
                do {
                    // Update each month's budgets
                    for (month, budgets) in monthlyBudgets {
                        try await budgetManager.updateMonthlyBudgets(
                            budgets,
                            for: month,
                            year: selectedYear
                        )
                    }
                    
                    await MainActor.run {
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
        
        private func resetNewCategoryFields() {
            newCategoryName = ""
            newCategoryAmount = 0
        }
    }

    // MARK: - Year Picker View
    private struct YearPickerView: View {
        @Binding var selectedYear: Int
        let onDismiss: () -> Void
        let onYearSelected: (Int) -> Void
        
        private let currentYear = Calendar.current.component(.year, from: Date())
        private let yearRange: ClosedRange<Int> = {
            let currentYear = Calendar.current.component(.year, from: Date())
            return (currentYear - 2)...(currentYear + 5)
        }()
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(yearRange, id: \.self) { year in
                        Button(action: {
                            selectedYear = year
                            onYearSelected(year)
                            onDismiss()
                        }) {
                            HStack {
                                Text(String(year))
                                Spacer()
                                if year == selectedYear {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Select Year")
                .navigationBarItems(trailing: Button("Cancel", action: onDismiss))
            }
        }
    }

    // MARK: - Preview Provider
    #if DEBUG
    struct BudgetView_Previews: PreviewProvider {
        static var previews: some View {
            BudgetView()
                .environmentObject(BudgetManager())
                .environmentObject(ThemeManager())
            
            BudgetView()
                .environmentObject(BudgetManager())
                .environmentObject(ThemeManager())
                .preferredColorScheme(.dark)
        }
    }
    #endif
