//
//  CSVImport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/29/25.
//

import Foundation

/// Service responsible for importing budget data from CSV format with proper validation and error handling
public enum CSVImport {
    // MARK: - Import Types
    public enum ImportType {
        case budgetEntries
        case monthlyBudgets
        case autoDetect
        
        var expectedHeaders: [String] {
            switch self {
            case .budgetEntries:
                return ["date", "amount", "category"]
            case .monthlyBudgets:
                return ["year", "month", "category", "amount"]
            case .autoDetect:
                return []
            }
        }
        
        var optionalHeaders: [String] {
            switch self {
            case .budgetEntries:
                return ["note"]
            case .monthlyBudgets:
                return ["ishistorical"]
            case .autoDetect:
                return []
            }
        }
    }
    
    // MARK: - Import Configuration
    public struct ImportConfiguration {
        let importType: ImportType
        let validateDuplicates: Bool
        let skipInvalidRows: Bool
        let maxFileSize: Int64
        let maxRowCount: Int
        let dateFormats: [String]
        let encoding: String.Encoding
        let delimiter: String
        let strictValidation: Bool
        
        public init(
            importType: ImportType = .autoDetect,
            validateDuplicates: Bool = true,
            skipInvalidRows: Bool = true,
            maxFileSize: Int64 = 10 * 1024 * 1024, // 10MB
            maxRowCount: Int = 10000,
            dateFormats: [String] = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy"],
            encoding: String.Encoding = .utf8,
            delimiter: String = ",",
            strictValidation: Bool = false
        ) {
            self.importType = importType
            self.validateDuplicates = validateDuplicates
            self.skipInvalidRows = skipInvalidRows
            self.maxFileSize = maxFileSize
            self.maxRowCount = maxRowCount
            self.dateFormats = dateFormats
            self.encoding = encoding
            self.delimiter = delimiter
            self.strictValidation = strictValidation
        }
        
        public static let `default` = ImportConfiguration()
        public static let strict = ImportConfiguration(skipInvalidRows: false, strictValidation: true)
    }
    
    // MARK: - Data Structures
    public struct PurchaseImportData: Codable, Equatable {
        public let date: String
        public let amount: Double
        public let category: String
        public let note: String?
        
        public init(date: String, amount: Double, category: String, note: String?) {
            self.date = date
            self.amount = amount
            self.category = category
            self.note = note
        }
        
        /// Convert to BudgetEntry
        public func toBudgetEntry(dateFormatter: DateFormatter) throws -> BudgetEntry {
            guard let parsedDate = dateFormatter.date(from: date) else {
                throw AppError.csvImport(underlying: NSError(
                    domain: "CSVImport",
                    code: 2003,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid date format: \(date)"]
                ))
            }
            
            return try BudgetEntry(
                amount: amount,
                category: category,
                date: parsedDate,
                note: note
            )
        }
    }
    
    public struct BudgetImportData: Codable, Equatable {
        public let year: Int
        public let month: Int
        public let category: String
        public let amount: Double
        public let isHistorical: Bool
        
        public init(year: Int, month: Int, category: String, amount: Double, isHistorical: Bool) {
            self.year = year
            self.month = month
            self.category = category
            self.amount = amount
            self.isHistorical = isHistorical
        }
        
        /// Convert to MonthlyBudget
        public func toMonthlyBudget() throws -> MonthlyBudget {
            return try MonthlyBudget(
                category: category,
                amount: amount,
                month: month,
                year: year,
                isHistorical: isHistorical
            )
        }
    }
    
    public struct ImportResults<T> {
        public let data: [T]
        public let categories: Set<String>
        public let existingCategories: Set<String>
        public let newCategories: Set<String>
        public let totalAmount: Double
        public let warningMessages: [String]
        public let skippedRowCount: Int
        public let duplicateCount: Int
        public let validationErrors: [ValidationError]
        
