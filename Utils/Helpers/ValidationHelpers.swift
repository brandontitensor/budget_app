
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
public enum ValidationResult: Equatable {
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
}

/// Comprehensive validation error types
public enum ValidationError: LocalizedError, Equatable {
    // String validation errors
    case empty(field: String)
    case tooShort(field: String, minimum: Int, actual: Int)
    case tooLong(field: String, maximum: Int, actual: Int)
    case invalidFormat(field: String, format: String)
    case containsInvalidCharacters(field: String, characters: String)
    case notAllowed(field: String, value: String, reason: String)
    
    // Numeric validation errors
    case notANumber(field: String, value: String)
    case tooSmall(field: String, minimum: Double, actual: Double)
    case tooLarge(field: String, maximum: Double, actual: Double)
    case notInteger(field: String, value: Double)
    case negativeNotAllowed(field: String, value: Double)
    case zeroNotAllowed(field: String)
    
    // Date validation errors
    case invalidDate(field: String, value: String)
    case dateInPast(field: String, date: Date)
    case dateInFuture(field: String, date: Date)
    case dateOutOfRange(field: String, date: Date, min: Date?, max: Date?)
    
    // Email validation errors
    case invalidEmail(email: String)
    case emailTooLong(email: String, maxLength: Int)
    case emailDomainInvalid(email: String, domain: String)
    
    // Budget-specific validation errors
    case invalidCurrency(amount: String)
    case budgetExceeded(category: String, amount: Double, limit: Double)
    case categoryNotFound(category: String)
    case duplicateCategory(category: String)
    case invalidTransactionDate(date: Date, reason: String)
    case invalidBudgetPeriod(period: String)
    
    // Custom validation errors
    case custom(message: String)
    case multipleErrors([ValidationError])
    
    public var errorDescription: String? {
        switch self {
        // String errors
        case .empty(let field):
            return "\(field) cannot be empty"
        case .tooShort(let field, let minimum, let actual):
            return "\(field) is too short (minimum \(minimum) characters, got \(actual))"
        case .tooLong(let field, let maximum, let actual):
            return "\(field) is too long (maximum \(maximum) characters, got \(actual))"
        case .invalidFormat(let field, let format):
            return "\(field) format is invalid. Expected format: \(format)"
        case .containsInvalidCharacters(let field, let characters):
            return "\(field) contains invalid characters: \(characters)"
        case .notAllowed(let field, let value, let reason):
            return "\(field) value '\(value)' is not allowed: \(reason)"
            
        // Numeric errors
        case .notANumber(let field, let value):
            return "\(field) must be a valid number (got '\(value)')"
        case .tooSmall(let field, let minimum, let actual):
            return "\(field) is too small (minimum \(minimum), got \(actual))"
        case .tooLarge(let field, let maximum, let actual):
            return "\(field) is too large (maximum \(maximum), got \(actual))"
        case .notInteger(let field, let value):
            return "\(field) must be a whole number (got \(value))"
        case .negativeNotAllowed(let field, let value):
            return "\(field) cannot be negative (got \(value))"
        case .zeroNotAllowed(let field):
            return "\(field) cannot be zero"
            
        // Date errors
        case .invalidDate(let field, let value):
            return "\(field) is not a valid date (got '\(value)')"
        case .dateInPast(let field, let date):
            return "\(field) cannot be in the past (got \(date.formatted()))"
        case .dateInFuture(let field, let date):
            return "\(field) cannot be in the future (got \(date.formatted()))"
        case .dateOutOfRange(let field, let date, let min, let max):
            let minStr = min?.formatted() ?? "beginning of time"
            let maxStr = max?.formatted() ?? "end of time"
            return "\(field) must be between \(minStr) and \(maxStr) (got \(date.formatted()))"
            
        // Email errors
        case .invalidEmail(let email):
            return "Invalid email address: \(email)"
        case .emailTooLong(let email, let maxLength):
            return "Email address is too long (maximum \(maxLength) characters): \(email)"
        case .emailDomainInvalid(let email, let domain):
            return "Email domain '\(domain)' is not valid in \(email)"
            
        // Budget-specific errors
        case .invalidCurrency(let amount):
            return "Invalid currency amount: \(amount)"
        case .budgetExceeded(let category, let amount, let limit):
            return "\(category) budget exceeded: \(amount.asCurrency) over limit of \(limit.asCurrency)"
        case .categoryNotFound(let category):
            return "Budget category '\(category)' not found"
        case .duplicateCategory(let category):
            return "Category '\(category)' already exists"
        case .invalidTransactionDate(let date, let reason):
            return "Invalid transaction date \(date.formatted()): \(reason)"
        case .invalidBudgetPeriod(let period):
            return "Invalid budget period: \(period)"
            
        // Custom errors
        case .custom(let message):
            return message
        case .multipleErrors(let errors):
            return "Multiple validation errors: " + errors.compactMap { $0.errorDescription }.joined(separator: "; ")
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
        case .notANumber:
            return "Please enter a valid number"
        case .tooSmall(_, let minimum, _):
            return "Please enter a value of at least \(minimum)"
        case .tooLarge(_, let maximum, _):
            return "Please enter a value no greater than \(maximum)"
        case .invalidEmail:
            return "Please enter a valid email address (e.g., user@example.com)"
        case .budgetExceeded:
            return "Consider adjusting your budget or reducing the amount"
        case .categoryNotFound:
            return "Please select an existing category or create a new one"
        case .duplicateCategory:
            return "Please choose a different category name"
        default:
            return "Please check your input and try again"
    }
}
#endif

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
        return trimmed.isEmpty ? .invalid(.empty(field: fieldName)) : .valid
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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let min = minLength, trimmed.count < min {
            return .invalid(.tooShort(field: fieldName, minimum: min, actual: trimmed.count))
        }
        
