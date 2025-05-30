//
//  SpendingData.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI

/// Represents spending data for visualization and analysis
public struct SpendingData: Identifiable, Hashable, Codable {
    // MARK: - Properties
    public let id: UUID
    private let _category: String
    private let _amount: Decimal
    private let _percentage: Decimal
    private let _colorComponents: ColorComponents
    
    // MARK: - Public Interface
    public var category: String {
        _category.isEmpty ? "Uncategorized" : _category
    }
    
    public var amount: Double {
        (try? _amount.asDouble()) ?? 0.0
    }
    
    public var percentage: Double {
        (try? _percentage.asDouble()) ?? 0.0
    }
    
    public var color: Color {
        Color(_colorComponents)
    }
    
    // MARK: - Validation
    public enum ValidationError: LocalizedError {
        case invalidCategory
        case negativeAmount
        case invalidPercentage
        
        public var errorDescription: String? {
            switch self {
            case .invalidCategory:
                return "Category name cannot be empty"
            case .negativeAmount:
                return "Amount cannot be negative"
            case .invalidPercentage:
                return "Percentage must be between 0 and 100"
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        id: UUID = UUID(),
        category: String,
        amount: Double,
        percentage: Double,
        color: Color
    ) throws {
        try Self.validate(
            category: category,
            amount: amount,
            percentage: percentage
        )
        
        self.id = id
        self._category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self._amount = Decimal(amount)
        self._percentage = Decimal(percentage)
        self._colorComponents = ColorComponents(from: color)
    }
    
    // MARK: - Validation Methods
    private static func validate(
        category: String,
        amount: Double,
        percentage: Double
    ) throws {
        guard !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidCategory
        }
        
        guard amount >= 0 else {
            throw ValidationError.negativeAmount
        }
        
        guard percentage >= 0 && percentage <= 100 else {
            throw ValidationError.invalidPercentage
        }
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    public static func == (lhs: SpendingData, rhs: SpendingData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Comparable
extension SpendingData: Comparable {
    public static func < (lhs: SpendingData, rhs: SpendingData) -> Bool {
        lhs.amount > rhs.amount // Sort by amount descending
    }
}



// MARK: - Decimal Extension
private extension Decimal {
    func asDouble() throws -> Double {
        if let double = NSDecimalNumber(decimal: self).doubleValue as Double? {
            return double
        }
        throw SpendingData.ValidationError.negativeAmount
    }
}

// MARK: - Testing Support
#if DEBUG
extension SpendingData {
    /// Create a test spending data instance
    /// - Returns: Valid test data
    static func mock(
        id: UUID = UUID(),
        category: String = "Test Category",
        amount: Double = 100.0,
        percentage: Double = 10.0,
        color: Color = .blue
    ) -> SpendingData {
        try! SpendingData(
            id: id,
            category: category,
            amount: amount,
            percentage: percentage,
            color: color
        )
    }
    
    /// Create an array of test spending data
    /// - Parameter count: Number of items to create
    /// - Returns: Array of test data
    static func mockArray(count: Int) -> [SpendingData] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return (0..<count).map { index in
            try! SpendingData(
                category: "Category \(index + 1)",
                amount: Double((index + 1) * 100),
                percentage: min(Double((index + 1) * 10), 100),
                color: colors[index % colors.count]
            )
        }
    }
}
#endif
