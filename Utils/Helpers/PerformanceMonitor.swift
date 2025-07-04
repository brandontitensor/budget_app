//
//  PerformanceMonitor.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//  Enhanced version with comprehensive performance tracking and Swift 6 compliance
//

import Foundation
import SwiftUI
import Combine

// MARK: - Performance Monitoring

/// Comprehensive performance monitoring system for the app with Swift 6 concurrency support
@MainActor
public final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Types
    
    public struct PerformanceMetric: Identifiable, Sendable {
        public let id = UUID()
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
    
    public enum PerformanceRating: String, CaseIterable, Sendable {
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
    
    public struct SystemMetrics: Sendable {
        public let memoryUsage: UInt64
        public let memoryPressure: MemoryPressure
        public let cpuUsage: Double
        public let diskSpace: DiskSpace
        public let batteryLevel: Float
        public let thermalState: ProcessInfo.ThermalState
        public let timestamp: Date
        
        public enum MemoryPressure: String, CaseIterable, Sendable {
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
        
        public struct DiskSpace: Sendable {
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
    
    public struct PerformanceReport: Sendable {
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
        
        let key = context != nil ? "\(operation)_\(context!)" : operation
        activeOperations[key] = Date()
    }
    
    /// End timing an operation and return duration
    @discardableResult
    public func endTiming(_ operation: String, context: String? = nil) -> TimeInterval? {
        guard isMonitoring else { return nil }
        
        let endTime = Date()
        let key = context != nil ? "\(operation)_\(context!)" : operation
        
        guard let startTime = activeOperations.removeValue(forKey: key) else {
            print("⚠️ PerformanceMonitor: No start time found for operation '\(operation)'")
            return nil
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            context: context,
            memoryUsage: getCurrentMemoryUsage()
        )
        
        addMetric(metric)
        return duration
    }
    
    /// Measure a block of code
    public func measure<T>(_ operation: String, context: String? = nil, block: () throws -> T) rethrows -> T {
        startTiming(operation, context: context)
        defer { endTiming(operation, context: context) }
        return try block()
    }
    
    /// Measure an async block of code
    public func measureAsync<T>(_ operation: String, context: String? = nil, block: () async throws -> T) async rethrows -> T {
        startTiming(operation, context: context)
        defer { endTiming(operation, context: context) }
        return try await block()
    }
    
    /// Generate a performance report for a given time range
    public func generateReport(for timeInterval: TimeInterval = 3600) -> PerformanceReport {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeInterval)
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        let filteredMetrics = metricsHistory.filter { metric in
            dateRange.contains(metric.timestamp)
        }
        
        let filteredSystemMetrics = systemMetricsHistory.filter { metric in
            dateRange.contains(metric.timestamp)
        }
        
        let slowestOps = filteredMetrics
            .sorted { $0.duration > $1.duration }
            .prefix(10)
            .map { $0 }
        
        let averages = calculateAverageDurations(from: filteredMetrics)
        let score = calculatePerformanceScore(from: filteredMetrics)
        let recommendations = generateRecommendations(from: filteredMetrics, systemMetrics: filteredSystemMetrics)
        
        return PerformanceReport(
            timeRange: dateRange,
            metrics: filteredMetrics,
            systemMetrics: filteredSystemMetrics,
            slowestOperations: slowestOps,
            averageDurations: averages,
            performanceScore: score,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func addMetric(_ metric: PerformanceMetric) {
        metricsHistory.append(metric)
        currentMetrics.append(metric)
        
        // Limit current metrics to last 20
        if currentMetrics.count > 20 {
            currentMetrics.removeFirst()
        }
        
        // Track slow operations
        if metric.duration > slowOperationThreshold {
            slowOperations.append(metric)
            if slowOperations.count > 50 {
                slowOperations.removeFirst()
            }
        }
        
        // Update performance score
        updatePerformanceScore()
        
        #if DEBUG
        if metric.duration > slowOperationThreshold {
            print("🐌 Slow operation: \(metric.operation) took \(metric.formattedDuration)")
        }
        #endif
    }
    
    private func startSystemMetricsCollection() {
        systemTimer = Timer.scheduledTimer(withTimeInterval: systemMetricsInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.collectSystemMetrics()
            }
        }
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performCleanup()
            }
        }
    }
    
    private func collectSystemMetrics() {
        let metrics = SystemMetrics(
            memoryUsage: getCurrentMemoryUsage(),
            memoryPressure: getCurrentMemoryPressure(),
            cpuUsage: getCurrentCPUUsage(),
            diskSpace: getDiskSpace(),
            batteryLevel: getBatteryLevel(),
            thermalState: ProcessInfo.processInfo.thermalState,
            timestamp: Date()
        )
        
        systemMetrics = metrics
        systemMetricsHistory.append(metrics)
        
        // Limit system metrics history
        if systemMetricsHistory.count > maxSystemMetricsHistory {
            systemMetricsHistory.removeFirst()
        }
    }
    
    private func performCleanup() {
        // Clean old metrics
        if metricsHistory.count > maxMetricsHistory {
            let excess = metricsHistory.count - maxMetricsHistory
            metricsHistory.removeFirst(excess)
        }
        
        // Clean old memory warnings
        let oneHourAgo = Date().addingTimeInterval(-3600)
        memoryWarnings.removeAll { $0 < oneHourAgo }
        
        // Clean old slow operations
        let oneDayAgo = Date().addingTimeInterval(-86400)
        slowOperations.removeAll { $0.timestamp < oneDayAgo }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupThermalStateObserver() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleThermalStateChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceScoreCalculation() {
        // Update performance score every minute
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePerformanceScore()
            }
        }
    }
    
    private func handleMemoryWarning() {
        memoryWarnings.append(Date())
        print("⚠️ Memory warning received at \(Date())")
        
        // Trigger cleanup
        performCleanup()
    }
    
    private func handleThermalStateChange() {
        let state = ProcessInfo.processInfo.thermalState
        print("🌡️ Thermal state changed to: \(state)")
        
        if state == .critical {
            // Reduce monitoring frequency during critical thermal state
            systemTimer?.invalidate()
            systemTimer = Timer.scheduledTimer(withTimeInterval: systemMetricsInterval * 2, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.collectSystemMetrics()
                }
            }
        }
    }
    
    private func updatePerformanceScore() {
        let recentMetrics = metricsHistory.suffix(100)
        guard !recentMetrics.isEmpty else {
            overallPerformanceScore = 1.0
            return
        }
        
        let averageDuration = recentMetrics.map { $0.duration }.reduce(0, +) / Double(recentMetrics.count)
        let slowOperationsRatio = Double(recentMetrics.filter { $0.duration > slowOperationThreshold }.count) / Double(recentMetrics.count)
        
        // Calculate score based on average duration and slow operations ratio
        let durationScore = max(0, 1.0 - (averageDuration / 2.0)) // Normalize to 2 seconds max
        let slowOpsScore = 1.0 - slowOperationsRatio
        
        overallPerformanceScore = (durationScore + slowOpsScore) / 2.0
    }
    
    private func calculateAverageDurations(from metrics: [PerformanceMetric]) -> [String: TimeInterval] {
        var operationDurations: [String: [TimeInterval]] = [:]
        
        for metric in metrics {
            operationDurations[metric.operation, default: []].append(metric.duration)
        }
        
        return operationDurations.mapValues { durations in
            durations.reduce(0, +) / Double(durations.count)
        }
    }
    
    private func calculatePerformanceScore(from metrics: [PerformanceMetric]) -> Double {
        guard !metrics.isEmpty else { return 1.0 }
        
        let totalDuration = metrics.map { $0.duration }.reduce(0, +)
        let averageDuration = totalDuration / Double(metrics.count)
        let slowOperationsCount = metrics.filter { $0.duration > slowOperationThreshold }.count
        let slowOperationsRatio = Double(slowOperationsCount) / Double(metrics.count)
        
        // Score calculation (lower is better)
        let durationScore = max(0, 1.0 - (averageDuration / 2.0))
        let slowOpsScore = 1.0 - slowOperationsRatio
        
        return (durationScore + slowOpsScore) / 2.0
    }
    
    private func generateRecommendations(from metrics: [PerformanceMetric], systemMetrics: [SystemMetrics]) -> [String] {
        var recommendations: [String] = []
        
        // Analyze slow operations
        let slowOps = metrics.filter { $0.duration > slowOperationThreshold }
        if !slowOps.isEmpty {
            let operationCounts = Dictionary(grouping: slowOps) { $0.operation }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            if let topSlowOp = operationCounts.first {
                recommendations.append("Consider optimizing '\(topSlowOp.key)' operation (\(topSlowOp.value) slow instances)")
            }
        }
        
        // Analyze memory usage
        if let latestSystemMetric = systemMetrics.last {
            if latestSystemMetric.memoryPressure == .critical {
                recommendations.append("Critical memory pressure detected - consider reducing memory usage")
            } else if latestSystemMetric.memoryPressure == .warning {
                recommendations.append("Memory pressure warning - monitor memory-intensive operations")
            }
            
            if latestSystemMetric.diskSpace.usedPercentage > 90 {
                recommendations.append("Low disk space - consider cleaning up temporary files")
            }
            
            if latestSystemMetric.cpuUsage > 80 {
                recommendations.append("High CPU usage detected - consider optimizing computational tasks")
            }
        }
        
        // General recommendations
        if metrics.count > 500 {
            recommendations.append("High operation frequency - consider batching operations where possible")
        }
        
        return recommendations
    }
    
    // MARK: - System Metrics Helpers
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCurrentMemoryPressure() -> SystemMetrics.MemoryPressure {
        let memoryUsage = getCurrentMemoryUsage()
        let memoryMB = Double(memoryUsage) / (1024 * 1024)
        
        if memoryMB > 1000 {
            return .critical
        } else if memoryMB > 500 {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: Int(PROCESSOR_CPU_LOAD_INFO_COUNT))
        var numCpuInfo = mach_msg_type_number_t(PROCESSOR_CPU_LOAD_INFO_COUNT)
        let numCpus = UInt32(ProcessInfo.processInfo.processorCount)
        
        defer {
            info.deallocate()
        }
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        if result == KERN_SUCCESS {
            let cpuInfo = UnsafeBufferPointer(start: info, count: Int(numCpuInfo))
            var totalTicks: UInt32 = 0
            var idleTicks: UInt32 = 0
            
            for i in stride(from: 0, to: Int(numCpuInfo), by: Int(CPU_STATE_MAX)) {
                totalTicks += cpuInfo[i + Int(CPU_STATE_USER)]
                totalTicks += cpuInfo[i + Int(CPU_STATE_SYSTEM)]
                totalTicks += cpuInfo[i + Int(CPU_STATE_NICE)]
                totalTicks += cpuInfo[i + Int(CPU_STATE_IDLE)]
                idleTicks += cpuInfo[i + Int(CPU_STATE_IDLE)]
            }
            
            if totalTicks > 0 {
                return Double(totalTicks - idleTicks) / Double(totalTicks) * 100
            }
        }
        
        return 0.0
    }
    
    private func getDiskSpace() -> SystemMetrics.DiskSpace {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
            let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
            return SystemMetrics.DiskSpace(available: freeSpace, total: totalSpace)
        }
        return SystemMetrics.DiskSpace(available: 0, total: 0)
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
}

