//
//  BudgetOverviewData.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/13/25.
//

import Foundation
import SwiftUI

/// Data structure for budget overview information
public struct BudgetOverviewData: Identifiable, Sendable {
    public let id = UUID()
    public let totalBudgeted: Double
    public let totalSpent: Double
    public let remainingBudget: Double
    public let percentageUsed: Double
    public let categoryCount: Int
    public let transactionCount: Int
    public let isOverBudget: Bool
    public let lastUpdated: Date
    public let timeframe: TimePeriod
    public let categoryBreakdowns: [CategoryBreakdown]
    // Note: Commented out to avoid widget compilation issues
    // public let recentTransactions: [BudgetEntry]
    
    // MARK: - Computed Properties
    public var statusColor: Color {
        if isOverBudget {
            return .red
        } else if percentageUsed > 0.9 {
            return .orange
        } else if percentageUsed > 0.7 {
            return .yellow
        } else {
            return .green
        }
    }
    
    public var statusMessage: String {
        if isOverBudget {
            let overAmount = totalSpent - totalBudgeted
            return "Over budget by \(overAmount.formatted(.currency(code: "USD")))"
        } else if remainingBudget <= 0 {
            return "Budget fully used"
        } else {
            return "\(remainingBudget.formatted(.currency(code: "USD"))) remaining"
        }
    }
    
    public var progressPercentage: Double {
        return min(percentageUsed, 1.0)
    }
    
    public var healthScore: Double {
        if isOverBudget {
            return 0.0
        } else if percentageUsed <= 0.7 {
            return 1.0
        } else if percentageUsed <= 0.9 {
            return 0.7
        } else {
            return 0.3
        }
    }
    
    // MARK: - Category Breakdown Structure
    public struct CategoryBreakdown: Identifiable, Sendable {
        public let id = UUID()
        public let category: String
        public let spent: Double
        public let budgeted: Double
        public let percentage: Double
        public let transactionCount: Int
        
        public var isOverBudget: Bool {
            spent > budgeted
        }
        
        public var remaining: Double {
            budgeted - spent
        }
        
        public var efficiency: Double {
            guard budgeted > 0 else { return 0 }
            return min(spent / budgeted, 1.0)
        }
        
        public init(category: String, spent: Double, budgeted: Double, transactionCount: Int) {
            self.category = category
            self.spent = max(0, spent)
            self.budgeted = max(0, budgeted)
            self.percentage = budgeted > 0 ? (spent / budgeted) * 100 : 0
            self.transactionCount = max(0, transactionCount)
        }
    }
    
    // MARK: - Initialization
    public init(
        totalBudgeted: Double,
        totalSpent: Double,
        categoryCount: Int,
        transactionCount: Int,
        timeframe: TimePeriod,
        categoryBreakdowns: [CategoryBreakdown] = []
        // Note: Removed recentTransactions parameter to avoid widget compilation issues
        // recentTransactions: [BudgetEntry] = []
    ) {
        self.totalBudgeted = max(0, totalBudgeted)
        self.totalSpent = max(0, totalSpent)
        self.remainingBudget = totalBudgeted - totalSpent
        self.percentageUsed = totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0
        self.categoryCount = max(0, categoryCount)
        self.transactionCount = max(0, transactionCount)
        self.isOverBudget = totalSpent > totalBudgeted
        self.lastUpdated = Date()
        self.timeframe = timeframe
        self.categoryBreakdowns = categoryBreakdowns
        // self.recentTransactions = recentTransactions
    }
}

// MARK: - Equatable
extension BudgetOverviewData: Equatable {
    public static func == (lhs: BudgetOverviewData, rhs: BudgetOverviewData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.totalBudgeted == rhs.totalBudgeted &&
               lhs.totalSpent == rhs.totalSpent &&
               lhs.categoryCount == rhs.categoryCount &&
               lhs.transactionCount == rhs.transactionCount &&
               lhs.timeframe == rhs.timeframe
    }
}

extension BudgetOverviewData.CategoryBreakdown: Equatable {
    public static func == (lhs: BudgetOverviewData.CategoryBreakdown, rhs: BudgetOverviewData.CategoryBreakdown) -> Bool {
        return lhs.category == rhs.category &&
               lhs.spent == rhs.spent &&
               lhs.budgeted == rhs.budgeted &&
               lhs.transactionCount == rhs.transactionCount
    }
}

// MARK: - Testing Support
#if DEBUG
extension BudgetOverviewData {
    static func mock(
        totalBudgeted: Double = 1000.0,
        totalSpent: Double = 750.0,
        categoryCount: Int = 5,
        transactionCount: Int = 25,
        timeframe: TimePeriod = .thisMonth
    ) -> BudgetOverviewData {
        let categories = [
            CategoryBreakdown(category: "Food", spent: 300, budgeted: 400, transactionCount: 10),
            CategoryBreakdown(category: "Transportation", spent: 200, budgeted: 250, transactionCount: 8),
            CategoryBreakdown(category: "Entertainment", spent: 150, budgeted: 200, transactionCount: 5),
            CategoryBreakdown(category: "Utilities", spent: 100, budgeted: 150, transactionCount: 2)
        ]
        
        return BudgetOverviewData(
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            categoryCount: categoryCount,
            transactionCount: transactionCount,
            timeframe: timeframe,
            categoryBreakdowns: categories
        )
    }
}
#endif