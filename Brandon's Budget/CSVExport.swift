//
//  CSVExport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import Foundation

enum CSVExportError: Error {
    case fileCreationFailed
    case dataWriteFailed
}

struct CSVExport {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static func exportToCSV(entries: [BudgetEntry], timePeriod: TimePeriod) -> Result<URL, CSVExportError> {
        let filteredEntries = filterEntries(entries, timePeriod: timePeriod)
        let csvString = createCSVString(from: filteredEntries)
        
        let fileManager = FileManager.default
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileName = generateFileName(for: timePeriod)
            let fileURL = documentDirectory.appendingPathComponent(fileName)
            
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return .success(fileURL)
        } catch {
            print("Failed to write CSV file: \(error.localizedDescription)")
            return .failure(.dataWriteFailed)
        }
    }
    
    private static func filterEntries(_ entries: [BudgetEntry], timePeriod: TimePeriod) -> [BudgetEntry] {
        let (startDate, endDate) = getDateRange(for: timePeriod)
        return entries.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    private static func getDateRange(for timePeriod: TimePeriod) -> (Date, Date) {
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
        case .custom(let startDate, let endDate):
            return (startDate, endDate)
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
    
    private static func createCSVString(from entries: [BudgetEntry]) -> String {
            let headerRow = "Date,Amount,Category,Note\n"
            let rows = entries.map { entry in
                let date = dateFormatter.string(from: entry.date)
                let amount = String(format: "%.2f", entry.amount)
                let category = entry.category.replacingOccurrences(of: ",", with: ";")
                let note = entry.note?.replacingOccurrences(of: ",", with: ";") ?? ""
                return "\(date),\(amount),\(category),\(note)"
            }
            return headerRow + rows.joined(separator: "\n")
        }
    
    
    private static func generateFileName(for timePeriod: TimePeriod) -> String {
        let currentDate = dateFormatter.string(from: Date())
        
        switch timePeriod {
        case .thisWeek:
            return "budget_export_week_\(currentDate).csv"
        case .thisMonth:
            return "budget_export_month_\(currentDate).csv"
        case .thisYear:
            return "budget_export_year_\(currentDate).csv"
        case .allTime:
            return "budget_export_all_time_\(currentDate).csv"
        case .custom(let startDate, let endDate):
            let start = dateFormatter.string(from: startDate)
            let end = dateFormatter.string(from: endDate)
            return "budget_export_custom_\(start)_to_\(end).csv"
        case .today:
            return "budget_export_today\(currentDate).csv"
        case .last7Days:
            return "budget_export_last7Days\(currentDate).csv"
        case .last30Days:
            return "budget_export_last30Days\(currentDate).csv"
        case .last12Months:
            return "budget_export_last12Months\(currentDate).csv"
        }
    }
}

// Extension to make CSVExport testable
extension CSVExport {
    static func exportForTesting(entries: [BudgetEntry], timePeriod: TimePeriod) -> String {
        let filteredEntries = filterEntries(entries, timePeriod: timePeriod)
        return createCSVString(from: filteredEntries)
    }
}
