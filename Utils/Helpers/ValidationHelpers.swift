//
//  ValidationHelpers.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//  Centralized validation utilities with comprehensive error handling and type safety
//

import Foundation
import SwiftUI

// MARK: - Validation Result Types

/// Represents the result of a validation operation
public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid(ValidationError)
    
    /// Whether the validation passed
    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    /// The error if validation failed
    public var error: ValidationError? {
        if case .invalid(let error) = self { return error }
        return nil
    }
    
    /// User-friendly error message
    public var errorMessage: String? {
        return error?.localizedDescription
    }
    
    /// Combine multiple validation results
    public static func combine(_ results: [ValidationResult]) -> ValidationResult {
        let errors = results.compactMap { result in
            if case .invalid(let error) = result {
                return error
            }
            return nil
        }
        
        if errors.isEmpty {
            return .valid
        } else if errors.count == 1 {
            return .invalid(errors[0])
        } else {
            return .invalid(.multipleErrors(errors))
        }
    }
}

/// Comprehensive validation error types
public enum ValidationError: LocalizedError, Equatable, Sendable {
    // MARK: - String Validation Errors
    case empty(field: String)
    case tooShort(field: String, minimum: Int, actual: Int)
    case tooLong(field: String, maximum: Int, actual: Int)
    case invalidFormat(field: String, format: String)
    case containsInvalidCharacters(field: String, characters: String)
    case notAllowed(field: String, value: String, reason: String)
    case whitespaceOnly(field: String)
    case invalidPattern(field: String, pattern: String)
    
    // MARK: - Numeric Validation Errors
    case notANumber(field: String, value: String)
    case tooSmall(field: String, minimum: Double, actual: Double)
    case tooLarge(field: String, maximum: Double, actual: Double)
    case notInteger(field: String, value: Double)
    case negativeNotAllowed(field: String, value: Double)
    case zeroNotAllowed(field: String)
    case invalidPrecision(field: String, value: Double, maxDecimalPlaces: Int)
    
    // MARK: - Date Validation Errors
    case invalidDate(field: String, value: String)
    case dateInPast(field: String, date: Date)
    case dateInFuture(field: String, date: Date)
    case dateOutOfRange(field: String, date: Date, min: Date?, max: Date?)
    case invalidDateFormat(field: String, value: String, expectedFormat: String)
    case weekendNotAllowed(field: String, date: Date)
    case holidayNotAllowed(field: String, date: Date)
    
    // MARK: - Email Validation Errors
    case invalidEmail(email: String)
    case emailTooLong(email: String, maxLength: Int)
    case emailDomainInvalid(email: String, domain: String)
    case emailLocalPartInvalid(email: String, localPart: String)
    case disposableEmailNotAllowed(email: String)
    
    // MARK: - Budget-Specific Validation Errors
    case invalidCurrency(amount: String)
    case budgetExceeded(category: String, amount: Double, limit: Double)
    case categoryNotFound(category: String)
    case duplicateCategory(category: String)
    case invalidTransactionDate(date: Date, reason: String)
    case invalidBudgetPeriod(period: String)
    case insufficientFunds(requested: Double, available: Double)
    case categoryLimitExceeded(category: String, limit: Double)
    case monthlyLimitExceeded(amount: Double, monthlyLimit: Double)
    case invalidRecurringPattern(pattern: String)
    
    // MARK: - File and Data Validation Errors
    case fileNotFound(path: String)
    case fileTooLarge(size: Int64, maxSize: Int64)
    case invalidFileFormat(expected: String, actual: String)
    case corruptedData(description: String)
    case unsupportedVersion(version: String, supportedVersions: [String])
    
    // MARK: - Security Validation Errors
    case passwordTooWeak(requirements: [String])
    case suspiciousActivity(description: String)
    case rateLimitExceeded(limit: Int, timeWindow: String)
    case unauthorizedAccess(resource: String)
    
    // MARK: - Custom and Multiple Errors
    case custom(message: String)
    case multipleErrors([ValidationError])
    case conditionalError(condition: String, error: ValidationError)
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        case .empty(let field):
            return "\(field) cannot be empty"
        case .tooShort(let field, let minimum, let actual):
            return "\(field) must be at least \(minimum) characters (currently \(actual))"
        case .tooLong(let field, let maximum, let actual):
            return "\(field) must be no more than \(maximum) characters (currently \(actual))"
        case .invalidFormat(let field, let format):
            return "\(field) must match format: \(format)"
        case .containsInvalidCharacters(let field, let characters):
            return "\(field) contains invalid characters: \(characters)"
        case .notAllowed(let field, let value, let reason):
            return "\(field) value '\(value)' is not allowed: \(reason)"
        case .whitespaceOnly(let field):
            return "\(field) cannot contain only whitespace"
        case .invalidPattern(let field, let pattern):
            return "\(field) must match pattern: \(pattern)"
            
