//
//  Date+Extensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import Foundation

/// Extended functionality for Date with robust error handling and thread safety
public extension Date {
    // MARK: - Calendar Operations
    
    /// Thread-safe calendar instance
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()
    
    /// Get the start of the day for this date
    var startOfDay: Date {
        Date.calendar.startOfDay(for: self)
    }
    
    /// Get the end of the day for this date
    var endOfDay: Date {
        guard let date = Date.calendar.date(bySettingHour: 23, minute: 59, second: 59, of: self) else {
            return self
        }
        return date
    }
    
    /// Get the start of the month for this date
    var startOfMonth: Date {
        let components = Date.calendar.dateComponents([.year, .month], from: self)
        return Date.calendar.date(from: components) ?? self
    }
    
    /// Get the end of the month for this date
    var endOfMonth: Date {
        guard let nextMonth = Date.calendar.date(byAdding: .month, value: 1, to: startOfMonth),
              let endOfMonth = Date.calendar.date(byAdding: .second, value: -1, to: nextMonth) else {
            return self
        }
        return endOfMonth
    }
    
    /// Get the start of the year for this date
    var startOfYear: Date {
        let components = Date.calendar.dateComponents([.year], from: self)
        return Date.calendar.date(from: components) ?? self
    }
    
    /// Get the end of the year for this date
    var endOfYear: Date {
        guard let nextYear = Date.calendar.date(byAdding: .year, value: 1, to: startOfYear),
              let endOfYear = Date.calendar.date(byAdding: .second, value: -1, to: nextYear) else {
            return self
        }
        return endOfYear
    }
    
    // MARK: - Date Components
    
    /// Get month number (1-12)
    var month: Int {
        Date.calendar.component(.month, from: self)
    }
    
    /// Get year number
    var year: Int {
        Date.calendar.component(.year, from: self)
    }
    
    /// Get day of month
    var day: Int {
        Date.calendar.component(.day, from: self)
    }
    
    /// Get weekday number (1-7, 1 is Sunday)
    var weekday: Int {
        Date.calendar.component(.weekday, from: self)
    }
    
    // MARK: - Date Checks
    
    /// Check if date is today
    var isToday: Bool {
        Date.calendar.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isYesterday: Bool {
        Date.calendar.isDateInYesterday(self)
    }
    
    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Date.calendar.isDateInTomorrow(self)
    }
    
    /// Check if date is in the current month
    var isInCurrentMonth: Bool {
        Date.calendar.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// Check if date is in the current year
    var isInCurrentYear: Bool {
        Date.calendar.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    /// Check if date is in the future
    var isFuture: Bool {
        self > Date()
    }
    
    // MARK: - Formatting
    
    /// Get relative time description (e.g., "2 days ago")
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Get month and year string (e.g., "January 2024")
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
    
    /// Format date to string with specified style
    /// - Parameter style: DateFormatter style to use
    /// - Returns: Formatted date string
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    // MARK: - Date Manipulation
    
    /// Add days to date
    /// - Parameter days: Number of days to add
    /// - Returns: New date with days added
    func adding(days: Int) -> Date {
        Date.calendar.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Add months to date
    /// - Parameter months: Number of months to add
    /// - Returns: New date with months added
    func adding(months: Int) -> Date {
        Date.calendar.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Add years to date
    /// - Parameter years: Number of years to add
    /// - Returns: New date with years added
    func adding(years: Int) -> Date {
        Date.calendar.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// Get days between two dates
    /// - Parameter date: Date to compare with
    /// - Returns: Number of days between dates
    func daysBetween(_ date: Date) -> Int {
        let days = Date.calendar.dateComponents([.day], from: self, to: date).day ?? 0
        return abs(days)
    }
    
    /// Get months between two dates
    /// - Parameter date: Date to compare with
    /// - Returns: Number of months between dates
    func monthsBetween(_ date: Date) -> Int {
        let months = Date.calendar.dateComponents([.month], from: self, to: date).month ?? 0
        return abs(months)
    }
    
    /// Get years between two dates
    /// - Parameter date: Date to compare with
    /// - Returns: Number of years between dates
    func yearsBetween(_ date: Date) -> Int {
        let years = Date.calendar.dateComponents([.year], from: self, to: date).year ?? 0
        return abs(years)
    }
    
    // MARK: - Date Creation
    
    /// Create date from year, month, and day components
    /// - Parameters:
    ///   - year: Year component
    ///   - month: Month component (1-12)
    ///   - day: Day component
    /// - Returns: Optional date
    static func from(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
    
    /// Create date from ISO8601 string
    /// - Parameter string: ISO8601 formatted string
    /// - Returns: Optional date
    static func fromISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

// MARK: - Test Support
#if DEBUG
extension Date {
    /// Create a test date for a specific year, month, and day
    /// - Parameters:
    ///   - year: Year component
    ///   - month: Month component (1-12)
    ///   - day: Day component
    /// - Returns: Test date
    static func testDate(year: Int, month: Int, day: Int) -> Date {
        from(year: year, month: month, day: day) ?? Date()
    }
}
#endif
