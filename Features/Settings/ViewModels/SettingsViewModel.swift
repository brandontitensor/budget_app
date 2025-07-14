//
//  SettingsViewModel.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/3/25.
//


import Foundation
import Combine
import UserNotifications
import SwiftUI

/// View model for managing settings screen state and operations with comprehensive error handling
@MainActor
public final class SettingsViewModel: ObservableObject {
    // MARK: - Types
    public enum OperationState {
        case idle
        case loading
        case success(String)
        case error(AppError)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
        
        var isError: Bool {
            if case .error = self { return true }
            return false
        }
        
        var message: String? {
            switch self {
            case .success(let message): return message
            case .error(let error): return error.errorDescription
            default: return nil
            }
        }
    }
    
    public enum ExportOperation {
        case none
        case preparing
        case exporting
        case complete(URL)
        case failed(AppError)
        
        var isActive: Bool {
            switch self {
            case .preparing, .exporting: return true
            default: return false
            }
        }
        
        var progress: Double {
            switch self {
            case .preparing: return 0.3
            case .exporting: return 0.7
            case .complete: return 1.0
            default: return 0.0
            }
        }
    }
    
    public enum ImportOperation {
        case none
        case validating
        case processing
        case mappingCategories([String])
        case importing
        case complete(ImportResult)
        case failed(AppError)
        
        var isActive: Bool {
            switch self {
            case .validating, .processing, .mappingCategories, .importing: return true
            default: return false
            }
        }
        
        var progress: Double {
            switch self {
            case .validating: return 0.2
            case .processing: return 0.4
            case .mappingCategories: return 0.6
            case .importing: return 0.8
            case .complete: return 1.0
            default: return 0.0
            }
        }
    }
    
    public struct ImportResult {
        public let entriesImported: Int
        public let budgetsImported: Int
        public let categoriesCreated: Int
        public let totalAmount: Double
        public let warnings: [String]
        
        public var summary: String {
            var parts: [String] = []
            
            if entriesImported > 0 {
                parts.append("\(entriesImported) transactions")
            }
            
            if budgetsImported > 0 {
                parts.append("\(budgetsImported) budgets")
            }
            
            if categoriesCreated > 0 {
                parts.append("\(categoriesCreated) new categories")
            }
            
            let summary = parts.isEmpty ? "No data imported" : parts.joined(separator: ", ")
            return "Imported: \(summary)"
        }
    }
    
    public struct ValidationIssue: Identifiable {
        public let id = UUID()
        public let field: String
        public let message: String
        public let severity: ErrorSeverity
        public let suggestion: String?
        
        public init(field: String, message: String, severity: ErrorSeverity = .warning, suggestion: String? = nil) {
            self.field = field
            self.message = message
            self.severity = severity
            self.suggestion = suggestion
        }
    }
    
    // MARK: - Dependencies
    private let settingsManager: SettingsManager
    private let budgetManager: BudgetManager
    private let themeManager: ThemeManager
    private let errorHandler: ErrorHandler
    private let notificationManager: NotificationManager
    
    // MARK: - Published Properties
    @Published public var operationState: OperationState = .idle
    @Published public var exportOperation: ExportOperation = .none
    @Published public var importOperation: ImportOperation = .none
    @Published public var validationIssues: [ValidationIssue] = []
    @Published public var showingExportOptions = false
    @Published public var showingImportOptions = false
    @Published public var showingCategoryMapping = false
    @Published public var showingResetConfirmation = false
    @Published public var showingBackupOptions = false
    @Published public var showingNotificationSettings = false
    @Published public var isValidatingSettings = false
    
    // MARK: - Export/Import State
    @Published public var selectedExportTimePeriod: TimePeriod = .thisMonth
    @Published public var exportedFileURL: URL?
    @Published public var pendingImportData: [CSVImport.PurchaseImportData] = []
    @Published public var unmappedCategories: Set<String> = []
    @Published public var importProgress: Double = 0.0
    @Published public var importStatusMessage: String = ""
    
    // MARK: - Settings State
    @Published public var tempUserName: String = ""
    @Published public var tempCurrency: String = ""
    @Published public var isEditingUserName = false
    @Published public var isEditingCurrency = false
    @Published public var pendingNotificationChanges = false
    