// MARK: - SwiftUI Integration

public extension View {
    /// Track performance for a view operation
    func trackPerformance(_ operation: String, context: String? = nil) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.startTiming(operation, context: context)
        }
        .onDisappear {
            PerformanceMonitor.shared.endTiming(operation, context: context)
        }
    }
    
    /// Track view load time
    func trackViewLoad(_ viewName: String) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.measure("ViewLoad", context: viewName) {
                // View appeared
            }
        }
    }
}

// MARK: - Debug Features

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
        
        updatePerformanceScore()
    }
    
    /// Clear test data
    public func clearTestData() {
        metricsHistory.removeAll()
        currentMetrics.removeAll()
        slowOperations.removeAll()
        systemMetricsHistory.removeAll()
        overallPerformanceScore = 1.0
    }
    
    /// Simulate performance issues for testing
    public func simulatePerformanceIssues() {
        // Add some slow operations
        for i in 1...5 {
            let metric = PerformanceMetric(
                operation: "SlowOperation\(i)",
                duration: TimeInterval.random(in: 2.0...5.0),
                context: "SimulatedIssue"
            )
            currentMetrics.append(metric)
            slowOperations.append(metric)
        }
        
        // Simulate memory warnings
        memoryWarnings.append(Date())
        
        updatePerformanceScore()
    }
}

