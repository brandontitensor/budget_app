import Foundation
import Combine
import WidgetKit
import Intents

struct MonthlyBudget: Identifiable, Codable, Equatable {
    let id: UUID
    let category: String
    let amount: Double
    let month: Int
    let year: Int
    let isHistorical: Bool
    
    init(id: UUID = UUID(), category: String, amount: Double, month: Int, year: Int, isHistorical: Bool = false) {
        self.id = id
        self.category = category
        self.amount = amount
        self.month = month
        self.year = year
        self.isHistorical = isHistorical
    }
}

class BudgetManager: ObservableObject {
    @Published private(set) var entries: [BudgetEntry] = []
    @Published private(set) var monthlyBudgets: [MonthlyBudget] = []
    
    private let coreDataManager: CoreDataManager
    private let calendar = Calendar.current
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        loadData()
        Task {
            await checkAndUpdateMonthlyBudgets()
            await MainActor.run {
                updateRemainingBudget()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadEntries()
        loadMonthlyBudgets()
    }
    
    private func loadEntries() {
        entries = coreDataManager.getAllEntries()
    }
    
    private func loadMonthlyBudgets() {
        monthlyBudgets = coreDataManager.getAllMonthlyBudgets()
    }
    
    // MARK: - Entry Management
    
    func addEntry(_ entry: BudgetEntry) {
        coreDataManager.addEntry(entry)
        entries.append(entry)
        
        refreshWidget()
    }
    
    func updateEntry(_ entry: BudgetEntry) {
        coreDataManager.updateEntry(entry)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
        
        refreshWidget()
    }
    
    func deleteEntry(_ entry: BudgetEntry) {
        coreDataManager.deleteEntry(entry)
        entries.removeAll { $0.id == entry.id }
        
        refreshWidget()
    }
    
    // MARK: - Budget Management
    
    func getMonthlyBudgets(from startDate: Date, to endDate: Date) -> [MonthlyBudget] {
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let endComponents = calendar.dateComponents([.year, .month], from: endDate)
        
        return monthlyBudgets.filter { budget in
            let budgetDate = calendar.date(from: DateComponents(year: budget.year, month: budget.month, day: 1))!
            return budgetDate >= calendar.date(from: startComponents)! && budgetDate <= calendar.date(from: endComponents)!
        }
    }
    
    func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        return monthlyBudgets.filter { $0.month == month && $0.year == year }
    }
    func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) {
        if let index = monthlyBudgets.firstIndex(where: { $0.category == budget.category && $0.month == budget.month && $0.year == budget.year }) {
            monthlyBudgets[index] = budget
        } else {
            monthlyBudgets.append(budget)
        }
        coreDataManager.addOrUpdateMonthlyBudget(budget)
        
        refreshWidget()
    }
    
    func updateMonthlyBudgets(_ budgets: [String: Double], for month: Int, year: Int) {
        for (category, amount) in budgets {
            let budget = MonthlyBudget(category: category, amount: amount, month: month, year: year)
            addOrUpdateMonthlyBudget(budget)
        }
        refreshWidget()
    }
    
    func deleteCategory(_ category: String, for month: Int, year: Int) {
        monthlyBudgets.removeAll { $0.category == category && $0.month == month && $0.year == year }
        coreDataManager.deleteMonthlyBudget(category: category, month: month, year: year)
        
        let updatedEntries = entries.map { entry in
            entry.category == category ?
            BudgetEntry(id: entry.id, amount: entry.amount, category: "Uncategorized", date: entry.date, note: entry.note) :
            entry
        }
        
        entries = updatedEntries
        updatedEntries.forEach { updateEntry($0) }
    }
    
    
    func checkAndUpdateMonthlyBudgets() async {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        let currentMonthBudgets = monthlyBudgets.filter { $0.month == currentMonth && $0.year == currentYear && !$0.isHistorical }
        
        if currentMonthBudgets.isEmpty {
            await copyPreviousMonthBudgets(to: currentMonth, year: currentYear)
        }
        
        await markPreviousMonthBudgetsAsHistorical(currentMonth: currentMonth, currentYear: currentYear)
        
        await MainActor.run {
            loadMonthlyBudgets()
            refreshWidget()
        }
    }
    
    private func copyPreviousMonthBudgets(to currentMonth: Int, year currentYear: Int) async {
        let (previousMonth, previousYear) = getPreviousMonth(month: currentMonth, year: currentYear)
        
        let previousMonthBudgets = monthlyBudgets.filter { $0.month == previousMonth && $0.year == previousYear && !$0.isHistorical }
        
        let newBudgets = previousMonthBudgets.map { budget in
            MonthlyBudget(category: budget.category, amount: budget.amount, month: currentMonth, year: currentYear)
        }
        
        await MainActor.run {
            monthlyBudgets.append(contentsOf: newBudgets)
        }
        
        for budget in newBudgets {
            await coreDataManager.addOrUpdateMonthlyBudgetAsync(budget)
        }
    }
    
    private func markPreviousMonthBudgetsAsHistorical(currentMonth: Int, currentYear: Int) async {
        let (previousMonth, previousYear) = getPreviousMonth(month: currentMonth, year: currentYear)
        
        let budgetsToUpdate = monthlyBudgets.filter { $0.month == previousMonth && $0.year == previousYear && !$0.isHistorical }
        
        for budget in budgetsToUpdate {
            let historicalBudget = MonthlyBudget(id: budget.id, category: budget.category, amount: budget.amount,
                                                 month: budget.month, year: budget.year, isHistorical: true)
            await coreDataManager.addOrUpdateMonthlyBudgetAsync(historicalBudget)
        }
    }
    
    private func getPreviousMonth(month: Int, year: Int) -> (Int, Int) {
        let previousMonth = month == 1 ? 12 : month - 1
        let previousYear = month == 1 ? year - 1 : year
        return (previousMonth, previousYear)
    }
    
    // MARK: - Data Retrieval
    
    func getEntries(from startDate: Date, to endDate: Date) -> [BudgetEntry] {
        return entries.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    func getEntries(for timePeriod: TimePeriod) -> [BudgetEntry] {
        let dateInterval = timePeriod.dateInterval()
        return getEntries(from: dateInterval.start, to: dateInterval.end)
    }
    
    func getCurrentMonthBudget() -> Double {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        return monthlyBudgets
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getCurrentMonthBudget(for category: String) -> Double {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        return monthlyBudgets
            .first { $0.month == currentMonth && $0.year == currentYear && $0.category == category }?
            .amount ?? 0
    }
    
    func getYearlyBudget() -> Double {
        let currentDate = Date()
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        let previousMonthsTotal = monthlyBudgets
            .filter { $0.year == currentYear && $0.month < currentMonth }
            .reduce(0) { $0 + $1.amount }
        
        let remainingMonths = 12 - currentMonth + 1
        return previousMonthsTotal + (Double(remainingMonths) * getCurrentMonthBudget())
    }
    
    func getAvailableCategories() -> [String] {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        return Array(Set(monthlyBudgets
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .map { $0.category }))
        .sorted()
    }
    
    func getTotalBudget(for month: Int, year: Int) -> Double {
        return monthlyBudgets
            .filter { $0.month == month && $0.year == year }
            .reduce(0) { $0 + $1.amount }
    }
    
    func refreshData() {
        loadData()
    }
    
    func resetAllData() {
        coreDataManager.deleteAllData()
        entries = []
        monthlyBudgets = []
    }
    
    //MARK: - Shared Data
    
    func refreshWidget() {
        updateBudgetData()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func updateBudgetData() {
        let monthlyBudget = calculateMonthlyBudget()
        let remainingBudget = calculateRemainingBudget()
        SharedDataManager.shared.setMonthlyBudget(monthlyBudget)
        SharedDataManager.shared.setRemainingBudget(remainingBudget)
    }
    
    private func calculateMonthlyBudget() -> Double {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        return monthlyBudgets
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .reduce(0) { $0 + $1.amount }
    }
    
    func updateRemainingBudget() {
        let remainingBudget = calculateRemainingBudget()
        SharedDataManager.shared.setRemainingBudget(remainingBudget)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func calculateRemainingBudget() -> Double {
        let currentDate = Date()
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        let totalBudget = monthlyBudgets
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .reduce(0) { $0 + $1.amount }
        
        let totalSpent = entries
            .filter {
                let entryMonth = calendar.component(.month, from: $0.date)
                let entryYear = calendar.component(.year, from: $0.date)
                return entryMonth == currentMonth && entryYear == currentYear
            }
            .reduce(0) { $0 + $1.amount }
        
        return totalBudget - totalSpent
    }
    
    // Call this method whenever you add, update, or delete an entry or budget
    func refreshBudgetData() {
        loadData()
        updateRemainingBudget()
    }
    
    
    // MARK: - Data Import
    enum ImportError: Error {
        case invalidFileFormat
        case dataParsingError(String)
        case fileAccessError
    }
    
    func importBudgetData(from url: URL) -> Result<Int, Error> {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(ImportError.fileAccessError)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let rows = csvString.components(separatedBy: .newlines)
            
            guard rows.count > 1 else {
                return .failure(ImportError.invalidFileFormat)
            }
            
            // Verify header
            let expectedHeader = "Year,Month,Category,Amount,IsHistorical"
            guard rows[0].trimmingCharacters(in: .whitespacesAndNewlines) == expectedHeader else {
                return .failure(ImportError.invalidFileFormat)
            }
            
            var importedCount = 0
            
            for (index, row) in rows.enumerated().dropFirst() {
                let columns = row.components(separatedBy: ",")
                guard columns.count == 5 else {
                    print("Skipping row \(index + 1): invalid number of columns")
                    continue
                }
                
                do {
                    let year = try parseIntFromString(columns[0], fieldName: "Year", rowNumber: index + 1)
                    let month = try parseIntFromString(columns[1], fieldName: "Month", rowNumber: index + 1)
                    let category = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let amount = try parseDoubleFromString(columns[3], fieldName: "Amount", rowNumber: index + 1)
                    let isHistorical = try parseBoolFromString(columns[4], fieldName: "IsHistorical", rowNumber: index + 1)
                    
                    let budget = MonthlyBudget(category: category, amount: amount, month: month, year: year, isHistorical: isHistorical)
                    addOrUpdateMonthlyBudget(budget)
                    importedCount += 1
                } catch {
                    print("Error parsing row \(index + 1): \(error.localizedDescription)")
                }
            }
            
            return .success(importedCount)
            
        } catch {
            return .failure(error)
        }
    }
    
    private func parseIntFromString(_ string: String, fieldName: String, rowNumber: Int) throws -> Int {
        guard let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ImportError.dataParsingError("Invalid \(fieldName) in row \(rowNumber)")
        }
        return value
    }
    
    private func parseDoubleFromString(_ string: String, fieldName: String, rowNumber: Int) throws -> Double {
        guard let value = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ImportError.dataParsingError("Invalid \(fieldName) in row \(rowNumber)")
        }
        return value
    }
    
    private func parseBoolFromString(_ string: String, fieldName: String, rowNumber: Int) throws -> Bool {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedString == "true" || trimmedString == "1" {
            return true
        } else if trimmedString == "false" || trimmedString == "0" {
            return false
        } else {
            throw ImportError.dataParsingError("Invalid \(fieldName) in row \(rowNumber)")
        }
    }
    
    func importPurchaseData(from url: URL) -> Result<Int, Error> {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(ImportError.fileAccessError)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let rows = csvString.components(separatedBy: .newlines)
            
            guard rows.count > 1 else {
                return .failure(ImportError.invalidFileFormat)
            }
            
            // Verify header
            let expectedHeader = "Date,Amount,Category,Note"
            guard rows[0].trimmingCharacters(in: .whitespacesAndNewlines) == expectedHeader else {
                return .failure(ImportError.invalidFileFormat)
            }
            
            var importedCount = 0
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for (index, row) in rows.enumerated().dropFirst() {
                let columns = row.components(separatedBy: ",")
                guard columns.count == 4 else {
                    print("Skipping row \(index + 1): invalid number of columns")
                    continue
                }
                
                do {
                    guard let date = dateFormatter.date(from: columns[0]) else {
                        throw ImportError.dataParsingError("Invalid date format in row \(index + 1)")
                    }
                    let amount = try parseDoubleFromString(columns[1], fieldName: "Amount", rowNumber: index + 1)
                    let category = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let entry = BudgetEntry(amount: amount, category: category, date: date, note: note.isEmpty ? nil : note)
                    addEntry(entry)
                    importedCount += 1
                } catch {
                    print("Error parsing row \(index + 1): \(error.localizedDescription)")
                }
            }
            
            return .success(importedCount)
        } catch {
            return .failure(error)
        }
    }
}
    

