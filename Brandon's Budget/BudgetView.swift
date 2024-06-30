//
//  BudgetView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var showingFilterMenu = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var budgetData: [BudgetCategoryData] = []
    
    var body: some View {
        NavigationView {
            List {
                timePeriodPicker
                totalBudgetSection
                categoryBreakdownSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterMenu = true }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingFilterMenu) {
                filterMenu
            }
            .onAppear(perform: loadBudgetData)
            .onChange(of: selectedTimePeriod) { oldValue, newValue in
                loadBudgetData()
            }
        }
        
    }
    
    
    
    private var timePeriodPicker: some View {
        Picker("Time Period", selection: $selectedTimePeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.vertical)
    }
    
    private var totalBudgetSection: some View {
        Section(header: Text("Total Budget")) {
            HStack {
                Text("Budgeted")
                Spacer()
                Text("$\(totalBudgeted, specifier: "%.2f")")
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)
            }
            HStack {
                Text("Spent")
                Spacer()
                Text("$\(totalSpent, specifier: "%.2f")")
                    .foregroundColor(totalSpent > totalBudgeted ? .red : .green)
                    .fontWeight(.bold)
            }
            ProgressView(value: totalSpent, total: max(totalBudgeted, totalSpent))
                .accentColor(totalSpent > totalBudgeted ? .red : themeManager.primaryColor)
        }
    }
    
    private var categoryBreakdownSection: some View {
        Section(header: Text("Category Breakdown")) {
            ForEach(budgetData) { category in
                VStack(alignment: .leading) {
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text("$\(category.spent, specifier: "%.2f") / $\(category.budgeted, specifier: "%.2f")")
                            .font(.caption)
                    }
                    ProgressView(value: category.spent, total: max(category.budgeted, category.spent))
                        .accentColor(category.spent > category.budgeted ? .red : themeManager.primaryColor)
                }
            }
        }
    }
    
    private var filterMenu: some View {
        NavigationView {
            Form {
                if case .custom = selectedTimePeriod {
                    DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Select Time Period")
            .navigationBarItems(trailing: Button("Done") {
                if case .custom = selectedTimePeriod {
                    selectedTimePeriod = .custom(customStartDate, customEndDate)
                }
                showingFilterMenu = false
                loadBudgetData()
            })
        }
    }
    
    private var totalBudgeted: Double {
        budgetData.reduce(0) { $0 + $1.budgeted }
    }
    
    private var totalSpent: Double {
        budgetData.reduce(0) { $0 + $1.spent }
    }
    
    private func loadBudgetData() {
            let (startDate, endDate) = getDateRange(for: selectedTimePeriod)
            let entries = budgetManager.getEntries(from: startDate, to: endDate)
            let budgets = budgetManager.getMonthlyBudgets(from: startDate, to: endDate)
        
        var categoryData: [String: BudgetCategoryData] = [:]
        
        for budget in budgets {
            let proRatedBudget = proRateBudget(budget: budget, startDate: startDate, endDate: endDate)
            categoryData[budget.category, default: BudgetCategoryData(name: budget.category)].budgeted += proRatedBudget
        }
        
        for entry in entries {
            categoryData[entry.category, default: BudgetCategoryData(name: entry.category)].spent += entry.amount
        }
        
        budgetData = Array(categoryData.values).sorted { $0.budgeted > $1.budgeted }
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
    
    private func proRateBudget(budget: MonthlyBudget, startDate: Date, endDate: Date) -> Double {
        let calendar = Calendar.current
        let budgetStartDate = calendar.date(from: DateComponents(year: budget.year, month: budget.month, day: 1))!
        let budgetEndDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: budgetStartDate)!
        
        let overlapStart = max(startDate, budgetStartDate)
        let overlapEnd = min(endDate, budgetEndDate)
        
        guard overlapStart <= overlapEnd else { return 0 }
        
        let totalDaysInBudgetMonth = calendar.dateComponents([.day], from: budgetStartDate, to: budgetEndDate).day! + 1
        let overlapDays = calendar.dateComponents([.day], from: overlapStart, to: overlapEnd).day! + 1
        
        return (Double(overlapDays) / Double(totalDaysInBudgetMonth)) * budget.amount
    }
}

struct BudgetCategoryData: Identifiable {
    let id = UUID()
    let name: String
    var budgeted: Double = 0
    var spent: Double = 0
}

struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetView()
            .environmentObject(BudgetManager())
            .environmentObject(ThemeManager())
    }
}
