//
//  TimePeriod.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//


//
//  TimePeriod.swift
//  Brandon's Budget
//
//  Extracted from SharedTypes.swift for better code organization
//

import Foundation

// MARK: - Time Period
public enum TimePeriod: Equatable, Hashable, Codable, Sendable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisQuarter
    case lastQuarter
    case thisYear
    case lastYear
    case last7Days
    case last30Days
    case last90Days
    case last12Months
    case allTime
    case custom(Date, Date)
    
    // MARK: - Display Properties
    
    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisQuarter: return "This Quarter"
        case .lastQuarter: return "Last Quarter"
        case .thisYear: return "This Year"
        case .lastYear: return "Last Year"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .last12Months: return "Last 12 Months"
        case .allTime: return "All Time"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
    
    public var shortDisplayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisQuarter: return "This Quarter"
        case .lastQuarter: return "Last Quarter"
        case .thisYear: return "This Year"
        case .lastYear: return "Last Year"
        case .last7Days: return "7 Days"
        case .last30Days: return "30 Days"
        case .last90Days: return "90 Days"
        case .last12Months: return "12 Months"
        case .allTime: return "All Time"
        case .custom: return "Custom"
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .today, .yesterday: return "calendar"
        case .thisWeek, .lastWeek: return "calendar.badge.clock"
        case .thisMonth, .lastMonth: return "calendar.circle"
        case .thisQuarter, .lastQuarter: return "calendar.circle.fill"
        case .thisYear, .lastYear: return "calendar.badge.plus"
        case .last7Days, .last30Days, .last90Days: return "clock.arrow.circlepath"
        case .last12Months: return "calendar.badge.minus"
        case .allTime: return "infinity.circle"
        case .custom: return "calendar.badge.exclamationmark"
        }
    }
    
    // MARK: - Date Interval Calculation
    
    public func dateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return DateInterval(start: startOfDay, end: endOfDay)
            
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let startOfYesterday = calendar.startOfDay(for: yesterday)
            let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday) ?? yesterday
            return DateInterval(start: startOfYesterday, end: endOfYesterday)
            
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            return DateInterval(start: startOfWeek, end: endOfWeek)
            
        case .lastWeek:
            let thisWeekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) ?? now
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            return DateInterval(start: lastWeekStart, end: thisWeekStart)
            
        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return DateInterval(start: startOfMonth, end: endOfMonth)
            
        case .lastMonth:
            let thisMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            return DateInterval(start: lastMonthStart, end: thisMonthStart)
            
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            let quarterStart = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: quarterStartMonth
            )) ?? now
            let quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            return DateInterval(start: quarterStart, end: quarterEnd)
            
        case .lastQuarter:
            let month = calendar.component(.month, from: now)
            let thisQuarterStartMonth = ((month - 1) / 3) * 3 + 1
            let lastQuarterStartMonth = thisQuarterStartMonth - 3
            let year = calendar.component(.year, from: now)
            let adjustedYear = lastQuarterStartMonth <= 0 ? year - 1 : year
            let adjustedMonth = lastQuarterStartMonth <= 0 ? lastQuarterStartMonth + 12 : lastQuarterStartMonth
            
            let quarterStart = calendar.date(from: DateComponents(
                year: adjustedYear,
                month: adjustedMonth
            )) ?? now
            let quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? now
            return DateInterval(start: quarterStart, end: quarterEnd)
            
        case .thisYear:
            let startOfYear = calendar.date(
                from: calendar.dateComponents([.year], from: now)
            ) ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
            return DateInterval(start: startOfYear, end: endOfYear)
            
        case .lastYear:
            let thisYearStart = calendar.date(
                from: calendar.dateComponents([.year], from: now)
            ) ?? now
            let lastYearStart = calendar.date(byAdding: .year, value: -1, to: thisYearStart) ?? now
            return DateInterval(start: lastYearStart, end: thisYearStart)
            
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: sevenDaysAgo, end: now)
            
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return DateInterval(start: thirtyDaysAgo, end: now)
            
        case .last90Days:
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return DateInterval(start: ninetyDaysAgo, end: now)
            
        case .last12Months:
            let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: now) ?? now
            return DateInterval(start: twelveMonthsAgo, end: now)
            
        case .allTime:
            return DateInterval(start: .distantPast, end: now)
            
        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
    
    // MARK: - Convenience Properties
    
    /// Duration of the time period in days
    public var durationInDays: Int {
        let interval = dateInterval()
        return Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    }
    
    /// Whether this time period includes today
    public var includesCurrentDate: Bool {
        let interval = dateInterval()
        let now = Date()
        return interval.contains(now)
    }
    
    /// Whether this is a relative time period (changes with current date)
    public var isRelative: Bool {
        switch self {
        case .custom, .allTime:
            return false
        default:
            return true
        }
    }
    
    /// Whether this time period represents a complete period (vs partial)
    public var isComplete: Bool {
        let now = Date()
        let interval = dateInterval()
        
        switch self {
        case .today, .yesterday:
            return interval.end <= now
        case .thisWeek, .thisMonth, .thisQuarter, .thisYear:
            return false // Current periods are incomplete
        case .lastWeek, .lastMonth, .lastQuarter, .lastYear:
            return true // Past periods are complete
        case .last7Days, .last30Days, .last90Days, .last12Months:
            return false // Rolling periods are always partial
        case .allTime:
            return false // All time is never complete
        case .custom(_, let end):
            return end <= now
        }
    }
    
    // MARK: - Static Collections
    
    /// All available time periods (excluding custom)
    static var allCases: [TimePeriod] {
        [
            .today,
            .yesterday,
            .thisWeek,
            .lastWeek,
            .thisMonth,
            .lastMonth,
            .thisQuarter,
            .lastQuarter,
            .thisYear,
            .lastYear,
            .last7Days,
            .last30Days,
            .last90Days,
            .last12Months,
            .allTime
        ]
    }
    
    /// Common time periods for quick selection
    static var commonPeriods: [TimePeriod] {
        [
            .today,
            .thisWeek,
            .thisMonth,
            .thisYear,
            .last7Days,
            .last30Days,
            .allTime
        ]
    }
    
    /// Recent time periods
    static var recentPeriods: [TimePeriod] {
        [
            .today,
            .yesterday,
            .last7Days,
            .last30Days
        ]
    }
    
    /// Historical time periods
    static var historicalPeriods: [TimePeriod] {
        [
            .lastWeek,
            .lastMonth,
            .lastQuarter,
            .lastYear,
            .last12Months,
            .allTime
        ]
    }
    
    // MARK: - Helper Methods
    
    /// Get the next time period of the same type
    public func next() -> TimePeriod? {
        let calendar = Calendar.current
        
        switch self {
        case .today:
            return .yesterday
        case .yesterday:
            let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return .custom(calendar.startOfDay(for: twoDaysAgo), calendar.startOfDay(for: oneDayAgo))
        case .thisWeek:
            return .lastWeek
        case .thisMonth:
            return .lastMonth
        case .thisQuarter:
            return .lastQuarter
        case .thisYear:
            return .lastYear
        case .custom(let start, let end):
            let duration = end.timeIntervalSince(start)
            let newEnd = start
            let newStart = Date(timeInterval: -duration, since: newEnd)
            return .custom(newStart, newEnd)
        default:
            return nil
        }
    }
    
    /// Get the previous time period of the same type
    public func previous() -> TimePeriod? {
        let calendar = Calendar.current
        
        switch self {
        case .yesterday:
            return .today
        case .lastWeek:
            return .thisWeek
        case .lastMonth:
            return .thisMonth
        case .lastQuarter:
            return .thisQuarter
        case .lastYear:
            return .thisYear
        case .custom(let start, let end):
            let duration = end.timeIntervalSince(start)
            let newStart = end
            let newEnd = Date(timeInterval: duration, since: newStart)
            return .custom(newStart, newEnd)
        default:
            return nil
        }
    }
    
    /// Check if this period contains a specific date
    public func contains(_ date: Date) -> Bool {
        return dateInterval().contains(date)
    }
    
    /// Get formatted date range string
    public func formattedDateRange(style: DateFormatter.Style = .medium) -> String {
        let interval = dateInterval()
        let formatter = DateFormatter()
        formatter.dateStyle = style
        
        let startString = formatter.string(from: interval.start)
        let endString = formatter.string(from: interval.end)
        
        // If same day, show only one date
        let calendar = Calendar.current
        if calendar.isDate(interval.start, inSameDayAs: interval.end) {
            return startString
        }
        
        return "\(startString) - \(endString)"
    }
    
    /// Create custom time period with validation
    public static func createCustom(start: Date, end: Date) -> TimePeriod? {
        guard start <= end else { return nil }
        return .custom(start, end)
    }
}

