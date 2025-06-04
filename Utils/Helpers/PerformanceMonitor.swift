//
//  PerformanceMonitor.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//  Enhanced version with comprehensive performance tracking
//

import Foundation
import SwiftUI
import Combine

// MARK: - Performance Monitoring

/// Comprehensive performance monitoring system for the app
@MainActor
public final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Types
    
    public struct PerformanceMetric {
        public let operation: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let context: String?
        public let memoryUsage: UInt64?
        public let thread: String
        
        public init(
            operation: String,
            duration: TimeInterval,
            timestamp: Date = Date(),
            context: String? = nil,
            memoryUsage: UInt64? = nil,
            thread: String = Thread.isMainThread ? "Main" : "Background"
        ) {
            self.operation = operation
            self.duration = duration
            self.timestamp = timestamp
            self.context = context
            self.memoryUsage = memoryUsage
            self.thread = thread
        }
        
        /// Human readable duration
        public var formattedDuration: String {
            if duration >= 1.0 {
                return String(format: "%.2fs", duration)
            } else {
                return String(format: "%.0fms", duration * 1000)
            }
        }
        
        /// Performance rating based on duration
        public var performanceRating: PerformanceRating {
            if duration < 0.1 {
                return .excellent
            } else if duration < 0.5 {
                return .good
            } else if duration < 1.0 {
                return .fair
            } else {
                return .poor
            }
        }
    }
    
    public enum PerformanceRating: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        public var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
        
        public var threshold: TimeInterval {
            switch self {
            case .excellent: return 0.1
            case .good: return 0.5
            case .fair: return 1.0
            case .poor: return Double.infinity
            }
        }
    }
    
    public struct SystemMetrics {
        public let memoryUsage: UInt64
        public let memoryPressure: MemoryPressure
        public let cpuUsage: Double
        public let diskSpace: DiskSpace
        public let batteryLevel: Float
        public let thermalState: ProcessInfo.ThermalState
        public let timestamp: Date
        
        public enum MemoryPressure: String, CaseIterable {
            case normal = "Normal"
            case warning = "Warning"
            case critical = "Critical"
            
            public var color: Color {
                switch self {
                case .normal: return .green
                case .warning: return .orange
                case .critical: return .red
                }
            }
        }
        
        public struct DiskSpace {
            public let available: UInt64
            public let total: UInt64
            
            public var usedPercentage: Double {
                let used = total - available
                return Double(used) / Double(total) * 100
            }
            
            public var availableFormatted: String {
                return ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .file)
            }
        }
    }
    
    public struct PerformanceReport {
        public let timeRange: DateInterval
        public let metrics: [PerformanceMetric]
        public let systemMetrics: [SystemMetrics]
        public let slowestOperations: [PerformanceMetric]
        public let averageDurations: [String: TimeInterval]
        public let performanceScore: Double
        public let recommendations: [String]
        public let generatedAt: Date
        
        public var summary: String {
            let score = Int(performanceScore * 100)
            return "Performance Score: \(score)% (\(metrics.count) operations tracked)"
        }
        
        public var overallRating: PerformanceRating {
            if performanceScore >= 0.9 { return .excellent }
            if performanceScore >= 0.7 { return .good }
            if performanceScore >= 0.5 { return .fair }
            return .poor
        }
    }
    
    // MARK: - Singleton
    public static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var currentMetrics: [PerformanceMetric] = []
    @Published public private(set) var systemMetrics: SystemMetrics?
    @Published public private(set) var slowOperations: [PerformanceMetric] = []
    @Published public private(set) var memoryWarnings: [Date] = []
    @Published public private(set) var overallPerformanceScore: Double = 1.0
    
    // MARK: - Private Properties
    private var activeOperations: [String: Date] = [:]
    private var metricsHistory: [PerformanceMetric] = []
    private var systemMetricsHistory: [SystemMetrics] = []
    private let metricsQueue = DispatchQueue(label: "com.brandonsbudget.performance", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private var systemTimer: Timer?
    private var cleanupTimer: Timer?
    
    // MARK: - Configuration
    private let maxMetricsHistory = 1000
    private let maxSystemMetricsHistory = 100
    private let slowOperationThreshold: TimeInterval = 1.0
    private let systemMetricsInterval: TimeInterval = 30.0
    private let cleanupInterval: TimeInterval = 300.0 // 5 minutes
    
    // MARK: - Initialization
    private init() {
        setupMemoryWarningObserver()
        setupThermalStateObserver()
        setupPerformanceScoreCalculation()
        
        #if DEBUG
        startMonitoring()
        #endif
    }
    
    // MARK: - Public Interface
    
    /// Start performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startSystemMetricsCollection()
        startPeriodicCleanup()
        
        print("📊 PerformanceMonitor: Started monitoring")
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        systemTimer?.invalidate()
        cleanupTimer?.invalidate()
        
        print("📊 PerformanceMonitor: Stopped monitoring")
    }
    
    /// Start timing an operation
    public func startTiming(_ operation: String, context: String? = nil) {
        guard isMonitoring else { return }
        
        metricsQueue.async {
            let key = context != nil ? "\(operation)_\(context!)" : operation
            self.activeOperations[key] = Date()
        }
    }
    
    /// End timing an operation and return duration
    @discardableResult
    public func endTiming(_ operation: String, context: String? = nil) -> TimeInterval? {
        guard isMonitoring else { return nil }
        
        let endTime = Date()
        var duration: TimeInterval?
        
        metricsQueue.sync {
            let key = context != nil ? "\(operation)_\(context!)" : operation
            
            guard let startTime = activeOperations.removeValue(forKey: key) else {
                return
            }
            
            duration = endTime.timeIntervalSince(startTime)
            
            let metric = PerformanceMetric(
                operation: operation,
                duration: duration!,
                timestamp: endTime,
                context: context,
                memoryUsage: getCurrentMemoryUsage()
            )
            
            metricsHistory.append(metric)
            
            // Track slow operations
            if duration! >= slowOperationThreshold {
                Task { @MainActor in
                    slowOperations.append(metric)
                    if slowOperations.count > 10 {
                        slowOperations.removeFirst()
                    }
                }
            }
            
            // Update current metrics
            Task { @MainActor in
                currentMetrics.append(metric)
                if currentMetrics.count > 50 {
                    currentMetrics.removeFirst()
                }
            }
            
            #if DEBUG
            if duration! > 0.5 {
                print("⚠️ PerformanceMonitor: Slow operation '\(operation)' took \(String(format: "%.2f", duration! * 1000))ms")
            }
            #endif
        }
        
        return duration
    }
    
    /// Measure execution time of a closure
    @discardableResult
    public func measure<T>(_ operation: String, context: String? = nil, _ closure: () throws -> T) rethrows -> T {
        startTiming(operation, context: context)
        defer { endTiming(operation, context: context) }
        return try closure()
    }
    
    /// Measure execution time of an async closure
    @discardableResult
    public func measureAsync<T>(_ operation: String, context: String? = nil, _ closure: () async throws -> T) async rethrows -> T {
        startTiming(operation, context: context)
        defer { endTiming(operation, context: context) }
        return try await closure()
    }
    
    /// Get performance report for a time period
    public func getPerformanceReport(for period: TimePeriod = .last7Days) -> PerformanceReport {
        let dateInterval = period.dateInterval()
        
        return metricsQueue.sync {
            let filteredMetrics = metricsHistory.filter { metric in
                dateInterval.contains(metric.timestamp)
            }
            
            let filteredSystemMetrics = systemMetricsHistory.filter { metric in
                dateInterval.contains(metric.timestamp)
            }
            
            let slowest = filteredMetrics
                .sorted { $0.duration > $1.duration }
                .prefix(10)
                .map { $0 }
            
            let averages = Dictionary(grouping: filteredMetrics, by: \.operation)
                .mapValues { metrics in
                    metrics.reduce(0) { $0 + $1.duration } / Double(metrics.count)
                }
            
            let score = calculatePerformanceScore(for: filteredMetrics)
            let recommendations = generateRecommendations(for: filteredMetrics, systemMetrics: filteredSystemMetrics)
            
            return PerformanceReport(
                timeRange: dateInterval,
                metrics: filteredMetrics,
                systemMetrics: filteredSystemMetrics,
                slowestOperations: slowest,
                averageDurations: averages,
                performanceScore: score,
                recommendations: recommendations,
                generatedAt: Date()
            )
        }
    }
    
    /// Get current system metrics
    public func getCurrentSystemMetrics() -> SystemMetrics {
        return SystemMetrics(
            memoryUsage: getCurrentMemoryUsage(),
            memoryPressure: getCurrentMemoryPressure(),
            cpuUsage: getCurrentCPUUsage(),
            diskSpace: getDiskSpace(),
            batteryLevel: getBatteryLevel(),
            thermalState: ProcessInfo.processInfo.thermalState,
            timestamp: Date()
        )
    }
    
    /// Clear all performance data
    public func clearPerformanceData() {
        metricsQueue.async {
            self.activeOperations.removeAll()
            self.metricsHistory.removeAll()
            self.systemMetricsHistory.removeAll()
            
            Task { @MainActor in
                self.currentMetrics.removeAll()
                self.slowOperations.removeAll()
                self.memoryWarnings.removeAll()
                self.overallPerformanceScore = 1.0
            }
        }
        
        print("🧹 PerformanceMonitor: Cleared all performance data")
    }
    
    /// Export performance data
    public func exportPerformanceData() -> [String: Any] {
        return metricsQueue.sync {
            return [
                "metrics": metricsHistory.map { metric in
                    [
                        "operation": metric.operation,
                        "duration": metric.duration,
                        "timestamp": metric.timestamp.timeIntervalSince1970,
                        "context": metric.context ?? "",
                        "memoryUsage": metric.memoryUsage ?? 0,
                        "thread": metric.thread,
                        "performanceRating": metric.performanceRating.rawValue
                    ]
                },
                "systemMetrics": systemMetricsHistory.map { metric in
                    [
                        "memoryUsage": metric.memoryUsage,
                        "memoryPressure": metric.memoryPressure.rawValue,
                        "cpuUsage": metric.cpuUsage,
                        "diskAvailable": metric.diskSpace.available,
                        "diskTotal": metric.diskSpace.total,
                        "batteryLevel": metric.batteryLevel,
                        "thermalState": metric.thermalState.rawValue,
                        "timestamp": metric.timestamp.timeIntervalSince1970
                    ]
                },
                "exportDate": Date().timeIntervalSince1970,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.memoryWarnings.append(Date())
                    if let self = self, self.memoryWarnings.count > 10 {
                        self.memoryWarnings.removeFirst()
                    }
                }
                print("⚠️ PerformanceMonitor: Memory warning received")
            }
            .store(in: &cancellables)
    }
    
    private func setupThermalStateObserver() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.recordSystemMetrics()
                print("🌡️ PerformanceMonitor: Thermal state changed to \(ProcessInfo.processInfo.thermalState.rawValue)")
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceScoreCalculation() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateOverallPerformanceScore()
        }
    }
    
    private func startSystemMetricsCollection() {
        systemTimer = Timer.scheduledTimer(withTimeInterval: systemMetricsInterval, repeats: true) { [weak self] _ in
            self?.recordSystemMetrics()
        }
        
        // Record initial metrics
        recordSystemMetrics()
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    private func recordSystemMetrics() {
        let metrics = getCurrentSystemMetrics()
        
        metricsQueue.async {
            self.systemMetricsHistory.append(metrics)
            
            // Keep only recent system metrics
            if self.systemMetricsHistory.count > self.maxSystemMetricsHistory {
                self.systemMetricsHistory.removeFirst()
            }
            
            Task { @MainActor in
                self.systemMetrics = metrics
            }
        }
    }
    
    private func updateOverallPerformanceScore() {
        let recentMetrics = metricsHistory.suffix(100)
        let score = calculatePerformanceScore(for: Array(recentMetrics))
        
        Task { @MainActor in
            overallPerformanceScore = score
        }
    }
    
    private func performCleanup() {
        metricsQueue.async {
            // Remove old metrics
            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours
            self.metricsHistory.removeAll { $0.timestamp < cutoffDate }
            
            // Limit total metrics count
            if self.metricsHistory.count > self.maxMetricsHistory {
                let excess = self.metricsHistory.count - self.maxMetricsHistory
                self.metricsHistory.removeFirst(excess)
            }
            
            print("🧹 PerformanceMonitor: Cleaned up old metrics")
        }
    }
    
    // MARK: - System Metrics Collection
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCurrentMemoryPressure() -> SystemMetrics.MemoryPressure {
        let memoryUsage = getCurrentMemoryUsage()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usagePercentage = Double(memoryUsage) / Double(totalMemory) * 100
        
        if usagePercentage > 80 {
            return .critical
        } else if usagePercentage > 60 {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        // This is a simplified CPU usage calculation
        // In a real implementation, you'd need to track CPU usage over time
        return 0.0 // Placeholder
    }
    
    private func getDiskSpace() -> SystemMetrics.DiskSpace {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return SystemMetrics.DiskSpace(available: 0, total: 0)
        }
        
        do {
            let values = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            let available = values.volumeAvailableCapacity ?? 0
            let total = values.volumeTotalCapacity ?? 0
            return SystemMetrics.DiskSpace(available: UInt64(available), total: UInt64(total))
        } catch {
            return SystemMetrics.DiskSpace(available: 0, total: 0)
        }
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    // MARK: - Analysis
    
    private func calculatePerformanceScore(for metrics: [PerformanceMetric]) -> Double {
        guard !metrics.isEmpty else { return 1.0 }
        
        let ratingScores: [PerformanceRating: Double] = [
            .excellent: 1.0,
            .good: 0.8,
            .fair: 0.6,
            .poor: 0.3
        ]
        
        let totalScore = metrics.reduce(0.0) { total, metric in
            return total + (ratingScores[metric.performanceRating] ?? 0.0)
        }
        
        return totalScore / Double(metrics.count)
    }
    
    private func generateRecommendations(for metrics: [PerformanceMetric], systemMetrics: [SystemMetrics]) -> [String] {
        var recommendations: [String] = []
        
        // Check for slow operations
        let slowOperations = metrics.filter { $0.duration > slowOperationThreshold }
        if !slowOperations.isEmpty {
            let uniqueOperations = Set(slowOperations.map { $0.operation })
            recommendations.append("Optimize slow operations: \(uniqueOperations.joined(separator: ", "))")
        }
        
        // Check memory usage
        if let latestSystemMetric = systemMetrics.last {
            switch latestSystemMetric.memoryPressure {
            case .warning:
                recommendations.append("Consider reducing memory usage - current usage is elevated")
            case .critical:
                recommendations.append("Critical memory usage detected - immediate optimization needed")
            case .normal:
                break
            }
            
            // Check disk space
            if latestSystemMetric.diskSpace.usedPercentage > 90 {
                recommendations.append("Low disk space detected - consider cleanup")
            }
            
            // Check thermal state
            switch latestSystemMetric.thermalState {
            case .fair, .serious, .critical:
                recommendations.append("Device thermal state is elevated - reduce CPU intensive operations")
            default:
                break
            }
        }
        
        // Check for memory warnings
        if !memoryWarnings.isEmpty {
            let recentWarnings = memoryWarnings.filter { $0.timeIntervalSinceNow > -3600 } // Last hour
            if !recentWarnings.isEmpty {
                recommendations.append("Recent memory warnings detected - review memory management")
            }
        }
        
        // Check operation frequency
        let operationCounts = Dictionary(grouping: metrics, by: \.operation).mapValues { $0.count }
        let frequentOperations = operationCounts.filter { $0.value > 100 }
        if !frequentOperations.isEmpty {
            recommendations.append("Consider caching for frequent operations: \(frequentOperations.keys.joined(separator: ", "))")
        }
        
        return recommendations
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
    }
}

// MARK: - App State Monitoring

@MainActor
public final class AppStateMonitor: ObservableObject {
    // MARK: - Published Properties
    @Published public var isActive = true
    @Published public var isInBackground = false
    @Published public var hasUnsavedChanges = false
    @Published public var networkStatus: NetworkStatus = .connected
    @Published public var lastForegroundDate: Date?
    @Published public var backgroundDuration: TimeInterval = 0
    @Published public var appLaunchTime: Date
    
    // MARK: - Types
    public enum NetworkStatus {
        case connected
        case disconnected
        case connecting
        
        var displayName: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting"
            }
        }
    }
    
    // MARK: - Singleton
    public static let shared = AppStateMonitor()
    
    // MARK: - Private Properties
    private var backgroundStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        self.appLaunchTime = Date()
        setupNotifications()
        startNetworkMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Get app uptime since launch
    public var appUptime: TimeInterval {
        Date().timeIntervalSince(appLaunchTime)
    }
    
    /// Get formatted uptime string
    public var formattedUptime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: appUptime) ?? "0s"
    }
    
    /// Check if app has been in background for extended period
    public var hasBeenInBackgroundLong: Bool {
        return backgroundDuration > 300 // 5 minutes
    }
    
    // MARK: - Private Implementation
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func startNetworkMonitoring() {
        // This is a simplified network monitoring
        // In a real app, you'd use Network framework or similar
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            // Placeholder for network status check
            // self?.checkNetworkStatus()
        }
    }
    
    private func handleAppBecameActive() {
        isActive = true
        isInBackground = false
        lastForegroundDate = Date()
        
        if let backgroundStart = backgroundStartTime {
            backgroundDuration = Date().timeIntervalSince(backgroundStart)
            backgroundStartTime = nil
        }
        
        print("📱 AppStateMonitor: App became active (background duration: \(String(format: "%.1f", backgroundDuration))s)")
    }
    
    private func handleAppWillResignActive() {
        isActive = false
        print("📱 AppStateMonitor: App will resign active")
    }
    
    private func handleAppDidEnterBackground() {
        isInBackground = true
        backgroundStartTime = Date()
        print("📱 AppStateMonitor: App entered background")
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 AppStateMonitor: App will enter foreground")
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Performance Extensions

extension View {
    /// Measure the performance of view updates
    public func measurePerformance(_ operation: String, context: String? = nil) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.startTiming(operation, context: context)
        }
        .onDisappear {
            PerformanceMonitor.shared.endTiming(operation, context: context)
        }
    }
    
    /// Track view load time
    public func trackViewLoad(_ viewName: String) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.measure("ViewLoad", context: viewName) {
                // View appeared
            }
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension PerformanceMonitor {
    /// Generate test performance data
    public func generateTestData() {
        let operations = ["DataLoad", "UIUpdate", "NetworkRequest", "DatabaseQuery", "ImageProcessing"]
        let contexts = ["UserAction", "BackgroundSync", "AppLaunch", "SettingsChange"]
        
        for _ in 0..<50 {
            let operation = operations.randomElement()!
            let context = contexts.randomElement()!
            let duration = TimeInterval.random(in: 0.01...2.0)
            
            let metric = PerformanceMetric(
                operation: operation,
                duration: duration,
                context: context,
                memoryUsage: UInt64.random(in: 50_000_000...200_000_000)
            )
            
            metricsHistory.append(metric)
            currentMetrics.append(metric)
            
            if duration > slowOperationThreshold {
                slowOperations.append(metric)
            }
        }
        
        // Generate test system metrics
        for _ in 0..<10 {
            let systemMetric = SystemMetrics(
                memoryUsage: UInt64.random(in: 100_000_000...500_000_000),
                memoryPressure: SystemMetrics.MemoryPressure.allCases.randomElement()!,
                cpuUsage: Double.random(in: 0...100),
                diskSpace: SystemMetrics.DiskSpace(
                    available: UInt64.random(in: 1_000_000_000...10_000_000_000),
                    total: 32_000_000_000
                ),
                batteryLevel: Float.random(in: 0.1...1.0),
                thermalState: .nominal,
                timestamp: Date().addingTimeInterval(-TimeInterval.random(in: 0...3600))
            )
            
            systemMetricsHistory.append(systemMetric)
        }
        
        // Keep arrays at reasonable size
        if currentMetrics.count > 50 {
            currentMetrics.removeFirst(currentMetrics.count - 50)
        }
        if slowOperations.count > 10 {
            slowOperations.removeFirst(slowOperations.count - 10)
        }
        
        updateOverallPerformanceScore()
        
        print("📊 PerformanceMonitor: Generated test data")
    }
    
    /// Create mock shared data manager
    public static func createMockSharedDataManager() -> SharedDataManager {
        return SharedDataManager.shared
    }
    
    /// Create mock theme manager
    public static func createMockThemeManager() -> ThemeManager {
        return ThemeManager.shared
    }
    
    /// Create mock budget manager
    public static func createMockBudgetManager() -> BudgetManager {
        return BudgetManager.shared
    }
    
    /// Simulate performance issues for testing
    public func simulatePerformanceIssues() {
        // Simulate slow operations
        for _ in 0..<5 {
            let slowMetric = PerformanceMetric(
                operation: "SlowOperation",
                duration: TimeInterval.random(in: 2.0...5.0),
                context: "SimulatedIssue",
                memoryUsage: UInt64.random(in: 300_000_000...800_000_000)
            )
            
            metricsHistory.append(slowMetric)
            slowOperations.append(slowMetric)
        }
        
        // Simulate memory warnings
        memoryWarnings.append(Date())
        memoryWarnings.append(Date().addingTimeInterval(-300))
        
        // Update performance score
        updateOverallPerformanceScore()
        
        print("⚠️ PerformanceMonitor: Simulated performance issues")
    }
    
    /// Clear test data
    public func clearTestData() {
        clearPerformanceData()
        print("🧹 PerformanceMonitor: Cleared test data")
    }
    
    /// Get performance insights for debugging
    public func getDebugInsights() -> [String: Any] {
        return metricsQueue.sync {
            let totalMetrics = metricsHistory.count
            let slowMetrics = metricsHistory.filter { $0.duration > slowOperationThreshold }.count
            let averageDuration = metricsHistory.isEmpty ? 0 : metricsHistory.reduce(0) { $0 + $1.duration } / Double(metricsHistory.count)
            
            let operationCounts = Dictionary(grouping: metricsHistory, by: \.operation)
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            return [
                "totalMetrics": totalMetrics,
                "slowMetrics": slowMetrics,
                "averageDuration": averageDuration,
                "topOperations": operationCounts.prefix(5).map { "\($0.key): \($0.value)" },
                "memoryWarnings": memoryWarnings.count,
                "overallScore": overallPerformanceScore,
                "isMonitoring": isMonitoring,
                "activeOperations": activeOperations.count
            ]
        }
    }
}

