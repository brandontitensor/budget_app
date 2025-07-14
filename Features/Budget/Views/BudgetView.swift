//
//  BudgetView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI

/// View for managing monthly budgets and categories with enhanced error handling and state management
struct BudgetView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var monthlyBudgets: [Int: [String: Double]] = [:]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryAmount: Double = 0
    @State private var showingFutureAddAlert = false
    @State private var showingFutureChangeAlert = false
    @State private var showingFutureYearAlert = false
    @State private var changedCategory = ""
    @State private var changedAmount: Double = 0
    @State private var showingYearPicker = false
    @State private var showingCalculator = false
    @State private var isProcessing = false
    @State private var dataLoadingState: DataLoadingState = .idle
    @State private var lastSaveDate: Date?
    
    // MARK: - Error State
    @State private var currentError: AppError?
    @State private var showingErrorDetails = false
    
    // MARK: - Properties
    private let calendar = Calendar.current
    
    // MARK: - Types
    private enum DataLoadingState {
        case idle
        case loading
        case loaded
        case failed(AppError)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var hasError: Bool {
            if case .failed = self { return true }
            return false
        }
    }
    
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
            ZStack {
                mainContent
                
                // Loading overlay
                if dataLoadingState.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Update Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancelAction()
                    }
                    .disabled(isProcessing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        handleSaveAction()
                    }
                    .disabled(isProcessing || !hasUnsavedChanges)
                }
            }
            .onAppear {
                setupView()
            }
            .onChange(of: selectedYear) { oldYear, newYear in
                handleYearChange(from: oldYear, to: newYear)
            }
            .sheet(isPresented: $showingAddCategory) {
                addCategorySheet
            }
            .sheet(isPresented: $showingCalculator) {
                MoneyCalculatorView(amount: $newCategoryAmount)
            }
            .confirmationDialog(
                "Update Future Months?",
                isPresented: $showingFutureChangeAlert,
                titleVisibility: .visible
            ) {
                Button("Yes") { updateFutureMonths() }
                Button("No", role: .cancel) { }
            } message: {
                Text("Do you want to apply this change to future months of the current year?")
            }
            .confirmationDialog(
                "Load Current Year's Budget?",
                isPresented: $showingFutureYearAlert,
                titleVisibility: .visible
            ) {
                Button("Yes") { loadCurrentYearBudget() }
                Button("No", role: .cancel) { }
            } message: {
                Text("Do you want to load the current year's budget into this future year?")
            }
            .confirmationDialog(
                "Add Category to Future Months?",
                isPresented: $showingFutureAddAlert,
                titleVisibility: .visible
            ) {
                Button("This month only") {
                    Task<Void, Never>{ await addCategory(includeFutureMonths: false) }
                }
                Button("All future months") {
                    Task<Void, Never>{ await addCategory(includeFutureMonths: true) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to add this category to future months as well?")
            }
            .errorAlert(onRetry: {
                Task<Void, Never>{ await retryFailedOperation() }
            })
        }
        .handleErrors(context: "Budget View")
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            yearSection
            monthTabs
            
            if case .failed(let error) = dataLoadingState {
                errorStateView(error)
            } else if case .loaded = dataLoadingState, !monthlyBudgets.isEmpty {
                budgetContentView
            } else if case .loaded = dataLoadingState {
                emptyStateView
            } else {
                placeholderView
            }
        }
    }
    
    private var budgetContentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                summarySection
                categoriesSection
                addCategoryButton
                
                if let lastSave = lastSaveDate {
                    lastSavedIndicator(lastSave)
                }
            }
            .padding()
        }
        .refreshable {
            await refreshBudgetData()
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
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(themeManager.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
            .accessibilityLabel("Select year: \(selectedYear)")
            
            HStack {
                Text("Total Yearly Budget:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(totalYearlyBudget.asCurrency)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.primaryColor)
            }
        }
        .padding()
    }
    
    private var monthTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(1...12, id: \.self) { month in
                        monthTab(month: month)
                            .id(month)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(selectedMonth, anchor: .center)
                    }
                }
            }
            .onChange(of: selectedMonth) { _, newMonth in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newMonth, anchor: .center)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func monthTab(month: Int) -> some View {
        VStack(spacing: 4) {
            Text(monthName(month))
                .font(.caption.weight(.medium))
            Text(totalMonthlyBudget(for: month).asCurrency)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(month == selectedMonth ? themeManager.primaryColor : Color.gray.opacity(0.15))
        )
        .foregroundColor(month == selectedMonth ? .white : .primary)
        .scaleEffect(month == selectedMonth ? 1.05 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMonth = month
            }
        }
        .disabled(isProcessing)
        .accessibilityLabel("\(monthName(month)): \(totalMonthlyBudget(for: month).asCurrency)")
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Budget Summary")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            HStack(spacing: 20) {
                summaryCard(
                    title: "Monthly Budget",
                    value: totalMonthlyBudget(for: selectedMonth).asCurrency,
                    color: themeManager.primaryColor
                )
                
                Spacer()
                
                summaryCard(
                    title: "Categories",
                    value: "\(monthlyBudgets[selectedMonth]?.count ?? 0)",
                    color: themeManager.semanticColors.info
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
        }
    }
    
    private var categoriesSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(monthlyBudgets[selectedMonth, default: [:]]
                .sorted(by: { $0.value > $1.value })), id: \.key) { category, amount in
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
                .disabled(isProcessing)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var addCategoryButton: some View {
        Button(action: { showingAddCategory = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add Category")
                    .font(.headline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.primaryColor.opacity(0.1))
            .foregroundColor(themeManager.primaryColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isProcessing)
        .accessibilityLabel("Add new budget category")
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(themeManager.primaryColor)
                
                Text("Updating budgets...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func errorStateView(_ error: AppError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Failed to Load Budgets")
                    .font(.headline.weight(.semibold))
                
                Text(error.errorDescription ?? "An unexpected error occurred")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                Task<Void, Never>{ await loadCurrentBudgets() }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Budget Categories")
                    .font(.headline.weight(.semibold))
                
                Text("Add your first budget category to get started with managing your finances.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Category") {
                showingAddCategory = true
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var placeholderView: some View {
        VStack(spacing: 20) {
            // Placeholder summary
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 20)
                
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 40)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 40)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Placeholder categories
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 60)
            }
            
            Spacer()
        }
        .padding()
        .redacted(reason: .placeholder)
    }
    
    private func lastSavedIndicator(_ date: Date) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Last saved: \(formatRelativeTime(date))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Add Category Sheet
    private var addCategorySheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Category Name", text: $newCategoryName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .onChange(of: newCategoryName) { oldValue, newValue in
                            if newValue.count > AppConstants.Validation.maxCategoryNameLength {
                                newCategoryName = String(newValue.prefix(AppConstants.Validation.maxCategoryNameLength))
                            }
                        }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(newCategoryAmount.asCurrency)
                            .foregroundColor(newCategoryAmount > 0 ? themeManager.primaryColor : .secondary)
                        Button("Edit") {
                            showingCalculator = true
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("Category Details")
                } footer: {
                    Text("This budget will apply starting from \(monthName(selectedMonth)) \(selectedYear)")
                }
                
                Section {
                    Text("The category will be created and added to your budget categories. You can choose to apply it to future months as well.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Note")
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetNewCategoryFields()
                        showingAddCategory = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        validateAndAddCategory()
                    }
                    .disabled(!isValidNewCategory)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Methods
    private func setupView() {
        Task<Void, Never>{
            await loadCurrentBudgets()
        }
    }
    
    private func handleCancelAction() {
        if hasUnsavedChanges {
            // Could show confirmation dialog here
        }
        dismiss()
    }
    
    private func handleSaveAction() {
        Task<Void, Never>{
            await saveBudgets()
        }
    }
    
    private func handleYearChange(from oldYear: Int, to newYear: Int) {
        if newYear > calendar.component(.year, from: Date()) {
            showingFutureYearAlert = true
        } else {
            Task<Void, Never>{
                await loadCurrentBudgets()
            }
        }
    }
    
    private var hasUnsavedChanges: Bool {
        // Simple check for changes - could be more sophisticated
        return !monthlyBudgets.isEmpty
    }
    
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
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Data Operations
    
    @MainActor
    private func loadCurrentBudgets() async {
        dataLoadingState = .loading
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading monthly budgets"
        ) {
            var newBudgets: [Int: [String: Double]] = [:]
            
            for month in 1...12 {
                let budgets = budgetManager.getMonthlyBudgets(for: month, year: selectedYear)
                newBudgets[month] = Dictionary(
                    uniqueKeysWithValues: budgets.map { ($0.category, $0.amount) }
                )
            }
            
            return newBudgets
        }
        
        if let budgets = result {
            monthlyBudgets = budgets
            dataLoadingState = .loaded
        } else if let error = errorHandler.errorHistory.first?.error {
            dataLoadingState = .failed(error)
        } else {
            dataLoadingState = .failed(.generic(message: "Failed to load budget data"))
        }
    }
    
    @MainActor
    private func refreshBudgetData() async {
        await loadCurrentBudgets()
    }
    
    private func validateAndAddCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorHandler.handle(.validation(message: "Please enter a category name"), context: "Adding category")
            return
        }
        
        guard newCategoryAmount > 0 else {
            errorHandler.handle(.validation(message: "Please enter a valid amount"), context: "Adding category")
            return
        }
        
        if monthlyBudgets[selectedMonth]?[trimmedName] != nil {
            errorHandler.handle(.validation(message: "This category already exists"), context: "Adding category")
            return
        }
        
        showingFutureAddAlert = true
    }
    
    @MainActor
    private func addCategory(includeFutureMonths: Bool) async {
        isProcessing = true
        defer { isProcessing = false }
        
        let result = await AsyncErrorHandler.execute(
            context: "Adding budget category"
        ) {
            // Add to the selected month
            try await budgetManager.addCategory(
                name: newCategoryName,
                amount: newCategoryAmount,
                month: selectedMonth,
                year: selectedYear
            )
            
            // If includeFutureMonths is true, add to future months as well
            if includeFutureMonths {
                for month in (selectedMonth + 1)...12 {
                    try await budgetManager.updateCategoryAmount(
                        category: newCategoryName,
                        amount: newCategoryAmount,
                        month: month,
                        year: selectedYear
                    )
                }
            }
            
            return true
        }
        
        if result != nil {
            // Update local state
            if includeFutureMonths {
                for month in selectedMonth...12 {
                    monthlyBudgets[month, default: [:]][newCategoryName] = newCategoryAmount
                }
            } else {
                monthlyBudgets[selectedMonth, default: [:]][newCategoryName] = newCategoryAmount
            }
            
            resetNewCategoryFields()
            showingAddCategory = false
            lastSaveDate = Date()
        }
    }
    
    private func updateCategory(oldCategory: String, newCategory: String, newAmount: Double) {
        var updatedBudget = monthlyBudgets[selectedMonth] ?? [:]
        updatedBudget[oldCategory] = nil
        if newAmount > 0 {
            updatedBudget[newCategory] = newAmount
        }
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
        lastSaveDate = Date()
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
    
    @MainActor
    private func saveBudgets() async {
        isProcessing = true
        defer { isProcessing = false }
        
        let result = await AsyncErrorHandler.execute(
            context: "Saving budget changes"
        ) {
            // Update each month's budgets
            for (month, budgets) in monthlyBudgets {
                for (category, amount) in budgets {
                    try await budgetManager.updateCategoryAmount(
                        category: category,
                        amount: amount,
                        month: month,
                        year: selectedYear
                    )
                }
            }
            
            return true
        }
        
        if result != nil {
            lastSaveDate = Date()
            dismiss()
        }
    }
    
    private func retryFailedOperation() async {
        await loadCurrentBudgets()
    }
    
    private func resetNewCategoryFields() {
        newCategoryName = ""
        newCategoryAmount = 0
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
    }
}
#endif
