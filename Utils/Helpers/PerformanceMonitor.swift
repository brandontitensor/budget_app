//
//  PerformanceMonitor.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//


// MARK: - Performance Monitoring
public class PerformanceMonitor {
    private static var startTimes: [String: Date] = [:]
    
    /// Start timing an operation
    public static func startTiming(_ operation: String) {
        startTimes[operation] = Date()
    }
    
    /// End timing an operation and return duration
    public static func endTiming(_ operation: String) -> TimeInterval? {
        guard let startTime = startTimes[operation] else { return nil }
        let duration = Date().timeIntervalSince(startTime)
        startTimes.removeValue(forKey: operation)
        
        #if DEBUG
        print("⏱️ \(operation) took \(String(format: "%.2f", duration * 1000))ms")
        #endif
        
        return duration
    }
    
    /// Measure execution time of a closure
    public static func measure<T>(_ operation: String, _ closure: () throws -> T) rethrows -> T {
        startTiming(operation)
        defer { _ = endTiming(operation) }
        return try closure()
    }
    
    /// Measure execution time of an async closure
    public static func measureAsync<T>(_ operation: String, _ closure: () async throws -> T) async rethrows -> T {
        startTiming(operation)
        defer { _ = endTiming(operation) }
        return try await closure()
    }
}

// MARK: - App State Monitoring
public class AppStateMonitor: ObservableObject {
    @Published public var isActive = true
    @Published public var isInBackground = false
    @Published public var hasUnsavedChanges = false
    
    public static let shared = AppStateMonitor()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = true
            self.isInBackground = false
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isActive = false
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isInBackground = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Testing Support
#if DEBUG
extension SharedDataManager {
    static func createMock() -> SharedDataManager {
        return SharedDataManager()
    }
}

extension ThemeManager {
    static func createMock() -> ThemeManager {
        return ThemeManager()
    }
}

extension BudgetManager {
    static func createMock() -> BudgetManager {
        return BudgetManager()
    }
    
    /// Create test data for previews
    func loadTestData() {
        Task {
            // Add test entries
            let testEntries = [
                try! BudgetEntry(amount: 45.67, category: "Groceries", date: Date()),
                try! BudgetEntry(amount: 25.00, category: "Transportation", date: Date().adding(days: -1)),
                try! BudgetEntry(amount: 15.99, category: "Entertainment", date: Date().adding(days: -2))
            ]
            
            await MainActor.run {
                self.entries = testEntries
            }
            
            // Add test budgets
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())
            
            let testBudgets = [
                try! MonthlyBudget(category: "Groceries", amount: 500, month: currentMonth, year: currentYear),
                try! MonthlyBudget(category: "Transportation", amount: 200, month: currentMonth, year: currentYear),
                try! MonthlyBudget(category: "Entertainment", amount: 150, month: currentMonth, year: currentYear)
            ]
            
            await MainActor.run {
                self.monthlyBudgets = testBudgets
                updateRemainingBudget()
            }
        }
    }
}
#endif