    // MARK: - Data Statistics
    @Published public var dataStatistics: BudgetManager.DataStatistics?
    @Published public var notificationStatistics: NotificationStatistics?
    @Published public var systemHealth: SystemHealth = SystemHealth()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = DispatchQueue(label: "com.brandonsbudget.settings.operations", qos: .userInitiated)
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.settings.metrics", qos: .utility)
    
    // MARK: - Initialization
    public init(
        settingsManager: SettingsManager = .shared,
        budgetManager: BudgetManager = .shared,
        themeManager: ThemeManager = .shared,
        errorHandler: ErrorHandler = .shared,
        notificationManager: NotificationManager = .shared
    ) {
        self.settingsManager = settingsManager
        self.budgetManager = budgetManager
        self.themeManager = themeManager
        self.errorHandler = errorHandler
        self.notificationManager = notificationManager
        
        setupInitialState()
        setupObservers()
        setupPerformanceMonitoring()
        
        // Load initial data
       Task<Void, Never>{
            await loadInitialData()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialState() {
        tempUserName = settingsManager.userName
        tempCurrency = settingsManager.defaultCurrency
    }
    
    private func setupObservers() {
        // Observe settings changes
        settingsManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.validateCurrentSettings()
            }
            .store(in: &cancellables)
        
        // Observe budget manager changes
        budgetManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
               Task<Void, Never>{ [weak self] in
                    await self?.updateDataStatistics()
                }
            }
            .store(in: &cancellables)
        
        // Observe notification changes
        notificationManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
               Task<Void, Never>{ [weak self] in
                    await self?.updateNotificationStatistics()
                }
            }
            .store(in: &cancellables)
        
        // Observe error handler changes
        errorHandler.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateSystemHealth()
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    private func loadInitialData() async {
        await updateDataStatistics()
        await updateNotificationStatistics()
        updateSystemHealth()
        validateCurrentSettings()
    }
    
    // MARK: - User Settings Methods
    
    /// Update user name with validation
    public func updateUserName() async {
        let startTime = Date()
        operationState = .loading
        
        do {
            try settingsManager.updateUserName(tempUserName)
            operationState = .success("User name updated successfully")
            isEditingUserName = false
            
            recordMetric("updateUserName", duration: Date().timeIntervalSince(startTime))
            
            // Auto-clear success message
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            operationState = .idle
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Updating user name")
            
            // Reset to previous value
            tempUserName = settingsManager.userName
        }
    }
    
    /// Update default currency with validation
    public func updateDefaultCurrency() async {
        let startTime = Date()
        operationState = .loading
        
        do {
            try settingsManager.updateDefaultCurrency(tempCurrency)
            operationState = .success("Currency updated successfully")
            isEditingCurrency = false
            
            recordMetric("updateDefaultCurrency", duration: Date().timeIntervalSince(startTime))
            
            // Auto-clear success message
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            operationState = .idle
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Updating default currency")
            
            // Reset to previous value
            tempCurrency = settingsManager.defaultCurrency
        }
    }
    
    /// Update notification settings with comprehensive validation
    public func updateNotificationSettings(
        allowed: Bool,
        purchaseEnabled: Bool,
        purchaseFrequency: SettingsManager.PurchaseNotificationFrequency,
        budgetEnabled: Bool,
        budgetFrequency: SettingsManager.BudgetTotalNotificationFrequency
    ) async {
        let startTime = Date()
        operationState = .loading
        pendingNotificationChanges = true
        
        do {
            try await settingsManager.updateNotificationSettings(
                allowed: allowed,
                purchaseEnabled: purchaseEnabled,
                purchaseFrequency: purchaseFrequency,
                budgetEnabled: budgetEnabled,
                budgetFrequency: budgetFrequency
            )
            
            operationState = .success("Notification settings updated")
            pendingNotificationChanges = false
            
            await updateNotificationStatistics()
            
            recordMetric("updateNotificationSettings", duration: Date().timeIntervalSince(startTime))
            
            // Auto-clear success message
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            operationState = .idle
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            pendingNotificationChanges = false
            errorHandler.handle(appError, context: "Updating notification settings")
        }
    }
    
    // MARK: - Export Methods
    
