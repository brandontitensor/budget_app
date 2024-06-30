//
//  SharedData.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//
import Foundation

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let sharedDefaults: UserDefaults?
    private let remainingBudgetKey = "remainingBudget"
    private let monthlyBudgetKey = "monthlyBudget"
    
    private init() {
        sharedDefaults = UserDefaults(suiteName: "group.com.brandontitensor.BrandonsBudget")
    }
    
    func setRemainingBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: remainingBudgetKey)
    }
    
    func getRemainingBudget() -> Double {
        return sharedDefaults?.double(forKey: remainingBudgetKey) ?? 0.0
    }
    
    func setMonthlyBudget(_ amount: Double) {
        sharedDefaults?.set(amount, forKey: monthlyBudgetKey)
    }
    
    func getMonthlyBudget() -> Double {
        return sharedDefaults?.double(forKey: monthlyBudgetKey) ?? 0.0
    }
}
