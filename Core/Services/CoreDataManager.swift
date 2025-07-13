//
//  CoreDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import CoreData
import Foundation
import Combine
import WidgetKit

/// Manages Core Data operations for the app with proper error handling, background operations, thread safety, and data persistence
public final class CoreDataManager {
    // MARK: - Singleton
    public static let shared = CoreDataManager()
    
    // MARK: - Properties
    private let persistentContainer: NSPersistentContainer
    private var _backgroundContext: NSManagedObjectContext? // Changed to var
    private var autoSaveTimer: Timer?
    private let autoSaveInterval: TimeInterval = 30 // Save every 30 seconds
    private let saveQueue = DispatchQueue(label: "com.brandonsbudget.coredata.save", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    /// Publisher for CoreData changes
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    /// Main context for UI operations
    public var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Background context for operations
    public var backgroundContext: NSManagedObjectContext {
        if let context = _backgroundContext {
            return context
        }
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        _backgroundContext = context
        return context
    }
    
    // MARK: - Performance Monitoring
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.metrics", qos: .utility)
    private var operationMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Initialization
    private init() {
        persistentContainer = NSPersistentContainer(name: "BudgetModel")
        
        // Configure persistent store for better performance and reliability
        setupPersistentStore()
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure main context
        setupMainContext()
        
        // Setup notification handling
        setupNotificationHandling()
        
        // Setup auto-save timer
        setupAutoSaveTimer()
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup Methods
    
    private func setupPersistentStore() {
        guard let storeDescription = persistentContainer.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        // Enable remote change notifications for widget support
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable persistent history tracking
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Configure for better performance
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.shouldMigrateStoreAutomatically = true
        
        // Enable Write-Ahead Logging for better concurrent access
        storeDescription.setOption("WAL" as NSString, forKey: NSSQLitePragmasOption)
        
        // Set memory map threshold for better performance
        storeDescription.setOption(16384 as NSNumber, forKey: NSSQLiteManualVacuumOption)
    }
    
    private func loadPersistentStores() {
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                loadError = error
                print("❌ CoreData: Failed to load store: \(error)")
            } else {
                print("✅ CoreData: Store loaded successfully from \(storeDescription.url?.path ?? "unknown")")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            fatalError("Failed to load Core Data stack: \(error)")
        }
    }
    
    private func setupMainContext() {
        let viewContext = persistentContainer.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Configure for better performance
        viewContext.undoManager = nil // Disable undo for better performance
        viewContext.shouldDeleteInaccessibleFaults = true
        
        // Set reasonable fetch batch size
        viewContext.stalenessInterval = 0.0
    }
    
    private func setupNotificationHandling() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleContextDidSave(notification)
            }
            .store(in: &cancellables)
        
