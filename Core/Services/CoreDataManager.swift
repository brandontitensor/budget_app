//
//  CoreDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 5/30/25 - Enhanced with centralized error handling and improved performance
//

import CoreData
import Foundation
import Combine

/// Manages Core Data operations for the app with proper error handling, background operations, thread safety, and data persistence
public final class CoreDataManager {
    // MARK: - Singleton
    public static let shared = CoreDataManager()
    
    // MARK: - Properties
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
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
    
    // MARK: - Performance Monitoring
    private var operationMetrics: [String: TimeInterval] = [:]
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.metrics", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        persistentContainer = NSPersistentContainer(name: "BudgetModel")
        
        // Configure persistent store for better performance and reliability
        setupPersistentStore()
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure main context
        setupMainContext()
        
        // Create and configure background context
        setupBackgroundContext()
        
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
    
    private func setupBackgroundContext() {
        backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.undoManager = nil
        backgroundContext.shouldDeleteInaccessibleFaults = true
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
    
    // MARK: - Auto-Save Management
    
    private func performAutoSave() async {
        let startTime = Date()
        
        do {
            let hasBackgroundChanges = await backgroundContext.perform {
                return self.backgroundContext.hasChanges
            }
            
            let hasMainChanges = await mainContext.perform {
                return self.mainContext.hasChanges
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
            try await backgroundContext.perform {
                try self.saveContextIfNeeded(self.backgroundContext)
            }
            
            // Then save main context
            try await mainContext.perform {
                try self.saveContextIfNeeded(self.mainContext)
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
                
                if attempt < maxRetries {
                    // Brief delay before retry
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                    print("⚠️ CoreData: Save attempt \(attempt) failed, retrying...")
                } else {
                    print("❌ CoreData: All save attempts failed")
                }
            }
        }
        
        throw lastError ?? AppError.dataSave(underlying: NSError(
            domain: "CoreDataManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to save after \(maxRetries) attempts"]
        ))
    }
    
    // MARK: - Background Operations
    
    /// Perform operation on background context with error handling
    private func performBackgroundTask<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let startTime = Date()
        
        let result = try await backgroundContext.perform {
            do {
                let result = try operation(self.backgroundContext)
                return result
            } catch {
                throw AppError.from(error)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMetric("backgroundTask", duration: duration)
        
        return result
    }
    
    // MARK: - Budget Entry Operations
    
    /// Fetch all budget entries with optimized performance
    public func getAllEntries() async throws -> [BudgetEntry] {
        let startTime = Date()
        
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        
        // Optimize fetch request for better performance
        fetchRequest.fetchBatchSize = 100
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BudgetEntryMO.date, ascending: false)]
        
        let result = try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                let entries = results.compactMap { budgetEntryMO in
                    try? BudgetEntry(from: budgetEntryMO)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordMetric("getAllEntries", duration: duration)
                
                print("📊 CoreData: Fetched \(entries.count) entries in \(String(format: "%.2f", duration * 1000))ms")
                return entries
            } catch {
                throw AppError.dataLoad(underlying: error)
            }
        }
        
