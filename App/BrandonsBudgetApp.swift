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
    @StateObject private var budgetManager = BudgetManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var appStateMonitor = AppStateMonitor.shared
    
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
                        .environmentObject(appStateMonitor)
                        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                        .tint(themeManager.primaryColor)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                Task {
                    await handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                Task {
                    await handleAppWillTerminate()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                Task {
                    await handleMemoryWarning()
                }
            }
        }
    }
    
    // MARK: - App Initialization
    
    /// Perform complete app initialization
    private func performAppInitialization() async {
        do {
            // Track app launch
            await MainActor.run {
                appLaunchCount += 1
                print("🚀 App Launch #\(appLaunchCount)")
            }
            
            // Setup app on launch
            await setupAppOnLaunch()
            
            // Perform initial setup
            await performInitialSetup()
            
            // Setup data persistence
            await setupDataPersistence()
            
            // Setup performance monitoring
            await setupPerformanceMonitoring()
            
            // Mark initialization complete
            await MainActor.run {
                isInitializing = false
                hasLaunchedBefore = true
            }
            
            print("✅ App initialization completed successfully")
            
        } catch {
            let appError = AppError.from(error)
            await MainActor.run {
                initializationError = appError
                errorHandler.handle(appError, context: "App initialization")
            }
            
            // Allow user to continue with limited functionality
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                isInitializing = false
            }
        }
    }
    
    /// Setup app on launch
    private func setupAppOnLaunch() async {
        // Apply stored theme
        await MainActor.run {
            themeManager.applyStoredTheme()
        }
        
        // Configure global appearance
        configureGlobalAppearance()
        
        // Initialize app state monitoring
        await appStateMonitor.updateAppState(.launching)
        
        // Set manager dependencies
        appStateMonitor.setDependencies(budgetManager: budgetManager, errorHandler: errorHandler)
    }
    
    /// Perform initial setup tasks
    private func performInitialSetup() async {
        await withTaskGroup(of: Void.self) { group in
            // Setup notifications
            group.addTask {
                await self.setupNotifications()
            }
            
            // Load data
            group.addTask {
                await self.loadInitialData()
            }
            
            // Load settings
            group.addTask {
                await self.loadSettings()
            }
        }
    }
    
    /// Setup notifications
    private func setupNotifications() async {
        let result = await AsyncErrorHandler.execute(
            context: "Setting up notifications"
        ) {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            if settings.authorizationStatus == .notDetermined {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                print(granted ? "✅ Notifications authorized" : "❌ Notifications denied")
            }
            
            return true
        }
        
        if result != nil {
            print("✅ Notification setup completed")
        }
    }
    
    /// Load initial data
    private func loadInitialData() async {
        await budgetManager.loadData()
        await appStateMonitor.markDataRefresh()
        print("✅ Initial data loaded")
    }
    
    /// Load settings
    private func loadSettings() async {
        let result = await AsyncErrorHandler.execute(
            context: "Loading settings"
        ) {
            try await settingsManager.loadSettings()
            return true
        }
        
        if result != nil {
            print("✅ Settings loaded")
        }
    }
    
    /// Configure global app appearance
    private func configureGlobalAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        print("✅ Global appearance configured")
    }
    
    /// Setup data persistence
    private func setupDataPersistence() async {
        // Configure automatic widget updates
        Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("✅ Data persistence configured")
    }
    
    /// Setup performance monitoring
    private func setupPerformanceMonitoring() async {
        #if DEBUG
        // Performance monitoring would be initialized here
        print("📊 Performance monitoring started")
        #endif
    }
    
    // MARK: - Scene Phase Handling
    
    /// Handle scene phase transitions
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) async {
        print("🔄 Scene phase changed from \(String(describing: oldPhase)) to \(String(describing: newPhase))")
        
        switch newPhase {
        case .active:
            await handleAppBecameActive()
        case .inactive:
            await handleAppBecameInactive()
        case .background:
            await handleAppEnteredBackground()
        @unknown default:
            break
        }
    }
    
    /// Handle app becoming active
    private func handleAppBecameActive() async {
        await appStateMonitor.updateAppState(.active)
        
        // Refresh data if needed
        if appStateMonitor.shouldRefreshData() {
            await refreshAppData()
        }
        
        // Update widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Handle app becoming inactive
    private func handleAppBecameInactive() async {
        await appStateMonitor.updateAppState(.inactive)
        await performQuickSave()
    }
    
    /// Handle app entering background
    private func handleAppEnteredBackground() async {
        await appStateMonitor.updateAppState(.background)
        await performBackgroundTasks()
    }
    
    /// Handle app termination
    private func handleAppWillTerminate() async {
        print("🔄 App will terminate - performing final save")
        
        await appStateMonitor.updateAppState(.terminating)
        
        // Perform synchronous save since app is terminating
        await performFinalSave()
        
        #if DEBUG
        print("📊 App termination cleanup completed")
        #endif
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() async {
        print("⚠️ Memory warning received")
        
        await withTaskGroup(of: Void.self) { group in
            // Clear caches
            group.addTask {
                await self.budgetManager.clearCaches()
            }
            
            group.addTask {
                await self.themeManager.clearCaches()
            }
            
            // Clear error history
            group.addTask {
                await self.errorHandler.clearHistory()
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Perform quick save for app state transitions
    private func performQuickSave() async {
        let result = await AsyncErrorHandler.execute(
            context: "Quick save"
        ) {
            try await budgetManager.saveCurrentState()
            try await settingsManager.saveSettings()
            return true
        }
        
        if result != nil {
            print("✅ Quick save completed")
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
        }
        
        print("✅ Background tasks completed")
    }
    
    /// Perform background save
    private func performBackgroundSave() async {
        let result = await AsyncErrorHandler.execute(
            context: "Background save"
        ) {
            try await budgetManager.performBackgroundSave()
            try await settingsManager.saveSettings()
            return true
        }
        
        if result != nil {
            print("✅ Background save completed")
        }
    }
    
    /// Perform final save before app termination
    private func performFinalSave() async {
        let result = await AsyncErrorHandler.execute(
            context: "Final save"
        ) {
            try await budgetManager.performFinalSave()
            try await settingsManager.saveSettings()
            return true
        }
        
        if result != nil {
            await updateWidgetData()
            print("✅ Final save completed")
        }
    }
    
    /// Refresh app data
    private func refreshAppData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Data refresh"
        ) {
            await budgetManager.refreshData()
            await appStateMonitor.markDataRefresh()
            return true
        }
        
        if result != nil {
            print("✅ App data refreshed")
        }
    }
    
    /// Update widget data
    private func updateWidgetData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Widget data update"
        ) {
            let widgetData = try await budgetManager.generateWidgetData()
            await SharedDataManager.shared.updateWidgetData(widgetData)
            return true
        }
        
        if result != nil {
            print("✅ Widget data updated")
        }
    }
    
    /// Cleanup temporary files
    private func cleanupTemporaryFiles() async {
        let result = await AsyncErrorHandler.executeSilently(
            context: "Cleanup temporary files"
        ) {
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
            
            return true
        }
        
        if result != nil {
            print("✅ Temporary files cleaned up")
        }
    }
}