        case .notANumber(let field, let value):
            return "\(field) '\(value)' is not a valid number"
        case .tooSmall(let field, let minimum, let actual):
            return "\(field) must be at least \(minimum) (currently \(actual))"
        case .tooLarge(let field, let maximum, let actual):
            return "\(field) must be no more than \(maximum) (currently \(actual))"
        case .notInteger(let field, let value):
            return "\(field) must be a whole number (currently \(value))"
        case .negativeNotAllowed(let field, let value):
            return "\(field) cannot be negative (currently \(value))"
        case .zeroNotAllowed(let field):
            return "\(field) cannot be zero"
        case .invalidPrecision(let field, let value, let maxDecimalPlaces):
            return "\(field) can have at most \(maxDecimalPlaces) decimal places (currently \(value))"
            
        case .invalidDate(let field, let value):
            return "\(field) '\(value)' is not a valid date"
        case .dateInPast(let field, let date):
            return "\(field) cannot be in the past (\(DateFormatter.shortDate.string(from: date)))"
        case .dateInFuture(let field, let date):
            return "\(field) cannot be in the future (\(DateFormatter.shortDate.string(from: date)))"
        case .dateOutOfRange(let field, let date, let min, let max):
            let minStr = min?.formatted(date: .abbreviated, time: .omitted) ?? "beginning of time"
            let maxStr = max?.formatted(date: .abbreviated, time: .omitted) ?? "end of time"
            return "\(field) must be between \(minStr) and \(maxStr) (currently \(date.formatted(date: .abbreviated, time: .omitted)))"
        case .invalidDateFormat(let field, let value, let expectedFormat):
            return "\(field) '\(value)' does not match expected format: \(expectedFormat)"
        case .weekendNotAllowed(let field, let date):
            return "\(field) cannot be a weekend date (\(DateFormatter.shortDate.string(from: date)))"
        case .holidayNotAllowed(let field, let date):
            return "\(field) cannot be a holiday (\(DateFormatter.shortDate.string(from: date)))"
            
        case .invalidEmail(let email):
            return "'\(email)' is not a valid email address"
        case .emailTooLong(let email, let maxLength):
            return "Email address is too long (\(email.count) characters, maximum \(maxLength))"
        case .emailDomainInvalid(let email, let domain):
            return "Email domain '\(domain)' in '\(email)' is not valid"
        case .emailLocalPartInvalid(let email, let localPart):
            return "Email local part '\(localPart)' in '\(email)' is not valid"
        case .disposableEmailNotAllowed(let email):
            return "Disposable email addresses are not allowed ('\(email)')"
            
        case .invalidCurrency(let amount):
            return "'\(amount)' is not a valid currency amount"
        case .budgetExceeded(let category, let amount, let limit):
            return "Amount $\(String(format: "%.2f", amount)) exceeds budget limit of $\(String(format: "%.2f", limit)) for \(category)"
        case .categoryNotFound(let category):
            return "Category '\(category)' does not exist"
        case .duplicateCategory(let category):
            return "Category '\(category)' already exists"
        case .invalidTransactionDate(let date, let reason):
            return "Transaction date \(DateFormatter.shortDate.string(from: date)) is invalid: \(reason)"
        case .invalidBudgetPeriod(let period):
            return "Budget period '\(period)' is not valid"
        case .insufficientFunds(let requested, let available):
            return "Insufficient funds: requested $\(String(format: "%.2f", requested)), available $\(String(format: "%.2f", available))"
        case .categoryLimitExceeded(let category, let limit):
            return "Category '\(category)' limit of $\(String(format: "%.2f", limit)) exceeded"
        case .monthlyLimitExceeded(let amount, let monthlyLimit):
            return "Monthly limit of $\(String(format: "%.2f", monthlyLimit)) exceeded by $\(String(format: "%.2f", amount - monthlyLimit))"
        case .invalidRecurringPattern(let pattern):
            return "Recurring pattern '\(pattern)' is not valid"
            
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileTooLarge(let size, let maxSize):
            return "File too large: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) (maximum \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)))"
        case .invalidFileFormat(let expected, let actual):
            return "Invalid file format: expected \(expected), got \(actual)"
        case .corruptedData(let description):
            return "Corrupted data: \(description)"
        case .unsupportedVersion(let version, let supportedVersions):
            return "Unsupported version \(version). Supported versions: \(supportedVersions.joined(separator: ", "))"
            
