//
//  CoreDataManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import CoreData
import Foundation
import Combine

/// Manages Core Data operations for the app with proper error handling, background operations, and thread safety
public final class CoreDataManager {
    // MARK: - Error Types
    public enum CoreDataError: LocalizedError {
        case saveError(Error)
        case fetchError(Error)
        case deleteError(Error)
        case migrationError(Error)
        case invalidManagedObjectID
        case contextError(String)
        
        public var errorDescription: String? {
            switch self {
            case .saveError(let error): return "Failed to save data: \(error.localizedDescription)"
            case .fetchError(let error): return "Failed to fetch data: \(error.localizedDescription)"
            case .deleteError(let error): return "Failed to delete data: \(error.localizedDescription)"
            case .migrationError(let error): return "Failed to migrate data: \(error.localizedDescription)"
            case .invalidManagedObjectID: return "Invalid managed object ID"
            case .contextError(let message): return message
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = CoreDataManager()
    
    // MARK: - Properties
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    
    /// Publisher for CoreData changes
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    /// Main context for UI operations
    public var mainContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        persistentContainer = NSPersistentContainer(name: "BudgetModel")
        
        // Configure persistent store
        let storeDescription = persistentContainer.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Load persistent stores
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Failed to load Core Data stack: \(error), \(error.userInfo)")
            }
        }
        
        // Configure main context
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Create and configure background context
        backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Setup notification handling
        setupNotificationHandling()
    }
    
    // MARK: - Notification Handling
    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        objectWillChange.send()
        
        // Merge changes to main context if they came from a background context
        if let context = notification.object as? NSManagedObjectContext,
           context !== mainContext {
            mainContext.perform {
                self.mainContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Perform operation on background context
    /// - Parameter operation: The operation to perform
    /// - Returns: Result of the operation
    private func performBackgroundTask<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await backgroundContext.perform {
            try operation(self.backgroundContext)
        }
    }
    
    /// Save context with error handling and retry mechanism
    /// - Parameter context: The context to save
    private func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        var saveError: Error?
        let maxRetries = 3
        var retryCount = 0
        
        repeat {
            do {
                try context.save()
                return
            } catch {
                saveError = error
                retryCount += 1
                
                // Wait briefly before retrying
                if retryCount < maxRetries {
                    Thread.sleep(forTimeInterval: 0.1 * Double(retryCount))
                }
            }
        } while retryCount < maxRetries
        
        throw CoreDataError.saveError(saveError ?? NSError(domain: "Unknown", code: -1))
    }
    
    // MARK: - Budget Entry Operations
    
    /// Fetch all budget entries
    /// - Returns: Array of budget entries
    public func getAllEntries() async throws -> [BudgetEntry] {
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        
        return try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                return results.map { BudgetEntry(from: $0) }
            } catch {
                throw CoreDataError.fetchError(error)
            }
        }
    }
    
    /// Add a new budget entry
    /// - Parameter entry: The entry to add
    public func addEntry(_ entry: BudgetEntry) async throws {
        try await performBackgroundTask { context in
            let newEntry = BudgetEntryMO(context: context)
            newEntry.update(from: entry)
            try self.saveContext(context)
        }
    }
    
    /// Update an existing budget entry
    /// - Parameter entry: The entry to update
    public func updateEntry(_ entry: BudgetEntry) async throws {
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            
            guard let entryToUpdate = try context.fetch(fetchRequest).first else {
                throw CoreDataError.contextError("Entry not found")
            }
            
            entryToUpdate.update(from: entry)
            try self.saveContext(context)
        }
    }
    
    /// Delete a budget entry
    /// - Parameter entry: The entry to delete
    public func deleteEntry(_ entry: BudgetEntry) async throws {
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            
            guard let entryToDelete = try context.fetch(fetchRequest).first else {
                throw CoreDataError.contextError("Entry not found")
            }
            
            context.delete(entryToDelete)
            try self.saveContext(context)
        }
    }
    
    // MARK: - Monthly Budget Operations
    
    /// Fetch all monthly budgets
    /// - Returns: Array of monthly budgets
    public func getAllMonthlyBudgets() async throws -> [MonthlyBudget] {
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        
        return try await mainContext.perform {
            do {
                let results = try self.mainContext.fetch(fetchRequest)
                return results.map { MonthlyBudget(from: $0) }
            } catch {
                throw CoreDataError.fetchError(error)
            }
        }
    }
    
    /// Add or update a monthly budget
    /// - Parameter budget: The budget to add or update
    public func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) async throws {
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
            
            budgetMO.id = budget.id
            budgetMO.category = budget.category
            budgetMO.amount = budget.amount
            budgetMO.month = Int16(budget.month)
            budgetMO.year = Int16(budget.year)
            budgetMO.isHistorical = budget.isHistorical
            
            try self.saveContext(context)
        }
    }
    
    /// Delete monthly budgets for a category
    /// - Parameters:
    ///   - category: The category to delete
    ///   - fromMonth: Starting month
    ///   - year: The year
    ///   - includeFutureMonths: Whether to delete from future months
    public func deleteMonthlyBudget(
        category: String,
        fromMonth: Int,
        year: Int,
        includeFutureMonths: Bool
    ) async throws {
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
            budgetsToDelete.forEach { context.delete($0) }
            
            try self.saveContext(context)
        }
    }
    
    /// Delete all data from the store
    public func deleteAllData() async throws {
        try await performBackgroundTask { context in
            let entityNames = ["BudgetEntryMO", "MonthlyBudgetMO"]
            
            for entityName in entityNames {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
                
                // Merge changes to main context
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDArray],
                    into: [self.mainContext]
                )
            }
            
            try self.saveContext(context)
        }
    }
    
    // MARK: - History Tracking
    
    /// Get the last token for widget updates
    public func lastHistoryToken() throws -> NSPersistentHistoryToken? {
        try persistentContainer.persistentStoreCoordinator.currentPersistentHistoryToken()
    }
    
    /// Get changes since the last token
    public func changesSinceToken(_ token: NSPersistentHistoryToken?) throws -> [NSPersistentHistoryChange] {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        let result = try persistentContainer.persistentStoreCoordinator.execute(request)
        guard let historyResult = result as? NSPersistentHistoryResult,
              let history = historyResult.result as? [NSPersistentHistoryTransaction] else {
            return []
        }
        return history.flatMap { $0.changes ?? [] }
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
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

// MARK: - Model Extensions
extension BudgetEntry {
    init(from managedObject: BudgetEntryMO) {
        self.id = managedObject.id ?? UUID()
        self.amount = managedObject.amount
        self.category = managedObject.category ?? "Uncategorized"
        self.date = managedObject.date ?? Date()
        self.note = managedObject.note
    }
}

extension MonthlyBudget {
    init(from managedObject: MonthlyBudgetMO) {
        self.id = managedObject.id ?? UUID()
        self.category = managedObject.category ?? "Uncategorized"
        self.amount = managedObject.amount
        self.month = Int(managedObject.month)
        self.year = Int(managedObject.year)
        self.isHistorical = managedObject.isHistorical
    }
}
