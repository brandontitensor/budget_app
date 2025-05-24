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
}

// MARK: - Decimal Extension
public extension Decimal {
    /// Format as currency string
    var asCurrency: String {
        let nsDecimal = self as NSDecimalNumber
        return NumberFormatter.formatCurrency(nsDecimal.doubleValue)
    }
}

// MARK: - Double Extension
public extension Double {
     var asCurrency: String {
        return NumberFormatter.formatCurrency(self)
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
        formatterCache.countLimit
    }
}
#endif