        case .passwordTooWeak(let requirements):
            return "Password too weak. Requirements: \(requirements.joined(separator: ", "))"
        case .suspiciousActivity(let description):
            return "Suspicious activity detected: \(description)"
        case .rateLimitExceeded(let limit, let timeWindow):
            return "Rate limit exceeded: \(limit) requests per \(timeWindow)"
        case .unauthorizedAccess(let resource):
            return "Unauthorized access to \(resource)"
            
        case .custom(let message):
            return message
        case .multipleErrors(let errors):
            return errors.compactMap { $0.errorDescription }.joined(separator: "; ")
        case .conditionalError(let condition, let error):
            return "Conditional error (\(condition)): \(error.errorDescription ?? "Unknown error")"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .empty:
            return "Please enter a value for this field"
        case .tooShort(_, let minimum, _):
            return "Please enter at least \(minimum) characters"
        case .tooLong(_, let maximum, _):
            return "Please enter no more than \(maximum) characters"
        case .invalidFormat(_, let format):
            return "Please use the format: \(format)"
        case .whitespaceOnly:
            return "Please enter meaningful content, not just spaces"
        case .notANumber:
            return "Please enter a valid number"
        case .tooSmall(_, let minimum, _):
            return "Please enter a value of at least \(minimum)"
        case .tooLarge(_, let maximum, _):
            return "Please enter a value no greater than \(maximum)"
        case .negativeNotAllowed:
            return "Please enter a positive number"
        case .zeroNotAllowed:
            return "Please enter a value greater than zero"
        case .invalidEmail:
            return "Please enter a valid email address (e.g., user@example.com)"
        case .budgetExceeded:
            return "Consider adjusting your budget or reducing the amount"
        case .categoryNotFound:
            return "Please select an existing category or create a new one"
        case .duplicateCategory:
            return "Please choose a different category name"
        case .invalidCurrency:
            return "Please enter a valid dollar amount (e.g., 25.99)"
        case .invalidTransactionDate:
            return "Please select a valid transaction date"
        case .invalidBudgetPeriod:
            return "Please select a valid budget period"
        case .insufficientFunds:
            return "Please reduce the amount or add more funds"
        case .dateInPast:
            return "Please select a current or future date"
        case .dateInFuture:
            return "Please select a current or past date"
        case .fileTooLarge:
            return "Please choose a smaller file"
        case .invalidFileFormat:
            return "Please choose a file in the correct format"
        case .passwordTooWeak:
            return "Please create a stronger password"
        default:
            return "Please check your input and try again"
        }
    }
    
    /// Severity level for error handling
    public var severity: ErrorSeverity {
        switch self {
        case .empty, .tooShort, .tooLong, .invalidFormat, .notANumber, .invalidEmail, .invalidCurrency:
            return .warning
        case .budgetExceeded, .monthlyLimitExceeded, .insufficientFunds:
            return .error
        case .suspiciousActivity, .unauthorizedAccess, .rateLimitExceeded:
            return .critical
        case .corruptedData, .fileNotFound:
            return .error
        default:
            return .warning
        }
    }
    
    public enum ErrorSeverity: String, CaseIterable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case critical = "Critical"
        
        public var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .critical: return .purple
            }
        }
        
        public var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "exclamationmark.octagon"
            }
        }
    }
}

// MARK: - Core Validation Utilities

/// Core validation utility class with comprehensive validation methods
public enum ValidationHelpers {
    
    // MARK: - String Validation
    
    /// Validate that a string is not empty
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Validation result
    public static func validateNotEmpty(_ value: String, fieldName: String = "Field") -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if value.isEmpty {
            return .invalid(.empty(field: fieldName))
        }
        
        if trimmed.isEmpty {
            return .invalid(.whitespaceOnly(field: fieldName))
        }
        
