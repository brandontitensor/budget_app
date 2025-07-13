//
//  CSVExport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import Foundation

/// Service responsible for exporting budget data to CSV format with proper error handling and validation
public enum CSVExport {
    // MARK: - Export Types
    public enum ExportType {
        case budgetEntries
        case monthlyBudgets
        case combined
        
        var fileName: String {
            switch self {
            case .budgetEntries: return "budget_entries"
            case .monthlyBudgets: return "monthly_budgets"
            case .combined: return "budget_export"
            }
        }
    }
    
    // MARK: - Export Configuration
    public struct ExportConfiguration {
        let timePeriod: TimePeriod
        let exportType: ExportType
        let includeCurrency: Bool
        let dateFormat: String
        let decimalPlaces: Int
        let includeHeaders: Bool
        let encoding: String.Encoding
        
        public init(
            timePeriod: TimePeriod = .allTime,
            exportType: ExportType = .budgetEntries,
            includeCurrency: Bool = true,
            dateFormat: String = "yyyy-MM-dd",
            decimalPlaces: Int = 2,
            includeHeaders: Bool = true,
            encoding: String.Encoding = .utf8
        ) {
            self.timePeriod = timePeriod
            self.exportType = exportType
            self.includeCurrency = includeCurrency
            self.dateFormat = dateFormat
            self.decimalPlaces = decimalPlaces
            self.includeHeaders = includeHeaders
            self.encoding = encoding
        }
        
        static let `default` = ExportConfiguration()
    }
    
    // MARK: - Export Result
    public struct ExportResult {
        public let fileURL: URL
        public let recordCount: Int
        public let fileSize: Int64
        public let exportDate: Date
        public let configuration: ExportConfiguration
        
        public var fileSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
        
        public var summary: String {
            "Exported \(recordCount) records (\(fileSizeFormatted))"
        }
    }
    
