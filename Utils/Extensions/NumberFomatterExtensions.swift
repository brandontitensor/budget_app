//
//  NumberFormatterExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import Foundation

// MARK: - NumberFormatter Extensions with Thread Safety
public extension NumberFormatter {
    /// Thread-safe formatter cache
    private static let formatterCache = NSCache<NSString, NumberFormatter>()
    
    /// Thread-safe currency formatter
    static var currencyFormatter: NumberFormatter {
        let key = "currencyFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Thread-safe percentage formatter
    static var percentageFormatter: NumberFormatter {
        let key = "percentageFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Thread-safe decimal formatter
    static var decimalFormatter: NumberFormatter {
        let key = "decimalFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Format number as currency with locale support
    static func formatCurrency(_ value: Double, locale: Locale = .current) -> String {
        let key = "currency-\(locale.identifier)" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = locale
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Format number as percentage
    static func formatPercentage(_ value: Double) -> String {
        return percentageFormatter.string(from: NSNumber(value: value)) ?? "0%"
    }
    
    /// Format number as decimal
    static func formatDecimal(_ value: Double) -> String {
        return decimalFormatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    /// Format number with specific currency code
    static func formatWithCurrency(_ value: Double, currencyCode: String) -> String {
        let key = "currency-code-\(currencyCode)" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Format number with grouping separators
    static func formatWithSeparators(_ value: Double) -> String {
        let key = "grouping" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.usesGroupingSeparator = true
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    /// Format number for compact display (e.g., 1.2K, 1.5M)
    static func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        switch absValue {
        case 0..<1_000:
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        case 1_000..<1_000_000:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000)) ?? "0")K"
        case 1_000_000..<1_000_000_000:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000_000)) ?? "0")M"
        default:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000_000_000)) ?? "0")B"
        }
    }
    
    /// Format currency with enhanced error handling and validation
    static func formatCurrencyRobust(_ value: Double, locale: Locale = .current, fallback: String = "$0.00") -> String {
        guard value.isFinite else { return fallback }
        
        let key = "currency-robust-\(locale.identifier)" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = locale
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? fallback
    }
    
    /// Format number as currency without symbol
    static func formatCurrencyValue(_ value: Double, locale: Locale = .current) -> String {
        let key = "currency-value-\(locale.identifier)" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = locale
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.usesGroupingSeparator = true
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    /// Parse currency string to double
    static func parseCurrency(_ string: String, locale: Locale = .current) -> Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        
        // Try parsing as-is first
        if let number = formatter.number(from: string) {
            return number.doubleValue
        }
        
        // Clean the string and try again
        let cleanedString = string
            .replacingOccurrences(of: "[^0-9.,\\-+]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: "")
        
        if let number = Double(cleanedString) {
            return number
        }
        
        return nil
    }
    
    /// Format amount range (e.g., "$50 - $100")
    static func formatAmountRange(min: Double, max: Double, locale: Locale = .current) -> String {
        let minFormatted = formatCurrency(min, locale: locale)
        let maxFormatted = formatCurrency(max, locale: locale)
        return "\(minFormatted) - \(maxFormatted)"
    }
    
    /// Format with custom decimal places
    static func formatWithDecimalPlaces(_ value: Double, decimalPlaces: Int, locale: Locale = .current) -> String {
        let key = "decimal-\(decimalPlaces)-\(locale.identifier)" as NSString
        
        let formatter: NumberFormatter
        if let cached = formatterCache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = locale
            formatter.minimumFractionDigits = decimalPlaces
            formatter.maximumFractionDigits = decimalPlaces
            formatter.usesGroupingSeparator = true
            formatterCache.setObject(formatter, forKey: key)
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Decimal Extension
public extension Decimal {
    /// Format as currency string using the canonical formatter
    var asCurrency: String {
        let nsDecimal = self as NSDecimalNumber
        return NumberFormatter.formatCurrency(nsDecimal.doubleValue)
    }
    
    /// Format as currency with specific locale
    func asCurrency(locale: Locale) -> String {
        let nsDecimal = self as NSDecimalNumber
        return NumberFormatter.formatCurrency(nsDecimal.doubleValue, locale: locale)
    }
    
    /// Format with specific decimal places
    func asDecimal(decimalPlaces: Int) -> String {
        let nsDecimal = self as NSDecimalNumber
        return NumberFormatter.formatWithDecimalPlaces(nsDecimal.doubleValue, decimalPlaces: decimalPlaces)
    }
}

// MARK: - Double Extension
public extension Double {
    /// Format as currency string using the canonical formatter
    var asCurrency: String {
        return NumberFormatter.formatCurrency(self)
    }
    
    /// Format as currency with specific locale
    func asCurrency(locale: Locale) -> String {
        return NumberFormatter.formatCurrency(self, locale: locale)
    }
    
    /// Format as percentage
    var asPercentage: String {
        return NumberFormatter.formatPercentage(self)
    }
    
    /// Format as decimal
    var asDecimal: String {
        return NumberFormatter.formatDecimal(self)
    }
    
    /// Format in compact notation
    var asCompact: String {
        return NumberFormatter.formatCompact(self)
    }
    
    /// Format with specific decimal places
    func asDecimal(decimalPlaces: Int) -> String {
        return NumberFormatter.formatWithDecimalPlaces(self, decimalPlaces: decimalPlaces)
    }
    
    /// Format currency value without symbol
    var asCurrencyValue: String {
        return NumberFormatter.formatCurrencyValue(self)
    }
    
    /// Check if the value represents a valid currency amount
    var isValidCurrencyAmount: Bool {
        return isFinite && self >= 0 && self <= 999_999_999.99
    }
}

// MARK: - Int Extension
public extension Int {
    /// Format as currency
    var asCurrency: String {
        return NumberFormatter.formatCurrency(Double(self))
    }
    
    /// Format with grouping separators
    var withSeparators: String {
        return NumberFormatter.formatWithSeparators(Double(self))
    }
    
    /// Format in compact notation
    var asCompact: String {
        return NumberFormatter.formatCompact(Double(self))
    }
}

// MARK: - String Extension for Currency
public extension String {
    /// Parse string as currency amount
    var currencyValue: Double? {
        return NumberFormatter.parseCurrency(self)
    }
    
    /// Parse string as currency amount with specific locale
    func currencyValue(locale: Locale) -> Double? {
        return NumberFormatter.parseCurrency(self, locale: locale)
    }
    
    /// Clean currency string for parsing
    var cleanedCurrencyString: String {
        return self
            .replacingOccurrences(of: "[^0-9.,\\-+]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: "")
    }
}

// MARK: - Locale Extension
public extension Locale {
    /// Get currency symbol for locale
    var safeCurrencySymbol: String {
        return self.currencySymbol ?? "$"
    }
    
    /// Get currency code for locale
    var safeCurrencyCode: String {
        return self.currency?.identifier ?? "USD"
    }
    
    /// Format currency with this locale
    func formatCurrency(_ value: Double) -> String {
        return NumberFormatter.formatCurrency(value, locale: self)
    }
}

// MARK: - Testing Support
#if DEBUG
extension NumberFormatter {
    /// Clear formatter cache (for testing)
    static func clearCache() {
        formatterCache.removeAllObjects()
    }
    
    /// Get formatter cache count (for testing)
    static var cacheCount: Int {
        return formatterCache.countLimit
    }
    
    /// Get cached formatter keys (for testing)
    static var cachedKeys: [String] {
        // Note: NSCache doesn't provide a way to enumerate keys
        // This is a placeholder for testing purposes
        return []
    }
}
#endif

// MARK: - App-Specific Formatting

/// App-specific currency formatting utilities
public enum AppCurrencyFormatter {
    /// Default app currency formatter
    public static func formatBudgetAmount(_ amount: Double) -> String {
        return NumberFormatter.formatCurrencyRobust(amount, fallback: "$0.00")
    }
    
    /// Format amount for display in lists
    public static func formatListAmount(_ amount: Double) -> String {
        if abs(amount) >= 1000 {
            return NumberFormatter.formatCompact(amount)
        } else {
            return NumberFormatter.formatCurrency(amount)
        }
    }
    
    /// Format amount for input fields
    public static func formatInputAmount(_ amount: Double) -> String {
        return NumberFormatter.formatCurrencyValue(amount)
    }
    
    /// Format transaction amount with sign
    public static func formatTransactionAmount(_ amount: Double, showPositiveSign: Bool = false) -> String {
        let formatted = NumberFormatter.formatCurrency(abs(amount))
        
        if amount < 0 {
            return "-\(formatted)"
        } else if amount > 0 && showPositiveSign {
            return "+\(formatted)"
        } else {
            return formatted
        }
    }
    
    /// Format budget summary amounts
    public static func formatSummaryAmount(_ amount: Double) -> String {
        return NumberFormatter.formatCurrency(amount)
    }
}
