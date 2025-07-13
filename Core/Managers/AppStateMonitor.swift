//
//  AppStateMonitor.swift
//  Brandon's Budget
//
//  Created on 7/5/25.
//

import SwiftUI
import Foundation
import Combine
import UIKit

/// Monitors and manages application state transitions with data coordination
@MainActor
public final class AppStateMonitor: ObservableObject {
    public static let shared = AppStateMonitor()
    
    // MARK: - Published Properties
    @Published public private(set) var currentState: AppState = .inactive
    @Published public private(set) var lastDataRefresh: Date = Date()
    @Published public private(set) var lastBackgroundTime: Date?
    @Published public private(set) var lastForegroundTime: Date?
    @Published public private(set) var appLaunchTime: Date
    @Published public private(set) var sessionDuration: TimeInterval = 0
    @Published public private(set) var backgroundTasksCompleted: Int = 0
    @Published public private(set) var isDataStale: Bool = false
    
    // MARK: - App State Types
    public enum AppState: String, CaseIterable, Sendable {
        case active = "Active"
        case inactive = "Inactive"
        case background = "Background"
        case launching = "Launching"
        case terminating = "Terminating"
        
        public var isInteractive: Bool {
            switch self {
            case .active: return true
            case .inactive, .background, .launching, .terminating: return false
            }
        }
        
        public var allowsDataOperations: Bool {
            switch self {
            case .active, .inactive: return true
            case .background, .launching, .terminating: return false
            }
        }
    }
    
    // MARK: - Configuration
    private let dataStaleThreshold: TimeInterval = 300 // 5 minutes
    private let maxBackgroundDuration: TimeInterval = 30 // 30 seconds for background tasks
    
    // MARK: - Private Properties
    private var sessionTimer: Timer?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var stateTransitionHistory: [StateTransition] = []
    private let maxHistoryEntries = 50
    
    // MARK: - Dependencies
    private weak var budgetManager: BudgetManager?
    private weak var errorHandler: ErrorHandler?
    
    // MARK: - State Transition Tracking
    public struct StateTransition: Sendable {
        public let fromState: AppState
        public let toState: AppState
        public let timestamp: Date
        public let duration: TimeInterval?
        
        public init(fromState: AppState, toState: AppState, timestamp: Date = Date(), duration: TimeInterval? = nil) {
            self.fromState = fromState
            self.toState = toState
            self.timestamp = timestamp
            self.duration = duration
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.appLaunchTime = Date()
        setupObservers()
        setupSessionTimer()
        print("✅ AppStateMonitor: Initialized")
    }
    