        // Handle remote changes for widget updates
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performAutoSave()
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        #if DEBUG
        // Monitor Core Data performance in debug builds
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        #endif
    }
    
    // MARK: - CRUD Operations
    
    /// Save context asynchronously
    public func saveContext() async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    try self.saveContextIfNeeded(self.backgroundContext)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("saveContext", duration: duration)
    }
    
    /// Add a budget entry
    public func addEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let managedEntry = BudgetEntryMO(context: self.backgroundContext)
                    managedEntry.update(from: entry)
                    
                    try self.saveContextIfNeeded(self.backgroundContext)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("addEntry", duration: duration)
        
        print("✅ CoreData: Added entry - \(entry.amount.formattedAsCurrency) for \(entry.category)")
    }
    
    /// Update a budget entry
    public func updateEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    guard let managedEntry = results.first else {
                        continuation.resume(throwing: AppError.dataLoad(underlying: NSError(
                            domain: "CoreDataManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Entry not found"]
                        )))
                        return
                    }
                    
                    managedEntry.update(from: entry)
                    try self.saveContextIfNeeded(self.backgroundContext)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("updateEntry", duration: duration)
        
        print("✅ CoreData: Updated entry - \(entry.amount.formattedAsCurrency) for \(entry.category)")
    }
    
    /// Delete a budget entry
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    guard let managedEntry = results.first else {
                        continuation.resume(throwing: AppError.dataLoad(underlying: NSError(
                            domain: "CoreDataManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Entry not found"]
                        )))
                        return
                    }
                    
                    self.backgroundContext.delete(managedEntry)
                    try self.saveContextIfNeeded(self.backgroundContext)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("deleteEntry", duration: duration)
        
        print("✅ CoreData: Deleted entry - \(entry.amount.formattedAsCurrency) for \(entry.category)")
    }
    
    /// Fetch all budget entries
    public func fetchAllEntries() async throws -> [BudgetEntry] {
        let startTime = Date()
        
        let entries: [BudgetEntry] = try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                    
                    let managedEntries = try self.backgroundContext.fetch(fetchRequest)
                    let entries = try managedEntries.map { try BudgetEntry(from: $0) }
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: AppError.dataLoad(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("fetchAllEntries", duration: duration)
        
        return entries
    }
    
    /// Add or update a monthly budget
    public func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Check if budget already exists
                    let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "category == %@ AND month == %d AND year == %d",
                        budget.category, budget.month, budget.year
                    )
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let managedBudget: MonthlyBudgetMO
                    
                    if let existingBudget = results.first {
                        managedBudget = existingBudget
                    } else {
                        managedBudget = MonthlyBudgetMO(context: self.backgroundContext)
                    }
                    
                    managedBudget.update(from: budget)
                    try self.saveContextIfNeeded(self.backgroundContext)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("addOrUpdateMonthlyBudget", duration: duration)
        
        print("✅ CoreData: Saved budget - \(budget.amount.formattedAsCurrency) for \(budget.category)")
    }
    
    /// Fetch monthly budgets
    public func fetchMonthlyBudgets() async throws -> [MonthlyBudget] {
        let startTime = Date()
        
        let budgets: [MonthlyBudget] = try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "year", ascending: false),
                        NSSortDescriptor(key: "month", ascending: false),
                        NSSortDescriptor(key: "category", ascending: true)
                    ]
                    
                    let managedBudgets = try self.backgroundContext.fetch(fetchRequest)
                    let budgets = try managedBudgets.map { try MonthlyBudget(from: $0) }
                    continuation.resume(returning: budgets)
                } catch {
                    continuation.resume(throwing: AppError.dataLoad(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("fetchMonthlyBudgets", duration: duration)
        
        return budgets
    }
    
    /// Delete all data from specific entities
    public func deleteAllData(from entityNames: [String] = ["BudgetEntryMO", "MonthlyBudgetMO"]) async throws {
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                var totalDeleted = 0
                
                do {
                    for entityName in entityNames {
                        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                        deleteRequest.resultType = .resultTypeObjectIDs
                        
                        let result = try self.backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                        let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                        totalDeleted += objectIDArray.count
                        
                        // Merge changes to main context
                        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDArray]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.mainContext])
                    }
                    
                    try self.saveContextIfNeeded(self.backgroundContext)
                    
                    print("🗑️ CoreData: Deleted \(totalDeleted) total objects")
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("deleteAllData", duration: duration)
    }
    
    // MARK: - Auto-Save Management
    
    private func performAutoSave() async {
        let startTime = Date()
        
        do {
            let hasBackgroundChanges = await withCheckedContinuation { continuation in
                backgroundContext.perform {
                    continuation.resume(returning: self.backgroundContext.hasChanges)
                }
            }
            
            let hasMainChanges = await withCheckedContinuation { continuation in
                mainContext.perform {
                    continuation.resume(returning: self.mainContext.hasChanges)
                }
            }
            
            if hasBackgroundChanges || hasMainChanges {
                try await forceSave()
                
                let duration = Date().timeIntervalSince(startTime)
                recordMetric("autoSave", duration: duration)
                
                print("✅ CoreData: Auto-save completed in \(String(format: "%.2f", duration * 1000))ms")
            }
        } catch {
            let appError = AppError.dataSave(underlying: error)
            await MainActor.run {
                ErrorHandler.shared.handle(appError, context: "Auto-save operation")
            }
        }
    }
    
    private func invalidateAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    // MARK: - Context Save Operations
    
    /// Force save all contexts immediately (async version)
    public func forceSave() async throws {
        let startTime = Date()
        
        do {
            // Save background context first
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                backgroundContext.perform {
                    do {
                        try self.saveContextIfNeeded(self.backgroundContext)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Then save main context
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                mainContext.perform {
                    do {
                        try self.saveContextIfNeeded(self.mainContext)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            recordMetric("forceSave", duration: duration)
            
            print("✅ CoreData: Force save completed in \(String(format: "%.2f", duration * 1000))ms")
        } catch {
            throw AppError.dataSave(underlying: error)
        }
    }
    
    /// Synchronous force save for app lifecycle events
    public func forceSaveSync() throws {
        let startTime = Date()
        var saveError: Error?
        
        // Save background context synchronously
        backgroundContext.performAndWait {
            do {
                try self.saveContextIfNeeded(self.backgroundContext)
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw AppError.dataSave(underlying: error)
        }
        
        // Save main context synchronously
        mainContext.performAndWait {
            do {
                try self.saveContextIfNeeded(self.mainContext)
            } catch {
                saveError = error
            }
        }
        
        if let error = saveError {
            throw AppError.dataSave(underlying: error)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("forceSaveSync", duration: duration)
        
        print("✅ CoreData: Synchronous force save completed in \(String(format: "%.2f", duration * 1000))ms")
    }
    
    /// Save context with error handling and retry mechanism
    private func saveContextIfNeeded(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try context.save()
                return
            } catch {
                lastError = error
                print("⚠️ CoreData: Save attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    // Brief delay before retry
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                    context.reset()
                }
            }
        }
        
        throw lastError ?? NSError(
            domain: "CoreDataManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to save after \(maxRetries) attempts"]
        )
    }
    
    // MARK: - Context Status and Health
    
    /// Check if there are unsaved changes in any context
    public func hasUnsavedChanges() async -> Bool {
        let backgroundHasChanges = await withCheckedContinuation { continuation in
            backgroundContext.perform {
                continuation.resume(returning: self.backgroundContext.hasChanges)
            }
        }
        
        let mainHasChanges = await withCheckedContinuation { continuation in
            mainContext.perform {
                continuation.resume(returning: self.mainContext.hasChanges)
            }
        }
        
        return backgroundHasChanges || mainHasChanges
    }
    
    /// Get detailed information about unsaved changes
    public func getUnsavedChangesInfo() async -> (background: ChangeInfo, main: ChangeInfo) {
        let backgroundInfo = await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let info = ChangeInfo(
                    inserted: self.backgroundContext.insertedObjects.count,
                    updated: self.backgroundContext.updatedObjects.count,
                    deleted: self.backgroundContext.deletedObjects.count
                )
                continuation.resume(returning: info)
            }
        }
        
        let mainInfo = await withCheckedContinuation { continuation in
            mainContext.perform {
                let info = ChangeInfo(
                    inserted: self.mainContext.insertedObjects.count,
                    updated: self.mainContext.updatedObjects.count,
                    deleted: self.mainContext.deletedObjects.count
                )
                continuation.resume(returning: info)
            }
        }
        
        return (background: backgroundInfo, main: mainInfo)
    }
    
    /// Get Core Data performance statistics
    public func getPerformanceStats() -> [String: Any] {
        return metricsQueue.sync {
            var stats: [String: Any] = [:]
            
            for (operation, duration) in operationMetrics {
                stats[operation] = String(format: "%.2fms", duration * 1000)
            }
            
            stats["autoSaveInterval"] = autoSaveInterval
            stats["isAutoSaveActive"] = autoSaveTimer?.isValid ?? false
            
            return stats
        }
    }
    
    // MARK: - History Tracking for Widgets
    
    /// Get the last history token for widget updates
    public func lastHistoryToken() throws -> NSPersistentHistoryToken? {
        guard let coordinator = persistentContainer.persistentStoreCoordinator.persistentStores.first else {
            return nil
        }
        return persistentContainer.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: [coordinator])
    }
    
    /// Get changes since the last token
    public func changesSinceToken(_ token: NSPersistentHistoryToken?) throws -> [NSPersistentHistoryChange] {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        
        guard let result = try persistentContainer.persistentStoreCoordinator.execute(request, with: mainContext) as? NSPersistentHistoryResult,
              let history = result.result as? [NSPersistentHistoryTransaction] else {
            return []
        }
        
        return history.flatMap { $0.changes ?? [] }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleContextDidSave(_ notification: Notification) {
        objectWillChange.send()
        
        // Merge changes to main context if they came from a background context
        if let context = notification.object as? NSManagedObjectContext,
           context !== mainContext {
            mainContext.perform {
                self.mainContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        print("📡 CoreData: Remote change detected")
        
        // Refresh main context to pick up remote changes
        mainContext.perform {
            self.mainContext.refreshAllObjects()
        }
        
        objectWillChange.send()
    }
    
    // MARK: - Performance Monitoring
    
    private func recordMetric(_ operation: String, duration: TimeInterval) {
        metricsQueue.async {
            self.operationMetrics[operation] = duration
        }
    }
    
    private func logPerformanceMetrics() {
        metricsQueue.async {
            guard !self.operationMetrics.isEmpty else { return }
            
            print("📊 CoreData Performance Metrics:")
            for (operation, duration) in self.operationMetrics.sorted(by: { $0.value > $1.value }) {
                print("   \(operation): \(String(format: "%.2f", duration * 1000))ms")
            }
            
            // Clear metrics after logging
            self.operationMetrics.removeAll()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        invalidateAutoSaveTimer()
        cancellables.removeAll()
        print("🧹 CoreData: Manager cleaned up")
    }
}

// MARK: - Supporting Types

public struct ChangeInfo {
    let inserted: Int
    let updated: Int
    let deleted: Int
    
    var total: Int {
        inserted + updated + deleted
    }
    
    var hasChanges: Bool {
        total > 0
    }
}

// MARK: - Managed Object Extensions

private extension BudgetEntryMO {
    func update(from entry: BudgetEntry) {
        self.id = entry.id
        self.amount = entry.amount
        self.category = entry.category
        self.date = entry.date
        self.note = entry.note
    }
}

private extension MonthlyBudgetMO {
    func update(from budget: MonthlyBudget) {
        self.id = budget.id
        self.category = budget.category
        self.amount = budget.amount
        self.month = Int16(budget.month)
        self.year = Int16(budget.year)
        self.isHistorical = budget.isHistorical
    }
}

// MARK: - Model Extensions

extension BudgetEntry {
    init(from managedObject: BudgetEntryMO) throws {
        guard let id = managedObject.id,
              let category = managedObject.category,
              let date = managedObject.date else {
            throw AppError.dataLoad(underlying: NSError(
                domain: "CoreDataManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid BudgetEntry data"]
            ))
        }
        
        try self.init(
            id: id,
            amount: managedObject.amount,
            category: category,
            date: date,
            note: managedObject.note
        )
    }
}

extension MonthlyBudget {
    init(from managedObject: MonthlyBudgetMO) throws {
        guard let id = managedObject.id,
              let category = managedObject.category else {
            throw AppError.dataLoad(underlying: NSError(
                domain: "CoreDataManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid MonthlyBudget data"]
            ))
        }
        
        try self.init(
            id: id,
            category: category,
            amount: managedObject.amount,
            month: Int(managedObject.month),
            year: Int(managedObject.year),
            isHistorical: managedObject.isHistorical
        )
    }
}

// MARK: - Missing BudgetManager Interface Methods
extension CoreDataManager {
    
    /// Load all budget entries (wrapper for fetchAllEntries)
    public func loadBudgetEntries() async throws -> [BudgetEntry] {
        return try await fetchAllEntries()
    }
    
    /// Save multiple budget entries
    public func saveBudgetEntries(_ entries: [BudgetEntry]) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // First, clear existing entries to avoid duplicates
                    let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
                    let existingEntries = try self.backgroundContext.fetch(fetchRequest)
                    
                    for entry in existingEntries {
                        self.backgroundContext.delete(entry)
                    }
                    
                    // Add all new entries
                    for entry in entries {
                        let managedObject = BudgetEntryMO(context: self.backgroundContext)
                        managedObject.id = entry.id
                        managedObject.amount = entry.amount
                        managedObject.category = entry.category
                        managedObject.date = entry.date
                        managedObject.note = entry.note
                    }
                    
                    try self.backgroundContext.save()
                    
                    DispatchQueue.main.async {
                        do {
                            try self.mainContext.save()
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: AppError.dataSave(underlying: error))
                        }
                    }
                    
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
    }
    
    /// Load all monthly budgets (wrapper for fetchMonthlyBudgets)
    public func loadMonthlyBudgets() async throws -> [MonthlyBudget] {
        return try await fetchMonthlyBudgets()
    }
    
    /// Save multiple monthly budgets
    public func saveMonthlyBudgets(_ budgets: [MonthlyBudget]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clear existing monthly budgets to avoid duplicates
                    let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
                    let existingBudgets = try self.backgroundContext.fetch(fetchRequest)
                    
                    for budget in existingBudgets {
                        self.backgroundContext.delete(budget)
                    }
                    
                    // Convert and save new budgets
                    // Note: The MonthlyBudget struct has a categories dictionary, but MonthlyBudgetMO 
                    // has individual category/amount pairs. We need to flatten the structure.
                    for budget in budgets {
                        for (category, amount) in budget.categories {
                            let managedObject = MonthlyBudgetMO(context: self.backgroundContext)
                            managedObject.id = budget.id
                            managedObject.month = Int16(budget.month)
                            managedObject.year = Int16(budget.year)
                            managedObject.category = category
                            managedObject.amount = amount
                            managedObject.isHistorical = false // Default value
                        }
                    }
                    
                    try self.backgroundContext.save()
                    
                    DispatchQueue.main.async {
                        do {
                            try self.mainContext.save()
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: AppError.dataSave(underlying: error))
                        }
                    }
                    
                } catch {
                    continuation.resume(throwing: AppError.dataSave(underlying: error))
                }
            }
        }
    }
}

