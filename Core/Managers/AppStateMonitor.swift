//
//  AppStateMonitor.swift
//  Brandon's Budget
//
//  Created on 7/5/25.
//  Purpose: Monitors app lifecycle states, data refresh tracking, and coordinates with other managers
//

import SwiftUI
import Foundation
import Combine

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
    public enum AppState: String, CaseIterable {
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
    private struct StateTransition {
        let fromState: AppState
        let toState: AppState
        let timestamp: Date
        let duration: TimeInterval?
        
        init(from: AppState, to: AppState) {
            self.fromState = from
            self.toState = to
            self.timestamp = Date()
            self.duration = nil
        }
    }
    
    private init() {
        self.appLaunchTime = Date()
        setupSessionTimer()
        checkDataStaleness()
        
        print("🔄 AppStateMonitor: Initialized at \(appLaunchTime)")
    }
    
    // MARK: - Public Interface
    
    /// Update the current app state
    public func updateAppState(_ newState: AppState) async {
        let previousState = currentState
        let transition = StateTransition(from: previousState, to: newState)
        
        // Record state transition
        stateTransitionHistory.insert(transition, at: 0)
        if stateTransitionHistory.count > maxHistoryEntries {
            stateTransitionHistory.removeLast()
        }
        
        // Update current state
        currentState = newState
        
        // Handle state-specific logic
        await handleStateTransition(from: previousState, to: newState)
        
        print("🔄 AppStateMonitor: State changed from \(previousState.rawValue) to \(newState.rawValue)")
    }
    
    /// Mark that data has been refreshed
    public func markDataRefresh() async {
        lastDataRefresh = Date()
        isDataStale = false
        print("🔄 AppStateMonitor: Data refresh marked at \(lastDataRefresh)")
    }
    
    /// Check if data needs refreshing
    public func shouldRefreshData() -> Bool {
        let timeSinceRefresh = Date().timeIntervalSince(lastDataRefresh)
        return timeSinceRefresh > dataStaleThreshold || isDataStale
    }
    
    /// Get current session duration
    public func getCurrentSessionDuration() -> TimeInterval {
        return Date().timeIntervalSince(appLaunchTime)
    }
    
    /// Get time since last data refresh
    public func getTimeSinceLastRefresh() -> TimeInterval {
        return Date().timeIntervalSince(lastDataRefresh)
    }
    
    /// Set data as stale (force refresh needed)
    public func markDataAsStale() {
        isDataStale = true
        print("⚠️ AppStateMonitor: Data marked as stale")
    }
    
    /// Set dependencies for coordination
    public func setDependencies(budgetManager: BudgetManager, errorHandler: ErrorHandler) {
        self.budgetManager = budgetManager
        self.errorHandler = errorHandler
    }
    
    // MARK: - Background Task Management
    
    /// Begin background task
    public func beginBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "BudgetDataSync") { [weak self] in
            self?.endBackgroundTask()
        }
        
        print("🔄 AppStateMonitor: Background task started (\(backgroundTaskIdentifier.rawValue))")
    }
    
    /// End background task
    public func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
        backgroundTasksCompleted += 1
        
        print("✅ AppStateMonitor: Background task completed (\(backgroundTasksCompleted) total)")
    }
    
    // MARK: - Private Methods
    
    private func handleStateTransition(from previousState: AppState, to newState: AppState) async {
        switch (previousState, newState) {
        case (_, .active):
            await handleBecameActive()
        case (_, .inactive):
            await handleBecameInactive()
        case (_, .background):
            await handleEnteredBackground()
        case (.background, .active):
            await handleReturnedFromBackground()
        default:
            break
        }
    }
    
    private func handleBecameActive() async {
        lastForegroundTime = Date()
        
        // Check if data needs refreshing
        if shouldRefreshData() {
            await coordinateDataRefresh()
        }
        
        // Resume session timer
        setupSessionTimer()
    }
    
    private func handleBecameInactive() async {
        // Prepare for potential background transition
        await saveCurrentState()
    }
    
    private func handleEnteredBackground() async {
        lastBackgroundTime = Date()
        
        // Invalidate session timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Begin background task
        beginBackgroundTask()
        
        // Perform background cleanup
        await performBackgroundCleanup()
        
        // End background task
        DispatchQueue.main.asyncAfter(deadline: .now() + maxBackgroundDuration) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func handleReturnedFromBackground() async {
        // Calculate background duration
        if let backgroundTime = lastBackgroundTime {
            let backgroundDuration = Date().timeIntervalSince(backgroundTime)
            print("🔄 AppStateMonitor: Returned from background after \(backgroundDuration) seconds")
            
            // If we were in background for a while, mark data as potentially stale
            if backgroundDuration > dataStaleThreshold {
                markDataAsStale()
            }
        }
    }
    
    private func coordinateDataRefresh() async {
        guard let budgetManager = budgetManager else { return }
        
        do {
            await budgetManager.refreshData()
            await markDataRefresh()
        } catch {
            errorHandler?.handle(AppError.from(error), context: "AppStateMonitor data refresh")
        }
    }
    
    private func saveCurrentState() async {
        guard let budgetManager = budgetManager else { return }
        
        do {
            await budgetManager.saveCurrentState()
            print("✅ AppStateMonitor: Current state saved")
        } catch {
            errorHandler?.handle(AppError.from(error), context: "AppStateMonitor save state")
        }
    }
    
    private func performBackgroundCleanup() async {
        // Clear temporary data
        await clearTemporaryData()
        
        // Update last background time
        lastBackgroundTime = Date()
    }
    
    private func clearTemporaryData() async {
        // This could coordinate with managers to clear caches, temporary files, etc.
        print("🧹 AppStateMonitor: Performed background cleanup")
    }
    
    private func setupSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
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
    
    /// Get app health status
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
    
    deinit {
        sessionTimer?.invalidate()
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
}

// MARK: - Supporting Types

public struct AppUsageStatistics {
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
}

public struct AppHealthStatus {
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
