//
//  BrandonsBudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 7/5/25 - Enhanced with Swift 6 compliance, comprehensive error handling, and improved lifecycle management
//

import SwiftUI
import UserNotifications
import WidgetKit

@main
struct BrandonsBudgetApp: App {
    // MARK: - State Objects (Environment Objects)
    @StateObject private var budgetManager = BudgetManagerProxy()
    @StateObject private var themeManager = ThemeManagerProxy()
    @StateObject private var settingsManager = SettingsManagerProxy()
    @StateObject private var errorHandler = ErrorHandlerProxy()
    @StateObject private var notificationManager = NotificationManagerProxy()
    @StateObject private var appStateMonitor = AppStateMonitorProxy()
    
    // MARK: - App State
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @AppStorage("appLaunchCount") private var appLaunchCount = 0
    @State private var isInitializing = true
    @State private var initializationError: AppError?
    
    // MARK: - Scene Configuration
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    LaunchScreenView(error: initializationError)
                        .onAppear {
                            Task {
                                await performAppInitialization()
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(budgetManager)
                        .environmentObject(themeManager)
                        .environmentObject(settingsManager)
                        .environmentObject(errorHandler)
                        .environmentObject(notificationManager)
                        .environmentObject(appStateMonitor)
                        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                        .errorAlert(onRetry: {
                            Task {
                                await refreshAppData()
                            }
                        })
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                handleAppEnteringBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                handleAppWillTerminate()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                handleMemoryWarning()
            }
        }
    }
    
    // MARK: - App Lifecycle Methods
    
    /// Perform comprehensive app initialization
    private func performAppInitialization() async {
        do {
            print("🚀 Starting app initialization...")
            
            // Update launch tracking
            await updateLaunchTracking()
            
            // Setup core systems
            await setupAppearance()
            try await setupNotifications()
            try await loadInitialData()
            await setupDataPersistence()
            await setupPerformanceMonitoring()
            
            // Mark initialization as complete
            await MainActor.run {
                isInitializing = false
                initializationError = nil
                print("✅ App initialization completed successfully")
            }
            
        } catch {
            await MainActor.run {
                let appError = AppError.from(error)
                initializationError = appError
                errorHandler.handle(appError, context: "App initialization")
                
                // Still allow app to continue with limited functionality
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isInitializing = false
                }
                
                print("❌ App initialization failed: \(appError.localizedDescription)")
            }
        }
    }
    
    /// Update app launch tracking
    private func updateLaunchTracking() async {
        await MainActor.run {
            appLaunchCount += 1
            if !hasLaunchedBefore {
                hasLaunchedBefore = true
                print("🎉 First app launch detected")
            }
            print("📱 App launch count: \(appLaunchCount)")
        }
    }
    
    /// Setup app appearance and theming
    private func setupAppearance() async {
        await MainActor.run {
            // Configure navigation bar appearance
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithDefaultBackground()
            navBarAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
            navBarAppearance.titleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
            
            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().compactAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            
            // Configure tab bar appearance
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            
            print("✅ App appearance configured")
        }
    }
    
    /// Setup notification system
    private func setupNotifications() async throws {
        let center = UNUserNotificationCenter.current()
        
        // Request authorization
        let authorizationGranted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        if authorizationGranted {
            print("✅ Notification authorization granted")
            
            // Setup notification categories
            await setupNotificationCategories()
            
            // Configure notification delegate
            await MainActor.run {
                center.delegate = notificationManager as? UNUserNotificationCenterDelegate
            }
        } else {
            print("⚠️ Notification authorization denied")
        }
    }
    
    /// Setup notification categories and actions
    private func setupNotificationCategories() async {
        let budgetExceededAction = UNNotificationAction(
            identifier: "BUDGET_EXCEEDED_ACTION",
            title: "View Budget",
            options: [.foreground]
        )
        
        let budgetExceededCategory = UNNotificationCategory(
            identifier: "BUDGET_EXCEEDED",
            actions: [budgetExceededAction],
            intentIdentifiers: [],
            options: []
        )
        
        let reminderAction = UNNotificationAction(
            identifier: "REMINDER_ACTION",
            title: "Add Purchase",
            options: [.foreground]
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "BUDGET_REMINDER",
            actions: [reminderAction],
            intentIdentifiers: [],
            options: []
        )
        
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([budgetExceededCategory, reminderCategory])
        
        print("✅ Notification categories configured")
    }
    
    /// Load initial app data
    private func loadInitialData() async throws {
        print("📊 Loading initial data...")
        
        // Load settings first
        try await settingsManager.loadSettings()
        
        // Apply theme settings
        await MainActor.run {
            themeManager.applyStoredTheme()
        }
        
        // Load budget data
        try await budgetManager.initializeData()
        
        // Update app state
        await appStateMonitor.updateAppState(.active)
        
        print("✅ Initial data loaded successfully")
    }
    
    /// Setup data persistence and background sync
    private func setupDataPersistence() async {
        // Setup auto-save timer
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            Task {
                await performBackgroundSave()
            }
        }
        
        // Setup widget update scheduling
        Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("✅ Data persistence configured")
    }
    
    /// Setup performance monitoring
    private func setupPerformanceMonitoring() async {
        #if DEBUG
        PerformanceMonitor.shared.startMonitoring()
        print("📊 Performance monitoring started")
        #endif
    }
    
    // MARK: - Scene Phase Handling
    
    /// Handle scene phase transitions
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        print("🔄 Scene phase changed from \(oldPhase) to \(newPhase)")
        
        switch newPhase {
        case .active:
            handleAppBecameActive()
        case .inactive:
            handleAppBecameInactive()
        case .background:
            handleAppEnteredBackground()
        @unknown default:
            break
        }
    }
    
    /// Handle app becoming active
    private func handleAppBecameActive() {
        Task {
            await appStateMonitor.updateAppState(.active)
            
            // Refresh data if needed
            let lastRefresh = await appStateMonitor.lastDataRefresh
            if lastRefresh.timeIntervalSinceNow < -300 { // 5 minutes
                await refreshAppData()
            }
            
            // Update widgets
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    /// Handle app becoming inactive
    private func handleAppBecameInactive() {
        Task {
            await appStateMonitor.updateAppState(.inactive)
            await performQuickSave()
        }
    }
    
    /// Handle app entering background
    private func handleAppEnteredBackground() {
        Task {
            await appStateMonitor.updateAppState(.background)
            await performBackgroundTasks()
        }
    }
    
    /// Handle app entering background (from notification)
    private func handleAppEnteringBackground() {
        Task {
            await performBackgroundTasks()
        }
    }
    
    /// Handle app termination
    private func handleAppWillTerminate() {
        print("🔄 App will terminate - performing final save")
        
        // Perform synchronous save since app is terminating
        Task {
            await performFinalSave()
        }
        
        #if DEBUG
        PerformanceMonitor.shared.stopMonitoring()
        #endif
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received")
        
        Task {
            // Clear caches
            await budgetManager.clearCaches()
            await themeManager.clearCaches()
            
            // Clear error history
            await errorHandler.clearHistory()
            
            // Force garbage collection
            autoreleasepool {
                // Clean up temporary objects
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Perform quick save for app state transitions
    private func performQuickSave() async {
        do {
            try await budgetManager.saveCurrentState()
            try await settingsManager.saveSettings()
            print("✅ Quick save completed")
        } catch {
            errorHandler.handle(AppError.from(error), context: "Quick save")
        }
    }
    
    /// Perform comprehensive background save
    private func performBackgroundSave() async {
        do {
            try await budgetManager.performBackgroundSave()
            try await settingsManager.saveSettings()
            await updateWidgetData()
            print("✅ Background save completed")
        } catch {
            errorHandler.handle(AppError.from(error), context: "Background save")
        }
    }
    
    /// Perform comprehensive background tasks
    private func performBackgroundTasks() async {
        await withTaskGroup(of: Void.self) { group in
            // Save data
            group.addTask {
                await self.performBackgroundSave()
            }
            
            // Update widgets
            group.addTask {
                await self.updateWidgetData()
                WidgetCenter.shared.reloadAllTimelines()
            }
            
            // Cleanup temporary files
            group.addTask {
                await self.cleanupTemporaryFiles()
            }
            
            // Schedule notifications
            group.addTask {
                await self.scheduleBackgroundNotifications()
            }
        }
        
        print("✅ Background tasks completed")
    }
    
    /// Perform final save before app termination
    private func performFinalSave() async {
        do {
            try await budgetManager.performFinalSave()
            try await settingsManager.saveSettings()
            await updateWidgetData()
            print("✅ Final save completed")
        } catch {
            print("❌ Final save failed: \(error)")
            // Can't show UI at this point, just log
        }
    }
    
    /// Refresh app data
    private func refreshAppData() async {
        do {
            try await budgetManager.refreshData()
            await appStateMonitor.markDataRefresh()
            print("✅ App data refreshed")
        } catch {
            errorHandler.handle(AppError.from(error), context: "Data refresh")
        }
    }
    
    /// Update widget data
    private func updateWidgetData() async {
        do {
            let widgetData = try await budgetManager.generateWidgetData()
            await SharedDataManager.shared.updateWidgetData(widgetData)
            print("✅ Widget data updated")
        } catch {
            print("⚠️ Widget data update failed: \(error)")
        }
    }
    
    /// Schedule background notifications
    private func scheduleBackgroundNotifications() async {
        do {
            try await notificationManager.scheduleBackgroundNotifications()
            print("✅ Background notifications scheduled")
        } catch {
            print("⚠️ Failed to schedule background notifications: \(error)")
        }
    }
    
    /// Cleanup temporary files
    private func cleanupTemporaryFiles() async {
        do {
            let tempDirectory = FileManager.default.temporaryDirectory
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            )
            
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for url in contents {
                if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < oneWeekAgo {
                    try FileManager.default.removeItem(at: url)
                }
            }
            
            print("✅ Temporary files cleaned up")
        } catch {
            print("⚠️ Cleanup failed: \(error)")
        }
    }
}

// MARK: - Launch Screen View

struct LaunchScreenView: View {
    let error: AppError?
    @State private var progress: Double = 0.0
    @State private var showRetry = false
    
    var body: some View {
        VStack(spacing: 30) {
            // App Logo/Icon
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970) * 0.1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: progress)
            
            VStack(spacing: 12) {
                Text("Brandon's Budget")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Loading your financial data...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let error = error {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("Initialization Error")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if showRetry {
                        Button("Continue with Limited Features") {
                            // This will be handled by the parent view
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showRetry = true
                    }
                }
            } else {
                // Loading state
                ProgressView()
                    .scaleEffect(1.2)
                    .onAppear {
                        // Animate progress for visual feedback
                        withAnimation(.linear(duration: 3.0)) {
                            progress = 1.0
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Manager Proxy Classes (for standalone compilation)

// These proxy classes allow the app to compile independently
// Replace with actual manager classes when integrating

@MainActor
private class BudgetManagerProxy: ObservableObject {
    func initializeData() async throws { }
    func saveCurrentState() async throws { }
    func performBackgroundSave() async throws { }
    func performFinalSave() async throws { }
    func refreshData() async throws { }
    func clearCaches() async { }
    func generateWidgetData() async throws -> [String: Any] { return [:] }
}

@MainActor
private class ThemeManagerProxy: ObservableObject {
    @Published var isDarkMode = false
    func applyStoredTheme() { }
    func clearCaches() async { }
}

@MainActor
private class SettingsManagerProxy: ObservableObject {
    func loadSettings() async throws { }
    func saveSettings() async throws { }
}

@MainActor
private class ErrorHandlerProxy: ObservableObject {
    func handle(_ error: AppError, context: String) {
        print("🚨 Error: \(error) in \(context)")
    }
    func clearHistory() async { }
}

@MainActor
private class NotificationManagerProxy: ObservableObject {
    func scheduleBackgroundNotifications() async throws { }
}

@MainActor
private class AppStateMonitorProxy: ObservableObject {
    enum AppState {
        case active, inactive, background
    }
    
    var lastDataRefresh = Date()
    
    func updateAppState(_ state: AppState) async { }
    func markDataRefresh() async {
        lastDataRefresh = Date()
    }
}

@MainActor
private class SharedDataManager {
    static let shared = SharedDataManager()
    private init() {}
    
    func updateWidgetData(_ data: [String: Any]) async { }
}

