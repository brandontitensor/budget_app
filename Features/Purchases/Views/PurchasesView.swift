//
//  PurchasesView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import Combine

/// Enhanced purchases view with comprehensive error handling and improved user experience
struct PurchasesView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var selectedCategory: String = "All"
    @State private var sortOption: BudgetSortOption = .date
    @State private var sortAscending = false
    @State private var showingAddPurchase = false
    @State private var showingUpdatePurchase = false
    @State private var selectedEntry: BudgetEntry?
    @State private var showingFilterOptions = false
    @State private var showingExportOptions = false
    @State private var isLoading = false
    @State private var lastRefreshDate: Date?
    @State private var hasAppeared = false
    
    // MARK: - Error State
    @State private var localError: AppError?
    @State private var showingErrorDetails = false
    @State private var retryCount = 0
    private let maxRetries = 3
    
    // MARK: - Data State
    @State private var filteredEntries: [BudgetEntry] = []
    @State private var categories: [String] = []
    @State private var isRefreshing = false
    @State private var loadingState: LoadingState = .idle
    
    // MARK: - Performance
    @State private var lastFilterUpdate = Date()
    private let filterDebounceInterval: TimeInterval = 0.3
    
    // MARK: - Types
    private enum LoadingState {
        case idle
        case loading
        case loaded
        case error(AppError)
        case refreshing
        
        var isLoading: Bool {
            switch self {
            case .loading, .refreshing: return true
            default: return false
            }
        }
        
        var hasError: Bool {
            if case .error = self { return true }
            return false
        }
    }
    
    // MARK: - Computed Properties
    private var displayedEntries: [BudgetEntry] {
        return filteredEntries
    }
    
    private var totalAmount: Double {
        return displayedEntries.reduce(0) { $0 + $1.amount }
    }
    
    private var entryCount: Int {
        return displayedEntries.count
    }
    
    private var availableCategories: [String] {
        let allCategories = budgetManager.getAvailableCategories()
        return ["All"] + allCategories.sorted()
    }
    
    private var isEmpty: Bool {
        return displayedEntries.isEmpty && !loadingState.isLoading
    }
    
    private var canExport: Bool {
        return !displayedEntries.isEmpty && !loadingState.isLoading
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if loadingState.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Purchases")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        // Export button
                        Button {
                            showingExportOptions = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(!canExport)
                        
                        // Filter button
                        Button {
                            showingFilterOptions = true
                        } label: {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .foregroundColor(hasActiveFilters ? themeManager.primaryColor : .primary)
                        }
                        
                        // Add purchase button
                        Button {
                            showingAddPurchase = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.primaryColor)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search purchases...")
            .onChange(of: searchText) { _, _ in
                scheduleFilterUpdate()
            }
            .refreshable {
                await performRefresh()
            }
            .sheet(isPresented: $showingAddPurchase) {
                PurchaseEntryView()
                    .environmentObject(budgetManager)
                    .environmentObject(themeManager)
                    .environmentObject(errorHandler)
            }
            .sheet(item: $selectedEntry) { entry in
                UpdatePurchaseView(entry: entry)
                    .environmentObject(budgetManager)
                    .environmentObject(themeManager)
                    .environmentObject(errorHandler)
            }
            .sheet(isPresented: $showingFilterOptions) {
                filterOptionsSheet
            }
            .sheet(isPresented: $showingExportOptions) {
                exportOptionsSheet
            }
            .alert("Purchase Error", isPresented: $showingErrorDetails, presenting: localError) { error in
                if error.isRetryable && retryCount < maxRetries {
                    Button("Retry") {
                       Task<Void, Never>{
                            await performRetry()
                        }
                    }
                }
                Button("OK", role: .cancel) {
                    clearLocalError()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.errorDescription ?? "An unknown error occurred")
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
            .onAppear {
                if !hasAppeared {
                    setupView()
                    hasAppeared = true
                }
            }
            .onChange(of: selectedTimePeriod) { _, _ in
                scheduleFilterUpdate()
            }
            .onChange(of: selectedCategory) { _, _ in
                scheduleFilterUpdate()
            }
            .onChange(of: sortOption) { _, _ in
                scheduleFilterUpdate()
            }
            .onChange(of: sortAscending) { _, _ in
                scheduleFilterUpdate()
            }
            .errorAlert(onRetry: {
               Task<Void, Never>{
                    await performGlobalRetry()
                }
            })
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text("Loading purchases...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if retryCount > 0 {
                Text("Retry attempt \(retryCount) of \(maxRetries)")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Summary header
            if !isEmpty {
                summaryHeader
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            // Content area
            if isEmpty {
                emptyStateView
            } else {
                purchasesList
            }
        }
    }
    
    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entryCount) Purchase\(entryCount == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Total: \(totalAmount.asCurrency)")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if let lastRefresh = lastRefreshDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Updated")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatRelativeTime(lastRefresh))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("No Purchases Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if hasActiveFilters {
                    Text("Try adjusting your filters or search terms")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Clear Filters") {
                        clearAllFilters()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.primaryColor)
                } else {
                    Text("Add your first purchase to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Purchase") {
                        showingAddPurchase = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var purchasesList: some View {
        List {
            // Error banner (if any)
            if let error = localError {
                Section {
                    InlineErrorView(
                        error: error,
                        onDismiss: { clearLocalError() },
                        onRetry: error.isRetryable ? {
                           Task<Void, Never>{ await performRetry() }
                        } : nil
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            
            // Purchases
            ForEach(displayedEntries) { entry in
                TransactionRowView(
                    entry: entry,
                    onTap: {
                        selectedEntry = entry
                        showingUpdatePurchase = true
                    },
                    onDelete: {
                       Task<Void, Never>{
                            await deletePurchase(entry)
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: displayedEntries.count)
    }
    
    private var filterOptionsSheet: some View {
        NavigationView {
            FilterOptionsView(
                selectedTimePeriod: $selectedTimePeriod,
                selectedCategory: $selectedCategory,
                sortOption: $sortOption,
                sortAscending: $sortAscending,
                availableCategories: availableCategories
            )
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterOptions = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                    .disabled(!hasActiveFilters)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var exportOptionsSheet: some View {
        NavigationView {
            ExportOptionsView(
                entries: displayedEntries,
                timePeriod: selectedTimePeriod
            )
            .navigationTitle("Export Purchases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingExportOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties for Filters
    
    private var hasActiveFilters: Bool {
        return selectedTimePeriod != .thisMonth ||
               selectedCategory != "All" ||
               !searchText.isEmpty ||
               sortOption != .date ||
               sortAscending != false
    }
    
    // MARK: - Data Management
    
    private func setupView() {
       Task<Void, Never>{
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        await MainActor.run {
            loadingState = .loading
            clearLocalError()
        }
        
        do {
            // Load categories first
            let availableCategories = budgetManager.getAvailableCategories()
            await MainActor.run {
                categories = availableCategories
            }
            
            // Load and filter entries
            await filterEntries()
            
            await MainActor.run {
                loadingState = .loaded
                lastRefreshDate = Date()
                retryCount = 0
            }
            
        } catch {
            await handleLoadError(AppError.from(error))
        }
    }
    
    private func filterEntries() async {
        do {
            let allEntries = try await budgetManager.getEntries(
                for: selectedTimePeriod,
                category: selectedCategory == "All" ? nil : selectedCategory,
                sortedBy: sortOption,
                ascending: sortAscending
            )
            
            var filtered = allEntries
            
            // Apply search filter if needed
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let searchTerms = searchText.lowercased()
                filtered = filtered.filter { entry in
                    entry.category.lowercased().contains(searchTerms) ||
                    (entry.note?.lowercased().contains(searchTerms) ?? false) ||
                    entry.formattedAmount.contains(searchTerms)
                }
            }
            
            await MainActor.run {
                filteredEntries = filtered
                lastFilterUpdate = Date()
            }
            
        } catch {
            await handleLoadError(AppError.from(error))
        }
    }
    
    private func scheduleFilterUpdate() {
        // Debounce filter updates to improve performance
        let updateTime = Date()
        lastFilterUpdate = updateTime
        
       Task<Void, Never>{
            try? await Task.sleep(nanoseconds: UInt64(filterDebounceInterval * 1_000_000_000))
            
            // Only proceed if this is still the latest update
            if lastFilterUpdate == updateTime {
                await filterEntries()
            }
        }
    }
    
    private func performRefresh() async {
        await MainActor.run {
            isRefreshing = true
            loadingState = .refreshing
        }
        
        // Add slight delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Reload data from budget manager
        budgetManager.loadData()
        
        // Re-filter entries
        await filterEntries()
        
        await MainActor.run {
            isRefreshing = false
            loadingState = .loaded
            lastRefreshDate = Date()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleLoadError(_ error: AppError) async {
        await MainActor.run {
            localError = error
            loadingState = .error(error)
            
            // Also report to global error handler for logging
            errorHandler.handle(error, context: "Loading purchases")
        }
    }
    
    private func clearLocalError() {
        localError = nil
        if case .error = loadingState {
            loadingState = .loaded
        }
    }
    
    private func performRetry() async {
        guard retryCount < maxRetries else {
            await MainActor.run {
                localError = AppError.validation(message: "Maximum retry attempts reached")
                showingErrorDetails = true
            }
            return
        }
        
        await MainActor.run {
            retryCount += 1
            clearLocalError()
        }
        
        await loadInitialData()
    }
    
    private func performGlobalRetry() async {
        await MainActor.run {
            retryCount = 0
            clearLocalError()
        }
        
        await loadInitialData()
    }
    
    // MARK: - Purchase Management
    
    private func deletePurchase(_ entry: BudgetEntry) async {
        do {
            try await budgetManager.deleteEntry(entry)
            
            // Update local state
            await MainActor.run {
                filteredEntries.removeAll { $0.id == entry.id }
                
                // Show success feedback
                if settingsManager.enableHapticFeedback {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            
        } catch {
            await MainActor.run {
                localError = AppError.from(error)
                showingErrorDetails = true
            }
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
       Task<Void, Never>{
            for index in offsets {
                let entry = displayedEntries[index]
                await deletePurchase(entry)
            }
        }
    }
    
    // MARK: - Filter Management
    
    private func clearAllFilters() {
        searchText = ""
        selectedTimePeriod = .thisMonth
        selectedCategory = "All"
        sortOption = .date
        sortAscending = false
        
        scheduleFilterUpdate()
    }
    
    private func resetFilters() {
        clearAllFilters()
    }
    
    // MARK: - Helper Methods
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Filter Options View

private struct FilterOptionsView: View {
    @Binding var selectedTimePeriod: TimePeriod
    @Binding var selectedCategory: String
    @Binding var sortOption: BudgetSortOption
    @Binding var sortAscending: Bool
    let availableCategories: [String]
    
    var body: some View {
        Form {
            Section("Time Period") {
                Picker("Time Period", selection: $selectedTimePeriod) {
                    ForEach(TimePeriod.commonPeriods, id: \.self) { period in
                        Text(period.displayName)
                            .tag(period)
                    }
                }
                .pickerStyle(.wheel)
            }
            
            Section("Category") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        Text(category)
                            .tag(category)
                    }
                }
                .pickerStyle(.wheel)
            }
            
            Section("Sort") {
                Picker("Sort By", selection: $sortOption) {
                    Text("Date").tag(BudgetSortOption.date)
                    Text("Amount").tag(BudgetSortOption.amount)
                    Text("Category").tag(BudgetSortOption.category)
                }
                .pickerStyle(.segmented)
                
                Toggle("Ascending", isOn: $sortAscending)
            }
        }
    }
}

// MARK: - Enhanced Transaction Row View

private struct PurchasesTransactionRowView: View {
    let entry: BudgetEntry
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category icon
                Circle()
                    .fill(themeManager.colorForCategory(entry.category))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: categoryIcon(for: entry.category))
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.category)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(entry.shortDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") {
                onTap()
            }
            
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete Purchase",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this purchase? This action cannot be undone.")
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "groceries", "food": return "cart.fill"
        case "transportation", "transport": return "car.fill"
        case "entertainment": return "gamecontroller.fill"
        case "utilities": return "bolt.fill"
        case "healthcare", "medical": return "cross.fill"
        case "shopping": return "bag.fill"
        case "dining", "restaurant": return "fork.knife"
        case "education": return "book.fill"
        case "savings": return "banknote.fill"
        default: return "creditcard.fill"
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct PurchasesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal state
            PurchasesView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Normal State")
            
            // Dark mode
            PurchasesView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Loading state
            PurchasesView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .onAppear {
                    // Simulate loading state
                }
                .previewDisplayName("Loading State")
        }
    }
}
#endif
