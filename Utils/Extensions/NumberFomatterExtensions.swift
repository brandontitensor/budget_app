//
//  NumberFomatterExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import Foundation

/// Extended functionality for number formatting with caching and thread safety
public extension NumberFormatter {
    /// Thread-safe formatter cache
    private static let formatterCache = NSCache<NSString, NumberFormatter>()
    
    /// Shared currency formatter instance with thread safety
    private static let _currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /// Thread-safe access to currency formatter
    static var currencyFormatter: NumberFormatter {
        let key = "currencyFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let formatter = _currencyFormatter.copy() as! NumberFormatter
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Shared percentage formatter instance with thread safety
    private static let _percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    /// Thread-safe access to percentage formatter
    static var percentageFormatter: NumberFormatter {
        let key = "percentageFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let formatter = _percentageFormatter.copy() as! NumberFormatter
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Shared decimal formatter instance with thread safety
    private static let _decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /// Thread-safe access to decimal formatter
    static var decimalFormatter: NumberFormatter {
        let key = "decimalFormatter" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let formatter = _decimalFormatter.copy() as! NumberFormatter
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Format number as currency string with error handling
    /// - Parameter value: Number to format
    /// - Returns: Formatted currency string
    @available(*, deprecated, message: "Use formatCurrency(_:locale:) instead")
    public static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Format number as currency string with locale support
    /// - Parameters:
    ///   - value: Number to format
    ///   - locale: Locale to use for formatting (defaults to current)
    /// - Returns: Formatted currency string
    public static func formatCurrency(_ value: Double, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(for: "currency-\(locale.identifier)") {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = locale
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f
        }
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Format number as percentage string with error handling
    /// - Parameter value: Number to format
    /// - Returns: Formatted percentage string
    public static func formatPercentage(_ value: Double) -> String {
        percentageFormatter.string(from: NSNumber(value: value)) ?? "0%"
    }
    
    /// Format number as decimal string with error handling
    /// - Parameter value: Number to format
    /// - Returns: Formatted decimal string
    public static func formatDecimal(_ value: Double) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
    
    /// Format number with specific currency code
    /// - Parameters:
    ///   - value: Number to format
    ///   - currencyCode: Currency code (e.g., "USD", "EUR")
    /// - Returns: Formatted currency string
    public static func formatWithCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = cachedFormatter(for: "currency-\(currencyCode)") {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currencyCode
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f
        }
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Format number with grouping separators
    /// - Parameter value: Number to format
    /// - Returns: Formatted string with thousand separators
    public static func formatWithSeparators(_ value: Double) -> String {
        let formatter = cachedFormatter(for: "grouping") {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            f.usesGroupingSeparator = true
            return f
        }
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    /// Create a custom currency formatter with caching
    /// - Parameters:
    ///   - currencyCode: Currency code
    ///   - minDigits: Minimum fraction digits
    ///   - maxDigits: Maximum fraction digits
    /// - Returns: Configured NumberFormatter
    public static func customCurrencyFormatter(
        currencyCode: String = "USD",
        minDigits: Int = 2,
        maxDigits: Int = 2
    ) -> NumberFormatter {
        let key = "custom-currency-\(currencyCode)-\(minDigits)-\(maxDigits)"
        return cachedFormatter(for: key) {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currencyCode
            f.minimumFractionDigits = minDigits
            f.maximumFractionDigits = maxDigits
            return f
        }
    }
    
    /// Format number for compact display (e.g., 1.2K, 1.5M)
    /// - Parameter value: Number to format
    /// - Returns: Formatted compact string
    public static func formatCompact(_ value: Double) -> String {
        let formatter = cachedFormatter(for: "compact") {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 1
            return f
        }
        
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
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
    
    /// Get cached formatter or create new one
    /// - Parameters:
    ///   - key: Cache key
    ///   - creator: Formatter creation closure
    /// - Returns: Cached or new formatter
    private static func cachedFormatter(
        for key: String,
        creator: () -> NumberFormatter
    ) -> NumberFormatter {
        let nsKey = key as NSString
        if let cached = formatterCache.object(forKey: nsKey) {
            return cached
        }
        let formatter = creator()
        formatterCache.setObject(formatter, forKey: nsKey)
        return formatter
    }
}

// MARK: - Decimal Extension
extension Decimal {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Testing Support
#if DEBUG
extension NumberFormatter {
    /// Clear formatter cache (for testing)
    static func clearCache() {
        formatterCache.removeAllObjects()
    }
    
    /// Get formatter cache size (for testing)
    static var cacheSize: Int {
        formatterCache.totalCostLimit
    }
}
#endif
