//
//  CSVExport.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import Foundation

/// Service responsible for exporting budget data to CSV format with proper error handling and validation
public enum CSVExport {
    // MARK: - Error Types
    public enum ExportError: LocalizedError {
        case fileCreationFailed(String)
        case dataWriteFailed(String)
        case invalidData(String)
        case invalidPath
        case insufficientDiskSpace
        
        public var errorDescription: String? {
            switch self {
            case .fileCreationFailed(let reason):
                return "Failed to create export file: \(reason)"
            case .dataWriteFailed(let reason):
                return "Failed to write data: \(reason)"
            case .invalidData(let reason):
                return "Invalid data format: \(reason)"
            case .invalidPath:
                return "Invalid export path"
            case .insufficientDiskSpace:
                return "Insufficient disk space for export"
            }
        }
    }
    
    // MARK: - Private Properties
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Data.csvExportDateFormat
        return formatter
    }()
    
    private static let queue = DispatchQueue(
        label: "com.brandonsbudget.csvexport",
        qos: .userInitiated
    )
    
    // MARK: - Public Methods
    
    /// Export budget entries to a CSV file
    /// - Parameters:
    ///   - entries: The budget entries to export
    ///   - timePeriod: The time period to filter entries by
    /// - Returns: Result containing either the exported file URL or an error
    public static func exportToCSV(
        entries: [BudgetEntry],
        timePeriod: TimePeriod
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let filteredEntries = filterEntries(entries, timePeriod: timePeriod)
                    let csvString = try createCSVString(from: filteredEntries)
                    let fileURL = try createExportFile(
                        withContent: csvString,
                        timePeriod: timePeriod
                    )
                    continuation.resume(returning: fileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Filter entries based on time period
    private static func filterEntries(
        _ entries: [BudgetEntry],
        timePeriod: TimePeriod
    ) -> [BudgetEntry] {
        let dateInterval = timePeriod.dateInterval()
        return entries.filter {
            $0.date >= dateInterval.start && $0.date <= dateInterval.end
        }
    }
    
    /// Create CSV string from entries
    private static func createCSVString(from entries: [BudgetEntry]) throws -> String {
        guard !entries.isEmpty else {
            throw ExportError.invalidData("No entries to export")
        }
        
        let headerRow = "Date,Amount,Category,Note\n"
        let rows = entries.map { entry in
            let date = dateFormatter.string(from: entry.date)
            let amount = String(format: "%.2f", entry.amount)
            let category = entry.category.escapingCSVCharacters()
            let note = (entry.note ?? "").escapingCSVCharacters()
            return "\(date),\(amount),\(category),\(note)"
        }
        
        return headerRow + rows.joined(separator: "\n")
    }
    
    /// Create export file with content
    private static func createExportFile(
        withContent content: String,
        timePeriod: TimePeriod
    ) throws -> URL {
        let fileManager = FileManager.default
        
        // Check available disk space
        if !hasSufficientDiskSpace(forContent: content) {
            throw ExportError.insufficientDiskSpace
        }
        
        // Get documents directory
        guard let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw ExportError.invalidPath
        }
        
        // Create export directory if needed
        let exportDirectory = documentsDirectory.appendingPathComponent("Exports")
        try? fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        
        // Create file URL
        let fileName = generateFileName(for: timePeriod)
        let fileURL = exportDirectory.appendingPathComponent(fileName)
        
        // Remove existing file if needed
        try? fileManager.removeItem(at: fileURL)
        
        // Write content
        try content.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        
        return fileURL
    }
    
    /// Generate file name for export
    private static func generateFileName(for timePeriod: TimePeriod) -> String {
        let currentDate = dateFormatter.string(from: Date())
        
        let prefix = "budget_export"
        let timeRange = timePeriod.displayName.lowercased().replacingOccurrences(of: " ", with: "_")
        
        return "\(prefix)_\(timeRange)_\(currentDate).csv"
    }
    
    /// Check if there's sufficient disk space
    private static func hasSufficientDiskSpace(forContent content: String) -> Bool {
        guard let contentSize = content.data(using: .utf8)?.count else {
            return false
        }
        
        let fileManager = FileManager.default
        guard let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: path.path)
            guard let freeSpace = attributes[.systemFreeSize] as? NSNumber else {
                return false
            }
            
            // Require at least double the content size plus 1MB buffer
            let requiredSpace = (contentSize * 2) + (1024 * 1024)
            return freeSpace.int64Value > requiredSpace
        } catch {
            return false
        }
    }
    
    /// Clean up old export files
    public static func cleanupOldExports() {
        queue.async {
            guard let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else { return }
            
            let exportDirectory = documentsDirectory.appendingPathComponent("Exports")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: exportDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { return }
            
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            
            for file in files {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                      let creationDate = attributes[.creationDate] as? Date,
                      creationDate < thirtyDaysAgo else {
                    continue
                }
                
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - String Extension
private extension String {
    /// Escape special characters for CSV
    func escapingCSVCharacters() -> String {
        let needsQuoting = contains(",") || contains("\"") || contains("\n")
        if needsQuoting {
            let escaped = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return self
    }
}

// MARK: - Testing Support
#if DEBUG
extension CSVExport {
    /// Export data for testing without writing to disk
    /// - Parameters:
    ///   - entries: The entries to export
    ///   - timePeriod: The time period to filter by
    /// - Returns: The generated CSV string
    static func exportForTesting(
        entries: [BudgetEntry],
        timePeriod: TimePeriod
    ) throws -> String {
        let filteredEntries = filterEntries(entries, timePeriod: timePeriod)
        return try createCSVString(from: filteredEntries)
    }
}
#endif
