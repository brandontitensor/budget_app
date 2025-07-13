//
//  FormatHelpers.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//


import Foundation

/// Collection of formatting utilities for the app with proper localization and validation
public enum FormatHelpers {
    
    // MARK: - Currency Formatting
    
    /// Format currency with enhanced localization support
    public struct CurrencyFormatter {
        private let formatter: NumberFormatter
        private let locale: Locale
        private let currencyCode: String
        
        public init(currencyCode: String = "USD", locale: Locale = .current) {
            self.locale = locale
            self.currencyCode = currencyCode
            
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = locale
            numberFormatter.currencyCode = currencyCode
            numberFormatter.minimumFractionDigits = 2
            numberFormatter.maximumFractionDigits = 2
            
            self.formatter = numberFormatter
        }
        
        /// Format amount as currency string
        public func format(_ amount: Double) -> String {
            return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        }
        
        /// Format amount with custom decimal places
        public func format(_ amount: Double, decimalPlaces: Int) -> String {
            let customFormatter = NumberFormatter()
            customFormatter.numberStyle = .currency
            customFormatter.locale = locale
            customFormatter.currencyCode = currencyCode
            customFormatter.minimumFractionDigits = decimalPlaces
            customFormatter.maximumFractionDigits = decimalPlaces
            return customFormatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        }
        
        /// Format amount without currency symbol
        public func formatAmount(_ amount: Double) -> String {
            let decimalFormatter = NumberFormatter()
            decimalFormatter.numberStyle = .decimal
            decimalFormatter.locale = locale
            decimalFormatter.minimumFractionDigits = 2
            decimalFormatter.maximumFractionDigits = 2
            return decimalFormatter.string(from: NSNumber(value: amount)) ?? "0.00"
        }
        
        /// Format amount with compact notation (K, M, B)
        public func formatCompact(_ amount: Double) -> String {
            let absAmount = abs(amount)
            let sign = amount < 0 ? "-" : ""
            
            if absAmount >= 1_000_000_000 {
                return "\(sign)\(format(absAmount / 1_000_000_000, decimalPlaces: 1))B"
            } else if absAmount >= 1_000_000 {
                return "\(sign)\(format(absAmount / 1_000_000, decimalPlaces: 1))M"
            } else if absAmount >= 1_000 {
                return "\(sign)\(format(absAmount / 1_000, decimalPlaces: 1))K"
            } else {
                return format(amount)
            }
        }
    }
    
    // MARK: - Date Formatting
    
    /// Comprehensive date formatting utilities
    public struct DateFormatter {
        private static let cache = NSCache<NSString, Foundation.DateFormatter>()
        
        /// Get cached formatter for performance
        private static func cachedFormatter(format: String, locale: Locale = .current) -> Foundation.DateFormatter {
            let key = "\(format)_\(locale.identifier)" as NSString
            
            if let cached = cache.object(forKey: key) {
                return cached
            }
            
            let formatter = Foundation.DateFormatter()
            formatter.dateFormat = format
            formatter.locale = locale
            formatter.timeZone = TimeZone.current
            
            cache.setObject(formatter, forKey: key)
            return formatter
        }
        
        /// Format date with predefined styles
        public static func format(_ date: Date, style: Style = .medium) -> String {
            let formatter = Foundation.DateFormatter()
            formatter.dateStyle = style.dateStyle
            formatter.timeStyle = .none
            formatter.locale = .current
            return formatter.string(from: date)
        }
        
        /// Format date for transactions (e.g., "Dec 15")
        public static func formatTransaction(_ date: Date) -> String {
            return cachedFormatter(format: "MMM d").string(from: date)
        }
        
        /// Format date for budget periods (e.g., "December 2024")
        public static func formatBudgetPeriod(_ date: Date) -> String {
            return cachedFormatter(format: "MMMM yyyy").string(from: date)
        }
        
        /// Format date for file exports (e.g., "2024-12-15")
        public static func formatForExport(_ date: Date) -> String {
            return cachedFormatter(format: "yyyy-MM-dd").string(from: date)
        }
        
        /// Format date with time (e.g., "Dec 15, 2024 at 2:30 PM")
        public static func formatWithTime(_ date: Date) -> String {
            let formatter = Foundation.DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        /// Format relative date (e.g., "2 days ago", "in 3 hours")
        public static func formatRelative(_ date: Date, relativeTo referenceDate: Date = Date()) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: referenceDate)
        }
        