    // MARK: - Private Properties
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        formatter.decimalSeparator = "."
        return formatter
    }()
    
    private static let queue = DispatchQueue(
        label: "com.brandonsbudget.csvexport",
        qos: .userInitiated
    )
    
    // MARK: - Public Export Methods
    
    /// Export budget entries to CSV with enhanced configuration
    /// - Parameters:
    ///   - entries: The budget entries to export
    ///   - configuration: Export configuration options
    /// - Returns: Export result with file URL and metadata
    public static func exportBudgetEntries(
        _ entries: [BudgetEntry],
        configuration: ExportConfiguration = .default
    ) async throws -> ExportResult {
        return try await performExport(
            data: entries,
            configuration: configuration,
            exportFunction: createBudgetEntriesCSV
        )
    }
    
    /// Export monthly budgets to CSV
    /// - Parameters:
    ///   - budgets: The monthly budgets to export
    ///   - configuration: Export configuration options
    /// - Returns: Export result with file URL and metadata
    public static func exportMonthlyBudgets(
        _ budgets: [MonthlyBudget],
        configuration: ExportConfiguration = .default
    ) async throws -> ExportResult {
        return try await performExport(
            data: budgets,
            configuration: configuration,
            exportFunction: createMonthlyBudgetsCSV
        )
    }
    
    /// Export combined budget and entry data
    /// - Parameters:
    ///   - entries: Budget entries to export
    ///   - budgets: Monthly budgets to export
    ///   - configuration: Export configuration options
    /// - Returns: Export result with file URL and metadata
    public static func exportCombinedData(
        entries: [BudgetEntry],
        budgets: [MonthlyBudget],
        configuration: ExportConfiguration = .default
    ) async throws -> ExportResult {
        let combinedData = CombinedExportData(entries: entries, budgets: budgets)
        return try await performExport(
            data: combinedData,
            configuration: configuration,
            exportFunction: createCombinedCSV
        )
    }
    
    /// Legacy method for backwards compatibility
    public static func exportToCSV(
        entries: [BudgetEntry],
        timePeriod: TimePeriod
    ) async throws -> URL {
        let config = ExportConfiguration(timePeriod: timePeriod, exportType: .budgetEntries)
        let result = try await exportBudgetEntries(entries, configuration: config)
        return result.fileURL
    }
    
    // MARK: - Core Export Logic
    
    private static func performExport<T>(
        data: T,
        configuration: ExportConfiguration,
        exportFunction: (T, ExportConfiguration) throws -> String
    ) async throws -> ExportResult {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let startTime = Date()
                    
                    // Validate export preconditions
                    try validateExportPreconditions()
                    
                    // Generate CSV content
                    let csvContent = try exportFunction(data, configuration)
                    
                    // Validate content
                    try validateCSVContent(csvContent)
                    
                    // Create export file
                    let fileURL = try createExportFile(
                        content: csvContent,
                        configuration: configuration
                    )
                    
                    // Get file metadata
                    let recordCount = getRecordCount(from: csvContent, configuration: configuration)
                    let fileSize = getFileSize(at: fileURL)
                    
                    let result = ExportResult(
                        fileURL: fileURL,
                        recordCount: recordCount,
                        fileSize: fileSize,
                        exportDate: startTime,
                        configuration: configuration
                    )
                    
                    // Log success
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ CSV Export: Completed in \(String(format: "%.2f", duration * 1000))ms - \(result.summary)")
                    
                    continuation.resume(returning: result)
                } catch {
                    let appError = AppError.csvExport(underlying: error)
                    print("❌ CSV Export: Failed - \(error.localizedDescription)")
                    continuation.resume(throwing: appError)
                }
            }
        }
    }
    
    // MARK: - CSV Generation Methods
    
    private static func createBudgetEntriesCSV(
        _ entries: [BudgetEntry],
        configuration: ExportConfiguration
    ) throws -> String {
        let filteredEntries = filterEntriesByTimePeriod(entries, timePeriod: configuration.timePeriod)
        
        guard !filteredEntries.isEmpty else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "No entries found for the specified time period"]
            ))
        }
        
        var csvLines: [String] = []
        
        // Add headers if requested
        if configuration.includeHeaders {
            let headers = ["Date", "Amount", "Category", "Note"]
            csvLines.append(headers.joined(separator: ","))
        }
        
        // Configure formatters
        dateFormatter.dateFormat = configuration.dateFormat
        numberFormatter.minimumFractionDigits = configuration.decimalPlaces
        numberFormatter.maximumFractionDigits = configuration.decimalPlaces
        
        // Add data rows
        for entry in filteredEntries.sorted(by: { $0.date > $1.date }) {
            let dateString = dateFormatter.string(from: entry.date)
            let amountString = formatAmount(entry.amount, configuration: configuration)
            let categoryString = entry.category.escapingCSVCharacters()
            let noteString = (entry.note ?? "").escapingCSVCharacters()
            
            let row = [dateString, amountString, categoryString, noteString]
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private static func createMonthlyBudgetsCSV(
        _ budgets: [MonthlyBudget],
        configuration: ExportConfiguration
    ) throws -> String {
        guard !budgets.isEmpty else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "No monthly budgets found"]
            ))
        }
        
        var csvLines: [String] = []
        
        // Add headers if requested
        if configuration.includeHeaders {
            let headers = ["Year", "Month", "Category", "Amount", "IsHistorical"]
            csvLines.append(headers.joined(separator: ","))
        }
        
        // Configure formatters
        numberFormatter.minimumFractionDigits = configuration.decimalPlaces
        numberFormatter.maximumFractionDigits = configuration.decimalPlaces
        
        // Add data rows
        for budget in budgets.sorted(by: {
            if $0.year != $1.year { return $0.year > $1.year }
            if $0.month != $1.month { return $0.month > $1.month }
            return $0.category < $1.category
        }) {
            let yearString = String(budget.year)
            let monthString = String(budget.month)
            let categoryString = budget.category.escapingCSVCharacters()
            let amountString = formatAmount(budget.amount, configuration: configuration)
            let isHistoricalString = budget.isHistorical ? "true" : "false"
            
            let row = [yearString, monthString, categoryString, amountString, isHistoricalString]
            csvLines.append(row.joined(separator: ","))
        }
        
        return csvLines.joined(separator: "\n")
    }
    
    private static func createCombinedCSV(
        _ data: CombinedExportData,
        configuration: ExportConfiguration
    ) throws -> String {
        var csvContent = ""
        
        // Export budget entries section
        if !data.entries.isEmpty {
            csvContent += "# Budget Entries\n"
            let entriesCSV = try createBudgetEntriesCSV(data.entries, configuration: configuration)
            csvContent += entriesCSV + "\n\n"
        }
        
        // Export monthly budgets section
        if !data.budgets.isEmpty {
            csvContent += "# Monthly Budgets\n"
            let budgetsCSV = try createMonthlyBudgetsCSV(data.budgets, configuration: configuration)
            csvContent += budgetsCSV + "\n"
        }
        
        guard !csvContent.isEmpty else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "No data available for export"]
            ))
        }
        
        return csvContent
    }
    
    // MARK: - Helper Methods
    
    private static func filterEntriesByTimePeriod(
        _ entries: [BudgetEntry],
        timePeriod: TimePeriod
    ) -> [BudgetEntry] {
        let dateInterval = timePeriod.dateInterval()
        return entries.filter { entry in
            entry.date >= dateInterval.start && entry.date <= dateInterval.end
        }
    }
    
    private static func formatAmount(_ amount: Double, configuration: ExportConfiguration) -> String {
        let formattedNumber = numberFormatter.string(from: NSNumber(value: amount)) ?? "0"
        return configuration.includeCurrency ? "$\(formattedNumber)" : formattedNumber
    }
    
    private static func validateExportPreconditions() throws {
        // Check available disk space
        guard hasSufficientDiskSpace() else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Insufficient disk space for export"]
            ))
        }
        
        // Check file system access
        guard hasFileSystemAccess() else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "Cannot access file system for export"]
            ))
        }
    }
    
    private static func validateCSVContent(_ content: String) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1006,
                userInfo: [NSLocalizedDescriptionKey: "Generated CSV content is empty"]
            ))
        }
        
        // Validate content size
        let contentSize = content.data(using: .utf8)?.count ?? 0
        guard contentSize <= AppConstants.Data.maxImportFileSize else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1007,
                userInfo: [NSLocalizedDescriptionKey: "Generated CSV file is too large"]
            ))
        }
    }
    
    private static func createExportFile(
        content: String,
        configuration: ExportConfiguration
    ) throws -> URL {
        let fileManager = FileManager.default
        
        // Get documents directory
        guard let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw AppError.csvExport(underlying: NSError(
                domain: "CSVExport",
                code: 1008,
                userInfo: [NSLocalizedDescriptionKey: "Cannot access documents directory"]
            ))
        }
        
        // Create export directory if needed
        let exportDirectory = documentsDirectory.appendingPathComponent("Exports")
        try? fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        
        // Generate unique file name
        let fileName = generateFileName(for: configuration)
        let fileURL = exportDirectory.appendingPathComponent(fileName)
        
        // Remove existing file if needed
        try? fileManager.removeItem(at: fileURL)
        
        // Write content to file
        do {
            try content.write(
                to: fileURL,
                atomically: true,
                encoding: configuration.encoding
            )
        } catch {
            throw AppError.csvExport(underlying: error)
        }
        
        return fileURL
    }
    
    private static func generateFileName(for configuration: ExportConfiguration) -> String {
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let baseFileName = configuration.exportType.fileName
        let timePeriodSuffix = configuration.timePeriod.shortDisplayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        
        return "\(baseFileName)_\(timePeriodSuffix)_\(timestamp).csv"
    }
    
    private static func getRecordCount(from csvContent: String, configuration: ExportConfiguration) -> Int {
        let lines = csvContent.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.hasPrefix("#") } // Exclude comment lines
        
        return configuration.includeHeaders ? max(0, lines.count - 1) : lines.count
    }
    
    private static func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private static func hasSufficientDiskSpace() -> Bool {
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return false
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(
                forPath: documentsPath.path
            )
            guard let freeSpace = attributes[.systemFreeSize] as? NSNumber else {
                return false
            }
            
            // Require at least 10MB free space
            let requiredSpace: Int64 = 10 * 1024 * 1024
            return freeSpace.int64Value > requiredSpace
        } catch {
            return false
        }
    }
    
    private static func hasFileSystemAccess() -> Bool {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return false
        }
        
        return FileManager.default.isWritableFile(atPath: documentsDirectory.path)
    }
    
    /// Clean up old export files
    public static func cleanupOldExports() {
        queue.async {
            guard let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else { return }
            
            let exportDirectory = documentsDirectory.appendingPathComponent("Exports")
            
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: exportDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                var cleanedCount = 0
                
                for file in files {
                    if file.pathExtension.lowercased() == "csv" {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                            if let creationDate = attributes[.creationDate] as? Date,
                               creationDate < thirtyDaysAgo {
                                try FileManager.default.removeItem(at: file)
                                cleanedCount += 1
                            }
                        } catch {
                            // Ignore individual file cleanup errors
                            print("⚠️ CSV Export: Failed to clean up file \(file.lastPathComponent): \(error)")
                        }
                    }
                }
                
                if cleanedCount > 0 {
                    print("🧹 CSV Export: Cleaned up \(cleanedCount) old export files")
                }
            } catch {
                print("⚠️ CSV Export: Failed to clean up exports directory: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

private struct CombinedExportData {
    let entries: [BudgetEntry]
    let budgets: [MonthlyBudget]
}

// MARK: - String CSV Extensions

private extension String {
    /// Escape special characters for CSV
    func escapingCSVCharacters() -> String {
        let needsQuoting = contains(",") || contains("\"") || contains("\n") || contains("\r")
        if needsQuoting {
            let escaped = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return self
    }
}

// MARK: - DateFormatter Extensions

private extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Testing Support

#if DEBUG
extension CSVExport {
    /// Export data for testing without writing to disk
    /// - Parameters:
    ///   - entries: The entries to export
    ///   - configuration: Export configuration
    /// - Returns: The generated CSV string
    static func exportForTesting(
        entries: [BudgetEntry],
        configuration: ExportConfiguration = .default
    ) throws -> String {
        return try createBudgetEntriesCSV(entries, configuration: configuration)
    }
    
    /// Export monthly budgets for testing
    static func exportBudgetsForTesting(
        budgets: [MonthlyBudget],
        configuration: ExportConfiguration = .default
    ) throws -> String {
        return try createMonthlyBudgetsCSV(budgets, configuration: configuration)
    }
    
    /// Create test export configuration
    static func createTestConfiguration(
        timePeriod: TimePeriod = .thisMonth,
        exportType: ExportType = .budgetEntries
    ) -> ExportConfiguration {
        return ExportConfiguration(
            timePeriod: timePeriod,
            exportType: exportType,
            includeCurrency: true,
            dateFormat: "yyyy-MM-dd",
            decimalPlaces: 2,
            includeHeaders: true
        )
    }
}
#endif
