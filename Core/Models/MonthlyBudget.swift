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
    private let _category: String
    private let _amount: Decimal
    private let _month: Int
    private let _year: Int
    private let _isHistorical: Bool
    
    // MARK: - Public Interface
    public var category: String {
        _category.isEmpty ? "Uncategorized" : _category
    }
    
    public var amount: Double {
        (try? _amount.asDouble()) ?? 0.0
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
    public init(
        id: UUID = UUID(),
        category: String,
        amount: Double,
        month: Int,
        year: Int,
        isHistorical: Bool = false
    ) throws {
        try Self.validate(
            category: category,
            amount: amount,
            month: month,
            year: year,
            isHistorical: isHistorical
        )
        
        self.id = id
        self._category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self._amount = Decimal(amount)
        self._month = month
        self._year = year
        self._isHistorical = isHistorical
    }
    
    // MARK: - Validation Methods
    private static func validate(
        category: String,
        amount: Double,
        month: Int,
        year: Int,
        isHistorical: Bool
    ) throws {
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidCategory
        }
        
        guard amount >= 0 else {
            throw ValidationError.negativeAmount
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw ValidationError.amountTooLarge
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

// MARK: - Decimal Extension
private extension Decimal {
    func asDouble() throws -> Double {
        if let double = NSDecimalNumber(decimal: self).doubleValue as Double? {
            return double
        }
        throw MonthlyBudget.ValidationError.negativeAmount
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
                category: "Category \(index + 1)",
                amount: Double((index + 1) * 1000),
                month: (index % 12) + 1,
                year: Calendar.current.component(.year, from: Date())
            )
        }
    }
}
#endif