        /// Format relative date abbreviated (e.g., "2d ago", "in 3h")
        public static func formatRelativeShort(_ date: Date, relativeTo referenceDate: Date = Date()) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: referenceDate)
        }
        
        /// Format day of week (e.g., "Monday", "Wed")
        public static func formatDayOfWeek(_ date: Date, abbreviated: Bool = false) -> String {
            let format = abbreviated ? "EEE" : "EEEE"
            return cachedFormatter(format: format).string(from: date)
        }
        
        /// Format month and year (e.g., "Dec 2024")
        public static func formatMonthYear(_ date: Date, abbreviated: Bool = false) -> String {
            let format = abbreviated ? "MMM yyyy" : "MMMM yyyy"
            return cachedFormatter(format: format).string(from: date)
        }
        
        /// Format timestamp for files (e.g., "20241215_143022")
        public static func formatTimestamp(_ date: Date) -> String {
            return cachedFormatter(format: "yyyyMMdd_HHmmss").string(from: date)
        }
        
        public enum Style {
            case short
            case medium
            case long
            case full
            
            var dateStyle: Foundation.DateFormatter.Style {
                switch self {
                case .short: return .short
                case .medium: return .medium
                case .long: return .long
                case .full: return .full
                }
            }
        }
    }
    
    // MARK: - Percentage Formatting
    
    /// Format percentages with various options
    public struct PercentageFormatter {
        private let formatter: NumberFormatter
        
        public init(decimalPlaces: Int = 1) {
            self.formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.minimumFractionDigits = decimalPlaces
            formatter.maximumFractionDigits = decimalPlaces
        }
        
        /// Format as percentage (0.85 -> "85%")
        public func format(_ value: Double) -> String {
            return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
        }
        
        /// Format as percentage from fraction (0.85 -> "85%")
        public func formatFromFraction(_ value: Double) -> String {
            return formatter.string(from: NSNumber(value: value)) ?? "0%"
        }
        
        /// Format with explicit sign (0.15 -> "+15%", -0.05 -> "-5%")
        public func formatWithSign(_ value: Double) -> String {
            formatter.positivePrefix = "+"
            defer { formatter.positivePrefix = "" }
            return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
        }
    }
    
    // MARK: - Number Formatting
    
    /// General number formatting utilities
    public struct NumberFormatterHelper {
        
        /// Format large numbers with separators (1000 -> "1,000")
        public static func formatWithSeparators(_ value: Double) -> String {
            let formatter = Foundation.NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = true
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        /// Format decimal with specific places
        public static func formatDecimal(_ value: Double, places: Int = 2) -> String {
            let formatter = Foundation.NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = places
            formatter.maximumFractionDigits = places
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        /// Format as ordinal (1 -> "1st", 2 -> "2nd", etc.)
        public static func formatOrdinal(_ value: Int) -> String {
            let formatter = Foundation.NumberFormatter()
            formatter.numberStyle = .ordinal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        
        /// Format file size (1024 -> "1 KB")
        public static func formatFileSize(_ bytes: Int64) -> String {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        
        /// Format duration in seconds to readable format
        public static func formatDuration(_ seconds: TimeInterval) -> String {
            let formatter = Foundation.DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            return formatter.string(from: seconds) ?? "0s"
        }
    }
    
    // MARK: - Budget-Specific Formatting
    
    /// Specialized formatting for budget-related data
    public struct BudgetFormatter {
        
        /// Format budget status with color coding
        public static func formatBudgetStatus(
            spent: Double,
            budget: Double,
            currency: String = "USD"
        ) -> (text: String, color: String) {
            let currencyFormatter = CurrencyFormatter(currencyCode: currency)
            let percentage = budget > 0 ? (spent / budget) * 100 : 0
            
            let text: String
            let color: String
            
            if spent > budget {
                let over = spent - budget
                text = "Over by \(currencyFormatter.format(over))"
                color = "red"
            } else if percentage > 90 {
                let remaining = budget - spent
                text = "\(currencyFormatter.format(remaining)) left"
                color = "orange"
            } else if percentage > 75 {
                let remaining = budget - spent
                text = "\(currencyFormatter.format(remaining)) remaining"
                color = "yellow"
            } else {
                let remaining = budget - spent
                text = "\(currencyFormatter.format(remaining)) available"
                color = "green"
            }
            
            return (text, color)
        }
        
        /// Format spending trend
        public static func formatSpendingTrend(
            current: Double,
            previous: Double,
            currency: String = "USD"
        ) -> (text: String, isIncrease: Bool) {
            let currencyFormatter = CurrencyFormatter(currencyCode: currency)
            let difference = current - previous
            let isIncrease = difference > 0
            
            if abs(difference) < 0.01 {
                return ("No change", false)
            }
            
            let percentageChange = previous > 0 ? abs(difference / previous) * 100 : 0
            let arrow = isIncrease ? "↑" : "↓"
            let verb = isIncrease ? "increase" : "decrease"
            
            let text = "\(arrow) \(currencyFormatter.format(abs(difference))) (\(String(format: "%.1f", percentageChange))% \(verb))"
            
            return (text, isIncrease)
        }
        
        /// Format budget progress
        public static func formatBudgetProgress(
            spent: Double,
            budget: Double
        ) -> (percentage: Double, displayText: String) {
            let percentage = budget > 0 ? min((spent / budget) * 100, 100) : 0
            let displayText = "\(String(format: "%.0f", percentage))% used"
            return (percentage, displayText)
        }
    }
    
    // MARK: - Text Formatting
    
    /// Text manipulation and formatting utilities
    public struct TextFormatter {
        
        /// Capitalize first letter of each word
        public static func titleCase(_ text: String) -> String {
            return text.capitalized
        }
        
        /// Format category name consistently
        public static func formatCategoryName(_ name: String) -> String {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
        }
        
        /// Truncate text to specified length with ellipsis
        public static func truncate(_ text: String, to length: Int) -> String {
            if text.count <= length {
                return text
            }
            let index = text.index(text.startIndex, offsetBy: length - 3)
            return String(text[..<index]) + "..."
        }
        
        /// Format transaction note
        public static func formatTransactionNote(_ note: String?) -> String {
            guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !note.isEmpty else {
                return "No notes"
            }
            return note
        }
        
        /// Format currency symbol display
        public static func formatCurrencySymbol(_ currencyCode: String) -> String {
            let locale = Locale.current
            return locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
        }
        
        /// Format amount range (e.g., "$50 - $100")
        public static func formatAmountRange(
            min: Double,
            max: Double,
            currency: String = "USD"
        ) -> String {
            let formatter = CurrencyFormatter(currencyCode: currency)
            return "\(formatter.format(min)) - \(formatter.format(max))"
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Input validation and formatting
    public struct ValidationFormatter {
        
        /// Clean and validate currency input
        public static func cleanCurrencyInput(_ input: String) -> String {
            let cleaned = input
                .replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                .replacingOccurrences(of: ",", with: "")
            
            // Handle multiple decimal points
            let components = cleaned.components(separatedBy: ".")
            if components.count > 2 {
                return components[0] + "." + components[1]
            }
            
            return cleaned
        }
        
        /// Validate and format percentage input
        public static func cleanPercentageInput(_ input: String) -> String {
            let cleaned = input
                .replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            
            if let value = Double(cleaned), value > 100 {
                return "100"
            }
            
            return cleaned
        }
        
        /// Format phone number input
        public static func formatPhoneNumber(_ input: String) -> String {
            let cleaned = input.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            
            if cleaned.count >= 10 {
                let area = String(cleaned.prefix(3))
                let middle = String(cleaned.dropFirst(3).prefix(3))
                let last = String(cleaned.dropFirst(6).prefix(4))
                return "(\(area)) \(middle)-\(last)"
            }
            
            return cleaned
        }
    }
}

// MARK: - Extensions

extension Double {
    /// Format as currency using default formatter
    public var formattedAsCurrency: String {
        return FormatHelpers.CurrencyFormatter().format(self)
    }
    
    /// Format as percentage
    public var formattedAsPercentage: String {
        return FormatHelpers.PercentageFormatter().format(self)
    }
    
    /// Format with separators
    public var formattedWithSeparators: String {
        return FormatHelpers.NumberFormatterHelper.formatWithSeparators(self)
    }
}

extension Date {
    /// Format for transaction display
    public var formattedForTransaction: String {
        return FormatHelpers.DateFormatter.formatTransaction(self)
    }
    
    /// Format for budget period
    public var formattedForBudgetPeriod: String {
        return FormatHelpers.DateFormatter.formatBudgetPeriod(self)
    }
    
    /// Format relative to now
    public var formattedRelative: String {
        return FormatHelpers.DateFormatter.formatRelative(self)
    }
}

extension String {
    /// Clean for currency input
    public var cleanedForCurrency: String {
        return FormatHelpers.ValidationFormatter.cleanCurrencyInput(self)
    }
    
    /// Format as title case
    public var titleCased: String {
        return FormatHelpers.TextFormatter.titleCase(self)
    }
    
    /// Truncate with ellipsis
    public func truncated(to length: Int) -> String {
        return FormatHelpers.TextFormatter.truncate(self, to: length)
    }
}

// MARK: - Testing Support

#if DEBUG
extension FormatHelpers {
    public struct TestData {
        public static let sampleAmounts: [Double] = [0, 0.01, 1.5, 15.99, 150.50, 1500, 15000, 150000]
        public static let sampleDates: [Date] = [
            Date(),
            Date().addingTimeInterval(-86400), // Yesterday
            Date().addingTimeInterval(-604800), // Last week
            Date().addingTimeInterval(-2592000), // Last month
            Date().addingTimeInterval(86400) // Tomorrow
        ]
        public static let sampleCategories = ["Groceries", "transportation", "ENTERTAINMENT", "utilities"]
        public static let sampleCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD"]
        
        /// Test all formatting functions
        public static func runFormatTests() {
            print("🧪 Running Format Helper Tests")
            
            // Test currency formatting
            let currencyFormatter = CurrencyFormatter()
            for amount in sampleAmounts {
                print("Currency: \(amount) -> \(currencyFormatter.format(amount))")
            }
            
            // Test date formatting
            for date in sampleDates {
                print("Date: \(date) -> \(DateFormatter.formatTransaction(date))")
            }
            
            // Test percentage formatting
            let percentFormatter = PercentageFormatter()
            for amount in [10, 50, 85, 100, 120] {
                print("Percentage: \(amount) -> \(percentFormatter.format(Double(amount)))")
            }
            
            // Test category formatting
            for category in sampleCategories {
                print("Category: '\(category)' -> '\(TextFormatter.formatCategoryName(category))'")
            }
            
            print("✅ Format Helper Tests Complete")
        }
    }
}
#endif
