//
//  MonthlyBudget.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import Foundation

/// Represents a monthly budget with validation and error handling
public struct MonthlyBudget: Identifiable, Codable, Equatable {
    // MARK: - Properties
    public let id: UUID
    private let _month: Int
    private let _year: Int
    private let _isHistorical: Bool
    private var _categories: [String: Double]
    
    // MARK: - Public Interface
    public var categories: [String: Double] {
        get { _categories }
        set { _categories = newValue }
    }
    
    public var month: Int {
        _month
    }
    
    public var year: Int {
        _year
    }
    
    public var isHistorical: Bool {
        _isHistorical
    }
    
    // MARK: - Computed Properties for Backward Compatibility
    public var category: String {
        _categories.keys.first ?? "Uncategorized"
    }
    
    public var amount: Double {
        _categories.values.reduce(0, +)
    }
    
    // MARK: - Validation
    public enum ValidationError: LocalizedError {
        case invalidCategory
        case negativeAmount
        case invalidMonth
        case invalidYear
        case futureDateForHistorical
        case amountTooLarge
        
        public var errorDescription: String? {
            switch self {
            case .invalidCategory:
                return "Category name cannot be empty"
            case .negativeAmount:
                return "Budget amount cannot be negative"
            case .invalidMonth:
                return "Month must be between 1 and 12"
            case .invalidYear:
                return "Invalid year"
            case .futureDateForHistorical:
                return "Historical budgets cannot be in the future"
            case .amountTooLarge:
                return "Budget amount exceeds maximum allowed"
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize with categories dictionary
    public init(
        id: UUID = UUID(),
        month: Int,
        year: Int,
        categories: [String: Double] = [:],
        isHistorical: Bool = false
    ) throws {
        try Self.validate(
            categories: categories,
            month: month,
            year: year,
            isHistorical: isHistorical
        )
        
        self.id = id
        self._month = month
        self._year = year
        self._categories = categories
        self._isHistorical = isHistorical
    }
    
    /// Initialize with single category (backward compatibility)
    public init(
        id: UUID = UUID(),
        category: String,
        amount: Double,
        month: Int,
        year: Int,
        isHistorical: Bool = false
    ) throws {
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        try self.init(
            id: id,
            month: month,
            year: year,
            categories: [cleanCategory: amount],
            isHistorical: isHistorical
        )
    }
    
    // MARK: - Validation Methods
    private static func validate(
        categories: [String: Double],
        month: Int,
        year: Int,
        isHistorical: Bool
    ) throws {
        // Validate categories
        for (categoryName, amount) in categories {
            guard !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidCategory
            }
            
            guard amount >= 0 else {
                throw ValidationError.negativeAmount
            }
            
            guard amount <= AppConstants.Validation.maximumTransactionAmount else {
                throw ValidationError.amountTooLarge
            }
        }
        
        guard (1...12).contains(month) else {
            throw ValidationError.invalidMonth
        }
        
        guard year >= 1900 && year <= 9999 else {
            throw ValidationError.invalidYear
        }
        
        if isHistorical {
            let currentDate = Date()
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: currentDate)
            let currentMonth = calendar.component(.month, from: currentDate)
            
            if year > currentYear || (year == currentYear && month > currentMonth) {
                throw ValidationError.futureDateForHistorical
            }
        }
    }
    
    // MARK: - Helper Methods
    public var startDate: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
    
    public var endDate: Date {
        Calendar.current.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: startDate
        ) ?? Date()
    }
    
    public var monthYearString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: startDate)
    }
    
    // MARK: - Comparison Methods
    public func isSameMonth(as other: MonthlyBudget) -> Bool {
        year == other.year && month == other.month
    }
    
    public func isBefore(_ date: Date) -> Bool {
        endDate < date
    }
    
    public func isAfter(_ date: Date) -> Bool {
        startDate > date
    }
}

// MARK: - Comparable
extension MonthlyBudget: Comparable {
    public static func < (lhs: MonthlyBudget, rhs: MonthlyBudget) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        return lhs.month < rhs.month
    }
}

// MARK: - Helper Methods for Categories
extension MonthlyBudget {
    /// Add or update a category in this budget
    public mutating func setCategory(_ name: String, amount: Double) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidCategory
        }
        
        guard amount >= 0 else {
            throw ValidationError.negativeAmount
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw ValidationError.amountTooLarge
        }
        
        _categories[name.trimmingCharacters(in: .whitespacesAndNewlines)] = amount
    }
    
    /// Remove a category from this budget
    public mutating func removeCategory(_ name: String) {
        _categories.removeValue(forKey: name)
    }
    
    /// Get amount for a specific category
    public func amountForCategory(_ name: String) -> Double {
        return _categories[name] ?? 0.0
    }
    
    /// Check if this budget has a specific category
    public func hasCategory(_ name: String) -> Bool {
        return _categories[name] != nil
    }
}

// MARK: - Testing Support
#if DEBUG
extension MonthlyBudget {
    /// Create a test monthly budget
    /// - Returns: Valid test budget
    static func mock(
        id: UUID = UUID(),
        category: String = "Test Category",
        amount: Double = 1000.0,
        month: Int = Calendar.current.component(.month, from: Date()),
        year: Int = Calendar.current.component(.year, from: Date()),
        isHistorical: Bool = false
    ) -> MonthlyBudget {
        try! MonthlyBudget(
            id: id,
            category: category,
            amount: amount,
            month: month,
            year: year,
            isHistorical: isHistorical
        )
    }
    
    /// Create an array of test monthly budgets
    /// - Parameter count: Number of budgets to create
    /// - Returns: Array of test budgets
    static func mockArray(count: Int) -> [MonthlyBudget] {
        (0..<count).map { index in
            try! MonthlyBudget(
                month: (index % 12) + 1,
                year: Calendar.current.component(.year, from: Date()),
                categories: ["Category \(index + 1)": Double((index + 1) * 1000)]
            )
        }
    }
    
    /// Create a multi-category test budget
    static func mockMultiCategory(
        month: Int = Calendar.current.component(.month, from: Date()),
        year: Int = Calendar.current.component(.year, from: Date())
    ) -> MonthlyBudget {
        try! MonthlyBudget(
            month: month,
            year: year,
            categories: [
                "Housing": 2000.0,
                "Food": 800.0,
                "Transportation": 500.0,
                "Entertainment": 300.0,
                "Utilities": 200.0
            ]
        )
    }
}
#endif