// MARK: - Codable Implementation

extension TimePeriod {
    private enum CodingKeys: String, CodingKey {
        case type, startDate, endDate
    }
    
    private enum PeriodType: String, Codable {
        case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth
        case thisQuarter, lastQuarter, thisYear, lastYear
        case last7Days, last30Days, last90Days, last12Months
        case allTime, custom
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PeriodType.self, forKey: .type)
        
        switch type {
        case .today: self = .today
        case .yesterday: self = .yesterday
        case .thisWeek: self = .thisWeek
        case .lastWeek: self = .lastWeek
        case .thisMonth: self = .thisMonth
        case .lastMonth: self = .lastMonth
        case .thisQuarter: self = .thisQuarter
        case .lastQuarter: self = .lastQuarter
        case .thisYear: self = .thisYear
        case .lastYear: self = .lastYear
        case .last7Days: self = .last7Days
        case .last30Days: self = .last30Days
        case .last90Days: self = .last90Days
        case .last12Months: self = .last12Months
        case .allTime: self = .allTime
        case .custom:
            let start = try container.decode(Date.self, forKey: .startDate)
            let end = try container.decode(Date.self, forKey: .endDate)
            self = .custom(start, end)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .today:
            try container.encode(PeriodType.today, forKey: .type)
        case .yesterday:
            try container.encode(PeriodType.yesterday, forKey: .type)
        case .thisWeek:
            try container.encode(PeriodType.thisWeek, forKey: .type)
        case .lastWeek:
            try container.encode(PeriodType.lastWeek, forKey: .type)
        case .thisMonth:
            try container.encode(PeriodType.thisMonth, forKey: .type)
        case .lastMonth:
            try container.encode(PeriodType.lastMonth, forKey: .type)
        case .thisQuarter:
            try container.encode(PeriodType.thisQuarter, forKey: .type)
        case .lastQuarter:
            try container.encode(PeriodType.lastQuarter, forKey: .type)
        case .thisYear:
            try container.encode(PeriodType.thisYear, forKey: .type)
        case .lastYear:
            try container.encode(PeriodType.lastYear, forKey: .type)
        case .last7Days:
            try container.encode(PeriodType.last7Days, forKey: .type)
        case .last30Days:
            try container.encode(PeriodType.last30Days, forKey: .type)
        case .last90Days:
            try container.encode(PeriodType.last90Days, forKey: .type)
        case .last12Months:
            try container.encode(PeriodType.last12Months, forKey: .type)
        case .allTime:
            try container.encode(PeriodType.allTime, forKey: .type)
        case .custom(let start, let end):
            try container.encode(PeriodType.custom, forKey: .type)
            try container.encode(start, forKey: .startDate)
            try container.encode(end, forKey: .endDate)
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension TimePeriod {
    /// Create test time periods
    static var testPeriods: [TimePeriod] {
        [
            .today,
            .last7Days,
            .thisMonth,
            .last12Months,
            .custom(
                Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                Date()
            )
        ]
    }
    
    /// Create a custom period for testing
    static func testCustom(daysAgo start: Int, daysAgo end: Int) -> TimePeriod {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -start, to: now) ?? now
        let endDate = calendar.date(byAdding: .day, value: -end, to: now) ?? now
        return .custom(startDate, endDate)
    }
}

// MARK: - Preview Support
struct TimePeriod_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section("Common Periods") {
                ForEach(TimePeriod.commonPeriods, id: \.self) { period in
                    HStack {
                        Image(systemName: period.systemImageName)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(period.displayName)
                                .font(.headline)
                            Text(period.formattedDateRange())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(period.durationInDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Historical Periods") {
                ForEach(TimePeriod.historicalPeriods, id: \.self) { period in
                    HStack {
                        Image(systemName: period.systemImageName)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(period.displayName)
                                .font(.headline)
                            Text(period.formattedDateRange(style: .short))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if period.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
}
#endif