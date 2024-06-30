//
//  BudgetOverviewView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
import Charts

struct BudgetOverviewView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("userName") private var userName: String = "User"
    
    @State private var currentMonthEntries: [BudgetEntry] = []
    @State private var recentTransactions: [BudgetEntry] = []
    
    private let pieChartColors: [Color] = [
        Color(red: 0.12, green: 0.58, blue: 0.95), // Dodger Blue
        Color(red: 0.99, green: 0.85, blue: 0.21), // Sunflower Yellow
        Color(red: 0.18, green: 0.80, blue: 0.44), // Emerald Green
        Color(red: 0.61, green: 0.35, blue: 0.71), // Royal Purple
        Color(red: 1.00, green: 0.60, blue: 0.00), // Orange
        Color(red: 0.20, green: 0.60, blue: 0.86), // Sky Blue
        Color(red: 0.95, green: 0.27, blue: 0.57), // Hot Pink
        Color(red: 0.40, green: 0.85, blue: 0.94), // Turquoise
        Color(red: 0.10, green: 0.74, blue: 0.61), // Mint
        Color(red: 0.46, green: 0.31, blue: 0.48), // Eggplant
        Color(red: 0.94, green: 0.50, blue: 0.14), // Tangerine
        Color(red: 0.28, green: 0.46, blue: 0.70), // Steel Blue
        Color(red: 0.87, green: 0.44, blue: 0.63), // Orchid
        Color(red: 0.55, green: 0.71, blue: 0.29), // Olive Green
        Color(red: 0.75, green: 0.24, blue: 0.52), // Magenta
        Color(red: 0.36, green: 0.54, blue: 0.66), // Slate Blue
        Color(red: 0.96, green: 0.76, blue: 0.05), // Golden Yellow
        Color(red: 0.00, green: 0.65, blue: 0.31), // Forest Green
        Color(red: 0.00, green: 0.50, blue: 0.50), // Teal
        Color(red: 0.25, green: 0.88, blue: 0.82), // Turquoise
        Color(red: 0.53, green: 0.81, blue: 0.98), // Light Sky Blue
        Color(red: 0.29, green: 0.00, blue: 0.51), // Indigo
        Color(red: 0.13, green: 0.55, blue: 0.13)  // Forest Green
    ]
    
    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dateSection
                    summaryCards
                    Divider()
                    spendingPieChart
                    Divider()
                    recentTransactionsList
                }
                .padding()
                .padding(.bottom, 60)
            }
            .navigationTitle("Welcome, \(userName)!")
            .onAppear(perform: loadData)
            .refreshable {
                await refreshData()
            }
        }
    
    
    private var welcomeSection: some View {
        Text("Welcome, \(userName)!")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(themeManager.primaryColor)
    }
    
    private var dateSection: some View {
        Text(formattedDate)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var summaryCards: some View {
        HStack {
            SummaryCard(title: "Total Spent", amount: totalSpent, color: .red)
            SummaryCard(title: "Monthly Budget", amount: budgetManager.getCurrentMonthBudget(), color: .green)
        }
    }
    
    private var spendingPieChart: some View {
        VStack(alignment: .leading) {
            Text("Spending by Category")
                .font(.title2)
                .fontWeight(.bold)
            
            Chart {
                ForEach(spendingData) { data in
                    SectorMark(
                        angle: .value("Amount", data.amount),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(data.color)
                }
            }
            .frame(height: 200)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(spendingData) { data in
                    HStack {
                        Circle()
                            .fill(data.color)
                            .frame(width: 10, height: 10)
                        Text(data.category)
                            .font(.caption)
                        Spacer()
                        Text("\(data.percentage, specifier: "%.1f")%")
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var recentTransactionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Transactions")
                .font(.title2)
                .fontWeight(.bold)
            ForEach(recentTransactions) { transaction in
                TransactionRow(transaction: transaction)
                Divider()
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    private var totalSpent: Double {
        currentMonthEntries.reduce(0) { $0 + $1.amount }
    }
    
    private var spendingData: [SpendingData] {
        let groupedEntries = Dictionary(grouping: currentMonthEntries, by: { $0.category })
        let sortedCategories = groupedEntries.keys.sorted()
        
        return sortedCategories.enumerated().map { index, category in
            let amount = groupedEntries[category]!.reduce(0) { $0 + $1.amount }
            let percentage = (amount / totalSpent) * 100
            return SpendingData(
                id: UUID(),
                category: category,
                amount: amount,
                percentage: percentage,
                color: pieChartColors[index % pieChartColors.count]
            )
        }
    }
    
    private func loadData() {
        _ = Calendar.current
        _ = Date()
            
            currentMonthEntries = budgetManager.getEntries(for: .thisMonth)
            recentTransactions = Array(budgetManager.entries.sorted { $0.date > $1.date }.prefix(5))
        }
        
        private func refreshData() async {
            await MainActor.run {
                loadData()
            }
        }
    }

struct SpendingData: Identifiable {
    let id: UUID
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Text("$\(amount, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TransactionRow: View {
    let transaction: BudgetEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("$\(transaction.amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 5)
    }
}

struct BudgetOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetOverviewView()
            .environmentObject(BudgetManager())
            .environmentObject(ThemeManager())
    }
}
