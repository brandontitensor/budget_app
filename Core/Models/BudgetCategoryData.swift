//
//  BudgetCategoryData.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation

/// Represents budget data for a specific category with validation and calculations
public struct BudgetCategoryData: Identifiable, Equatable, Hashable {
    // MARK: - Properties
    public let id: UUID
    private let _name: String
    private let _budgeted: Decimal
    private let _spent: Decimal
    
    // MARK: - Public Interface
    public var name: String {
        _name.isEmpty ? "Uncategorized" : _name
    }
    
    public var budgeted: Double {
        (try? _budgeted.asDouble()) ?? 0.0
    }
    
    public var spent: Double {
        (try? _spent.asDouble()) ?? 0.0
    }
    
    public var percentageSpent: Double {
        guard budgeted > 0 else { return 0 }
        return (spent / budgeted) * 100
    }
    
    public var isOverBudget: Bool {
        spent > budgeted
    }
    
    public var remaining: Double {
        budgeted - spent
    }
    
    public var percentageRemaining: Double {
        guard budgeted > 0 else { return 0 }
        return (remaining / budgeted) * 100
    }
    
    // MARK: - Validation
    public enum ValidationError: LocalizedError {
        case invalidName
        case negativeBudget
        case negativeSpending
        case budgetTooLarge
        
        public var errorDescription: String? {
            switch self {
            case .invalidName:
                return "Category name cannot be empty"
            case .negativeBudget:
                return "Budget amount cannot be negative"
            case .negativeSpending:
                return "Spent amount cannot be negative"
            case .budgetTooLarge:
                return "Budget amount exceeds maximum allowed"
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        id: UUID = UUID(),
        name: String,
        budgeted: Double,
        spent: Double
    ) throws {
        try Self.validate(name: name, budgeted: budgeted, spent: spent)
        
        self.id = id
        self._name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self._budgeted = Decimal(budgeted)
        self._spent = Decimal(spent)
    }
    
    // MARK: - Validation Methods
    private static func validate(
        name: String,
        budgeted: Double,
        spent: Double
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName
        }
        
        guard budgeted >= 0 else {
            throw ValidationError.negativeBudget
        }
        
        guard spent >= 0 else {
            throw ValidationError.negativeSpending
        }
        
        guard budgeted <= AppConstants.Validation.maximumTransactionAmount else {
            throw ValidationError.budgetTooLarge
        }
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    public static func == (lhs: BudgetCategoryData, rhs: BudgetCategoryData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Comparable
extension BudgetCategoryData: Comparable {
    public static func < (lhs: BudgetCategoryData, rhs: BudgetCategoryData) -> Bool {
        lhs.budgeted > rhs.budgeted
    }
}

// MARK: - Decimal Extension
private extension Decimal {
    func asDouble() throws -> Double {
        if let double = NSDecimalNumber(decimal: self).doubleValue as Double? {
            return double
        }
        throw BudgetCategoryData.ValidationError.negativeBudget
    }
}

// MARK: - Testing Support
#if DEBUG
extension BudgetCategoryData {
    /// Create a test budget category data instance
    /// - Returns: Valid test data
    static func mock(
        id: UUID = UUID(),
        name: String = "Test Category",
        budgeted: Double = 1000.0,
        spent: Double = 500.0
    ) -> BudgetCategoryData {
        try! BudgetCategoryData(
            id: id,
            name: name,
            budgeted: budgeted,
            spent: spent
        )
    }
    
    /// Create an array of test budget category data
    /// - Parameter count: Number of categories to create
    /// - Returns: Array of test data
    static func mockArray(count: Int) -> [BudgetCategoryData] {
        (0..<count).map { index in
            mock(
                name: "Category \(index + 1)",
                budgeted: Double((index + 1) * 1000),
                spent: Double((index + 1) * 500)
            )
        }
    }
}
#endif
