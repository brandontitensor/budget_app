//
//  BudgetHistoryView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/1/24.
//
import SwiftUI
import Charts

struct BudgetHistoryData: Identifiable {
    let id = UUID()
    let category: String
    let budgetedAmount: Double
    let amountSpent: Double
}

enum BudgetSortOption: String, CaseIterable {
    case category = "Category"
    case budgetedAmount = "Budgeted Amount"
    case amountSpent = "Amount Spent"
}

struct BudgetHistoryView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTimePeriod: TimePeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var sortOption: BudgetSortOption = .category
    @State private var sortAscending = true
    @State private var showingFilterMenu = false

    private let chartColors: [Color] = [
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        filterSortButton
                        if filteredAndSortedBudgetData.isEmpty {
                            Text("No data available for the selected period.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            summaryCards
                            Divider()
                            budgetBarChart
                            Divider()
                            budgetList
                        }
                    }
                    .padding()
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Budget History")
            .sheet(isPresented: $showingFilterMenu) {
                filterMenu
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
       
       private var summaryCards: some View {
           HStack {
               BudgetSummaryCard(title: "Total Budget", amount: totalBudget(), color: .green)
               BudgetSummaryCard(title: "Total Spent", amount: totalSpent(), color: .red)
           }
       }
       
    private var budgetBarChart: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Budget Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Chart {
                    ForEach(Array(filteredAndSortedBudgetData.enumerated()), id: \.element.id) { index, data in
                        BarMark(
                            x: .value("Category", "\(index + 1)"),
                            y: .value("Amount", data.amountSpent)
                        )
                        .foregroundStyle(chartColors[index % chartColors.count])
                        
                        if data.amountSpent <= data.budgetedAmount {
                            BarMark(
                                x: .value("Category", "\(index + 1)"),
                                y: .value("Amount", data.budgetedAmount)
                            )
                            .foregroundStyle(chartColors[index % chartColors.count].opacity(0.3))
                        }
                    }
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel("")
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                
                // Two-column legend with percentages
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(filteredAndSortedBudgetData.enumerated()), id: \.element.id) { index, data in
                        HStack {
                            
                            Rectangle()
                                .fill(chartColors[index % chartColors.count])
                                .frame(width: 20, height: 10)
                                Text(data.category)
                                    .font(.caption)
                                Spacer()
                                Text("\(percentage(spent: data.amountSpent, budgeted: data.budgetedAmount), specifier: "%.1f")%")
                                    .font(.caption2)
                                    .foregroundColor(data.amountSpent > data.budgetedAmount ? .red : .green)
                            
                        }
                    }
                }
                .padding(.top)
            }
        }
    private func percentage(spent: Double, budgeted: Double) -> Double {
            guard budgeted > 0 else { return 0 }
            return (spent / budgeted) * 100
        }

        private var budgetList: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Budget Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                ForEach(Array(filteredAndSortedBudgetData.enumerated()), id: \.element.id) { index, data in
                    BudgetHistoryRow(data: data, color: chartColors[index % chartColors.count])
                }
            }
        }
       
       private var filterMenu: some View {
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
                           ForEach(BudgetSortOption.allCases, id: \.self) { option in
                               Text(option.rawValue).tag(option)
                           }
                       }
                       
                       Toggle("Ascending", isOn: $sortAscending)
                   }
               }
               .navigationTitle("Filter & Sort")
               .navigationBarItems(trailing: Button("Done") {
                   showingFilterMenu = false
               })
           }
       }
       
       private var filteredAndSortedBudgetData: [BudgetHistoryData] {
           calculateBudgetHistoryData().sorted { a, b in
               let result: Bool
               switch sortOption {
               case .category:
                   result = a.category < b.category
               case .budgetedAmount:
                   result = a.budgetedAmount < b.budgetedAmount
               case .amountSpent:
                   result = a.amountSpent < b.amountSpent
               }
               return sortAscending ? result : !result
           }
       }
       
    private func calculateBudgetHistoryData() -> [BudgetHistoryData] {
           let dateInterval = selectedTimePeriod.dateInterval()
           let entries = budgetManager.getEntries(from: dateInterval.start, to: dateInterval.end)
           let budgets = budgetManager.getMonthlyBudgets(from: dateInterval.start, to: dateInterval.end)
           
           var budgetDataDict: [String: BudgetHistoryData] = [:]
           
           // Calculate total budgeted amount for the period
           let totalBudgetedForPeriod = calculateTotalBudgetForPeriod(budgets: budgets)
           
           // Process budgets
           for budget in budgets {
               let category = budget.category
               let budgetedAmount = selectedTimePeriod == .thisYear ?
                   calculateYearlyBudgetForCategory(category: category) :
                   proRateBudget(totalBudget: totalBudgetedForPeriod, category: category)
               
               if let existingData = budgetDataDict[category] {
                   budgetDataDict[category] = BudgetHistoryData(
                       category: category,
                       budgetedAmount: budgetedAmount,
                       amountSpent: existingData.amountSpent
                   )
               } else {
                   budgetDataDict[category] = BudgetHistoryData(
                       category: category,
                       budgetedAmount: budgetedAmount,
                       amountSpent: 0
                   )
               }
           }
           
           // Process entries
           for entry in entries {
               let category = entry.category
               if let existingData = budgetDataDict[category] {
                   budgetDataDict[category] = BudgetHistoryData(
                       category: category,
                       budgetedAmount: existingData.budgetedAmount,
                       amountSpent: existingData.amountSpent + entry.amount
                   )
               } else {
                   budgetDataDict[category] = BudgetHistoryData(
                       category: category,
                       budgetedAmount: 0,
                       amountSpent: entry.amount
                   )
               }
           }
           
           return Array(budgetDataDict.values)
       }

    private func calculateYearlyBudgetForCategory(category: String) -> Double {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let currentMonth = calendar.component(.month, from: Date())
            
            var totalBudget = 0.0
            
            // Calculate budget for past months
            for month in 1..<currentMonth {
                if let monthlyBudget = budgetManager.getMonthlyBudgets(from: Date(), to: Date()).first(where: { $0.year == currentYear && $0.month == month && $0.category == category }) {
                    totalBudget += monthlyBudget.amount
                }
            }
            
            // Calculate budget for current and future months
            if let currentMonthBudget = budgetManager.getMonthlyBudgets(from: Date(), to: Date()).first(where: { $0.year == currentYear && $0.month == currentMonth && $0.category == category }) {
                let remainingMonths = 13 - currentMonth // Including current month
                totalBudget += currentMonthBudget.amount * Double(remainingMonths)
            }
            
            return totalBudget
        }

       private func calculateTotalBudgetForPeriod(budgets: [MonthlyBudget]) -> Double {
           let calendar = Calendar.current
           let now = Date()
           
           switch selectedTimePeriod {
           case .thisMonth:
               return budgets.filter { $0.year == calendar.component(.year, from: now) && $0.month == calendar.component(.month, from: now) }
                             .reduce(0) { $0 + $1.amount }
           case .thisWeek:
               let monthlyBudget = budgets.filter { $0.year == calendar.component(.year, from: now) && $0.month == calendar.component(.month, from: now) }
                                          .reduce(0) { $0 + $1.amount }
               let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
               return (monthlyBudget / daysInMonth) * 7
           case .thisYear:
               return budgets.filter { $0.year == calendar.component(.year, from: now) }
                             .reduce(0) { $0 + $1.amount }
           case .today:
               let monthlyBudget = budgets.filter { $0.year == calendar.component(.year, from: now) && $0.month == calendar.component(.month, from: now) }
                                          .reduce(0) { $0 + $1.amount }
               let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
               return monthlyBudget / daysInMonth
           case .last7Days, .last30Days:
               let monthlyBudget = budgets.filter { $0.year == calendar.component(.year, from: now) && $0.month == calendar.component(.month, from: now) }
                                          .reduce(0) { $0 + $1.amount }
               let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
               return (monthlyBudget / daysInMonth) * Double(selectedTimePeriod == .last7Days ? 7 : 30)
           case .last12Months:
               return budgets.filter {
                   let budgetDate = calendar.date(from: DateComponents(year: $0.year, month: $0.month, day: 1))!
                   return budgetDate >= calendar.date(byAdding: .month, value: -12, to: now)!
               }.reduce(0) { $0 + $1.amount }
           case .allTime:
               return budgets.reduce(0) { $0 + $1.amount }
           case .custom(let start, let end):
               let months = calendar.dateComponents([.month], from: start, to: end).month ?? 1
               let averageMonthlyBudget = budgets.reduce(0) { $0 + $1.amount } / Double(budgets.count)
               return averageMonthlyBudget * Double(months)
           }
       }

       private func proRateBudget(totalBudget: Double, category: String) -> Double {
           let categoryBudgets = budgetManager.getMonthlyBudgets(from: Date(), to: Date()).filter { $0.category == category }
           let totalCategoryBudget = categoryBudgets.reduce(0) { $0 + $1.amount }
           let totalAllBudgets = budgetManager.getMonthlyBudgets(from: Date(), to: Date()).reduce(0) { $0 + $1.amount }
           
           guard totalAllBudgets > 0 else { return 0 }
           
           let categoryRatio = totalCategoryBudget / totalAllBudgets
           return totalBudget * categoryRatio
       }
       
       private func calculateOverlayHeight(total: Double, spent: Double, availableHeight: CGFloat) -> CGFloat {
           let ratio = max(0, min(1, (total - spent) / total))
           return CGFloat(ratio) * availableHeight
       }
       
       private func totalBudget() -> Double {
           filteredAndSortedBudgetData.reduce(0) { $0 + $1.budgetedAmount }
       }
       
       private func totalSpent() -> Double {
           filteredAndSortedBudgetData.reduce(0) { $0 + $1.amountSpent }
       }
   }

   

   struct BudgetSummaryCard: View {
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

struct BudgetHistoryRow: View {
    let data: BudgetHistoryData
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(data.category)
                .font(.headline)
            HStack {
                Text("Budget: $\(data.budgetedAmount, specifier: "%.2f")")
                Spacer()
                Text("Spent: $\(data.amountSpent, specifier: "%.2f")")
                    .foregroundColor(data.amountSpent > data.budgetedAmount ? .red : color)
            }
            .font(.subheadline)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(data.amountSpent > data.budgetedAmount ? Color.red : color)
                        .frame(width: min(CGFloat(data.amountSpent / data.budgetedAmount) * geometry.size.width, geometry.size.width))
                    
                    if data.amountSpent < data.budgetedAmount {
                        Rectangle()
                            .fill(color.opacity(0.3))
                            .frame(width: CGFloat((data.budgetedAmount - data.amountSpent) / data.budgetedAmount) * geometry.size.width)
                    }
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