        public init(
            data: [T],
            categories: Set<String>,
            existingCategories: Set<String>,
            newCategories: Set<String>,
            totalAmount: Double,
            warningMessages: [String] = [],
            skippedRowCount: Int = 0,
            duplicateCount: Int = 0,
            validationErrors: [ValidationError] = []
        ) {
            self.data = data
            self.categories = categories
            self.existingCategories = existingCategories
            self.newCategories = newCategories
            self.totalAmount = totalAmount
            self.warningMessages = warningMessages
            self.skippedRowCount = skippedRowCount
            self.duplicateCount = duplicateCount
            self.validationErrors = validationErrors
        }
        
        public var summary: String {
            var parts: [String] = []
            parts.append("\(data.count) records imported")
            
            if skippedRowCount > 0 {
                parts.append("\(skippedRowCount) rows skipped")
            }
            
            if duplicateCount > 0 {
                parts.append("\(duplicateCount) duplicates found")
            }
            
            if !newCategories.isEmpty {
                parts.append("\(newCategories.count) new categories")
            }
            
            return parts.joined(separator: ", ")
        }
    }
    
    // MARK: - Validation Error
    public struct ValidationError {
        public let rowNumber: Int
        public let field: String
        public let value: String
        public let message: String
        
        public init(rowNumber: Int, field: String, value: String, message: String) {
            self.rowNumber = rowNumber
            self.field = field
            self.value = value
            self.message = message
        }
        
        public var description: String {
            "Row \(rowNumber): \(field) '\(value)' - \(message)"
        }
    }
    
    // MARK: - Import Methods
    
    /// Import purchases from CSV file
    public static func importPurchases(
        from url: URL,
        existingCategories: [String] = [],
        configuration: ImportConfiguration = ImportConfiguration.default
    ) async throws -> ImportResults<PurchaseImportData> {
        return try await performImport(
            from: url,
            expectedType: .budgetEntries,
            existingCategories: existingCategories,
            configuration: configuration,
            parseFunction: parsePurchaseData
        )
    }
    
    /// Import monthly budgets from CSV file
    public static func importBudgets(
        from url: URL,
        existingCategories: [String] = [],
        configuration: ImportConfiguration = ImportConfiguration.default
    ) async throws -> ImportResults<BudgetImportData> {
        return try await performImport(
            from: url,
            expectedType: .monthlyBudgets,
            existingCategories: existingCategories,
            configuration: configuration,
            parseFunction: parseBudgetData
        )
    }
    