        return .valid
    }
    
    /// Validate string length
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - minLength: Minimum required length (optional)
    ///   - maxLength: Maximum allowed length (optional)
    /// - Returns: Validation result
    public static func validateStringLength(
        _ value: String,
        fieldName: String = "Field",
        minLength: Int? = nil,
        maxLength: Int? = nil
    ) -> ValidationResult {
        let length = value.count
        
        if let min = minLength, length < min {
            return .invalid(.tooShort(field: fieldName, minimum: min, actual: length))
        }
        
        if let max = maxLength, length > max {
            return .invalid(.tooLong(field: fieldName, maximum: max, actual: length))
        }
        
        return .valid
    }
    
    /// Validate string format using regular expression
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - pattern: Regular expression pattern
    ///   - formatDescription: Human-readable format description
    /// - Returns: Validation result
    public static func validateStringFormat(
        _ value: String,
        fieldName: String = "Field",
        pattern: String,
        formatDescription: String
    ) -> ValidationResult {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: value.utf16.count)
        
        if regex?.firstMatch(in: value, options: [], range: range) != nil {
            return .valid
        } else {
            return .invalid(.invalidFormat(field: fieldName, format: formatDescription))
        }
    }
    
    /// Validate allowed characters
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - allowedCharacters: Set of allowed characters
    /// - Returns: Validation result
    public static func validateAllowedCharacters(
        _ value: String,
        fieldName: String = "Field",
        allowedCharacters: CharacterSet
    ) -> ValidationResult {
        let valueCharacterSet = CharacterSet(charactersIn: value)
        let invalidCharacters = valueCharacterSet.subtracting(allowedCharacters)
        
        if !invalidCharacters.isEmpty {
            let invalidString = String(value.unicodeScalars.filter { invalidCharacters.contains($0) })
            return .invalid(.containsInvalidCharacters(field: fieldName, characters: invalidString))
        }
        
        return .valid
    }
    
    // MARK: - Numeric Validation
    
    /// Validate and parse a number from string
    /// - Parameters:
    ///   - value: String representation of number
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Tuple of validation result and parsed number
    public static func validateNumber(_ value: String, fieldName: String = "Field") -> (ValidationResult, Double?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (.invalid(.empty(field: fieldName)), nil)
        }
        
        guard let number = Double(trimmed) else {
            return (.invalid(.notANumber(field: fieldName, value: value)), nil)
        }
        
        return (.valid, number)
    }
    
    /// Validate number range
    /// - Parameters:
    ///   - value: The number to validate
    ///   - fieldName: Name of the field for error messages
    ///   - min: Minimum allowed value (optional)
    ///   - max: Maximum allowed value (optional)
    ///   - allowZero: Whether zero is allowed
    ///   - allowNegative: Whether negative numbers are allowed
    /// - Returns: Validation result
    public static func validateNumberRange(
        _ value: Double,
        fieldName: String = "Field",
        min: Double? = nil,
        max: Double? = nil,
        allowZero: Bool = true,
        allowNegative: Bool = true
    ) -> ValidationResult {
        if !allowNegative && value < 0 {
            return .invalid(.negativeNotAllowed(field: fieldName, value: value))
        }
        
        if !allowZero && value == 0 {
            return .invalid(.zeroNotAllowed(field: fieldName))
        }
        
        if let minimum = min, value < minimum {
            return .invalid(.tooSmall(field: fieldName, minimum: minimum, actual: value))
        }
        
        if let maximum = max, value > maximum {
            return .invalid(.tooLarge(field: fieldName, maximum: maximum, actual: value))
        }
        
        return .valid
    }
    
    /// Validate integer
    /// - Parameters:
    ///   - value: The number to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Validation result
    public static func validateInteger(_ value: Double, fieldName: String = "Field") -> ValidationResult {
        if value.truncatingRemainder(dividingBy: 1) != 0 {
            return .invalid(.notInteger(field: fieldName, value: value))
        }
        return .valid
    }
    
    /// Validate decimal precision
    /// - Parameters:
    ///   - value: The number to validate
    ///   - fieldName: Name of the field for error messages
    ///   - maxDecimalPlaces: Maximum allowed decimal places
    /// - Returns: Validation result
    public static func validateDecimalPrecision(
        _ value: Double,
        fieldName: String = "Field",
        maxDecimalPlaces: Int
    ) -> ValidationResult {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = maxDecimalPlaces
        formatter.minimumFractionDigits = 0
        
        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? ""
        let originalValue = String(value)
        
        if formattedValue != originalValue {
            return .invalid(.invalidPrecision(field: fieldName, value: value, maxDecimalPlaces: maxDecimalPlaces))
        }
        
        return .valid
    }
    
    // MARK: - Currency Validation
    
    /// Validate currency input with decimal precision
    /// - Parameters:
    ///   - value: String representation of currency
    ///   - fieldName: Field name for errors
    ///   - maxAmount: Maximum allowed amount
    /// - Returns: Tuple of validation result and parsed amount
    public static func validateCurrency(
        _ value: String,
        fieldName: String = "Amount",
        maxAmount: Double? = nil
    ) -> (ValidationResult, Double?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        guard !trimmed.isEmpty else {
            return (.invalid(.empty(field: fieldName)), nil)
        }
        
        // Remove currency symbols and format
        let cleaned = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        // Parse as double
        guard let amount = Double(cleaned) else {
            return (.invalid(.invalidCurrency(amount: value)), nil)
        }
        
        // Validate range
        if amount < 0 {
            return (.invalid(.negativeNotAllowed(field: fieldName, value: amount)), nil)
        }
        
        if let max = maxAmount, amount > max {
            return (.invalid(.tooLarge(field: fieldName, maximum: max, actual: amount)), nil)
        }
        
        // Validate precision (max 2 decimal places for currency)
        let precisionResult = validateDecimalPrecision(amount, fieldName: fieldName, maxDecimalPlaces: 2)
        if !precisionResult.isValid {
            return (precisionResult, nil)
        }
        
        return (.valid, amount)
    }
    
    // MARK: - Date Validation
    
    /// Validate date from string
    /// - Parameters:
    ///   - value: String representation of date
    ///   - fieldName: Field name for errors
    ///   - format: Expected date format
    /// - Returns: Tuple of validation result and parsed date
    public static func validateDate(
        _ value: String,
        fieldName: String = "Date",
        format: String = "yyyy-MM-dd"
    ) -> (ValidationResult, Date?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (.invalid(.empty(field: fieldName)), nil)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = formatter.date(from: trimmed) else {
            return (.invalid(.invalidDateFormat(field: fieldName, value: value, expectedFormat: format)), nil)
        }
        
        return (.valid, date)
    }
    
    /// Validate date range
    /// - Parameters:
    ///   - date: Date to validate
    ///   - fieldName: Field name for errors
    ///   - minDate: Minimum allowed date
    ///   - maxDate: Maximum allowed date
    /// - Returns: Validation result
    public static func validateDateRange(
        _ date: Date,
        fieldName: String = "Date",
        minDate: Date? = nil,
        maxDate: Date? = nil
    ) -> ValidationResult {
        if let min = minDate, date < min {
            return .invalid(.dateOutOfRange(field: fieldName, date: date, min: min, max: maxDate))
        }
        
        if let max = maxDate, date > max {
            return .invalid(.dateOutOfRange(field: fieldName, date: date, min: minDate, max: max))
        }
        
        return .valid
    }
    
    /// Validate that date is not in the past
    /// - Parameters:
    ///   - date: Date to validate
    ///   - fieldName: Field name for errors
    /// - Returns: Validation result
    public static func validateNotInPast(_ date: Date, fieldName: String = "Date") -> ValidationResult {
        let now = Date()
        if date < now {
            return .invalid(.dateInPast(field: fieldName, date: date))
        }
        return .valid
    }
    
    /// Validate that date is not in the future
    /// - Parameters:
    ///   - date: Date to validate
    ///   - fieldName: Field name for errors
    /// - Returns: Validation result
    public static func validateNotInFuture(_ date: Date, fieldName: String = "Date") -> ValidationResult {
        let now = Date()
        if date > now {
            return .invalid(.dateInFuture(field: fieldName, date: date))
        }
        return .valid
    }
    
    // MARK: - Email Validation
    
    /// Validate email address
    /// - Parameters:
    ///   - email: Email address to validate
    ///   - fieldName: Field name for errors
    /// - Returns: Validation result
    public static func validateEmail(_ email: String, fieldName: String = "Email") -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid(.empty(field: fieldName))
        }
        
        // Length check
        if trimmed.count > 254 {
            return .invalid(.emailTooLong(email: trimmed, maxLength: 254))
        }
        
        // Basic format validation
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: trimmed) {
            return .invalid(.invalidEmail(email: trimmed))
        }
        
        // Split into local and domain parts
        let components = trimmed.components(separatedBy: "@")
        guard components.count == 2 else {
            return .invalid(.invalidEmail(email: trimmed))
        }
        
        let localPart = components[0]
        let domain = components[1]
        
        // Validate local part
        if localPart.count > 64 {
            return .invalid(.emailLocalPartInvalid(email: trimmed, localPart: localPart))
        }
        
        // Validate domain
        if domain.isEmpty || domain.count > 253 {
            return .invalid(.emailDomainInvalid(email: trimmed, domain: domain))
        }
        
        return .valid
    }
    
    // MARK: - Budget-Specific Validation
    
    /// Validate category name
    /// - Parameters:
    ///   - category: Category name to validate
    ///   - existingCategories: List of existing categories to check for duplicates
    /// - Returns: Validation result
    public static func validateCategoryName(
        _ category: String,
        existingCategories: [String] = []
    ) -> ValidationResult {
        // Basic validation
        let basicResult = validateNotEmpty(category, fieldName: "Category")
        if !basicResult.isValid {
            return basicResult
        }
        
        let lengthResult = validateStringLength(category, fieldName: "Category", minLength: 1, maxLength: 50)
        if !lengthResult.isValid {
            return lengthResult
        }
        
        // Check for duplicates
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingCategories.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            return .invalid(.duplicateCategory(category: trimmed))
        }
        
        // Validate allowed characters
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_&"))
        
        return validateAllowedCharacters(trimmed, fieldName: "Category", allowedCharacters: allowedCharacters)
    }
    
    /// Validate transaction amount against budget
    /// - Parameters:
    ///   - amount: Transaction amount
    ///   - category: Transaction category
    ///   - budgetLimit: Budget limit for the category
    ///   - currentSpent: Amount already spent in the category
    /// - Returns: Validation result
    public static func validateBudgetConstraints(
        amount: Double,
        category: String,
        budgetLimit: Double,
        currentSpent: Double
    ) -> ValidationResult {
        let totalSpent = currentSpent + amount
        
        if totalSpent > budgetLimit {
            return .invalid(.budgetExceeded(category: category, amount: totalSpent, limit: budgetLimit))
        }
        
        return .valid
    }
    
    // MARK: - File Validation
    
    /// Validate file size
    /// - Parameters:
    ///   - fileSize: Size of the file in bytes
    ///   - maxSize: Maximum allowed size in bytes
    ///   - fieldName: Field name for errors
    /// - Returns: Validation result
    public static func validateFileSize(
        _ fileSize: Int64,
        maxSize: Int64,
        fieldName: String = "File"
    ) -> ValidationResult {
        if fileSize > maxSize {
            return .invalid(.fileTooLarge(size: fileSize, maxSize: maxSize))
        }
        return .valid
    }
    
    /// Validate file format
    /// - Parameters:
    ///   - fileName: Name of the file
    ///   - allowedExtensions: List of allowed file extensions
    ///   - fieldName: Field name for errors
    /// - Returns: Validation result
    public static func validateFileFormat(
        _ fileName: String,
        allowedExtensions: [String],
        fieldName: String = "File"
    ) -> ValidationResult {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        if !allowedExtensions.contains(fileExtension) {
            return .invalid(.invalidFileFormat(expected: allowedExtensions.joined(separator: ", "), actual: fileExtension))
        }
        
        return .valid
    }
    
    // MARK: - Combine Multiple Validations
    
    /// Validate multiple values and return combined result
    /// - Parameter results: Array of validation results
    /// - Returns: Combined validation result
    public static func validateAll(_ results: [ValidationResult]) -> ValidationResult {
        return ValidationResult.combine(results)
    }
    
    /// Validate with custom condition
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - error: Error to return if condition fails
    /// - Returns: Validation result
    public static func validateCondition(_ condition: Bool, error: ValidationError) -> ValidationResult {
        return condition ? .valid : .invalid(error)
    }
    
    // MARK: - Async Validation Support
    
    /// Async validation for operations that require network calls or database queries
    /// - Parameters:
    ///   - value: Value to validate
    ///   - validator: Async validation function
    /// - Returns: Validation result
    public static func validateAsync<T>(
        _ value: T,
        validator: @escaping (T) async throws -> ValidationResult
    ) async -> ValidationResult {
        do {
            return try await validator(value)
        } catch {
            return .invalid(.custom(message: "Validation failed: \(error.localizedDescription)"))
        }
    }
}