    /// Prepare and show export options
    public func prepareDataExport() {
        showingExportOptions = true
        try validateExportPreconditions()
    }
    
    /// Perform data export with progress tracking
    public func performDataExport() async {
        let startTime = Date()
        exportOperation = .preparing
        
        do {
            // Validate export preconditions
            try validateExportPreconditions()
            
            exportOperation = .exporting
            
            // Get entries for the selected time period
            let entries = try await budgetManager.getEntries(
                for: selectedExportTimePeriod,
                category: nil,
                sortedBy: .date,
                ascending: false
            )
            
            // Create export configuration
            let configuration = CSVExport.ExportConfiguration(
                timePeriod: selectedExportTimePeriod,
                exportType: .budgetEntries,
                includeCurrency: true,
                dateFormat: AppConstants.Data.csvExportDateFormat,
                decimalPlaces: 2,
                includeHeaders: true
            )
            
            // Perform export
            let result = try await CSVExport.exportBudgetEntries(entries, configuration: configuration)
            
            exportedFileURL = result.fileURL
            exportOperation = .complete(result.fileURL)
            
            operationState = .success("Export completed: \(result.summary)")
            
            recordMetric("performDataExport", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            exportOperation = .failed(appError)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Exporting data")
        }
    }
    
    /// Share exported file
    public func shareExportedFile() {
        guard case .complete(let url) = exportOperation else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Present activity controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Import Methods
    
    /// Handle budget data import
    public func handleBudgetImport(from url: URL) async {
        let startTime = Date()
        importOperation = .validating
        importProgress = 0.1
        importStatusMessage = "Validating file..."
        
        do {
            // Import and validate budget data
            let importResults = try await budgetManager.importBudgets(from: url)
            
            importOperation = .processing
            importProgress = 0.5
            importStatusMessage = "Processing \(importResults.data.count) budget entries..."
            
            // Process imported budgets
            try await budgetManager.processImportedBudgets(importResults)
            
            let result = ImportResult(
                entriesImported: 0,
                budgetsImported: importResults.data.count,
                categoriesCreated: importResults.newCategories.count,
                totalAmount: importResults.totalAmount,
                warnings: importResults.warningMessages
            )
            
            importOperation = .complete(result)
            importProgress = 1.0
            importStatusMessage = "Import completed"
            
            operationState = .success(result.summary)
            await updateDataStatistics()
            
            recordMetric("handleBudgetImport", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            importOperation = .failed(appError)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Importing budget data")
        }
    }
    
    /// Handle purchase data import
    public func handlePurchaseImport(from url: URL) async {
        let startTime = Date()
        importOperation = .validating
        importProgress = 0.1
        importStatusMessage = "Validating file..."
        
        do {
            // Import purchase data
            let importResults = try await budgetManager.importPurchases(from: url)
            
            importOperation = .processing
            importProgress = 0.3
            importStatusMessage = "Processing \(importResults.data.count) transactions..."
            
            pendingImportData = importResults.data
            unmappedCategories = importResults.newCategories
            
            if unmappedCategories.isEmpty {
                // No new categories, process directly
                importOperation = .importing
                importProgress = 0.8
                importStatusMessage = "Importing transactions..."
                
                try await budgetManager.processImportedPurchases(importResults, categoryMappings: [:])
                
                let result = ImportResult(
                    entriesImported: importResults.data.count,
                    budgetsImported: 0,
                    categoriesCreated: 0,
                    totalAmount: importResults.totalAmount,
                    warnings: importResults.warningMessages
                )
                
                importOperation = .complete(result)
                importProgress = 1.0
                operationState = .success(result.summary)
                
            } else {
                // Show category mapping interface
                importOperation = .mappingCategories(Array(unmappedCategories))
                importProgress = 0.6
                importStatusMessage = "Mapping \(unmappedCategories.count) new categories..."
                showingCategoryMapping = true
            }
            
            await updateDataStatistics()
            
            recordMetric("handlePurchaseImport", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            importOperation = .failed(appError)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Importing purchase data")
        }
    }
    
    /// Complete category mapping and finalize import
    public func completeCategoryMapping(with mappings: [String: String]) async {
        let startTime = Date()
        importOperation = .importing
        importProgress = 0.8
        importStatusMessage = "Finalizing import..."
        
        do {
            let importResults = CSVImport.ImportResults(
                data: pendingImportData,
                categories: Set(pendingImportData.map { $0.category }),
                existingCategories: Set(budgetManager.getAvailableCategories()),
                newCategories: unmappedCategories,
                totalAmount: pendingImportData.reduce(0) { $0 + $1.amount }
            )
            
            try await budgetManager.processImportedPurchases(importResults, categoryMappings: mappings)
            
            let result = ImportResult(
                entriesImported: pendingImportData.count,
                budgetsImported: 0,
                categoriesCreated: unmappedCategories.count,
                totalAmount: importResults.totalAmount,
                warnings: []
            )
            
            importOperation = .complete(result)
            importProgress = 1.0
            importStatusMessage = "Import completed"
            operationState = .success(result.summary)
            
            // Clean up temporary data
            pendingImportData = []
            unmappedCategories = []
            showingCategoryMapping = false
            
            await updateDataStatistics()
            
            recordMetric("completeCategoryMapping", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            importOperation = .failed(appError)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Completing category mapping")
        }
    }
    
    // MARK: - Data Management Methods
    
    /// Reset all app data with confirmation
    public func resetAllAppData() async {
        let startTime = Date()
        operationState = .loading
        
        do {
            try await budgetManager.resetAllData()
            try await settingsManager.resetToDefaults()
            themeManager.resetToDefaults()
            await NotificationManager.shared.cancelAllNotifications()
            
            operationState = .success("All app data has been reset")
            await updateDataStatistics()
            updateSystemHealth()
            
            recordMetric("resetAllAppData", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Resetting all app data")
        }
    }
    
    /// Create data backup
    public func createDataBackup() async {
        let startTime = Date()
        operationState = .loading
        
        do {
            let backupURL = try await settingsManager.createBackup()
            operationState = .success("Backup created successfully")
            
            // Optionally share the backup file
            exportedFileURL = backupURL
            
            recordMetric("createDataBackup", duration: Date().timeIntervalSince(startTime))
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Creating data backup")
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate current settings and update validation issues
    private func validateCurrentSettings() {
        isValidatingSettings = true
        var issues: [ValidationIssue] = []
        
        // Validate user name
        let userName = settingsManager.userName
        if userName.isEmpty {
            issues.append(ValidationIssue(
                field: "User Name",
                message: "User name is not set",
                severity: .warning,
                suggestion: "Add your name for personalized experience"
            ))
        } else if userName.count < 2 {
            issues.append(ValidationIssue(
                field: "User Name",
                message: "User name is too short",
                severity: .warning,
                suggestion: "Use at least 2 characters"
            ))
        }
        
        // Validate currency
        if !settingsManager.supportedCurrencies.contains(where: { $0.code == settingsManager.defaultCurrency }) {
            issues.append(ValidationIssue(
                field: "Currency",
                message: "Unsupported currency selected",
                severity: .error,
                suggestion: "Select a supported currency"
            ))
        }
        
        // Validate notification settings
        if settingsManager.notificationsAllowed && settingsManager.notificationAuthorizationStatus != .authorized {
            issues.append(ValidationIssue(
                field: "Notifications",
                message: "Notifications enabled but not authorized",
                severity: .warning,
                suggestion: "Grant notification permission in system settings"
            ))
        }
        
        // Validate backup settings
        if settingsManager.enableDataBackup && settingsManager.lastBackupDate == nil {
            issues.append(ValidationIssue(
                field: "Backup",
                message: "Backup enabled but no backup exists",
                severity: .info,
                suggestion: "Create your first backup"
            ))
        }
        
        validationIssues = issues
        isValidatingSettings = false
    }
    
    /// Validate export preconditions
    private func validateExportPreconditions() throws {
        guard dataStatistics?.entryCount ?? 0 > 0 else {
            throw AppError.validation(message: "No data available to export")
        }
        
        // Check available disk space
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                let requiredSpace: Int64 = 10 * 1024 * 1024 // 10MB
                if freeSpace.int64Value < requiredSpace {
                    throw AppError.validation(message: "Insufficient storage space for export")
                }
            }
        } catch {
            throw AppError.fileAccess(underlying: error)
        }
    }
    
    // MARK: - Statistics and Health Methods
    
    /// Update data statistics
    private func updateDataStatistics() async {
        dataStatistics = budgetManager.getDataStatistics()
    }
    
    /// Update notification statistics
    private func updateNotificationStatistics() async {
        notificationStatistics = await notificationManager.getNotificationStatistics()
    }
    
    /// Update system health
    private func updateSystemHealth() {
        let dataHealth = dataStatistics?.healthStatus ?? .poor
        let hasErrors = errorHandler.errorHistory.count > 0
        let backupStatus = settingsManager.getBackupStatus()
        
        var healthLevel: SystemHealth.HealthLevel = .healthy
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check data health
        if dataHealth == .poor || dataHealth == .fair {
            healthLevel = .warning
            issues.append("Data integrity issues detected")
            recommendations.append("Review your data for inconsistencies")
        }
        
        // Check error history
        if hasErrors {
            healthLevel = healthLevel == .healthy ? .caution : healthLevel
            issues.append("Recent errors detected")
            recommendations.append("Review error history and resolve issues")
        }
        
        // Check backup status
        if backupStatus.enabled && backupStatus.lastBackup == nil {
            healthLevel = healthLevel == .healthy ? .caution : healthLevel
            issues.append("No backup exists")
            recommendations.append("Create your first data backup")
        }
        
        // Check notification health
        if let notifStats = notificationStatistics,
           notifStats.healthStatus == .error || notifStats.healthStatus == .warning {
            healthLevel = healthLevel == .healthy ? .caution : healthLevel
            issues.append("Notification system issues")
            recommendations.append("Check notification settings")
        }
        
        systemHealth = SystemHealth(
            level: healthLevel,
            issues: issues,
            recommendations: recommendations,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Cancel current operation
    public func cancelCurrentOperation() {
        operationState = .idle
        exportOperation = .none
        importOperation = .none
        importProgress = 0.0
        importStatusMessage = ""
        isValidatingSettings = false
    }
    
    /// Clear operation state
    public func clearOperationState() {
        operationState = .idle
        exportOperation = .none
        importOperation = .none
    }
    
    /// Retry last failed operation
    public func retryLastOperation() async {
        // Implementation would depend on tracking the last operation
        // For now, just clear error state
        if case .error = operationState {
            operationState = .idle
        }
        
        if case .failed = exportOperation {
            exportOperation = .none
        }
        
        if case .failed = importOperation {
            importOperation = .none
        }
    }
    
    /// Get formatted app information
    public func getAppInformation() -> [String: String] {
        return [
            "Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "Build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "Data Entries": "\(dataStatistics?.entryCount ?? 0)",
            "Budget Categories": "\(dataStatistics?.categoryCount ?? 0)",
            "Last Backup": settingsManager.lastBackupDate?.formatted() ?? "Never",
            "Settings Version": "3",
            "Data Health": dataStatistics?.healthStatus.rawValue ?? "Unknown"
        ]
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
            
            #if DEBUG
            if duration > 2.0 {
                print("⚠️ SettingsViewModel: Slow operation '\(operation)' took \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            #if DEBUG
            print("📊 SettingsViewModel Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            #endif
            
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
        print("🧹 SettingsViewModel: Cleaned up resources")
    }
}

// MARK: - Supporting Types

public struct SystemHealth {
    public enum HealthLevel: String, CaseIterable {
        case healthy = "Healthy"
        case caution = "Caution"
        case warning = "Warning"
        case critical = "Critical"
        
        public var color: Color {
            switch self {
            case .healthy: return .green
            case .caution: return .yellow
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .caution: return "exclamationmark.circle"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.octagon.fill"
            }
        }
    }
    
    public let level: HealthLevel
    public let issues: [String]
    public let recommendations: [String]
    public let lastUpdated: Date
    
    public init(level: HealthLevel = .healthy, issues: [String] = [], recommendations: [String] = [], lastUpdated: Date = Date()) {
        self.level = level
        self.issues = issues
        self.recommendations = recommendations
        self.lastUpdated = lastUpdated
    }
    
    public var isHealthy: Bool {
        return level == .healthy
    }
    
    public var needsAttention: Bool {
        return level == .warning || level == .critical
    }
    
    public var summary: String {
        if issues.isEmpty {
            return "All systems operational"
        } else {
            return "\(issues.count) \(issues.count == 1 ? "issue" : "issues") detected"
        }
    }
}

// MARK: - Extensions

extension SettingsViewModel {
    /// Get detailed export statistics
    public func getExportStatistics() -> [String: Any] {
        let entries = dataStatistics?.entryCount ?? 0
        let budgets = dataStatistics?.budgetCount ?? 0
        let categories = dataStatistics?.categoryCount ?? 0
        
        return [
            "availableEntries": entries,
            "availableBudgets": budgets,
            "availableCategories": categories,
            "totalData": entries + budgets,
            "estimatedFileSize": calculateEstimatedExportSize(),
            "supportedFormats": ["CSV"],
            "timePeriodOptions": TimePeriod.allCases.map { $0.displayName }
        ]
    }
    
    /// Calculate estimated export file size
    private func calculateEstimatedExportSize() -> String {
        let entries = dataStatistics?.entryCount ?? 0
        // Rough estimate: ~100 bytes per entry (including headers)
        let estimatedBytes = entries * 100
        return ByteCountFormatter.string(fromByteCount: Int64(estimatedBytes), countStyle: .file)
    }
    
    /// Get import capabilities
    public func getImportCapabilities() -> [String: Any] {
        return [
            "supportedFormats": ["CSV"],
            "maxFileSize": ByteCountFormatter.string(fromByteCount: AppConstants.Data.maxImportFileSize, countStyle: .file),
            "supportedDataTypes": ["Budget Entries", "Monthly Budgets"],
            "requiresCategoryMapping": true,
            "validatesDuplicates": true,
            "maxRowCount": 10000
        ]
    }
    
    /// Get notification configuration
    public func getNotificationConfiguration() async -> [String: Any] {
        let config = await notificationManager.checkNotificationConfiguration()
        
        return [
            "hasPermission": config.hasPermission,
            "needsSetup": config.needsSetup,
            "recommendations": config.recommendations,
            "purchaseEnabled": settingsManager.purchaseNotificationsEnabled,
            "budgetEnabled": settingsManager.budgetTotalNotificationsEnabled,
            "authorizationStatus": settingsManager.notificationAuthorizationStatus.displayName
        ]
    }
    
    /// Format validation issues for display
    public func getFormattedValidationIssues() -> [String] {
        return validationIssues.map { issue in
            var formatted = "\(issue.field): \(issue.message)"
            if let suggestion = issue.suggestion {
                formatted += " (\(suggestion))"
            }
            return formatted
        }
    }
    
    /// Check if specific feature is available
    public func isFeatureAvailable(_ feature: String) -> Bool {
        switch feature {
        case "export":
            return (dataStatistics?.entryCount ?? 0) > 0
        case "import":
            return true
        case "backup":
            return settingsManager.enableDataBackup
        case "notifications":
            return settingsManager.notificationsAllowed
        case "biometrics":
            return settingsManager.isBiometricAuthAvailable
        default:
            return false
        }
    }
    
    /// Get feature status with details
    public func getFeatureStatus(_ feature: String) -> (available: Bool, reason: String?) {
        switch feature {
        case "export":
            let available = (dataStatistics?.entryCount ?? 0) > 0
            return (available, available ? nil : "No data available to export")
        case "import":
            return (true, nil)
        case "backup":
            let available = settingsManager.enableDataBackup
            return (available, available ? nil : "Backup is disabled in settings")
        case "notifications":
            let available = settingsManager.notificationsAllowed
            return (available, available ? nil : "Notifications are disabled")
        case "biometrics":
            let available = settingsManager.isBiometricAuthAvailable
            return (available, available ? nil : "Biometric authentication not available on this device")
        default:
            return (false, "Unknown feature")
        }
    }
}

// MARK: - Validation Extensions

extension SettingsViewModel {
    /// Validate specific setting
    public func validateSetting(_ setting: String, value: Any) -> ValidationIssue? {
        switch setting {
        case "userName":
            guard let name = value as? String else { return nil }
            if name.isEmpty {
                return ValidationIssue(field: "User Name", message: "Name cannot be empty")
            }
            if name.count < 2 {
                return ValidationIssue(field: "User Name", message: "Name too short", suggestion: "Use at least 2 characters")
            }
            if name.count > 50 {
                return ValidationIssue(field: "User Name", message: "Name too long", suggestion: "Use 50 characters or less")
            }
            
        case "currency":
            guard let currency = value as? String else { return nil }
            if !settingsManager.supportedCurrencies.contains(where: { $0.code == currency }) {
                return ValidationIssue(field: "Currency", message: "Unsupported currency", severity: .error)
            }
            
        default:
            break
        }
        
        return nil
    }
    
    /// Validate all settings at once
    public func validateAllSettings() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate user name
        if let issue = validateSetting("userName", value: settingsManager.userName) {
            issues.append(issue)
        }
        
        // Validate currency
        if let issue = validateSetting("currency", value: settingsManager.defaultCurrency) {
            issues.append(issue)
        }
        
        // Add more validations as needed
        
        return issues
    }
    
    /// Check if settings are valid for export
    public func canPerformExport() -> (canExport: Bool, reason: String?) {
        let entries = dataStatistics?.entryCount ?? 0
        if entries == 0 {
            return (false, "No transactions available to export")
        }
        
        if exportOperation.isActive {
            return (false, "Export already in progress")
        }
        
        return (true, nil)
    }
    
    /// Check if settings are valid for import
    public func canPerformImport() -> (canImport: Bool, reason: String?) {
        if importOperation.isActive {
            return (false, "Import already in progress")
        }
        
        if operationState.isLoading {
            return (false, "Another operation in progress")
        }
        
        return (true, nil)
    }
}

// MARK: - Async Extensions

extension SettingsViewModel {
    /// Perform comprehensive system check
    public func performSystemCheck() async -> SystemDiagnostic {
        let startTime = Date()
        var issues: [String] = []
        var warnings: [String] = []
        var successfulChecks: [String] = []
        
        // Check data integrity
        if let stats = dataStatistics {
            if stats.healthStatus == .excellent || stats.healthStatus == .good {
                successfulChecks.append("Data integrity good")
            } else {
                warnings.append("Data integrity issues detected")
            }
        }
        
        // Check notification system
        let notificationDiagnostic = await notificationManager.performSystemDiagnostic()
        switch notificationDiagnostic.overallHealth {
        case .healthy:
            successfulChecks.append("Notification system healthy")
        case .caution, .warning:
            warnings.append("Notification system issues")
        case .critical:
            issues.append("Critical notification system problems")
        }
        
        // Check backup status
        let backupStatus = settingsManager.getBackupStatus()
        if backupStatus.enabled {
            if backupStatus.lastBackup != nil {
                successfulChecks.append("Backup system operational")
            } else {
                warnings.append("Backup enabled but no backup exists")
            }
        }
        
        // Check settings validity
        let settingsValidation = validateAllSettings()
        if settingsValidation.isEmpty {
            successfulChecks.append("All settings valid")
        } else {
            warnings.append("Settings validation issues found")
        }
        
        // Check error history
        if errorHandler.errorHistory.isEmpty {
            successfulChecks.append("No recent errors")
        } else {
            let criticalErrors = errorHandler.errorHistory.filter { $0.error.severity == .critical }
            if !criticalErrors.isEmpty {
                issues.append("Critical errors in history")
            } else {
                warnings.append("Some errors in history")
            }
        }
        
        let overallHealth = determineOverallHealth(issues: issues, warnings: warnings)
        
        return SystemDiagnostic(
            timestamp: Date(),
            duration: Date().timeIntervalSince(startTime),
            authorizationStatus: settingsManager.notificationAuthorizationStatus,
            systemSettings: await UNUserNotificationCenter.current().notificationSettings(),
            pendingCount: notificationStatistics?.totalPending ?? 0,
            deliveredCount: notificationStatistics?.totalDelivered ?? 0,
            issues: issues,
            warnings: warnings,
            successfulChecks: successfulChecks,
            overallHealth: overallHealth
        )
    }
    
    private func determineOverallHealth(issues: [String], warnings: [String]) -> SystemDiagnostic.HealthLevel {
        if !issues.isEmpty {
            return .critical
        } else if warnings.count > 3 {
            return .warning
        } else if warnings.count > 0 {
            return .caution
        } else {
            return .healthy
        }
    }
    
    /// Optimize app performance
    public func optimizeAppPerformance() async {
        operationState = .loading
        
        do {
            // Clean up old error history
            errorHandler.clearHistory()
            
            // Clean up old notifications
            await notificationManager.cleanupOldNotifications()
            
            // Optimize core data if needed
            let hasUnsavedChanges = await CoreDataManager.shared.hasUnsavedChanges()
            if hasUnsavedChanges {
                try await CoreDataManager.shared.forceSave()
            }
            
            // Clean up old exports
            CSVExport.cleanupOldExports()
            
            // Update statistics
            await updateDataStatistics()
            await updateNotificationStatistics()
            updateSystemHealth()
            
            operationState = .success("App performance optimized")
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Optimizing app performance")
        }
    }
    
    /// Refresh all data
    public func refreshAllData() async {
        operationState = .loading
        
        do {
            // Refresh budget data
            budgetManager.loadData()
            
            // Update all statistics
            await updateDataStatistics()
            await updateNotificationStatistics()
            updateSystemHealth()
            
            // Revalidate settings
            validateCurrentSettings()
            
            operationState = .success("All data refreshed")
            
        } catch {
            let appError = AppError.from(error)
            operationState = .error(appError)
            errorHandler.handle(appError, context: "Refreshing all data")
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension SettingsViewModel {
    /// Create test view model with mock data
    static func createTestViewModel() -> SettingsViewModel {
        let viewModel = SettingsViewModel()
        
        // Load test data
       Task<Void, Never>{
            await viewModel.loadTestData()
        }
        
        return viewModel
    }
    
    /// Load test data for development
    func loadTestData() async {
        // Simulate data statistics
        dataStatistics = BudgetManager.DataStatistics(
            entryCount: 150,
            budgetCount: 12,
            categoryCount: 8,
            totalSpent: 2450.75,
            totalBudgeted: 3000.00,
            oldestEntry: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            newestEntry: Date(),
            dataIntegrityScore: 0.92
        )
        
        // Simulate validation issues
        validationIssues = [
            ValidationIssue(field: "User Name", message: "Name not set", severity: .warning),
            ValidationIssue(field: "Backup", message: "No backup exists", severity: .info)
        ]
        
        // Update system health
        updateSystemHealth()
        
        print("✅ SettingsViewModel: Loaded test data")
    }
    
    /// Simulate error states for testing
    func simulateErrorState() {
        operationState = .error(AppError.validation(message: "Test error"))
        exportOperation = .failed(AppError.csvExport(underlying: NSError(domain: "Test", code: -1)))
        importOperation = .failed(AppError.csvImport(underlying: NSError(domain: "Test", code: -1)))
    }
    
    /// Simulate loading states for testing
    func simulateLoadingState() {
        operationState = .loading
        exportOperation = .exporting
        importOperation = .processing
        importProgress = 0.5
        importStatusMessage = "Test processing..."
    }
    
    /// Get current state for testing validation
    func getCurrentStateForTesting() -> (
        operationState: OperationState,
        exportState: ExportOperation,
        importState: ImportOperation,
        validationIssueCount: Int,
        systemHealthLevel: SystemHealth.HealthLevel
    ) {
        return (
            operationState: operationState,
            exportState: exportOperation,
            importState: importOperation,
            validationIssueCount: validationIssues.count,
            systemHealthLevel: systemHealth.level
        )
    }
    
    /// Force update statistics for testing
    func forceUpdateStatisticsForTesting() async {
        await updateDataStatistics()
        await updateNotificationStatistics()
        updateSystemHealth()
    }
    
    /// Clear all state for testing
    func clearStateForTesting() {
        operationState = .idle
        exportOperation = .none
        importOperation = .none
        validationIssues = []
        importProgress = 0.0
        importStatusMessage = ""
        pendingImportData = []
        unmappedCategories = []
        isValidatingSettings = false
        
        metricsQueue.sync {
            operationMetrics.removeAll()
        }
    }
    
    /// Get performance metrics for testing
    func getPerformanceMetricsForTesting() -> [String: TimeInterval] {
        return metricsQueue.sync {
            return operationMetrics
        }
    }
}
#endif