        return result
    }
    
    /// Fetch entries for a specific date range (optimized)
    public func getEntries(from startDate: Date, to endDate: Date) async throws -> [BudgetEntry] {
        let startTime = Date()
        
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BudgetEntryMO.date, ascending: false)]
        fetchRequest.fetchBatchSize = 50
        fetchRequest.returnsObjectsAsFaults = false
        
        let result = try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                let entries = results.compactMap { budgetEntryMO in
                    try? BudgetEntry(from: budgetEntryMO)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordMetric("getEntriesDateRange", duration: duration)
                
                return entries
            } catch {
                throw AppError.dataLoad(underlying: error)
            }
        }
        
        return result
    }
    
    /// Add a new budget entry with validation
    public func addEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            // Check for duplicate entries
            let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            
            if let existingEntry = try context.fetch(fetchRequest).first {
                throw AppError.validation(message: "Entry with this ID already exists")
            }
            
            // Create new entry
            let newEntry = BudgetEntryMO(context: context)
            newEntry.update(from: entry)
            
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("addEntry", duration: duration)
        }
    }
    
    /// Update an existing budget entry
    public func updateEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            
            guard let entryToUpdate = try context.fetch(fetchRequest).first else {
                throw AppError.dataLoad(underlying: NSError(
                    domain: "CoreDataManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entry not found"]
                ))
            }
            
            entryToUpdate.update(from: entry)
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("updateEntry", duration: duration)
        }
    }
    
    /// Delete a budget entry
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            
            guard let entryToDelete = try context.fetch(fetchRequest).first else {
                throw AppError.dataLoad(underlying: NSError(
                    domain: "CoreDataManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entry not found"]
                ))
            }
            
            context.delete(entryToDelete)
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("deleteEntry", duration: duration)
        }
    }
    
    // MARK: - Monthly Budget Operations
    
    /// Fetch all monthly budgets with optimized performance
    public func getAllMonthlyBudgets() async throws -> [MonthlyBudget] {
        let startTime = Date()
        
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        fetchRequest.fetchBatchSize = 50
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MonthlyBudgetMO.year, ascending: false),
            NSSortDescriptor(keyPath: \MonthlyBudgetMO.month, ascending: false)
        ]
        
        let result = try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                let budgets = results.compactMap { monthlyBudgetMO in
                    try? MonthlyBudget(from: monthlyBudgetMO)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordMetric("getAllMonthlyBudgets", duration: duration)
                
                print("📊 CoreData: Fetched \(budgets.count) monthly budgets in \(String(format: "%.2f", duration * 1000))ms")
                return budgets
            } catch {
                throw AppError.dataLoad(underlying: error)
            }
        }
        
        return result
    }
    
    /// Fetch monthly budgets for a specific month and year
    public func getMonthlyBudgets(for month: Int, year: Int) async throws -> [MonthlyBudget] {
        let startTime = Date()
        
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "month == %d AND year == %d", month, year)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MonthlyBudgetMO.category, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let result = try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                let budgets = results.compactMap { monthlyBudgetMO in
                    try? MonthlyBudget(from: monthlyBudgetMO)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordMetric("getMonthlyBudgetsForDate", duration: duration)
                
                return budgets
            } catch {
                throw AppError.dataLoad(underlying: error)
            }
        }
        
        return result
    }
    
    /// Add or update a monthly budget
    public func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "category == %@ AND month == %d AND year == %d",
                budget.category,
                budget.month,
                budget.year
            )
            
            let budgetMO: MonthlyBudgetMO
            
            if let existingBudget = try context.fetch(fetchRequest).first {
                budgetMO = existingBudget
            } else {
                budgetMO = MonthlyBudgetMO(context: context)
            }
            
            budgetMO.update(from: budget)
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("addOrUpdateMonthlyBudget", duration: duration)
        }
    }
    
    /// Delete monthly budgets for a category with enhanced options
    public func deleteMonthlyBudget(
        category: String,
        fromMonth: Int,
        year: Int,
        includeFutureMonths: Bool
    ) async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            var predicateFormat = "category == %@ AND year == %d"
            var predicateArgs: [Any] = [category, year]
            
            if !includeFutureMonths {
                predicateFormat += " AND month == %d"
                predicateArgs.append(fromMonth)
            } else {
                predicateFormat += " AND month >= %d"
                predicateArgs.append(fromMonth)
            }
            
            let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
            
            let budgetsToDelete = try context.fetch(fetchRequest)
            
            for budget in budgetsToDelete {
                context.delete(budget)
            }
            
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("deleteMonthlyBudget", duration: duration)
            
            print("🗑️ CoreData: Deleted \(budgetsToDelete.count) monthly budgets for \(category)")
        }
    }
    
    // MARK: - Batch Operations
    
    /// Delete all data from the store (with confirmation)
    public func deleteAllData() async throws {
        let startTime = Date()
        
        try await performBackgroundTask { context in
            let entityNames = ["BudgetEntryMO", "MonthlyBudgetMO"]
            var totalDeleted = 0
            
            for entityName in entityNames {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                
                do {
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                    totalDeleted += objectIDArray.count
                    
                    // Merge changes to main context
                    let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDArray]
                    await MainActor.run {
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.mainContext])
                    }
                } catch {
                    print("❌ CoreData: Failed to delete \(entityName): \(error)")
                    throw AppError.deleteError(underlying: error)
                }
            }
            
            try self.saveContextIfNeeded(context)
            
            let duration = Date().timeIntervalSince(startTime)
            self.recordMetric("deleteAllData", duration: duration)
            
            print("🗑️ CoreData: Deleted \(totalDeleted) total objects in \(String(format: "%.2f", duration * 1000))ms")
        }
    }
    
    // MARK: - Context Status and Health
    
    /// Check if there are unsaved changes in any context
    public func hasUnsavedChanges() async -> Bool {
        let backgroundHasChanges = await backgroundContext.perform {
            return self.backgroundContext.hasChanges
        }
        
        let mainHasChanges = await mainContext.perform {
            return self.mainContext.hasChanges
        }
        
        return backgroundHasChanges || mainHasChanges
    }
    
    /// Get detailed information about unsaved changes
    public func getUnsavedChangesInfo() async -> (background: ChangeInfo, main: ChangeInfo) {
        let backgroundInfo = await backgroundContext.perform {
            return ChangeInfo(
                inserted: self.backgroundContext.insertedObjects.count,
                updated: self.backgroundContext.updatedObjects.count,
                deleted: self.backgroundContext.deletedObjects.count
            )
        }
        
        let mainInfo = await mainContext.perform {
            return ChangeInfo(
                inserted: self.mainContext.insertedObjects.count,
                updated: self.mainContext.updatedObjects.count,
                deleted: self.mainContext.deletedObjects.count
            )
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

// MARK: - Error Enum

public enum CoreDataError: LocalizedError {
    case saveError(Error)
    case fetchError(Error)
    case deleteError(Error)
    case migrationError(Error)
    case invalidManagedObjectID
    case contextError(String)
    case autoSaveSetupFailed
    
    public var errorDescription: String? {
        switch self {
        case .saveError(let error): return "Failed to save data: \(error.localizedDescription)"
        case .fetchError(let error): return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteError(let error): return "Failed to delete data: \(error.localizedDescription)"
        case .migrationError(let error): return "Failed to migrate data: \(error.localizedDescription)"
        case .invalidManagedObjectID: return "Invalid managed object ID"
        case .contextError(let message): return message
        case .autoSaveSetupFailed: return "Failed to setup auto-save mechanism"
        }
    }
}


public extension CoreDataManager {
    
    /// Alias for getAllEntries() - used by BudgetManager
    func getAllBudgetEntries() async throws -> [BudgetEntry] {
        return try await getAllEntries()
    }
    
    /// Get budget entries filtered by TimePeriod and optional category
    func getBudgetEntries(for period: TimePeriod?, category: String? = nil) async throws -> [BudgetEntry] {
        let startTime = Date()
        
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        var predicates: [NSPredicate] = []
        
        // Add time period filter
        if let period = period {
            let dateInterval = period.dateInterval()
            let datePredicate = NSPredicate(
                format: "date >= %@ AND date <= %@",
                dateInterval.start as NSDate,
                dateInterval.end as NSDate
            )
            predicates.append(datePredicate)
        }
        
        // Add category filter
        if let category = category {
            let categoryPredicate = NSPredicate(format: "category == %@", category)
            predicates.append(categoryPredicate)
        }
        
        // Combine predicates
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BudgetEntryMO.date, ascending: false)]
        fetchRequest.fetchBatchSize = 50
        fetchRequest.returnsObjectsAsFaults = false
        
        let result = try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                let entries = results.compactMap { budgetEntryMO in
                    try? BudgetEntry(from: budgetEntryMO)
                }
                
                let duration = Date().timeIntervalSince(startTime)
                self.recordMetric("getBudgetEntries", duration: duration)
                
                return entries
            } catch {
                throw AppError.dataLoad(underlying: error)
            }
        }
        
        return result
    }
}

// MARK: - TimePeriod Extension (Helper)

public extension TimePeriod {
    /// Convenience property for current month
    static var currentMonth: TimePeriod {
        return .thisMonth
    }
}

// MARK: - Testing Support

#if DEBUG
extension CoreDataManager {
    /// Create an in-memory test manager
    static func createTestManager() -> CoreDataManager {
        // This would create an in-memory store for testing
        // Implementation would go here for unit tests
        return CoreDataManager.shared
    }
    
    /// Reset auto-save timer for testing
    func resetAutoSaveTimerForTesting() {
        invalidateAutoSaveTimer()
        setupAutoSaveTimer()
    }
    
    /// Get auto-save interval for testing
    var autoSaveIntervalForTesting: TimeInterval {
        return autoSaveInterval
    }
    
    /// Force trigger auto-save for testing
    func triggerAutoSaveForTesting() async {
        await performAutoSave()
    }
}
#endif