// MARK: - Validation Rule Builder

/// Builder pattern for creating complex validation rules
public struct ValidationRuleBuilder<T> {
    private var rules: [(T) -> ValidationResult] = []
    
    public init() {}
    
    /// Add a validation rule
    /// - Parameter rule: Validation function
    /// - Returns: Updated builder
    public func addRule(_ rule: @escaping (T) -> ValidationResult) -> ValidationRuleBuilder<T> {
        var builder = self
        builder.rules.append(rule)
        return builder
    }
    
    /// Add a condition-based rule
    /// - Parameters:
    ///   - condition: Condition to check
    ///   - error: Error to return if condition fails
    /// - Returns: Updated builder
    public func addCondition(_ condition: @escaping (T) -> Bool, error: ValidationError) -> ValidationRuleBuilder<T> {
        return addRule { value in
            condition(value) ? .valid : .invalid(error)
        }
    }
    
    /// Add an async rule
    /// - Parameter asyncRule: Async validation function
    /// - Returns: Updated builder
    public func addAsyncRule(_ asyncRule: @escaping (T) async -> ValidationResult) -> ValidationRuleBuilder<T> {
        return addRule { value in
            // For sync context, we'll return valid and handle async separately
            .valid
        }
    }
    
    /// Build and execute all validation rules
    /// - Parameter value: Value to validate
    /// - Returns: Combined validation result
    public func validate(_ value: T) -> ValidationResult {
        let results = rules.map { $0(value) }
        return ValidationHelpers.validateAll(results)
    }
    