// MARK: - Launch Screen View

struct LaunchScreenView: View {
    let error: AppError?
    @State private var showRetry = false
    @State private var progress = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(error != nil ? 1.0 : (0.8 + progress * 0.2))
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: progress)
            
            VStack(spacing: 12) {
                Text("Brandon's Budget")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let error = error {
                    VStack(spacing: 16) {
                        Text("⚠️ Initialization Error")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text(error.localizedDescription)
                            .font(.body)
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
                    VStack(spacing: 8) {
                        Text("Setting up your budget...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Manager Classes (for standalone compilation)

// These are simplified versions that allow the app to compile independently
// Replace with actual manager classes when integrating

#if DEBUG
// Preview support
@MainActor
private class PreviewBudgetManager: ObservableObject {
    static let shared = PreviewBudgetManager()
    func loadData() async { }
    func saveCurrentState() async throws { }
    func performBackgroundSave() async throws { }
    func performFinalSave() async throws { }
    func refreshData() async { }
    func clearCaches() async { }
    func generateWidgetData() async throws -> [String: Any] { return [:] }
}

@MainActor
private class PreviewThemeManager: ObservableObject {
    static let shared = PreviewThemeManager()
    @Published var isDarkMode = false
    @Published var primaryColor = Color.blue
    func applyStoredTheme() { }
    func clearCaches() async { }
}

@MainActor
private class PreviewSettingsManager: ObservableObject {
    static let shared = PreviewSettingsManager()
    func loadSettings() async throws { }
    func saveSettings() async throws { }
}

@MainActor
private class PreviewErrorHandler: ObservableObject {
    static let shared = PreviewErrorHandler()
    func handle(_ error: AppError, context: String) {
        print("🚨 Error: \(error) in \(context)")
    }
    func clearHistory() async { }
}

@MainActor
private class PreviewAppStateMonitor: ObservableObject {
    static let shared = PreviewAppStateMonitor()
    
    enum AppState {
        case active, inactive, background, launching, terminating
    }
    
    func updateAppState(_ state: AppState) async { }
    func markDataRefresh() async { }
    func shouldRefreshData() -> Bool { return false }
    func setDependencies(budgetManager: Any, errorHandler: Any) { }
}

private class PreviewSharedDataManager {
    static let shared = PreviewSharedDataManager()
    func updateWidgetData(_ data: [String: Any]) async { }
}
#endif
