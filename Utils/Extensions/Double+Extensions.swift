//
//  Double+Extensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/23/25.
//

import Foundation

// MARK: - Double Extensions for Currency Formatting
public extension Double {
    /// Format as currency string using default locale
    var asCurrency: String {
        NumberFormatter.formatCurrency(self)
    }
    
    /// Format as percentage string
    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
    
    /// Format with grouping separators
    var withSeparators: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
    
    /// Format as compact string (1.2K, 1.5M, etc.)
    var compact: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        switch absValue {
        case 0..<1_000:
            return formatter.string(from: NSNumber(value: self)) ?? "0"
        case 1_000..<1_000_000:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000)) ?? "0")K"
        case 1_000_000..<1_000_000_000:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000_000)) ?? "0")M"
        default:
            return "\(sign)\(formatter.string(from: NSNumber(value: absValue / 1_000_000_000)) ?? "0")B"
        }
    }
    
    /// Format as currency with specific locale
    func asCurrency(locale: Locale = .current) -> String {
        NumberFormatter.formatCurrency(self, locale: locale)
    }
}

// MARK: - NumberFormatter Extension for Consistency
public extension NumberFormatter {
    /// Format currency with default locale
    static func formatCurrency(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
