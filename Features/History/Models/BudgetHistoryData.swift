//
//  BudgetHistoryData.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/22/25.
//


import Foundation
import SwiftUI

public struct BudgetHistoryData: Identifiable {
    public let id = UUID()
    public let category: String
    public let budgetedAmount: Double
    public let amountSpent: Double
    
    public var remainingAmount: Double {
        budgetedAmount - amountSpent
    }
    
    public var percentageSpent: Double {
        guard budgetedAmount > 0 else { return 0 }
        return (amountSpent / budgetedAmount) * 100
    }
    
    public var isOverBudget: Bool {
        amountSpent > budgetedAmount
    }
    
    public init(category: String, budgetedAmount: Double, amountSpent: Double) {
        self.category = category
        self.budgetedAmount = budgetedAmount
        self.amountSpent = amountSpent
    }
}