// MARK: - Performance Monitoring Dashboard View

/// SwiftUI view for monitoring performance in real-time during development
struct PerformanceMonitorDashboard: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var selectedTimeRange: TimeInterval = 3600 // 1 hour
    @State private var showingDetailedReport = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Performance Overview
                    performanceOverviewSection
                    
                    // Current Metrics
                    currentMetricsSection
                    
                    // System Health
                    systemHealthSection
                    
                    // Controls
                    controlsSection
                }
                .padding()
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingDetailedReport) {
            PerformanceReportView(timeRange: selectedTimeRange)
        }
    }
    
    private var performanceOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Overview")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatusCard(
                    title: "Overall Score",
                    value: "\(Int(performanceMonitor.overallPerformanceScore * 100))%",
                    color: performanceMonitor.overallPerformanceScore > 0.8 ? .green :
                           performanceMonitor.overallPerformanceScore > 0.6 ? .orange : .red,
                    systemImage: "speedometer"
                )
                
                StatusCard(
                    title: "Slow Operations",
                    value: "\(performanceMonitor.slowOperations.count)",
                    color: performanceMonitor.slowOperations.isEmpty ? .green : .red,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var currentMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Operations")
                .font(.headline)
            
            if performanceMonitor.currentMetrics.isEmpty {
                Text("No recent operations")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(performanceMonitor.currentMetrics.suffix(10), id: \.id) { metric in
                    MetricRow(metric: metric, isHighlighted: metric.duration > 1.0)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health")
                .font(.headline)
            
            if let systemMetrics = performanceMonitor.systemMetrics {
                VStack(spacing: 8) {
                    StatusCard(
                        title: "Memory",
                        value: ByteCountFormatter.string(fromByteCount: Int64(systemMetrics.memoryUsage), countStyle: .memory),
                        color: systemMetrics.memoryPressure.color,
                        systemImage: "memorychip"
                    )
                    
                    StatusCard(
                        title: "CPU",
                        value: String(format: "%.1f%%", systemMetrics.cpuUsage),
                        color: systemMetrics.cpuUsage > 80 ? .red : systemMetrics.cpuUsage > 60 ? .orange : .green,
                        systemImage: "cpu"
                    )
                    
                    StatusCard(
                        title: "Storage",
                        value: systemMetrics.diskSpace.availableFormatted,
                        color: systemMetrics.diskSpace.usedPercentage > 90 ? .red :
                               systemMetrics.diskSpace.usedPercentage > 75 ? .orange : .green,
                        systemImage: "internaldrive"
                    )
                }
            } else {
                Text("No system metrics available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button {
                    if performanceMonitor.isMonitoring {
                        performanceMonitor.stopMonitoring()
                    } else {
                        performanceMonitor.startMonitoring()
                    }
                } label: {
                    Label(
                        performanceMonitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                        systemImage: performanceMonitor.isMonitoring ? "stop.circle" : "play.circle"
                    )
                }
                
                Button("Generate Test Data") {
                    performanceMonitor.generateTestData()
                }
                
                Button("Clear Data") {
                    performanceMonitor.clearTestData()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

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
                    .fontWeight(.medium)
                    .foregroundColor(metric.performanceRating.color)
                
                Text(metric.thread)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .background(isHighlighted ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct PerformanceReportView: View {
    let timeRange: TimeInterval
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Report")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    let report = performanceMonitor.generateReport(for: timeRange)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                        
                        Text(report.summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Rating:")
                            Text(report.overallRating.rawValue)
                                .foregroundColor(report.overallRating.color)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if !report.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(.headline)
                            
                            ForEach(report.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.orange)
                                    Text(recommendation)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
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
    }
}
#endif