        if let max = maxLength, trimmed.count > max {
            return .invalid(.tooLong(field: fieldName, maximum: max, actual: trimmed.count))
        }
        
        return .valid
    }
    
    /// Validate string format using regex
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - pattern: Regular expression pattern
    ///   - formatDescription: Description of the expected format
    /// - Returns: Validation result
    public static func validateStringFormat(
        _ value: String,
        fieldName: String = "Field",
        pattern: String,
        formatDescription: String
    ) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let matches = regex.matches(in: trimmed, options: [], range: range)
            
            return matches.isEmpty ? .invalid(.invalidFormat(field: fieldName, format: formatDescription)) : .valid
        } catch {
            return .invalid(.custom(message: "Invalid validation pattern"))
        }
    }
    
    /// Validate that string contains only allowed characters
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - allowedCharacters: Character set of allowed characters
    /// - Returns: Validation result
    public static func validateAllowedCharacters(
        _ value: String,
        fieldName: String = "Field",
        allowedCharacters: CharacterSet
    ) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let range = trimmed.rangeOfCharacter(from: allowedCharacters.inverted) {
            let invalidChars = String(trimmed[range])
            return .invalid(.containsInvalidCharacters(field: fieldName, characters: invalidChars))
        }
        
        return .valid
    }
    
    // MARK: - Numeric Validation
    
    /// Validate that a string represents a valid number
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Validation result with parsed number
    public static func validateNumber(_ value: String, fieldName: String = "Field") -> (ValidationResult, Double?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove currency symbols and formatting
        let cleanedValue = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        guard let number = Double(cleanedValue) else {
            return (.invalid(.notANumber(field: fieldName, value: trimmed)), nil)
        }
        
        return (.valid, number)
    }
    
    /// Validate numeric range
    /// - Parameters:
    ///   - value: The number to validate
    ///   - fieldName: Name of the field for error messages
    ///   - min: Minimum allowed value (optional)
    ///   - max: Maximum allowed value (optional)
    ///   - allowZero: Whether zero is allowed (default: true)
    ///   - allowNegative: Whether negative values are allowed (default: true)
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
    
    /// Validate that a number is an integer
    /// - Parameters:
    ///   - value: The number to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Validation result
    public static func validateInteger(_ value: Double, fieldName: String = "Field") -> ValidationResult {
        return value.truncatingRemainder(dividingBy: 1) == 0 ? .valid : .invalid(.notInteger(field: fieldName, value: value))
    }
    
    // MARK: - Currency Validation
    
    /// Validate currency amount
    /// - Parameters:
    ///   - value: The currency string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - maxAmount: Maximum allowed amount (optional)
    /// - Returns: Validation result with parsed amount
    public static func validateCurrency(
        _ value: String,
        fieldName: String = "Amount",
        maxAmount: Double? = nil
    ) -> (ValidationResult, Double?) {
        let (numberResult, amount) = validateNumber(value, fieldName: fieldName)
        
        guard case .valid = numberResult, let validAmount = amount else {
            return (.invalid(.invalidCurrency(amount: value)), nil)
        }
        
        let rangeResult = validateNumberRange(
            validAmount,
            fieldName: fieldName,
            min: 0,
            max: maxAmount,
            allowZero: false,
            allowNegative: false
        )
        
        return (rangeResult, validAmount)
    }
    
    // MARK: - Date Validation
    
    /// Validate date string
    /// - Parameters:
    ///   - value: The date string to validate
    ///   - fieldName: Name of the field for error messages
    ///   - format: Expected date format (default: "yyyy-MM-dd")
    /// - Returns: Validation result with parsed date
    public static func validateDate(
        _ value: String,
        fieldName: String = "Date",
        format: String = "yyyy-MM-dd"
    ) -> (ValidationResult, Date?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = formatter.date(from: trimmed) else {
            return (.invalid(.invalidDate(field: fieldName, value: trimmed)), nil)
        }
        
        return (.valid, date)
    }
    
    /// Validate date range
    /// - Parameters:
    ///   - date: The date to validate
    ///   - fieldName: Name of the field for error messages
    ///   - minDate: Minimum allowed date (optional)
    ///   - maxDate: Maximum allowed date (optional)
    ///   - allowPast: Whether past dates are allowed (default: true)
    ///   - allowFuture: Whether future dates are allowed (default: true)
    /// - Returns: Validation result
    public static func validateDateRange(
        _ date: Date,
        fieldName: String = "Date",
        minDate: Date? = nil,
        maxDate: Date? = nil,
        allowPast: Bool = true,
        allowFuture: Bool = true
    ) -> ValidationResult {
        let now = Date()
        
        if !allowPast && date < now {
            return .invalid(.dateInPast(field: fieldName, date: date))
        }
        
        if !allowFuture && date > now {
            return .invalid(.dateInFuture(field: fieldName, date: date))
        }
        
        if let min = minDate, date < min {
            return .invalid(.dateOutOfRange(field: fieldName, date: date, min: min, max: maxDate))
        }
        
        if let max = maxDate, date > max {
            return .invalid(.dateOutOfRange(field: fieldName, date: date, min: minDate, max: max))
        }
        
        return .valid
    }
    
    // MARK: - Email Validation
    
    /// Validate email address
    /// - Parameters:
    ///   - email: The email string to validate
    ///   - maxLength: Maximum allowed length (default: 254)
    /// - Returns: Validation result
    public static func validateEmail(_ email: String, maxLength: Int = 254) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        if trimmed.count > maxLength {
            return .invalid(.emailTooLong(email: trimmed, maxLength: maxLength))
        }
        
        // Basic email regex pattern
        let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        
        do {
            let regex = try NSRegularExpression(pattern: emailPattern, options: [])
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let matches = regex.matches(in: trimmed, options: [], range: range)
            
            if matches.isEmpty {
                return .invalid(.invalidEmail(email: trimmed))
            }
            
            // Additional domain validation
            let components = trimmed.split(separator: "@")
            if components.count == 2 {
                let domain = String(components[1])
                if domain.hasPrefix(".") || domain.hasSuffix(".") || domain.contains("..") {
                    return .invalid(.emailDomainInvalid(email: trimmed, domain: domain))
                }
            }
            
            return .valid
        } catch {
            return .invalid(.custom(message: "Email validation failed"))
        }
    }
    
    // MARK: - Budget-Specific Validation
    
    /// Validate category name
    /// - Parameters:
    ///   - category: The category name to validate
    ///   - existingCategories: List of existing categories to check for duplicates
    ///   - maxLength: Maximum allowed length (default: 30)
    /// - Returns: Validation result
    public static func validateCategory(
        _ category: String,
        existingCategories: [String] = [],
        maxLength: Int = AppConstants.Validation.maxCategoryNameLength
    ) -> ValidationResult {
        // Check if empty
        let emptyResult = validateNotEmpty(category, fieldName: "Category")
        if case .invalid = emptyResult { return emptyResult }
        
        // Check length
        let lengthResult = validateStringLength(category, fieldName: "Category", maxLength: maxLength)
        if case .invalid = lengthResult { return lengthResult }
        
        // Check for duplicates
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingCategories.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            return .invalid(.duplicateCategory(category: trimmed))
        }
        
        // Check for valid characters (letters, numbers, spaces, hyphens, underscores)
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
        return validateAllowedCharacters(trimmed, fieldName: "Category", allowedCharacters: allowedCharacters)
    }
    
    /// Validate transaction amount against budget
    /// - Parameters:
    ///   - amount: Transaction amount
    ///   - category: Budget category
    ///   - currentSpent: Current amount spent in category
    ///   - budgetLimit: Budget limit for category
    ///   - allowOverBudget: Whether to allow going over budget (default: true)
    /// - Returns: Validation result
    public static func validateBudgetLimit(
        amount: Double,
        category: String,
        currentSpent: Double,
        budgetLimit: Double,
        allowOverBudget: Bool = true
    ) -> ValidationResult {
        let newTotal = currentSpent + amount
        
        if !allowOverBudget && newTotal > budgetLimit {
            let overAmount = newTotal - budgetLimit
            return .invalid(.budgetExceeded(category: category, amount: overAmount, limit: budgetLimit))
        }
        
        return .valid
    }
    
    /// Validate transaction date for budget entry
    /// - Parameters:
    ///   - date: Transaction date
    ///   - allowFuture: Whether future dates are allowed (default: false)
    ///   - maxPastDays: Maximum days in the past allowed (default: 365)
    /// - Returns: Validation result
    public static func validateTransactionDate(
        _ date: Date,
        allowFuture: Bool = false,
        maxPastDays: Int = 365
    ) -> ValidationResult {
        let now = Date()
        let maxPastDate = Calendar.current.date(byAdding: .day, value: -maxPastDays, to: now) ?? now
        
        if !allowFuture && date > now {
            return .invalid(.invalidTransactionDate(date: date, reason: "Future dates are not allowed"))
        }
        
        if date < maxPastDate {
            return .invalid(.invalidTransactionDate(date: date, reason: "Date is too far in the past"))
        }
        
        return .valid
    }
    
    // MARK: - Composite Validation
    
    /// Validate multiple conditions and return combined result
    /// - Parameter validations: Array of validation results
    /// - Returns: Combined validation result
    public static func validateAll(_ validations: [ValidationResult]) -> ValidationResult {
        let errors = validations.compactMap { result in
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
    
    /// Validate with custom conditions
    /// - Parameters:
    ///   - condition: Boolean condition to check
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
    
    /// Build and execute all validation rules
    /// - Parameter value: Value to validate
    /// - Returns: Combined validation result
    public func validate(_ value: T) -> ValidationResult {
        let results = rules.map { $0(value) }
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
            let (result, _) = ValidationHelpers.validateCurrency(value, maxAmount: AppConstants.Validation.maximumTransactionAmount)
            return result
        }
    
    /// Category name validation rules
    public static let categoryName = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Category") }
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Category", maxLength: AppConstants.Validation.maxCategoryNameLength) }
        .addRule { ValidationHelpers.validateAllowedCharacters($0, fieldName: "Category", allowedCharacters: .alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))) }
    
    /// Transaction note validation rules
    public static let transactionNote = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateStringLength($0, fieldName: "Note", maxLength: AppConstants.Data.maxTransactionNoteLength) }
    
    /// Email validation rules
    public static let email = ValidationRuleBuilder<String>()
        .addRule { ValidationHelpers.validateNotEmpty($0, fieldName: "Email") }
        .addRule { ValidationHelpers.validateEmail($0) }
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
            cachedResult = nil // Clear cache when value changes
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
}