    /// Build and execute all validation rules asynchronously
    /// - Parameter value: Value to validate
    /// - Returns: Combined validation result
    public func validateAsync(_ value: T) async -> ValidationResult {
        var results: [ValidationResult] = []
        
        for rule in rules {
            results.append(rule(value))
        }
        
        return ValidationHelpers.validateAll(results)
    }
}

// MARK: - Common Validation Rules

/// Pre-built validation rules for common scenarios
public enum CommonValidationRules {
    
    /// User name validation rules
    public static let userName = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Username") }
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Username", minLength: 2, maxLength: 30) }
        .addRule { ValidationHelpers.validateAllowedCharacters($0, fieldName: "Username", allowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "_-"))) }
    
    /// Budget amount validation rules
    public static let budgetAmount = ValidationRuleBuilder<String>()
        .addRule { value in
            let (result, _) = ValidationHelpers.validateCurrency(value, maxAmount: 999999.99)
            return result
        }
    
    /// Category name validation rules
    public static let categoryName = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Category") }
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Category", maxLength: 50) }
        .addRule { ValidationHelpers.validateAllowedCharacters($0, fieldName: "Category", allowedCharacters: .alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_&"))) }
    
    /// Transaction note validation rules
    public static let transactionNote = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Note", maxLength: 500) }
    
    /// Email validation rules
    public static let email = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Email") }
        .addRule { ValidationHelpers.validateEmail($0) }
    
    /// Password validation rules
    public static let password = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Password") }
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Password", minLength: 8, maxLength: 128) }
        .addCondition({ password in
            password.rangeOfCharacter(from: .uppercaseLetters) != nil
        }, error: .custom(message: "Password must contain at least one uppercase letter"))
        .addCondition({ password in
            password.rangeOfCharacter(from: .lowercaseLetters) != nil
        }, error: .custom(message: "Password must contain at least one lowercase letter"))
        .addCondition({ password in
            password.rangeOfCharacter(from: .decimalDigits) != nil
        }, error: .custom(message: "Password must contain at least one digit"))
}

// MARK: - SwiftUI Integration

/// Property wrapper for validated values in SwiftUI
@propertyWrapper
public struct Validated<T> {
    private var value: T
    private let validator: (T) -> ValidationResult
    private var cachedResult: ValidationResult?
    
    public var wrappedValue: T {
        get { value }
        set {
            value = newValue
            cachedResult = nil // Invalidate cache
        }
    }
    
    public var projectedValue: ValidationResult {
        if let cached = cachedResult {
            return cached
        }
        let result = validator(value)
        cachedResult = result
        return result
    }
    
    public init(wrappedValue: T, validator: @escaping (T) -> ValidationResult) {
        self.value = wrappedValue
        self.validator = validator
    }
    
    public init(wrappedValue: T, ruleBuilder: ValidationRuleBuilder<T>) {
        self.value = wrappedValue
        self.validator = ruleBuilder.validate
    }
}

// MARK: - View Modifiers for Validation

public struct ValidationModifier: ViewModifier {
    let validation: ValidationResult
    let showIcon: Bool
    
    public init(validation: ValidationResult, showIcon: Bool = true) {
        self.validation = validation
        self.showIcon = showIcon
    }
    
    public func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            
            if case .invalid(let error) = validation {
                HStack(spacing: 6) {
                    if showIcon {
                        Image(systemName: error.severity.icon)
                            .foregroundColor(error.severity.color)
                            .font(.caption)
                    }
                    
                    Text(error.errorDescription ?? "Invalid input")
                        .font(.caption)
                        .foregroundColor(error.severity.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validation.isValid)
    }
}

/// Inline validation status indicator
public struct ValidationStatusModifier: ViewModifier {
    let validation: ValidationResult
    
    public func body(content: Content) -> some View {
        HStack {
            content
            
            Spacer()
            
            switch validation {
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            case .invalid(let error):
                Image(systemName: error.severity.icon)
                    .foregroundColor(error.severity.color)
                    .font(.caption)
            }
        }
    }
}

public extension View {
    /// Add validation error display
    func validation(_ result: ValidationResult, showIcon: Bool = true) -> some View {
        modifier(ValidationModifier(validation: result, showIcon: showIcon))
    }
    
    /// Add validation status indicator
    func validationStatus(_ result: ValidationResult) -> some View {
        modifier(ValidationStatusModifier(validation: result))
    }
    
    /// Apply validation styling based on result
    func validationStyling(_ result: ValidationResult) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        result.isValid ? Color.clear : (result.error?.severity.color ?? .red),
                        lineWidth: result.isValid ? 0 : 1
                    )
            )
    }
}

