//
//  CSVImport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/29/25.
//


//
//  CSVImport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on [Date]
//

import Foundation

/// Service responsible for importing budget data from CSV format with proper validation and error handling
public enum CSVImport {
    // MARK: - Error Types
    public enum ImportError: LocalizedError {
        case fileReadFailed(String)
        case invalidFormat(String)
        case parsingFailed(String)
        case invalidDateFormat(String)
        case invalidAmount(String)
        case missingRequiredFields([String])
        case duplicateHeaders
        case emptyFile
        case fileTooLarge
        
        public var errorDescription: String? {
            switch self {
            case .fileReadFailed(let reason):
                return "Failed to read file: \(reason)"
            case .invalidFormat(let reason):
                return "Invalid CSV format: \(reason)"
            case .parsingFailed(let reason):
                return "Failed to parse CSV: \(reason)"
            case .invalidDateFormat(let format):
                return "Invalid date format: \(format)"
            case .invalidAmount(let amount):
                return "Invalid amount: \(amount)"
            case .missingRequiredFields(let fields):
                return "Missing required fields: \(fields.joined(separator: ", "))"
            case .duplicateHeaders:
                return "Duplicate column headers found"
            case .emptyFile:
                return "File is empty or contains no data"
            case .fileTooLarge:
                return "File size exceeds maximum allowed limit"
            }
        }
    }
    
    // MARK: - Data Structures
    public struct PurchaseImportData {
        let date: String
        let amount: Double
        let category: String
        let note: String?
        
        public init(date: String, amount: Double, category: String, note: String?) {
            self.date = date
            self.amount = amount
            self.category = category
            self.note = note
        }
    }
    
    public struct BudgetImportData {
        let year: Int
        let month: Int
        let category: String
        let amount: Double
        let isHistorical: Bool
        
        public init(year: Int, month: Int, category: String, amount: Double, isHistorical: Bool) {
            self.year = year
            self.month = month
            self.category = category
            self.amount = amount
            self.isHistorical = isHistorical
        }
    }
    
    public struct ImportResults<T> {
        let data: [T]
        let categories: Set<String>
        let existingCategories: Set<String>
        let newCategories: Set<String>
        let totalAmount: Double
        let warningMessages: [String]
        
        public init(data: [T], categories: Set<String>, existingCategories: Set<String>, newCategories: Set<String>, totalAmount: Double, warningMessages: [String] = []) {
            self.data = data
            self.categories = categories
            self.existingCategories = existingCategories
            self.newCategories = newCategories
            self.totalAmount = totalAmount
            self.warningMessages = warningMessages
        }
    }
    
    // MARK: - Constants
    private static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    private static let maxRowCount = 10000
    
    // MARK: - Purchase Import
    public static func importPurchases(
        from url: URL,
        existingCategories: [String]
    ) async throws -> ImportResults<PurchaseImportData> {
        let fileContent = try await readAndValidateFile(url)
        let csvData = try parseCSV(fileContent)
        
        guard !csvData.isEmpty else {
            throw ImportError.emptyFile
        }
        
        // Validate headers for purchase data
        let expectedHeaders = ["date", "amount", "category"]
        let optionalHeaders = ["note"]
        try validateHeaders(csvData[0], required: expectedHeaders, optional: optionalHeaders)
        
        var purchases: [PurchaseImportData] = []
        var categories: Set<String> = []
        var totalAmount: Double = 0
        var warningMessages: [String] = []
        
        // Process data rows (skip header row)
        for (index, row) in csvData.dropFirst().enumerated() {
            do {
                let purchase = try parsePurchaseRow(row, rowIndex: index + 2)
                purchases.append(purchase)
                categories.insert(purchase.category)
                totalAmount += purchase.amount
            } catch {
                warningMessages.append("Row \(index + 2): \(error.localizedDescription)")
            }
        }
        
        if purchases.isEmpty {
            throw ImportError.parsingFailed("No valid purchase data found")
        }
        
        let existingCategoriesSet = Set(existingCategories)
        let newCategories = categories.subtracting(existingCategoriesSet)
        
        return ImportResults(
            data: purchases,
            categories: categories,
            existingCategories: existingCategoriesSet.intersection(categories),
            newCategories: newCategories,
            totalAmount: totalAmount,
            warningMessages: warningMessages
        )
    }
    