// MARK: - Performance Dashboard View

#if DEBUG
public struct PerformanceDashboard: View {
    @ObservedObject private var performanceMonitor = PerformanceMonitor.shared
    @ObservedObject private var appStateMonitor = AppStateMonitor.shared
    @State private var selectedTimeRange: TimePeriod = .last7Days
    @State private var showingDetailedReport = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                // Current Status Section
                Section("Current Status") {
                    StatusCard(
                        title: "Performance Score",
                        value: "\(Int(performanceMonitor.overallPerformanceScore * 100))%",
                        color: performanceMonitor.overallPerformanceScore > 0.8 ? .green : .orange,
                        systemImage: "speedometer"
                    )
                    
                    StatusCard(
                        title: "App State",
                        value: appStateMonitor.isActive ? "Active" : "Background",
                        color: appStateMonitor.isActive ? .green : .gray,
                        systemImage: "app.badge"
                    )
                    
                    StatusCard(
                        title: "Uptime",
                        value: appStateMonitor.formattedUptime,
                        color: .blue,
                        systemImage: "clock"
                    )
                    
                    if let systemMetrics = performanceMonitor.systemMetrics {
                        StatusCard(
                            title: "Memory",
                            value: ByteCountFormatter.string(fromByteCount: Int64(systemMetrics.memoryUsage), countStyle: .memory),
                            color: systemMetrics.memoryPressure.color,
                            systemImage: "memorychip"
                        )
                    }
                }
                