/// SwiftUI view modifier for validation display
public struct ValidationModifier: ViewModifier {
    let validationResult: ValidationResult
    let showValidation: Bool
    
    public func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            
            if showValidation, case .invalid(let error) = validationResult {
                Text(error.errorDescription ?? "Invalid input")
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
}

public extension View {
    /// Add validation display to a view
    /// - Parameters:
    ///   - result: Validation result to display
    ///   - showValidation: Whether to show validation messages
    /// - Returns: Modified view with validation display
    func validation(_ result: ValidationResult, show: Bool = true) -> some View {
        modifier(ValidationModifier(validationResult: result, showValidation: show))
    }
}

// MARK: - Testing Support

#if DEBUG
public extension ValidationHelpers {
    /// Testing utilities for validation
    enum Testing {
        /// Test all validation functions with sample data
        public static func runValidationTests() -> [String: Bool] {
            var results: [String: Bool] = [:]
            
            // String validation tests
            results["empty_string"] = (validateNotEmpty("", fieldName: "Test").isValid == false)
            results["valid_string"] = validateNotEmpty("Valid", fieldName: "Test").isValid
            results["long_string"] = (validateStringLength("Very long string that exceeds limit", fieldName: "Test", maxLength: 10).isValid == false)
            
            // Number validation tests
            let (numberResult, _) = validateNumber("123.45", fieldName: "Test")
            results["valid_number"] = numberResult.isValid
            let (invalidNumberResult, _) = validateNumber("abc", fieldName: "Test")
            results["invalid_number"] = (invalidNumberResult.isValid == false)
            
            // Currency validation tests
            let (currencyResult, _) = validateCurrency("$123.45", fieldName: "Test")
            results["valid_currency"] = currencyResult.isValid
            let (invalidCurrencyResult, _) = validateCurrency("-$50", fieldName: "Test")
            results["negative_currency"] = (invalidCurrencyResult.isValid == false)
            
            // Email validation tests
            results["valid_email"] = validateEmail("test@example.com").isValid
            results["invalid_email"] = (validateEmail("invalid.email").isValid == false)
            
            // Date validation tests
            let (dateResult, _) = validateDate("2024-01-01", fieldName: "Test")
            results["valid_date"] = dateResult.isValid
            let (invalidDateResult, _) = validateDate("invalid-date", fieldName: "Test")
            results["invalid_date"] = (invalidDateResult.isValid == false)
            
            return results
        }
        
        /// Performance test for validation functions
        public static func performanceTest(iterations: Int = 1000) -> TimeInterval {
            let startTime = Date()
            
            for _ in 0..<iterations {
                _ = validateNotEmpty("Test String", fieldName: "Test")
                let (_, _) = validateNumber("123.45", fieldName: "Test")
                _ = validateEmail("test@example.com")
                let (_, _) = validateDate("2024-01-01", fieldName: "Test")
            }
            
            return Date().timeIntervalSince(startTime)
        }
        
        /// Generate test validation errors for UI testing
        public static func sampleValidationErrors() -> [ValidationError] {
            return [
                .empty(field: "Username"),
                .tooShort(field: "Password", minimum: 8, actual: 4),
                .invalidEmail(email: "invalid.email"),
                .budgetExceeded(category: "Groceries", amount: 150.0, limit: 100.0),
                .invalidCurrency(amount: "invalid"),
                .custom(message: "Custom validation error")
            ]
        }
    }
}
