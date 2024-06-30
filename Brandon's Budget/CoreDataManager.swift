//
//  DatabaseManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BudgetModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - BudgetEntry Methods
    
    func getAllEntries() -> [BudgetEntry] {
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { BudgetEntry(managedObject: $0) }
        } catch {
            print("Failed to fetch entries: \(error)")
            return []
        }
    }
    
    func addEntry(_ entry: BudgetEntry) {
        let newEntry = BudgetEntryMO(context: context)
        newEntry.id = entry.id
        newEntry.amount = entry.amount
        newEntry.category = entry.category
        newEntry.date = entry.date
        newEntry.note = entry.note
        saveContext()
    }
    
    func updateEntry(_ entry: BudgetEntry) {
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        do {
            let results = try context.fetch(fetchRequest)
            if let entryToUpdate = results.first {
                entryToUpdate.amount = entry.amount
                entryToUpdate.category = entry.category
                entryToUpdate.date = entry.date
                entryToUpdate.note = entry.note
                saveContext()
            }
        } catch {
            print("Failed to update entry: \(error)")
        }
    }
    
    func deleteEntry(_ entry: BudgetEntry) {
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        do {
            let results = try context.fetch(fetchRequest)
            if let entryToDelete = results.first {
                context.delete(entryToDelete)
                saveContext()
            }
        } catch {
            print("Failed to delete entry: \(error)")
        }
    }
    
    func getEntries(from startDate: Date, to endDate: Date) -> [BudgetEntry] {
        let fetchRequest: NSFetchRequest<BudgetEntryMO> = BudgetEntryMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { BudgetEntry(managedObject: $0) }
        } catch {
            print("Failed to fetch entries: \(error)")
            return []
        }
    }
    
    // MARK: - MonthlyBudget Methods
    
    func getAllMonthlyBudgets() -> [MonthlyBudget] {
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { MonthlyBudget(managedObject: $0) }
        } catch {
            print("Failed to fetch monthly budgets: \(error)")
            return []
        }
    }
    
    func addOrUpdateMonthlyBudget(_ budget: MonthlyBudget) {
            let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "category == %@ AND month == %d AND year == %d",
                                                 budget.category, budget.month, budget.year)
            
            do {
                let results = try context.fetch(fetchRequest)
                let budgetMO: MonthlyBudgetMO
                
                if let existingBudget = results.first {
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
                
                saveContext()
            } catch {
                print("Failed to add or update monthly budget: \(error)")
            }
        }
    
    func addOrUpdateMonthlyBudgetAsync(_ budget: MonthlyBudget) async {
            await withCheckedContinuation { continuation in
                self.persistentContainer.performBackgroundTask { context in
                    let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "category == %@ AND month == %d AND year == %d",
                                                         budget.category, budget.month, budget.year)
                    
                    do {
                        let results = try context.fetch(fetchRequest)
                        let budgetMO: MonthlyBudgetMO
                        
                        if let existingBudget = results.first {
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
                        
                        try context.save()
                        continuation.resume()
                    } catch {
                        print("Failed to add or update monthly budget: \(error)")
                        continuation.resume()
                    }
                }
            }
        }
    
    func deleteMonthlyBudget(category: String, month: Int, year: Int) {
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category == %@ AND month == %d AND year == %d", category, month, year)
        do {
            let results = try context.fetch(fetchRequest)
            for budgetToDelete in results {
                context.delete(budgetToDelete)
            }
            saveContext()
        } catch {
            print("Failed to delete monthly budget: \(error)")
        }
    }
    
    func getMonthlyBudgets(for month: Int, year: Int) -> [MonthlyBudget] {
        let fetchRequest: NSFetchRequest<MonthlyBudgetMO> = MonthlyBudgetMO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "month == %d AND year == %d", month, year)
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { MonthlyBudget(managedObject: $0) }
        } catch {
            print("Failed to fetch monthly budgets: \(error)")
            return []
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteAllData() {
        let entityNames = ["BudgetEntryMO", "MonthlyBudgetMO"]
        
        for entityName in entityNames {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                print("Failed to delete all data for entity \(entityName): \(error)")
            }
        }
        
        saveContext()
    }
}

// MARK: - Managed Object to Model conversions

extension BudgetEntry {
    init(managedObject: BudgetEntryMO) {
        self.id = managedObject.id ?? UUID()
        self.amount = managedObject.amount
        self.category = managedObject.category ?? ""
        self.date = managedObject.date ?? Date()
        self.note = managedObject.note
    }
}

extension MonthlyBudget {
    init(managedObject: MonthlyBudgetMO) {
        self.id = managedObject.id ?? UUID()
        self.category = managedObject.category ?? ""
        self.amount = managedObject.amount
        self.month = Int(managedObject.month)
        self.year = Int(managedObject.year)
        self.isHistorical = managedObject.isHistorical
    }
}