    deinit {
        sessionTimer?.invalidate()
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
    
    // MARK: - Public Methods
    
    /// Update app state with transition tracking
    public func updateAppState(_ newState: AppState) async {
        let previousState = currentState
        let transition = StateTransition(
            fromState: previousState,
            toState: newState,
            timestamp: Date(),
            duration: newState == .background ? getCurrentSessionDuration() : nil
        )
        
        currentState = newState
        stateTransitionHistory.insert(transition, at: 0)
        
        // Limit history size
        if stateTransitionHistory.count > maxHistoryEntries {
            stateTransitionHistory.removeLast()
        }
        
        // Handle state-specific logic
        await handleStateTransition(from: previousState, to: newState)
        
        print("🔄 AppStateMonitor: State changed from \(previousState.rawValue) to \(newState.rawValue)")
    }
    
    /// Mark data as refreshed
    public func markDataRefreshed() {
        lastDataRefresh = Date()
        isDataStale = false
        print("✅ AppStateMonitor: Data marked as refreshed")
    }
    
    /// Check if data refresh is needed
    public func shouldRefreshData() -> Bool {
        return getTimeSinceLastRefresh() > dataStaleThreshold
    }
    
    /// Mark data as stale
    public func markDataAsStale() {
        isDataStale = true
        print("⚠️ AppStateMonitor: Data marked as stale")
    }
    
    /// Get time since last data refresh
    public func getTimeSinceLastRefresh() -> TimeInterval {
        return Date().timeIntervalSince(lastDataRefresh)
    }
    
    /// Get current session duration
    public func getCurrentSessionDuration() -> TimeInterval {
        return Date().timeIntervalSince(appLaunchTime)
    }
    
    // MARK: - BackgroundTask<Void, Never>Management
    
    /// Perform background tasks with proper lifecycle management
    public func performBackgroundTasks() async {
        print("🔄 AppStateMonitor: Starting background tasks")
        
        // Start backgroundTask<Void, Never>to ensure completion
        backgroundTaskIdentifier = await UIApplication.shared.beginBackgroundTask { [weak self] in
           Task<Void, Never>{ @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
        
        defer {
           Task<Void, Never>{ @MainActor [weak self] in
                self?.endBackgroundTask()
            }
        }
        
        // Fixed: Removed unnecessary do-catch for non-throwing operations
        await performDataSave()
        await performWidgetUpdate()
        await performCacheCleanup()
        
        backgroundTasksCompleted += 1
        print("✅ AppStateMonitor: Background tasks completed (\(backgroundTasksCompleted) total)")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupObservers() {
        // Setup dependencies
        self.budgetManager = BudgetManager.shared
        self.errorHandler = ErrorHandler.shared
        
        // Setup notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
       Task<Void, Never>{ @MainActor in
            print("⚠️ AppStateMonitor: Memory warning received")
            
            // Clean up state transition history
            if stateTransitionHistory.count > 20 {
                stateTransitionHistory = Array(stateTransitionHistory.prefix(20))
            }
            
            // Request garbage collection
            autoreleasepool {
                // Clear any unnecessary cached data
            }
        }
    }
    
    private func handleStateTransition(from oldState: AppState, to newState: AppState) async {
        switch newState {
        case .active:
            lastForegroundTime = Date()
            await handleAppBecameActive()
            
        case .background:
            lastBackgroundTime = Date()
            await handleAppEnteredBackground()
            
        case .launching:
            await handleAppLaunching()
            
        case .terminating:
            await handleAppTerminating()
            
        case .inactive:
            // No specific action needed for inactive state
            break
        }
    }
    
    private func handleAppBecameActive() async {
        // Check if data refresh is needed
        if shouldRefreshData() {
            await refreshAppData()
        }
    }
    
    private func handleAppEnteredBackground() async {
        // Perform background tasks
        await performBackgroundTasks()
    }
    
    private func handleAppLaunching() async {
        // App is launching - minimal setup
        print("🚀 AppStateMonitor: App launching")
    }
    
    private func handleAppTerminating() async {
        // App is terminating - final cleanup
        print("🔄 AppStateMonitor: App terminating")
        
        // Fixed: Added try for potentially throwing operation
        do {
            try await budgetManager?.saveCurrentState()
        } catch {
            print("❌ AppStateMonitor: Failed to save state during termination - \(error)")
        }
    }
    
    private func refreshAppData() async {
        guard let budgetManager = budgetManager else { return }
        
        await budgetManager.refreshData()
        markDataRefreshed()
        print("🔄 AppStateMonitor: App data refreshed")
    }
    
    private func performDataSave() async {
        guard let budgetManager = budgetManager else { return }
        
        // Fixed: Added try for potentially throwing operation
        do {
            try await budgetManager.performBackgroundSave()
            print("💾 AppStateMonitor: Data saved in background")
        } catch {
            print("❌ AppStateMonitor: Background save failed - \(error)")
        }
    }
    
    private func performWidgetUpdate() async {
        // Update widgets
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 AppStateMonitor: Widgets updated")
    }
    
    private func performCacheCleanup() async {
        // Clean up caches and temporary files
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for fileURL in tempFiles {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < sevenDaysAgo {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("❌ AppStateMonitor: Cache cleanup failed - \(error)")
        }
        
        print("🧹 AppStateMonitor: Performed background cleanup")
    }
    
    private func setupSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
           Task<Void, Never>{ @MainActor [weak self] in
                self?.updateSessionDuration()
            }
        }
    }
    
    private func updateSessionDuration() {
        sessionDuration = getCurrentSessionDuration()
        checkDataStaleness()
    }
    
    private func checkDataStaleness() {
        let timeSinceRefresh = getTimeSinceLastRefresh()
        let wasStale = isDataStale
        isDataStale = timeSinceRefresh > dataStaleThreshold
        
        if isDataStale && !wasStale {
            print("⚠️ AppStateMonitor: Data became stale (last refresh: \(timeSinceRefresh) seconds ago)")
        }
    }
    
    // MARK: - Analytics and Insights
    
    /// Get app usage statistics
    public func getUsageStatistics() -> AppUsageStatistics {
        let totalForegroundTime = stateTransitionHistory
            .filter { $0.toState == .active }
            .reduce(0) { total, transition in
                // Calculate time spent in active state
                if let nextTransition = stateTransitionHistory.first(where: {
                    $0.timestamp > transition.timestamp && $0.fromState == .active
                }) {
                    return total + nextTransition.timestamp.timeIntervalSince(transition.timestamp)
                }
                return total
            }
        
        let backgroundTransitions = stateTransitionHistory.filter { $0.toState == .background }.count
        let averageSessionLength = totalForegroundTime / max(1, Double(backgroundTransitions))
        
        return AppUsageStatistics(
            totalSessionTime: sessionDuration,
            totalForegroundTime: totalForegroundTime,
            backgroundTransitions: backgroundTransitions,
            averageSessionLength: averageSessionLength,
            dataRefreshCount: backgroundTasksCompleted,
            currentStateUptime: getCurrentStateUptime()
        )
    }
    
    private func getCurrentStateUptime() -> TimeInterval {
        guard let lastTransition = stateTransitionHistory.first else {
            return sessionDuration
        }
        return Date().timeIntervalSince(lastTransition.timestamp)
    }
    
    /// Get recent state transitions for debugging
    public func getRecentStateTransitions(limit: Int = 10) -> [StateTransition] {
        return Array(stateTransitionHistory.prefix(limit))
    }
    
    // MARK: - Health Monitoring
    
    /// Check if app state is healthy
    public func isHealthy() -> Bool {
        let recentErrors = errorHandler?.getRecentErrors().count ?? 0
        let timeSinceLastRefresh = getTimeSinceLastRefresh()
        
        return recentErrors < 5 && timeSinceLastRefresh < dataStaleThreshold * 2
    }
    
    /// Get app health status - Fixed: Made return type public
    public func getHealthStatus() -> AppHealthStatus {
        let recentErrors = errorHandler?.getRecentErrors().count ?? 0
        let timeSinceLastRefresh = getTimeSinceLastRefresh()
        let isResponsive = currentState.isInteractive
        
        let issues: [String] = [
            recentErrors > 5 ? "Multiple recent errors (\(recentErrors))" : nil,
            timeSinceLastRefresh > dataStaleThreshold * 2 ? "Data very stale" : nil,
            !isResponsive ? "App not responsive" : nil
        ].compactMap { $0 }
        
        let level: AppHealthStatus.HealthLevel
        if issues.isEmpty {
            level = .healthy
        } else if issues.count == 1 {
            level = .caution
        } else if issues.count == 2 {
            level = .warning
        } else {
            level = .critical
        }
        
        return AppHealthStatus(
            level: level,
            issues: issues,
            lastChecked: Date(),
            sessionDuration: sessionDuration,
            dataFreshness: timeSinceLastRefresh
        )
    }
}

// MARK: - Supporting Types

public struct AppUsageStatistics: Sendable {
    public let totalSessionTime: TimeInterval
    public let totalForegroundTime: TimeInterval
    public let backgroundTransitions: Int
    public let averageSessionLength: TimeInterval
    public let dataRefreshCount: Int
    public let currentStateUptime: TimeInterval
    
    public var foregroundPercentage: Double {
        guard totalSessionTime > 0 else { return 0 }
        return (totalForegroundTime / totalSessionTime) * 100
    }
    
    public init(
        totalSessionTime: TimeInterval,
        totalForegroundTime: TimeInterval,
        backgroundTransitions: Int,
        averageSessionLength: TimeInterval,
        dataRefreshCount: Int,
        currentStateUptime: TimeInterval
    ) {
        self.totalSessionTime = totalSessionTime
        self.totalForegroundTime = totalForegroundTime
        self.backgroundTransitions = backgroundTransitions
        self.averageSessionLength = averageSessionLength
        self.dataRefreshCount = dataRefreshCount
        self.currentStateUptime = currentStateUptime
    }
}

public struct AppHealthStatus: Sendable {
    public enum HealthLevel: String, CaseIterable, Sendable {
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
        
        public var systemImage: String {
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
    public let lastChecked: Date
    public let sessionDuration: TimeInterval
    public let dataFreshness: TimeInterval
    
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
    
    public init(
        level: HealthLevel,
        issues: [String],
        lastChecked: Date,
        sessionDuration: TimeInterval,
        dataFreshness: TimeInterval
    ) {
        self.level = level
        self.issues = issues
        self.lastChecked = lastChecked
        self.sessionDuration = sessionDuration
        self.dataFreshness = dataFreshness
    }
}

// MARK: - Integration Extensions

public extension AppStateMonitor {
    /// Integration with PerformanceMonitor for comprehensive monitoring
    func coordinateWithPerformanceMonitor() {
        #if DEBUG
        // Could integrate with PerformanceMonitor here
        // Example: PerformanceMonitor.shared.recordStateTransition(currentState)
        #endif
    }
    
    /// Get formatted state information for debugging
    func getDebugInfo() -> [String: Any] {
        return [
            "Current State": currentState.rawValue,
            "Session Duration": String(format: "%.1f seconds", sessionDuration),
            "Last Data Refresh": DateFormatter.localizedString(from: lastDataRefresh, dateStyle: .none, timeStyle: .medium),
            "Data Stale": isDataStale,
            "Background Tasks": backgroundTasksCompleted,
            "State Transitions": stateTransitionHistory.count,
            "Health Status": getHealthStatus().level.rawValue
        ]
    }
}


// MARK: - Testing Support

#if DEBUG
extension AppStateMonitor {
    /// Create test monitor with custom state
    static func createTestMonitor() -> AppStateMonitor {
        let monitor = AppStateMonitor()
        return monitor
    }
    
    /// Simulate state transitions for testing
    func simulateStateTransition(to state: AppState) async {
        await updateAppState(state)
    }
    
    /// Force data staleness for testing
    func simulateStaleData() {
        lastDataRefresh = Date().addingTimeInterval(-dataStaleThreshold * 2)
        markDataAsStale()
    }
    
    /// Reset for testing
    func resetForTesting() {
        currentState = .inactive
        lastDataRefresh = Date()
        isDataStale = false
        backgroundTasksCompleted = 0
        stateTransitionHistory.removeAll()
        sessionDuration = 0
    }
    
    /// Get internal state for testing
    func getInternalStateForTesting() -> (
        stateTransitionCount: Int,
        backgroundTaskCount: Int,
        isHealthy: Bool,
        dataStaleThreshold: TimeInterval
    ) {
        return (
            stateTransitionCount: stateTransitionHistory.count,
            backgroundTaskCount: backgroundTasksCompleted,
            isHealthy: isHealthy(),
            dataStaleThreshold: dataStaleThreshold
        )
    }
}
#endif
