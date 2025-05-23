//
//  BudgetEntry.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation

/// Represents a budget entry with proper value types and validation
public struct BudgetEntry: Identifiable, Codable, Equatable {
    // MARK: - Properties
    public let id: UUID
    private let _amount: Decimal // Use Decimal for financial calculations
    private let _category: String
    private let _date: Date
    private let _note: String?
    
    // MARK: - Computed Properties
    public var amount: Double {
        (try? _amount.asDouble()) ?? 0.0
    }
    
    public var category: String {
        _category.isEmpty ? "Uncategorized" : _category
    }
    
    public var date: Date {
        _date
    }
    
    public var note: String? {
        _note
    }
    
    // MARK: - Validation
    public enum ValidationError: LocalizedError {
        case invalidAmount
        case invalidCategory
        case invalidDate
        case noteTooLong
        
        public var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return "Amount must be greater than zero"
            case .invalidCategory:
                return "Category cannot be empty"
            case .invalidDate:
                return "Invalid date"
            case .noteTooLong:
                return "Note exceeds maximum length"
            }
        }
    }
    
    // MARK: - Initialization
    /// Create a new budget entry with validation
    /// - Parameters:
    ///   - id: Optional UUID (defaults to new UUID)
    ///   - amount: Entry amount
    ///   - category: Category name
    ///   - date: Entry date
    ///   - note: Optional note
    /// - Throws: ValidationError if parameters are invalid
    public init(
        id: UUID = UUID(),
        amount: Double,
        category: String,
        date: Date,
        note: String? = nil
    ) throws {
        try Self.validate(
            amount: amount,
            category: category,
            date: date,
            note: note
        )
        
        self.id = id
        self._amount = Decimal(amount)
        self._category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self._date = date
        self._note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Validation Methods
    private static func validate(
        amount: Double,
        category: String,
        date: Date,
        note: String?
    ) throws {
        guard amount > 0 else {
            throw ValidationError.invalidAmount
        }
        
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidCategory
        }
        
        guard date <= Date() else {
            throw ValidationError.invalidDate
        }
        
        if let note = note, note.count > 500 {
            throw ValidationError.noteTooLong
        }
    }
}

// MARK: - Comparable
extension BudgetEntry: Comparable {
    public static func < (lhs: BudgetEntry, rhs: BudgetEntry) -> Bool {
        lhs.date > rhs.date // Default sort by date descending
    }
}

// MARK: - Formatting
extension BudgetEntry {
    /// Format date as string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Format amount as currency string
    var formattedAmount: String {
        NumberFormatter.formatCurrency(amount)
    }
    
    /// Format short date
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Helpers
private extension Decimal {
    /// Convert Decimal to Double safely
    func asDouble() throws -> Double {
        guard let double = NSDecimalNumber(decimal: self).doubleValue as Double? else {
            throw BudgetEntry.ValidationError.invalidAmount
        }
        return double
    }
}

// MARK: - Testing Support
#if DEBUG
extension BudgetEntry {
    /// Create a test budget entry
    /// - Returns: Valid test entry
    static func mock(
        id: UUID = UUID(),
        amount: Double = 100.0,
        category: String = "Test Category",
        date: Date = Date(),
        note: String? = nil
    ) -> BudgetEntry {
        try! BudgetEntry(
            id: id,
            amount: amount,
            category: category,
            date: date,
            note: note
        )
    }
}
#endif