    /// Auto-detect import type and import data accordingly
    public static func importWithAutoDetection(
        from url: URL,
        existingCategories: [String] = []
    ) async throws -> Either<ImportResults<PurchaseImportData>, ImportResults<BudgetImportData>> {
        // Read and parse file to determine type
        let fileContent = try await readAndValidateFile(url, configuration: .default)
        let csvData = try parseCSVContent(fileContent, configuration: .default)
        
        guard let headerRow = csvData.first else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2001,
                userInfo: [NSLocalizedDescriptionKey: "CSV file contains no data"]
            ))
        }
        
        let headers = Set(headerRow.keys.map { $0.lowercased() })
        
        // Determine import type based on headers
        let budgetHeaders = Set(ImportType.budgetEntries.expectedHeaders)
        let monthlyHeaders = Set(ImportType.monthlyBudgets.expectedHeaders)
        
        if budgetHeaders.isSubset(of: headers) {
            let result = try await importPurchases(from: url, existingCategories: existingCategories)
            return .left(result)
        } else if monthlyHeaders.isSubset(of: headers) {
            let result = try await importBudgets(from: url, existingCategories: existingCategories)
            return .right(result)
        } else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2002,
                userInfo: [NSLocalizedDescriptionKey: "Unable to determine import type from headers: \(Array(headers))"]
            ))
        }
    }
    
    // MARK: - Core Import Logic
    
    private static func performImport<T>(
        from url: URL,
        expectedType: ImportType,
        existingCategories: [String],
        configuration: ImportConfiguration,
        parseFunction: @escaping ([[String: String]], ImportConfiguration, [String]) throws -> ImportResults<T>
    ) async throws -> ImportResults<T> {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let startTime = Date()
                    
                    // Read and validate file
                    let fileContent = try await readAndValidateFile(url, configuration: configuration)
                    
                    // Parse CSV content
                    let csvData = try parseCSVContent(fileContent, configuration: configuration)
                    
                    // Validate headers
                    let actualType = try validateAndDetectType(csvData, expectedType: expectedType)
                    
                    // Parse data using appropriate function
                    let result = try parseFunction(csvData, configuration, existingCategories)
                    
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ CSV Import: Completed in \(String(format: "%.2f", duration * 1000))ms - \(result.summary)")
                    
                    continuation.resume(returning: result)
                } catch {
                    let appError = AppError.csvImport(underlying: error)
                    print("❌ CSV Import: Failed - \(error.localizedDescription)")
                    continuation.resume(throwing: appError)
                }
            }
        }
    }
    
    // MARK: - File Reading and Validation
    
    private static func readAndValidateFile(
        _ url: URL,
        configuration: ImportConfiguration
    ) async throws -> String {
        // Validate file accessibility
        guard url.startAccessingSecurityScopedResource() else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2004,
                userInfo: [NSLocalizedDescriptionKey: "Cannot access the selected file"]
            ))
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Check file size
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                guard fileSize > 0 else {
                    throw AppError.csvImport(underlying: NSError(
                        domain: "CSVImport",
                        code: 2005,
                        userInfo: [NSLocalizedDescriptionKey: "The selected file is empty"]
                    ))
                }
                
                guard fileSize <= configuration.maxFileSize else {
                    let maxSizeMB = configuration.maxFileSize / (1024 * 1024)
                    throw AppError.csvImport(underlying: NSError(
                        domain: "CSVImport",
                        code: 2006,
                        userInfo: [NSLocalizedDescriptionKey: "File size exceeds maximum limit of \(maxSizeMB)MB"]
                    ))
                }
            }
        } catch {
            if error is AppError {
                throw error
            }
            throw AppError.csvImport(underlying: error)
        }
        
        // Read file content
        do {
            let fileContent = try String(contentsOf: url, encoding: configuration.encoding)
            
            guard !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AppError.csvImport(underlying: NSError(
                    domain: "CSVImport",
                    code: 2007,
                    userInfo: [NSLocalizedDescriptionKey: "The file contains no readable content"]
                ))
            }
            
            return fileContent
        } catch {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2008,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read file content. Please ensure the file is in UTF-8 format."]
            ))
        }
    }
    
    // MARK: - CSV Parsing
    
    private static func parseCSVContent(
        _ content: String,
        configuration: ImportConfiguration
    ) throws -> [[String: String]] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") } // Skip empty lines and comments
        
        guard !lines.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2009,
                userInfo: [NSLocalizedDescriptionKey: "No valid data rows found in the file"]
            ))
        }
        
        guard lines.count <= configuration.maxRowCount else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2010,
                userInfo: [NSLocalizedDescriptionKey: "File contains too many rows (max: \(configuration.maxRowCount))"]
            ))
        }
        
        // Parse header row
        guard let headerLine = lines.first else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2011,
                userInfo: [NSLocalizedDescriptionKey: "No header row found"]
            ))
        }
        
        let headers = parseCSVRow(headerLine, delimiter: configuration.delimiter)
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Validate headers
        try validateHeaders(headers)
        
        // Parse data rows
        var csvData: [[String: String]] = []
        
        for (index, line) in lines.dropFirst().enumerated() {
            let fields = parseCSVRow(line, delimiter: configuration.delimiter)
            
            // Ensure field count matches header count
            let normalizedFields = normalizeFieldCount(fields, to: headers.count)
            
            let rowDict = Dictionary(uniqueKeysWithValues: zip(headers, normalizedFields))
            csvData.append(rowDict)
        }
        
        return csvData
    }
    
    private static func parseCSVRow(_ row: String, delimiter: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = row.startIndex
        
        while i < row.endIndex {
            let char = row[i]
            
            if char == "\"" {
                if insideQuotes && i < row.index(before: row.endIndex) && row[row.index(after: i)] == "\"" {
                    // Escaped quote
                    currentField.append("\"")
                    i = row.index(after: i) // Skip next quote
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                }
            } else if String(char) == delimiter && !insideQuotes {
                // Field separator
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            i = row.index(after: i)
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return fields
    }
    
    private static func normalizeFieldCount(_ fields: [String], to count: Int) -> [String] {
        if fields.count >= count {
            return Array(fields.prefix(count))
        } else {
            return fields + Array(repeating: "", count: count - fields.count)
        }
    }
    
    // MARK: - Header Validation
    
    private static func validateHeaders(_ headers: [String]) throws {
        // Check for duplicate headers
        let uniqueHeaders = Set(headers)
        guard uniqueHeaders.count == headers.count else {
            let duplicates = headers.filter { header in
                headers.filter { $0 == header }.count > 1
            }
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2012,
                userInfo: [NSLocalizedDescriptionKey: "Duplicate headers found: \(Set(duplicates).joined(separator: ", "))"]
            ))
        }
        
        // Check for empty headers
        guard !headers.contains(where: { $0.isEmpty }) else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2013,
                userInfo: [NSLocalizedDescriptionKey: "Empty header columns are not allowed"]
            ))
        }
    }
    
    private static func validateAndDetectType(
        _ csvData: [[String: String]],
        expectedType: ImportType
    ) throws -> ImportType {
        guard let headerRow = csvData.first else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2014,
                userInfo: [NSLocalizedDescriptionKey: "No data found in CSV file"]
            ))
        }
        
        let availableHeaders = Set(headerRow.keys)
        
        // Auto-detect if needed
        if expectedType == .autoDetect {
            let budgetHeaders = Set(ImportType.budgetEntries.expectedHeaders)
            let monthlyHeaders = Set(ImportType.monthlyBudgets.expectedHeaders)
            
            if budgetHeaders.isSubset(of: availableHeaders) {
                return .budgetEntries
            } else if monthlyHeaders.isSubset(of: availableHeaders) {
                return .monthlyBudgets
            } else {
                throw AppError.csvImport(underlying: NSError(
                    domain: "CSVImport",
                    code: 2015,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot determine file type. Available headers: \(Array(availableHeaders).sorted().joined(separator: ", "))"]
                ))
            }
        }
        
        // Validate expected headers are present
        let requiredHeaders = Set(expectedType.expectedHeaders)
        let missingHeaders = requiredHeaders.subtracting(availableHeaders)
        
        guard missingHeaders.isEmpty else {
            let expectedFormat = getExpectedFormatDescription(for: expectedType)
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2016,
                userInfo: [NSLocalizedDescriptionKey: "Missing required headers: \(Array(missingHeaders).sorted().joined(separator: ", ")). Expected format: \(expectedFormat)"]
            ))
        }
        
        return expectedType
    }
    
    private static func getExpectedFormatDescription(for type: ImportType) -> String {
        switch type {
        case .budgetEntries:
            return "Date,Amount,Category,Note"
        case .monthlyBudgets:
            return "Year,Month,Category,Amount,IsHistorical"
        case .autoDetect:
            return "Auto-detect based on headers"
        }
    }
    
    // MARK: - Data Parsing
    
    private static func parsePurchaseData(
        _ csvData: [[String: String]],
        configuration: ImportConfiguration,
        existingCategories: [String]
    ) throws -> ImportResults<PurchaseImportData> {
        var purchases: [PurchaseImportData] = []
        var categories: Set<String> = []
        var totalAmount: Double = 0
        var warningMessages: [String] = []
        var validationErrors: [ValidationError] = []
        var skippedRowCount = 0
        var duplicateCount = 0
        var existingPurchases: Set<String> = []
        
        let dateFormatters = configuration.dateFormats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
        
        // Process data rows (skip header)
        for (index, row) in csvData.dropFirst().enumerated() {
            let rowNumber = index + 2 // Account for header and 0-based index
            
            do {
                let purchase = try parsePurchaseRow(
                    row,
                    rowIndex: rowNumber,
                    dateFormatters: dateFormatters,
                    configuration: configuration
                )
                
                // Check for duplicates if enabled
                if configuration.validateDuplicates {
                    let purchaseKey = "\(purchase.date)_\(purchase.amount)_\(purchase.category)"
                    if existingPurchases.contains(purchaseKey) {
                        duplicateCount += 1
                        if !configuration.skipInvalidRows {
                            throw AppError.csvImport(underlying: NSError(
                                domain: "CSVImport",
                                code: 2017,
                                userInfo: [NSLocalizedDescriptionKey: "Duplicate entry found at row \(rowNumber)"]
                            ))
                        }
                        warningMessages.append("Row \(rowNumber): Duplicate entry skipped")
                        continue
                    }
                    existingPurchases.insert(purchaseKey)
                }
                
                purchases.append(purchase)
                categories.insert(purchase.category)
                totalAmount += purchase.amount
                
            } catch {
                let validationError = ValidationError(
                    rowNumber: rowNumber,
                    field: "general",
                    value: "row data",
                    message: error.localizedDescription
                )
                validationErrors.append(validationError)
                
                if configuration.skipInvalidRows {
                    skippedRowCount += 1
                    warningMessages.append("Row \(rowNumber): \(error.localizedDescription)")
                } else {
                    throw error
                }
            }
        }
        
        guard !purchases.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2018,
                userInfo: [NSLocalizedDescriptionKey: "No valid purchase data found in the file"]
            ))
        }
        
        let existingCategoriesSet = Set(existingCategories)
        let newCategories = categories.subtracting(existingCategoriesSet)
        
        return ImportResults(
            data: purchases,
            categories: categories,
            existingCategories: existingCategoriesSet.intersection(categories),
            newCategories: newCategories,
            totalAmount: totalAmount,
            warningMessages: warningMessages,
            skippedRowCount: skippedRowCount,
            duplicateCount: duplicateCount,
            validationErrors: validationErrors
        )
    }
    
    private static func parseBudgetData(
        _ csvData: [[String: String]],
        configuration: ImportConfiguration,
        existingCategories: [String]
    ) throws -> ImportResults<BudgetImportData> {
        var budgets: [BudgetImportData] = []
        var categories: Set<String> = []
        var totalAmount: Double = 0
        var warningMessages: [String] = []
        var validationErrors: [ValidationError] = []
        var skippedRowCount = 0
        var duplicateCount = 0
        var existingBudgets: Set<String> = []
        
        // Process data rows (skip header)
        for (index, row) in csvData.dropFirst().enumerated() {
            let rowNumber = index + 2 // Account for header and 0-based index
            
            do {
                let budget = try parseBudgetRow(row, rowIndex: rowNumber, configuration: configuration)
                
                // Check for duplicates if enabled
                if configuration.validateDuplicates {
                    let budgetKey = "\(budget.year)_\(budget.month)_\(budget.category)"
                    if existingBudgets.contains(budgetKey) {
                        duplicateCount += 1
                        if !configuration.skipInvalidRows {
                            throw AppError.csvImport(underlying: NSError(
                                domain: "CSVImport",
                                code: 2019,
                                userInfo: [NSLocalizedDescriptionKey: "Duplicate budget found at row \(rowNumber)"]
                            ))
                        }
                        warningMessages.append("Row \(rowNumber): Duplicate budget skipped")
                        continue
                    }
                    existingBudgets.insert(budgetKey)
                }
                
                budgets.append(budget)
                categories.insert(budget.category)
                totalAmount += budget.amount
                
            } catch {
                let validationError = ValidationError(
                    rowNumber: rowNumber,
                    field: "general",
                    value: "row data",
                    message: error.localizedDescription
                )
                validationErrors.append(validationError)
                
                if configuration.skipInvalidRows {
                    skippedRowCount += 1
                    warningMessages.append("Row \(rowNumber): \(error.localizedDescription)")
                } else {
                    throw error
                }
            }
        }
        
        guard !budgets.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2020,
                userInfo: [NSLocalizedDescriptionKey: "No valid budget data found in the file"]
            ))
        }
        
        let existingCategoriesSet = Set(existingCategories)
        let newCategories = categories.subtracting(existingCategoriesSet)
        
        return ImportResults(
            data: budgets,
            categories: categories,
            existingCategories: existingCategoriesSet.intersection(categories),
            newCategories: newCategories,
            totalAmount: totalAmount,
            warningMessages: warningMessages,
            skippedRowCount: skippedRowCount,
            duplicateCount: duplicateCount,
            validationErrors: validationErrors
        )
    }
    
    // MARK: - Row Parsing
    
    private static func parsePurchaseRow(
        _ row: [String: String],
        rowIndex: Int,
        dateFormatters: [DateFormatter],
        configuration: ImportConfiguration
    ) throws -> PurchaseImportData {
        // Parse date
        guard let dateString = row["date"], !dateString.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2021,
                userInfo: [NSLocalizedDescriptionKey: "Date field is empty"]
            ))
        }
        
        // Try different date formats
        var validDate = false
        for formatter in dateFormatters {
            if formatter.date(from: dateString) != nil {
                validDate = true
                break
            }
        }
        
        guard validDate else {
            let supportedFormats = configuration.dateFormats.joined(separator: ", ")
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2022,
                userInfo: [NSLocalizedDescriptionKey: "Invalid date format '\(dateString)'. Supported formats: \(supportedFormats)"]
            ))
        }
        
        // Parse amount
        guard let amountString = row["amount"], !amountString.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2023,
                userInfo: [NSLocalizedDescriptionKey: "Amount field is empty"]
            ))
        }
        
        // Clean amount string (remove currency symbols, commas)
        let cleanAmountString = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let amount = Double(cleanAmountString), amount >= 0 else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2024,
                userInfo: [NSLocalizedDescriptionKey: "Invalid amount '\(amountString)'. Must be a positive number."]
            ))
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2025,
                userInfo: [NSLocalizedDescriptionKey: "Amount '\(amountString)' exceeds maximum allowed value"]
            ))
        }
        
        // Parse category
        guard let category = row["category"], !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2026,
                userInfo: [NSLocalizedDescriptionKey: "Category field is empty"]
            ))
        }
        
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCategory.count <= AppConstants.Validation.maxCategoryNameLength else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2027,
                userInfo: [NSLocalizedDescriptionKey: "Category name '\(cleanCategory)' exceeds maximum length"]
            ))
        }
        
        // Parse optional note
        let note = row["note"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.isEmpty == false ? note : nil
        
        if let noteText = cleanNote, noteText.count > AppConstants.Data.maxTransactionNoteLength {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2028,
                userInfo: [NSLocalizedDescriptionKey: "Note exceeds maximum length of \(AppConstants.Data.maxTransactionNoteLength) characters"]
            ))
        }
        
        return PurchaseImportData(
            date: dateString,
            amount: amount,
            category: cleanCategory,
            note: cleanNote
        )
    }
    
    private static func parseBudgetRow(
        _ row: [String: String],
        rowIndex: Int,
        configuration: ImportConfiguration
    ) throws -> BudgetImportData {
        // Parse year
        guard let yearString = row["year"], !yearString.isEmpty,
              let year = Int(yearString), year >= 1900 && year <= 9999 else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2029,
                userInfo: [NSLocalizedDescriptionKey: "Invalid year '\(row["year"] ?? "")'. Must be between 1900 and 9999."]
            ))
        }
        
        // Parse month
        guard let monthString = row["month"], !monthString.isEmpty,
              let month = Int(monthString), month >= 1 && month <= 12 else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2030,
                userInfo: [NSLocalizedDescriptionKey: "Invalid month '\(row["month"] ?? "")'. Must be between 1 and 12."]
            ))
        }
        
        // Parse category
        guard let category = row["category"], !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2031,
                userInfo: [NSLocalizedDescriptionKey: "Category field is empty"]
            ))
        }
        
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCategory.count <= AppConstants.Validation.maxCategoryNameLength else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2032,
                userInfo: [NSLocalizedDescriptionKey: "Category name '\(cleanCategory)' exceeds maximum length"]
            ))
        }
        
        // Parse amount
        guard let amountString = row["amount"], !amountString.isEmpty else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2033,
                userInfo: [NSLocalizedDescriptionKey: "Amount field is empty"]
            ))
        }
        
        // Clean amount string
        let cleanAmountString = amountString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let amount = Double(cleanAmountString), amount >= 0 else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2034,
                userInfo: [NSLocalizedDescriptionKey: "Invalid amount '\(amountString)'. Must be a positive number."]
            ))
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw AppError.csvImport(underlying: NSError(
                domain: "CSVImport",
                code: 2035,
                userInfo: [NSLocalizedDescriptionKey: "Amount '\(amountString)' exceeds maximum allowed value"]
            ))
        }
        
        // Parse optional isHistorical
        let isHistoricalString = row["ishistorical"]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "false"
        let isHistorical = ["true", "1", "yes", "y"].contains(isHistoricalString)
        
        return BudgetImportData(
            year: year,
            month: month,
            category: cleanCategory,
            amount: amount,
            isHistorical: isHistorical
        )
    }
}

