//
//  PurchasesView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import Foundation

/// Main view for displaying and managing purchases with filtering and sorting capabilities
struct PurchasesView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - State
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var sortOption: BudgetSortOption = .date
    @State private var sortAscending = false
    @State private var searchText = ""
    @State private var showingFilterMenu = false
    @State private var selectedTransaction: BudgetEntry?
    @State private var filteredEntries: [BudgetEntry] = []
    @State private var showingAddPurchase = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - Private Properties
    private var groupedEntries: [Date: [BudgetEntry]] {
        Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                filterSortButton
                searchBar
                Divider()
                
                if isLoading {
                    loadingView
                } else if errorMessage != nil {
                    errorView
                } else if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            
            addButton
        }
        .navigationTitle("Purchases")
        .sheet(isPresented: $showingFilterMenu) {
            FilterSortView(
                selectedTimePeriod: $selectedTimePeriod,
                sortOption: $sortOption,
                sortAscending: $sortAscending,
                onDismiss: filterAndSortEntries
            )
        }
        .sheet(item: $selectedTransaction) { transaction in
            UpdatePurchaseView(
                transaction: transaction,
                onUpdate: { updatedTransaction in
                    handleTransactionUpdate(updatedTransaction)
                },
                onDelete: {
                    handleTransactionDelete(transaction)
                }
            )
        }
        .sheet(isPresented: $showingAddPurchase) {
            PurchaseEntryView()
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: budgetManager.entries) { oldValue, newValue in
            filterAndSortEntries()
        }
    }
    
    // MARK: - View Components
    private var filterSortButton: some View {
        Button(action: { showingFilterMenu = true }) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("Filter & Sort")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityLabel("Open filter and sort options")
    }
    
    private var searchBar: some View {
        TextField("Search transactions", text: $searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            .padding(.vertical, 10)
            .onChange(of: searchText) { oldValue, newValue in
                filterAndSortEntries()
            }
    }
    
    private var loadingView: some View {
        ProgressView("Loading transactions...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(errorMessage ?? "An error occurred")
                .font(.headline)
            
            Button("Try Again") {
                Task {
                    await loadInitialData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No transactions found")
                .font(.headline)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Button(action: { showingAddPurchase = true }) {
                    Text("Add First Purchase")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(themeManager.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var entriesList: some View {
        List {
            ForEach(groupedEntries.keys.sorted().reversed(), id: \.self) { date in
                Section(header: Text(formatDate(date))) {
                    ForEach(groupedEntries[date] ?? []) { entry in
                        TransactionRowView(entry: entry)
                            .onTapGesture {
                                selectedTransaction = entry
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(createAccessibilityLabel(for: entry))
                            .accessibilityHint("Double tap to edit")
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await refreshData()
        }
    }
    
    private var addButton: some View {
        Button(action: { showingAddPurchase = true }) {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(themeManager.primaryColor)
                .background(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
        }
        .padding(.bottom, 36)
        .padding(.trailing, 20)
        .accessibilityLabel("Add new purchase")
    }
    
    // MARK: - Helper Methods
    private func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        // Load data and then filter/sort
        budgetManager.loadData()
        
        // Add a small delay to ensure data is loaded
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await MainActor.run {
            filterAndSortEntries()
            isLoading = false
        }
    }
    
    private func filterAndSortEntries() {
        let dateInterval = selectedTimePeriod.dateInterval()
        
        filteredEntries = budgetManager.entries.filter { entry in
            let dateMatches = (entry.date >= dateInterval.start && entry.date <= dateInterval.end)
            let searchMatches = searchText.isEmpty ||
                entry.category.localizedCaseInsensitiveContains(searchText) ||
                entry.note?.localizedCaseInsensitiveContains(searchText) == true
            
            return dateMatches && searchMatches
        }
        
        sortEntries()
    }
    
    private func sortEntries() {
        filteredEntries.sort { entry1, entry2 in
            let result: Bool
            switch sortOption {
            case .date:
                result = entry1.date < entry2.date
            case .amount:
                result = entry1.amount < entry2.amount
            case .category:
                result = entry1.category < entry2.category
            case .budgetedAmount, .amountSpent:
                result = entry1.amount < entry2.amount
            }
            return sortAscending ? result : !result
        }
    }
    
    private func refreshData() async {
        await loadInitialData()
    }
    
    private func handleTransactionUpdate(_ transaction: BudgetEntry) {
        filterAndSortEntries()
    }
    
    private func handleTransactionDelete(_ transaction: BudgetEntry) {
        filterAndSortEntries()
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func createAccessibilityLabel(for entry: BudgetEntry) -> String {
        let amount = NumberFormatter.currencyFormatter.string(from: NSNumber(value: entry.amount)) ?? ""
        let date = formatDate(entry.date)
        return "\(amount) for \(entry.category) on \(date)\(entry.note.map { ", Note: \($0)" } ?? "")"
    }
}

// MARK: - Preview Provider
#if DEBUG
struct PurchasesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PurchasesView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
        }
        
        NavigationView {
            PurchasesView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