    // MARK: - Budget Import
    public static func importBudgets(
        from url: URL,
        existingCategories: [String]
    ) async throws -> ImportResults<BudgetImportData> {
        let fileContent = try await readAndValidateFile(url)
        let csvData = try parseCSV(fileContent)
        
        guard !csvData.isEmpty else {
            throw ImportError.emptyFile
        }
        
        // Validate headers for budget data
        let expectedHeaders = ["year", "month", "category", "amount"]
        let optionalHeaders = ["ishistorical"]
        try validateHeaders(csvData[0], required: expectedHeaders, optional: optionalHeaders)
        
        var budgets: [BudgetImportData] = []
        var categories: Set<String> = []
        var totalAmount: Double = 0
        var warningMessages: [String] = []
        
        // Process data rows (skip header row)
        for (index, row) in csvData.dropFirst().enumerated() {
            do {
                let budget = try parseBudgetRow(row, rowIndex: index + 2)
                budgets.append(budget)
                categories.insert(budget.category)
                totalAmount += budget.amount
            } catch {
                warningMessages.append("Row \(index + 2): \(error.localizedDescription)")
            }
        }
        
        if budgets.isEmpty {
            throw ImportError.parsingFailed("No valid budget data found")
        }
        
        let existingCategoriesSet = Set(existingCategories)
        let newCategories = categories.subtracting(existingCategoriesSet)
        
        return ImportResults(
            data: budgets,
            categories: categories,
            existingCategories: existingCategoriesSet.intersection(categories),
            newCategories: newCategories,
            totalAmount: totalAmount,
            warningMessages: warningMessages
        )
    }
    
    // MARK: - Private Helper Methods
    private static func readAndValidateFile(_ url: URL) async throws -> String {
        // Check file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = fileAttributes[.size] as? Int64, fileSize > maxFileSize {
            throw ImportError.fileTooLarge
        }
        
        // Read file content
        guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileReadFailed("Unable to read file as UTF-8 text")
        }
        
        guard !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyFile
        }
        
        return fileContent
    }
    
    private static func parseCSV(_ content: String) throws -> [[String: String]] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw ImportError.emptyFile
        }
        
        guard lines.count <= maxRowCount else {
            throw ImportError.parsingFailed("File contains too many rows (max: \(maxRowCount))")
        }
        
        // Parse header row
        let headerRow = lines[0]
        let headers = parseCSVRow(headerRow).map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Check for duplicate headers
        let uniqueHeaders = Set(headers)
        if uniqueHeaders.count != headers.count {
            throw ImportError.duplicateHeaders
        }
        
        var csvData: [[String: String]] = []
        csvData.append(Dictionary(uniqueKeysWithValues: zip(headers, headers))) // Header row for validation
        
        // Parse data rows
        for (index, line) in lines.dropFirst().enumerated() {
            let fields = parseCSVRow(line)
            
            // Ensure field count matches header count
            let normalizedFields = Array(fields.prefix(headers.count)) + Array(repeating: "", count: max(0, headers.count - fields.count))
            
            let rowDict = Dictionary(uniqueKeysWithValues: zip(headers, normalizedFields))
            csvData.append(rowDict)
        }
        
        return csvData
    }
    
    private static func parseCSVRow(_ row: String) -> [String] {
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
            } else if char == "," && !insideQuotes {
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
    
    private static func validateHeaders(_ headerRow: [String: String], required: [String], optional: [String] = []) throws {
        let availableHeaders = Set(headerRow.keys)
        let requiredHeaders = Set(required)
        let missingHeaders = requiredHeaders.subtracting(availableHeaders)
        
        if !missingHeaders.isEmpty {
            throw ImportError.missingRequiredFields(Array(missingHeaders))
        }
    }
    
    private static func parsePurchaseRow(_ row: [String: String], rowIndex: Int) throws -> PurchaseImportData {
        // Parse date
        guard let dateString = row["date"], !dateString.isEmpty else {
            throw ImportError.invalidDateFormat("Date field is empty")
        }
        
        // Validate date format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard dateFormatter.date(from: dateString) != nil else {
            throw ImportError.invalidDateFormat("Expected format: yyyy-MM-dd, got: \(dateString)")
        }
        
        // Parse amount
        guard let amountString = row["amount"], !amountString.isEmpty,
              let amount = Double(amountString), amount >= 0 else {
            throw ImportError.invalidAmount(row["amount"] ?? "empty")
        }
        
        // Parse category
        guard let category = row["category"], !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.parsingFailed("Category field is empty")
        }
        
        // Parse optional note
        let note = row["note"]?.isEmpty == false ? row["note"] : nil
        
        return PurchaseImportData(
            date: dateString,
            amount: amount,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note
        )
    }
    
    private static func parseBudgetRow(_ row: [String: String], rowIndex: Int) throws -> BudgetImportData {
        // Parse year
        guard let yearString = row["year"], !yearString.isEmpty,
              let year = Int(yearString), year >= 1900 && year <= 9999 else {
            throw ImportError.parsingFailed("Invalid year: \(row["year"] ?? "empty")")
        }
        
        // Parse month
        guard let monthString = row["month"], !monthString.isEmpty,
              let month = Int(monthString), month >= 1 && month <= 12 else {
            throw ImportError.parsingFailed("Invalid month: \(row["month"] ?? "empty")")
        }
        
        // Parse category
        guard let category = row["category"], !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.parsingFailed("Category field is empty")
        }
        
        // Parse amount
        guard let amountString = row["amount"], !amountString.isEmpty,
              let amount = Double(amountString), amount >= 0 else {
            throw ImportError.invalidAmount(row["amount"] ?? "empty")
        }
        
        // Parse optional isHistorical
        let isHistorical = row["ishistorical"]?.lowercased() == "true"
        
        return BudgetImportData(
            year: year,
            month: month,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            isHistorical: isHistorical
        )
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
}
#endif