// MARK: - Either Type for Auto-Detection

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
    
    public var leftValue: Left? {
        if case .left(let value) = self { return value }
        return nil
    }
    
    public var rightValue: Right? {
        if case .right(let value) = self { return value }
        return nil
    }
}

// MARK: - Testing Support

#if DEBUG
extension CSVImport {
    /// Create test CSV content for purchases
    static func createTestPurchaseCSV() -> String {
        return """
        Date,Amount,Category,Note
        2024-01-15,45.67,Groceries,Weekly shopping
        2024-01-16,12.50,Transportation,Bus fare
        2024-01-17,89.99,Entertainment,Movie tickets
        """
    }
    
    /// Create test CSV content for budgets
    static func createTestBudgetCSV() -> String {
        return """
        Year,Month,Category,Amount,IsHistorical
        2024,1,Groceries,500.00,false
        2024,1,Transportation,200.00,false
        2024,1,Entertainment,150.00,false
        """
    }
    
    /// Create test configuration
    static func createTestConfiguration(
        importType: ImportType = .autoDetect,
        strictValidation: Bool = false
    ) -> ImportConfiguration {
        return ImportConfiguration(
            importType: importType,
            validateDuplicates: true,
            skipInvalidRows: !strictValidation,
            maxFileSize: 1024 * 1024, // 1MB for testing
            maxRowCount: 1000,
            strictValidation: strictValidation
        )
    }
    
    /// Parse CSV content for testing without file I/O
    static func parseTestCSV<T>(
        content: String,
        importType: ImportType,
        parseFunction: ([[String: String]], ImportConfiguration, [String]) throws -> ImportResults<T>
    ) throws -> ImportResults<T> {
        let configuration = createTestConfiguration(importType: importType)
        let csvData = try parseCSVContent(content, configuration: configuration)
        return try parseFunction(csvData, configuration, [])
    }
}
#endif
