//
//  UpdatedBudgetView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
struct UpdateBudgetView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyBudgets: [Int: [String: Double]] = [:]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryAmount: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingFutureChangeAlert = false
    @State private var showingFutureYearAlert = false
    @State private var changedCategory = ""
    @State private var changedAmount: Double = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showingYearPicker = false
    
    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        self._selectedYear = State(initialValue: currentYear)
        self._selectedMonth = State(initialValue: currentMonth)
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                yearSection
                monthTabs
                ScrollView {
                    VStack(spacing: 20) {
                        summarySection
                        categoriesSection
                        addCategoryButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Update Budget")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { saveBudgets() }
            )
            .onAppear(perform: loadCurrentBudgets)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingAddCategory) {
                addCategoryView
            }
            .alert("Update Future Months?", isPresented: $showingFutureChangeAlert) {
                Button("Yes") { updateFutureMonths() }
                Button("No", role: .cancel) {}
            } message: {
                Text("Do you want to apply this change to future months of the current year?")
            }
            .alert("Load Current Year's Budget?", isPresented: $showingFutureYearAlert) {
                Button("Yes") { loadCurrentYearBudget() }
                Button("No", role: .cancel) {}
            } message: {
                Text("Do you want to load the current year's budget into this future year?")
            }
            .sheet(isPresented: $showingYearPicker) {
                yearPickerView
            }
        }
    }
    
    private var yearSection: some View {
        VStack(spacing: 8) {
            yearButton
            Text("Total Yearly Budget: $\(totalYearlyBudget, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
        }
        .padding(.bottom, 8)
    }
    
    private var yearButton: some View {
        Button(action: {
            showingYearPicker = true
        }) {
            HStack {
                Text(yearString)
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
        .padding(.horizontal)
    }
    
    private var yearString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter.string(from: NSNumber(value: selectedYear)) ?? String(selectedYear)
    }
    
    private var totalYearlyBudget: Double {
        monthlyBudgets.values.reduce(0) { $0 + $1.values.reduce(0, +) }
    }
    
    private var yearPickerView: some View {
        NavigationView {
            ScrollViewReader { scrollProxy in
                List {
                    ForEach(Calendar.current.component(.year, from: Date())-20...Calendar.current.component(.year, from: Date())+20, id: \.self) { year in
                        Button(action: {
                            selectedYear = year
                            showingYearPicker = false
                            if year > Calendar.current.component(.year, from: Date()) {
                                showingFutureYearAlert = true
                            } else {
                                loadCurrentBudgets()
                            }
                        }) {
                            HStack {
                                Text(String(year))
                                Spacer()
                                if year == selectedYear {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }
                        .id(year)
                    }
                }
                .onAppear {
                    scrollProxy.scrollTo(selectedYear, anchor: .center)
                }
            }
            .navigationTitle("Select Year")
            .navigationBarItems(trailing: Button("Cancel") {
                showingYearPicker = false
            })
        }
    }
    
    private var monthTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(1...12, id: \.self) { month in
                        monthTab(month: month)
                            .id(month)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        scrollProxy?.scrollTo(selectedMonth, anchor: .center)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func monthTab(month: Int) -> some View {
        VStack {
            Text(DateFormatter().monthSymbols[month - 1])
                .font(.caption)
            Text("$\(totalMonthlyBudget(for: month), specifier: "%.0f")")
                .font(.caption2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(month == selectedMonth ? themeManager.primaryColor : Color.gray.opacity(0.2))
        .foregroundColor(month == selectedMonth ? .white : .primary)
        .cornerRadius(8)
        .onTapGesture {
            selectedMonth = month
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading) {
            Text("Summary for \(monthName(selectedMonth)) \(String(selectedYear))")
                .font(.headline)
            HStack {
                Text("Total Monthly Budget:")
                Spacer()
                Text("$\(totalMonthlyBudget(for: selectedMonth), specifier: "%.2f")")
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)
            }
        }
    }
    
    private var categoriesSection: some View {
           ForEach(Array(monthlyBudgets[selectedMonth, default: [:]]
               .sorted(by: { $0.key < $1.key })), id: \.key) { category, amount in
               NavigationLink(destination: EditCategoryView(
                   monthlyBudgets: $monthlyBudgets,
                   initialCategory: category,
                   month: selectedMonth,
                   year: selectedYear,
                   onUpdate: { oldCategory, newCategory, newAmount in
                       updateCategory(oldCategory: oldCategory, newCategory: newCategory, newAmount: newAmount)
                   },
                   onDelete: { deletedCategory in
                       deleteCategory(deletedCategory)
                   }
               )) {
                   HStack {
                       Text(category)
                           .foregroundColor(.primary)
                       Spacer()
                       Text(formatCurrency(amount))
                           .foregroundColor(.secondary)
                           .frame(height: 40)
                           .clipShape(RoundedRectangle(cornerRadius: 5))
                   }
                   .padding(.vertical, 5)
                   .padding(.horizontal,10)
                   .background(Color.gray.opacity(0.1))
                   .cornerRadius(10)
               }
           }
       }
    
        private func formatCurrency(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
        }
    
    private var addCategoryButton: some View {
        Button(action: { showingAddCategory = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Category")
            }
        }
    }
    
    private var addCategoryView: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $newCategoryName)
                HStack {
                    Text("$")
                    TextField("Amount", value: $newCategoryAmount, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarItems(
                leading: Button("Cancel") { showingAddCategory = false },
                trailing: Button("Add") { addCategory() }
            )
        }
    }
    
    private func monthName(_ month: Int) -> String {
        DateFormatter().monthSymbols[month - 1]
    }
    
    private func totalMonthlyBudget(for month: Int) -> Double {
        monthlyBudgets[month, default: [:]].values.reduce(0, +)
    }
    
    private func loadCurrentBudgets() {
        monthlyBudgets = [:]
        for month in 1...12 {
            let budgets = budgetManager.getMonthlyBudgets(for: month, year: selectedYear)
            monthlyBudgets[month] = Dictionary(uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) })
        }
    }
    
    private func saveBudgets() {
            for (month, budgets) in monthlyBudgets {
                budgetManager.updateMonthlyBudgets(budgets, for: month, year: selectedYear)
            }
            dismiss()
        }
    
    private func addCategory() {
        guard !newCategoryName.isEmpty && newCategoryAmount > 0 else {
            alertMessage = "Please enter a valid category name and amount."
            showingAlert = true
            return
        }
        
        if monthlyBudgets[selectedMonth, default: [:]][newCategoryName] != nil {
            alertMessage = "This category already exists."
            showingAlert = true
            return
        }
        
        monthlyBudgets[selectedMonth, default: [:]][newCategoryName] = newCategoryAmount
        newCategoryName = ""
        newCategoryAmount = 0
        showingAddCategory = false
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
        let currentYear = Calendar.current.component(.year, from: Date())
        for month in 1...12 {
            let currentYearBudgets = budgetManager.getMonthlyBudgets(for: month, year: currentYear)
            monthlyBudgets[month] = Dictionary(uniqueKeysWithValues: currentYearBudgets.map { ($0.category, $0.amount) })
        }
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
        
        private func deleteCategory(_ category: String) {
            var updatedBudget = monthlyBudgets[selectedMonth] ?? [:]
            updatedBudget[category] = nil
            monthlyBudgets[selectedMonth] = updatedBudget
            
            changedCategory = category
            changedAmount = 0
            showingFutureChangeAlert = true
        }

        
        
    }
