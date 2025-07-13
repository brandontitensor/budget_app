//
//  PerformanceMonitor.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//

import Foundation
import SwiftUI
import Combine
import UIKit

// Required imports for system monitoring
#if canImport(Darwin)
import Darwin
import mach
#endif

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
    @Published public private(set) var overallPerformanceScore: Double = 1.0
    
    // MARK: - Private Properties
    private var metricsHistory: [PerformanceMetric] = []
    private var activeTimers: [String: Date] = [:]
    private let maxHistoryCount = 1000
    private let slowOperationThreshold: TimeInterval = 1.0
    
    private let monitoringQueue = DispatchQueue(label: "com.brandonsbudget.performance", qos: .utility)
    private var systemMonitoringTimer: Timer?
    
    private init() {
        setupSystemMonitoring()
        print("✅ PerformanceMonitor: Initialized")
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start performance monitoring
    public func startMonitoring() {
        isMonitoring = true
        startSystemMetricsCollection()
        print("📊 PerformanceMonitor: Monitoring started")
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        isMonitoring = false
        systemMonitoringTimer?.invalidate()
        systemMonitoringTimer = nil
        print("⏹️ PerformanceMonitor: Monitoring stopped")
    }
    
    /// Start timing an operation
    public func startTiming(_ operation: String, context: String? = nil) {
        let key = context != nil ? "\(operation)_\(context!)" : operation
        activeTimers[key] = Date()
    }
    
    /// End timing an operation
    @discardableResult
    public func endTiming(_ operation: String, context: String? = nil) -> TimeInterval? {
        let key = context != nil ? "\(operation)_\(context!)" : operation
        
        guard let startTime = activeTimers.removeValue(forKey: key) else {
            print("⚠️ PerformanceMonitor: No start time found for operation: \(operation)")
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            context: context,
            memoryUsage: getCurrentMemoryUsage()
        )
        
        addMetric(metric)
        return duration
    }
    
    /// Measure execution time of a closure
    @discardableResult
    public func measure<T>(_ operation: String, context: String? = nil, _ closure: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try closure()
        let duration = Date().timeIntervalSince(startTime)
        
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            context: context,
            memoryUsage: getCurrentMemoryUsage()
        )
        
        addMetric(metric)
        return result
    }
    
    /// Measure execution time of an async closure
    @discardableResult
    public func measureAsync<T>(_ operation: String, context: String? = nil, _ closure: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await closure()
        let duration = Date().timeIntervalSince(startTime)
        
        let metric = PerformanceMetric(
            operation: operation,
            duration: duration,
            context: context,
            memoryUsage: getCurrentMemoryUsage()
        )
        
        await MainActor.run {
            addMetric(metric)
        }
        
        return result
    }
    
    /// Generate performance report
    public func generateReport(for timeRange: DateInterval? = nil) -> PerformanceReport {
        let range = timeRange ?? DateInterval(start: Date().addingTimeInterval(-3600), end: Date()) // Last hour
        let relevantMetrics = metricsHistory.filter { range.contains($0.timestamp) }
        
        let slowest = relevantMetrics.sorted { $0.duration > $1.duration }.prefix(10)
        let averages = Dictionary(grouping: relevantMetrics) { $0.operation }
            .mapValues { metrics in
                metrics.reduce(0) { $0 + $1.duration } / Double(metrics.count)
            }
        
        let score = calculatePerformanceScore(for: relevantMetrics)
        let recommendations = generateRecommendations(for: relevantMetrics)
        
        return PerformanceReport(
            timeRange: range,
            metrics: relevantMetrics,
            systemMetrics: [],
            slowestOperations: Array(slowest),
            averageDurations: averages,
            performanceScore: score,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }
    
    /// Clear all metrics
    public func clearMetrics() {
        metricsHistory.removeAll()
        currentMetrics.removeAll()
        slowOperations.removeAll()
        overallPerformanceScore = 1.0
        print("🧹 PerformanceMonitor: Metrics cleared")
    }
    
    // MARK: - Private Methods
    
    private func setupSystemMonitoring() {
        // Initial system metrics collection
        collectSystemMetrics()
    }
    
    private func startSystemMetricsCollection() {
        systemMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.collectSystemMetrics()
        }
    }
    
    private func addMetric(_ metric: PerformanceMetric) {
        metricsHistory.append(metric)
        currentMetrics.append(metric)
        
        // Maintain size limits
        if metricsHistory.count > maxHistoryCount {
            metricsHistory.removeFirst(metricsHistory.count - maxHistoryCount)
        }
        
        if currentMetrics.count > 50 {
            currentMetrics.removeFirst(currentMetrics.count - 50)
        }
        
        // Track slow operations
        if metric.duration > slowOperationThreshold {
            slowOperations.append(metric)
            if slowOperations.count > 20 {
                slowOperations.removeFirst(slowOperations.count - 20)
            }
        }
        
        // Update overall score
        updateOverallPerformanceScore()
    }
    
    private func updateOverallPerformanceScore() {
        guard !metricsHistory.isEmpty else {
            overallPerformanceScore = 1.0
            return
        }
        
        let recentMetrics = metricsHistory.suffix(100) // Last 100 operations
        let averageDuration = recentMetrics.reduce(0) { $0 + $1.duration } / Double(recentMetrics.count)
        
        // Score based on average duration (lower is better)
        if averageDuration < 0.1 {
            overallPerformanceScore = 1.0
        } else if averageDuration < 0.5 {
            overallPerformanceScore = 0.8
        } else if averageDuration < 1.0 {
            overallPerformanceScore = 0.6
        } else {
            overallPerformanceScore = 0.4
        }
    }
    
    private func collectSystemMetrics() {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = SystemMetrics(
                memoryUsage: self.getCurrentMemoryUsage(),
                memoryPressure: self.getCurrentMemoryPressure(),
                cpuUsage: self.getCurrentCPUUsage(),
                diskSpace: self.getDiskSpace(),
                batteryLevel: self.getBatteryLevel(),
                thermalState: ProcessInfo.processInfo.thermalState,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                self.systemMetrics = metrics
            }
        }
    }
    
    private func calculatePerformanceScore(for metrics: [PerformanceMetric]) -> Double {
        guard !metrics.isEmpty else { return 1.0 }
        
        let averageDuration = metrics.reduce(0) { $0 + $1.duration } / Double(metrics.count)
        let slowOperationsCount = metrics.filter { $0.duration > slowOperationThreshold }.count
        
        let durationScore = max(0, 1.0 - (averageDuration / 2.0)) // Normalize to 2 seconds max
        let slowOpsScore = max(0, 1.0 - (Double(slowOperationsCount) / Double(metrics.count)))
        
        return (durationScore + slowOpsScore) / 2.0
    }
    
    private func generateRecommendations(for metrics: [PerformanceMetric]) -> [String] {
        var recommendations: [String] = []
        
        // Analyze slow operations
        let slowOps = metrics.filter { $0.duration > slowOperationThreshold }
        if !slowOps.isEmpty {
            let operationCounts = Dictionary(grouping: slowOps, by: { $0.operation })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            if let topSlowOp = operationCounts.first {
                recommendations.append("Consider optimizing '\(topSlowOp.key)' operation (\(topSlowOp.value) slow instances)")
            }
        }
        
        // Analyze memory usage
        if let latestSystemMetric = systemMetrics {
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
        #if canImport(Darwin)
        // Alternative implementation without PROCESSOR_CPU_LOAD_INFO_COUNT
        let HOST_CPU_LOAD_INFO_COUNT: mach_msg_type_number_t = 4
        var cpuInfo = host_cpu_load_info()
        var count = HOST_CPU_LOAD_INFO_COUNT
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userTicks = cpuInfo.cpu_ticks.0
            let systemTicks = cpuInfo.cpu_ticks.1
            let idleTicks = cpuInfo.cpu_ticks.2
            let niceTicks = cpuInfo.cpu_ticks.3
            
            let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
            
            if totalTicks > 0 {
                return Double(totalTicks - idleTicks) / Double(totalTicks) * 100
            }
        }
        #endif
        
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

// MARK: - Performance Dashboard View

public struct PerformanceDashboardView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var selectedTimeRange = TimeRange.lastHour
    
    private enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case lastDay = "Last Day"
        case lastWeek = "Last Week"
        
        var interval: DateInterval {
            let now = Date()
            switch self {
            case .lastHour:
                return DateInterval(start: now.addingTimeInterval(-3600), end: now)
            case .lastDay:
                return DateInterval(start: now.addingTimeInterval(-86400), end: now)
            case .lastWeek:
                return DateInterval(start: now.addingTimeInterval(-604800), end: now)
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    overviewSection
                    currentMetricsSection
                    systemHealthSection
                }
                .padding()
            }
            .navigationTitle("Performance Monitor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(range.rawValue) {
                                selectedTimeRange = range
                            }
                        }
                    } label: {
                        Label("Time Range", systemImage: "clock")
                    }
                }
            }
        }
    }
    
    private var overviewSection: some View {
        VStack(spacing: 12) {
            Text("Performance Overview")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatusCard(
                    title: "Score",
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
                ForEach(Array(performanceMonitor.currentMetrics.suffix(10).enumerated()), id: \.offset) { _, metric in
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
                Text("System metrics unavailable")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

private struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

private struct MetricRow: View {
    let metric: PerformanceMonitor.PerformanceMetric
    let isHighlighted: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
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
            
            VStack(alignment: .trailing) {
                Text(metric.formattedDuration)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(metric.performanceRating.color)
                
                Text(metric.thread)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isHighlighted ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(4)
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
        
        updateOverallPerformanceScore()
        print("📊 PerformanceMonitor: Test data generated")
    }
    
    /// Reset for testing
    public func resetForTesting() {
        clearMetrics()
        activeTimers.removeAll()
        systemMetrics = nil
    }
}
#endif
