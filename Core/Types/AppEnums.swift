//
//  AppEnums.swift
//  Brandon's Budget
//
//  Extracted from SharedTypes.swift for better code organization
//

import Foundation

// MARK: - Sort Options
public enum BudgetSortOption: String, CaseIterable, Codable {
    case category = "Category"
    case budgetedAmount = "Budgeted Amount"
    case amountSpent = "Amount Spent"
    case date = "Date"
    case amount = "Amount"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Filter Options
public enum FilterType: String, CaseIterable, Codable {
    case all = "All"
    case category = "Category"
    case date = "Date"
    case amount = "Amount"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Sort Direction
public enum SortDirection: String, CaseIterable, Codable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var isAscending: Bool {
        return self == .ascending
    }
}

// MARK: - View Type Options
public enum ViewType: String, CaseIterable, Codable {
    case list = "List"
    case chart = "Chart"
    case summary = "Summary"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .list: return "list.bullet"
        case .chart: return "chart.bar"
        case .summary: return "doc.text"
        }
    }
}

// MARK: - Budget Category Type
public enum BudgetCategoryType: String, CaseIterable, Codable {
    case expense = "Expense"
    case income = "Income"
    case savings = "Savings"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var color: String {
        switch self {
        case .expense: return "red"
        case .income: return "green"
        case .savings: return "blue"
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .expense: return "minus.circle"
        case .income: return "plus.circle"
        case .savings: return "arrow.up.circle"
        }
    }
}

// MARK: - Chart Type
public enum ChartType: String, CaseIterable, Codable {
    case pie = "Pie"
    case bar = "Bar"
    case line = "Line"
    case donut = "Donut"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .pie: return "chart.pie"
        case .bar: return "chart.bar"
        case .line: return "chart.line.uptrend.xyaxis"
        case .donut: return "chart.donut"
        }
    }
}

// MARK: - Date Range Type
public enum DateRangeType: String, CaseIterable, Codable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case custom = "Custom"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .day: return "calendar"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar.circle"
        case .year: return "calendar.badge.plus"
        case .custom: return "calendar.badge.exclamationmark"
        }
    }
}

// MARK: - Transaction Status
public enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case failed = "Failed"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .pending: return "clock"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    public var color: String {
        switch self {
        case .pending: return "orange"
        case .completed: return "green"
        case .cancelled: return "gray"
        case .failed: return "red"
        }
    }
}

// MARK: - Export Format
public enum ExportFormat: String, CaseIterable, Codable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var fileExtension: String {
        return self.rawValue.lowercased()
    }
    
    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .pdf: return "application/pdf"
        }
    }
}

// MARK: - Import Format
public enum ImportFormat: String, CaseIterable, Codable {
    case csv = "CSV"
    case json = "JSON"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var fileExtension: String {
        return self.rawValue.lowercased()
    }
    
    public var allowedContentTypes: [String] {
        switch self {
        case .csv: return ["public.comma-separated-values-text", "text/csv"]
        case .json: return ["public.json", "application/json"]
        }
    }
}

// MARK: - Notification Frequency
public enum NotificationFrequency: String, CaseIterable, Codable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .never: return "bell.slash"
        case .daily: return "bell.badge"
        case .weekly: return "bell.badge.circle"
        case .monthly: return "bell.badge.fill"
        }
    }
}

// MARK: - App Theme
public enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

// MARK: - Data Validation Level
public enum ValidationLevel: String, CaseIterable, Codable {
    case strict = "Strict"
    case moderate = "Moderate"
    case lenient = "Lenient"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var description: String {
        switch self {
        case .strict: return "All fields must be perfectly formatted"
        case .moderate: return "Minor formatting issues are corrected automatically"
        case .lenient: return "Most formatting issues are ignored or corrected"
        }
    }
}

// MARK: - Currency Display Format
public enum CurrencyFormat: String, CaseIterable, Codable {
    case symbol = "Symbol" // $1,234.56
    case code = "Code" // USD 1,234.56
    case name = "Name" // 1,234.56 US Dollars
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var example: String {
        switch self {
        case .symbol: return "$1,234.56"
        case .code: return "USD 1,234.56"
        case .name: return "1,234.56 US Dollars"
        }
    }
}

// MARK: - Date Display Format
public enum DateDisplayFormat: String, CaseIterable, Codable {
    case short = "Short" // 12/31/24
    case medium = "Medium" // Dec 31, 2024
    case long = "Long" // December 31, 2024
    case full = "Full" // Tuesday, December 31, 2024
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var dateStyle: DateFormatter.Style {
        switch self {
        case .short: return .short
        case .medium: return .medium
        case .long: return .long
        case .full: return .full
        }
    }
}

// MARK: - Widget Size
public enum WidgetSize: String, CaseIterable, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .small: return "rectangle"
        case .medium: return "rectangle.grid.1x2"
        case .large: return "rectangle.grid.2x2"
        }
    }
}

// MARK: - Backup Frequency
public enum BackupFrequency: String, CaseIterable, Codable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case manual = "Manual Only"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var systemImageName: String {
        switch self {
        case .never: return "xmark.icloud"
        case .daily: return "icloud.and.arrow.up"
        case .weekly: return "icloud.and.arrow.up.fill"
        case .monthly: return "icloud.circle"
        case .manual: return "hand.raised"
        }
    }
}

// MARK: - Helper Extensions

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    /// Get all display names for picker views
    static var allDisplayNames: [String] {
        return allCases.map { ($0 as! any CustomStringConvertible).displayName }
    }
}

extension RawRepresentable where RawValue == String {
    /// Get localized display name if available
    var localizedDisplayName: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

// MARK: - Type Aliases for Convenience

public typealias SortOption = BudgetSortOption
public typealias Filter = FilterType
public typealias Sort = SortDirection
