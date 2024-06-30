import SwiftUI

struct PurchasesView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var sortOption: SortOption = .date
    @State private var sortAscending = false
    @State private var searchText = ""
    @State private var showingFilterMenu = false
    @State private var selectedTransaction: BudgetEntry?
    @State private var filteredEntries: [BudgetEntry] = []
    @State private var showingAddPurchase = false

    var body: some View {
        VStack(spacing: 0) {
                    filterSortButton
                    searchBar
                    Divider()
                    entriesList
                }
                .navigationTitle("Purchases")
                .sheet(isPresented: $showingFilterMenu) {
                    FilterSortView(
                        selectedTimePeriod: $selectedTimePeriod,
                        customStartDate: $customStartDate,
                        customEndDate: $customEndDate,
                        sortOption: $sortOption,
                        sortAscending: $sortAscending,
                        onDismiss: { filterAndSortEntries() }
                    )
                }
                .sheet(item: $selectedTransaction) { transaction in
                    UpdatePurchaseView(transaction: transaction) { updatedTransaction in
                        budgetManager.updateEntry(updatedTransaction)
                        filterAndSortEntries()
                    } onDelete: {
                        budgetManager.deleteEntry(transaction)
                        filterAndSortEntries()
                    }
                }
                .sheet(isPresented: $showingAddPurchase) {
                    PurchaseEntryView()
                        .environmentObject(budgetManager)
                        .environmentObject(themeManager)
                }
                .onAppear(perform: filterAndSortEntries)
                .onChange(of: budgetManager.entries) { _, _ in
                    filterAndSortEntries()
                }
            }
    
        
    
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
    }
    
    private var searchBar: some View {
        TextField("Search", text: $searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            .padding(.vertical, 10)
            .onChange(of: searchText) { _, _ in
                filterAndSortEntries()
            }
    }
    
    private var entriesList: some View {
        List {
            ForEach(filteredEntries) { entry in
                TransactionRowView(entry: entry)
                    .onTapGesture {
                        selectedTransaction = entry
                    }
            }
            .onDelete(perform: deleteEntries)
        }
        .refreshable {
            filterAndSortEntries()
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { filteredEntries[$0] }
        for entry in entriesToDelete {
            budgetManager.deleteEntry(entry)
        }
        filterAndSortEntries()
    }
    
    private func filterAndSortEntries() {
        let (startDate, endDate) = getDateRange(for: selectedTimePeriod)
        
        filteredEntries = budgetManager.entries.filter { entry in
            (entry.date >= startDate && entry.date <= endDate) &&
            (searchText.isEmpty ||
             entry.category.lowercased().contains(searchText.lowercased()) ||
             entry.note?.lowercased().contains(searchText.lowercased()) == true)
        }
        
        filteredEntries.sort { entry1, entry2 in
            let result: Bool
            switch sortOption {
            case .date:
                result = entry1.date < entry2.date
            case .amount:
                result = entry1.amount < entry2.amount
            case .category:
                result = entry1.category < entry2.category
            }
            return sortAscending ? result : !result
        }
    }
    
    private func getDateRange(for timePeriod: TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timePeriod {
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (startOfWeek, now)
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (startOfMonth, now)
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (startOfYear, now)
        case .allTime:
            return (Date.distantPast, now)
        case .custom(let start, let end):
            return (start, end)

        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return (startOfDay,now)
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return (sevenDaysAgo, now)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            return (thirtyDaysAgo, now)
        case .last12Months:
            let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now)!
            return (twelveMonthsAgo, now)
        }
    }
}

struct FilterSortView: View {
    @Binding var selectedTimePeriod: TimePeriod
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Binding var sortOption: SortOption
    @Binding var sortAscending: Bool
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time Period")) {
                    Picker("Time Period", selection: $selectedTimePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    
                    if case .custom = selectedTimePeriod {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Sort By")) {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Toggle("Ascending", isOn: $sortAscending)
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarItems(trailing: Button("Done") {
                onDismiss()
                dismiss()
            })
        }
    }
}

struct TransactionRowView: View {
    let entry: BudgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(entry.date, style: .date)
                Spacer()
                Text("$\(entry.amount, specifier: "%.2f")")
                    .bold()
            }
            HStack {
                Text(entry.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let note = entry.note, !note.isEmpty {
                    Text("Note: \(note)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
           
        }
        .padding()
        
    }
}

enum SortOption: String, CaseIterable {
    case date = "Date"
    case amount = "Amount"
    case category = "Category"
}