                // Recent Metrics Section
                Section("Recent Operations") {
                    if performanceMonitor.currentMetrics.isEmpty {
                        Text("No recent operations")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(performanceMonitor.currentMetrics.suffix(5).reversed(), id: \.timestamp) { metric in
                            MetricRow(metric: metric)
                        }
                    }
                }
                
                // Slow Operations Section
                if !performanceMonitor.slowOperations.isEmpty {
                    Section("Slow Operations") {
                        ForEach(performanceMonitor.slowOperations.suffix(5).reversed(), id: \.timestamp) { metric in
                            MetricRow(metric: metric, isHighlighted: true)
                        }
                    }
                }
                
                // Memory Warnings Section
                if !performanceMonitor.memoryWarnings.isEmpty {
                    Section("Memory Warnings") {
                        ForEach(performanceMonitor.memoryWarnings.suffix(5).reversed(), id: \.self) { date in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading) {
                                    Text("Memory Warning")
                                        .font(.subheadline)
                                    Text(date.formattedRelative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                // Controls Section
                Section("Controls") {
                    Button(action: {
                        if performanceMonitor.isMonitoring {
                            performanceMonitor.stopMonitoring()
                        } else {
                            performanceMonitor.startMonitoring()
                        }
                    }) {
                        Label(
                            performanceMonitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                            systemImage: performanceMonitor.isMonitoring ? "stop.circle" : "play.circle"
                        )
                    }
                    
                    Button("Generate Test Data") {
                        performanceMonitor.generateTestData()
                    }
                    
                    Button("Simulate Issues") {
                        performanceMonitor.simulatePerformanceIssues()
                    }
                    
                    Button("Clear Data") {
                        performanceMonitor.clearTestData()
                    }
                    .foregroundColor(.red)
                    
                    Button("Detailed Report") {
                        showingDetailedReport = true
                    }
                }
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingDetailedReport) {
            PerformanceReportView(timeRange: selectedTimeRange)
        }
    }
}

// MARK: - Supporting Dashboard Views

private struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct MetricRow: View {
    let metric: PerformanceMonitor.PerformanceMetric
    let isHighlighted: Bool
    
    init(metric: PerformanceMonitor.PerformanceMetric, isHighlighted: Bool = false) {
        self.metric = metric
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.operation)
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .semibold : .regular)
                
                if let context = metric.context {
                    Text(context)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(metric.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(metric.performanceRating.color)
                    .fontWeight(.medium)
                
                Text(metric.performanceRating.rawValue)
                    .font(.caption)
                    .foregroundColor(metric.performanceRating.color)
            }
        }
        .padding(.vertical, 2)
        .background(isHighlighted ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Performance Report View

private struct PerformanceReportView: View {
    let timeRange: TimePeriod
    @State private var report: PerformanceMonitor.PerformanceReport?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let report = report {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Overview Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Overview")
                                .font(.headline)
                            
                            ReportCard(
                                title: "Performance Score",
                                value: "\(Int(report.performanceScore * 100))%",
                                subtitle: report.overallRating.rawValue,
                                color: report.overallRating.color
                            )
                            
                            ReportCard(
                                title: "Operations Tracked",
                                value: "\(report.metrics.count)",
                                subtitle: "Total operations",
                                color: .blue
                            )
                            
                            ReportCard(
                                title: "Average Duration",
                                value: String(format: "%.0fms", (report.metrics.reduce(0) { $0 + $1.duration } / Double(report.metrics.count)) * 1000),
                                subtitle: "Per operation",
                                color: .purple
                            )
                        }
                        
                        // Slowest Operations
                        if !report.slowestOperations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Slowest Operations")
                                    .font(.headline)
                                
                                ForEach(report.slowestOperations.prefix(5), id: \.timestamp) { metric in
                                    MetricRow(metric: metric, isHighlighted: true)
                                }
                            }
                        }
                        
                        // Recommendations
                        if !report.recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recommendations")
                                    .font(.headline)
                                
                                ForEach(report.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text(recommendation)
                                            .font(.subheadline)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        // Operation Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Operation Breakdown")
                                .font(.headline)
                            
                            ForEach(report.averageDurations.sorted(by: { $0.value > $1.value }), id: \.key) { operation, avgDuration in
                                HStack {
                                    Text(operation)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.0fms avg", avgDuration * 1000))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    ProgressView("Generating Report...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            generateReport()
        }
    }
    
    private func generateReport() {
        Task {
            let generatedReport = PerformanceMonitor.shared.getPerformanceReport(for: timeRange)
            await MainActor.run {
                report = generatedReport
            }
        }
    }
}

private struct ReportCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
#endif
