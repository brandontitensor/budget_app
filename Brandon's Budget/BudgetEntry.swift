//
//  BudgetEntry.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import Foundation

struct BudgetEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let amount: Double
    let category: String
    let date: Date
    let note: String?
    
    init(id: UUID = UUID(), amount: Double, category: String, date: Date, note: String? = nil) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.note = note
    }
    
    static func == (lhs: BudgetEntry, rhs: BudgetEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.amount == rhs.amount &&
        lhs.category == rhs.category &&
        lhs.date == rhs.date &&
        lhs.note == rhs.note
    }
}
