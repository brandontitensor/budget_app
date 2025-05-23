//
//  BudgetOverviewView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
import Charts

/// Main dashboard view showing budget overview and recent transactions
struct BudgetOverviewView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("userName") private var userName: String = "User"
    
    // MARK: - State
    @State private var currentMonthEntries: [BudgetEntry] = []
    @State private var recentTransactions: [BudgetEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSpendingData: SpendingData?
    
    // MARK: - Constants
    private let maxRecentTransactions = 5
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcomeHeader
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .padding()
        }
        .navigationTitle("Welcome, \(userName)!")
        .onAppear {
            Task {
                await loadData()
            }
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - View Components
    private var welcomeHeader: some View {
        Text(formattedDate)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    private var loadingView: some View {
        ProgressView("Loading budget data...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 50)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            summaryCards
            Divider()
            SpendingPieChart(spendingData: spendingData)
                .frame(height: 300)
            Divider()
            recentTransactionsList
        }
    }
    
    private var summaryCards: some View {
        HStack {
            SummaryCard(
                title: "Total Spent",
                amount: totalSpent,
                color: totalSpent > budgetManager.getCurrentMonthBudget() ? .red : .green
            )
            
            SummaryCard(
                title: "Monthly Budget",
                amount: budgetManager.getCurrentMonthBudget(),
                color: themeManager.primaryColor
            )
        }
    }
    
    private var recentTransactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.title2)
                .fontWeight(.bold)
            
            if recentTransactions.isEmpty {
                Text("No recent transactions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != recentTransactions.last?.id {
                        Divider()
                    }
                }
                
                if recentTransactions.count == maxRecentTransactions {
                    NavigationLink(destination: PurchasesView()) {
                        Text("View All Transactions")
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryColor)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    private var totalSpent: Double {
        currentMonthEntries.reduce(0) { $0 + $1.amount }
    }
    
    private var spendingData: [SpendingData] {
        let groupedEntries = Dictionary(grouping: currentMonthEntries) { $0.category }
        
        return groupedEntries.map { category, entries in
            let amount = entries.reduce(0) { $0 + $1.amount }
            let percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0
            
            return try! SpendingData(
                category: category,
                amount: amount,
                percentage: percentage,
                color: themeManager.colorForCategory(category)
            )
        }
        .sorted()
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let entries = try await budgetManager.getEntries(for: .thisMonth)
            let recentEntries = Array(budgetManager.entries
                .sorted { $0.date > $1.date }
                .prefix(maxRecentTransactions))
            
            await MainActor.run {
                currentMonthEntries = entries
                recentTransactions = recentEntries
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Summary Card
private struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Text(amount.asCurrency)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BudgetOverviewView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
        }
        
        NavigationView {
            BudgetOverviewView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
