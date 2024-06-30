//
//  TimePeriod.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import Foundation

enum TimePeriod: Equatable, Hashable {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case last7Days
    case last30Days
    case last12Months
    case allTime
    case custom(Date, Date)
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last12Months: return "Last 12 Months"
        case .allTime: return "All Time"
        case .custom: return "Custom Range"
        }
    }
    
    func dateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return DateInterval(start: startOfMonth, end: now)
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return DateInterval(start: startOfYear, end: now)
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return DateInterval(start: sevenDaysAgo, end: now)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            return DateInterval(start: thirtyDaysAgo, end: now)
        case .last12Months:
            let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now)!
            return DateInterval(start: twelveMonthsAgo, end: now)
        case .allTime:
            return DateInterval(start: .distantPast, end: now)
        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
    
    static var allCases: [TimePeriod] {
        [.today, .thisWeek, .thisMonth, .thisYear, .last7Days, .last30Days, .last12Months, .allTime]
    }
}
    
   
    
   