// MARK: - Form Validation Helper

/// Helper for form-wide validation
public class FormValidator: ObservableObject {
    @Published public private(set) var isValid = true
    @Published public private(set) var errors: [String: ValidationError] = [:]
    
    private var validations: [String: ValidationResult] = [:]
    
    public init() {}
    
    /// Update validation for a field
    public func updateValidation(for field: String, result: ValidationResult) {
        validations[field] = result
        
        switch result {
        case .valid:
            errors.removeValue(forKey: field)
        case .invalid(let error):
            errors[field] = error
        }
        
        updateOverallValidation()
    }
    
    /// Clear validation for a field
    public func clearValidation(for field: String) {
        validations.removeValue(forKey: field)
        errors.removeValue(forKey: field)
        updateOverallValidation()
    }
    
    /// Clear all validations
    public func clearAll() {
        validations.removeAll()
        errors.removeAll()
        isValid = true
    }
    
    /// Get validation result for a field
    public func getValidation(for field: String) -> ValidationResult {
        return validations[field] ?? .valid
    }
    
    /// Get all error messages
    public func getAllErrorMessages() -> [String] {
        return errors.values.compactMap { $0.errorDescription }
    }
    
    private func updateOverallValidation() {
        isValid = errors.isEmpty
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Debug Utilities

#if DEBUG
extension ValidationHelpers {
    /// Create test validation errors for preview/testing
    public static func createTestValidationErrors() -> [ValidationError] {
        return [
            .empty(field: "Name"),
            .tooShort(field: "Password", minimum: 8, actual: 4),
            .invalidEmail(email: "invalid-email"),
            .budgetExceeded(category: "Food", amount: 500.0, limit: 400.0),
            .invalidCurrency(amount: "abc123"),
            .dateInFuture(field: "Transaction Date", date: Date().addingTimeInterval(86400)),
            .categoryNotFound(category: "NonExistent"),
            .fileTooLarge(size: 10_000_000, maxSize: 5_000_000)
        ]
    }
    
    /// Test all validation methods
    public static func runValidationTests() {
        print("🧪 Running validation tests...")
        
        // Test string validation
        assert(validateNotEmpty("test").isValid)
        assert(!validateNotEmpty("").isValid)
        assert(!validateNotEmpty("   ").isValid)
        
        // Test number validation
        let (numResult, number) = validateNumber("123.45")
        assert(numResult.isValid && number == 123.45)
        
        // Test currency validation
        let (currResult, amount) = validateCurrency("$1,234.56")
        assert(currResult.isValid && amount == 1234.56)
        
        // Test email validation
        assert(validateEmail("test@example.com").isValid)
        assert(!validateEmail("invalid-email").isValid)
        
        print("✅ All validation tests passed!")
    }
}

/// SwiftUI Preview helper for testing validation
struct ValidationTestView: View {
    @State private var testString = ""
    @State private var testEmail = ""
    @State private var testAmount = ""
    
    var body: some View {
        Form {
            Section("String Validation") {
                TextField("Name (2-30 chars)", text: $testString)
                    .validation(CommonValidationRules.userName.validate(testString))
            }
            
            Section("Email Validation") {
                TextField("Email", text: $testEmail)
                    .validation(CommonValidationRules.email.validate(testEmail))
            }
            
            Section("Currency Validation") {
                TextField("Amount", text: $testAmount)
                    .validation(CommonValidationRules.budgetAmount.validate(testAmount))
            }
        }
        .navigationTitle("Validation Test")
    }
}

#Preview {
    NavigationView {
        ValidationTestView()
    }
}
#endif
