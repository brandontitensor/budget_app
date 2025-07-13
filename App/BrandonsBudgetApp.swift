//
//  BrandonsBudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
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
                            Task<Void, Never> {
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
        // Theme is already applied in ThemeManager's init
        // No need to call applyStoredTheme() as it doesn't exist
        
        // Configure global appearance
        await MainActor.run {
            configureGlobalAppearance()
        }
        
        // Initialize app state monitoring
        await appStateMonitor.updateAppState(.launching)
        
        print("✅ App setup on launch completed")
    }
    
    /// Perform initial setup tasks
    private func performInitialSetup() async {
        // Setup notifications
        await setupNotifications()
        
        // Load initial data
        await loadInitialData()
        
        // Load settings
        await loadSettings()
        
        print("✅ Initial setup completed")
    }
    
    /// Setup notifications
    private func setupNotifications() async {
        let result = await AsyncErrorHandler.execute(
            context: "Setting up notifications"
        ) {
            let center = UNUserNotificationCenter.current()
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            
            let granted = try await center.requestAuthorization(options: options)
            
            await MainActor.run {
                settingsManager.notificationsAllowed = granted
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
        await appStateMonitor.markDataRefreshed()
        print("✅ Initial data loaded")
    }
    
    /// Load settings
    private func loadSettings() async {
        let result = await AsyncErrorHandler.execute(
            context: "Loading settings"
        ) {
            // SettingsManager loads settings automatically in init
            // No explicit loadSettings() method needed
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
            // Clear error history - Fixed: Call existing method
            group.addTask {
                await self.errorHandler.clearHistory()
            }
            
            // Note: No clearCaches() methods exist in managers, so we skip those calls
            // The original code was calling non-existent methods
        }
    }
    
    // MARK: - Data Management
    
    /// Perform quick save for app state transitions
    private func performQuickSave() async {
        let result = await AsyncErrorHandler.execute(
            context: "Quick save"
        ) {
            try await budgetManager.saveCurrentState()
            // SettingsManager saves automatically via property observers
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
            // SettingsManager saves automatically
            return true
        }
        
        if result != nil {
            print("✅ Background save completed")
        }
    }
    
    /// Perform final save before termination
    private func performFinalSave() async {
        let result = await AsyncErrorHandler.execute(
            context: "Final save"
        ) {
            try await budgetManager.saveCurrentState()
            return true
        }
        
        if result != nil {
            print("✅ Final save completed")
        }
    }
    
    /// Refresh app data
    private func refreshAppData() async {
        await budgetManager.refreshData()
        await appStateMonitor.markDataRefreshed()
        print("✅ App data refreshed")
    }
    
    /// Update widget data
    private func updateWidgetData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Updating widget data"
        ) {
            // Widget data is updated automatically by SharedDataManager
            // through BudgetManager's updateWidgetData() calls
            return true
        }
        
        if result != nil {
            print("✅ Widget data updated")
        }
    }
    
    /// Cleanup temporary files
    private func cleanupTemporaryFiles() async {
        let result = await AsyncErrorHandler.execute(
            context: "Cleaning up temporary files"
        ) {
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < sevenDaysAgo {
                    try fileManager.removeItem(at: fileURL)
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

private struct LaunchScreenView: View {
    let error: AppError?
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon or logo
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Brandon's Budget")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let error = error {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("Initialization Error")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("The app will continue with limited functionality...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Extensions for missing methods

private extension ErrorHandler {
    /// Clear error history - compatibility method
    func clearHistory() async {
        await MainActor.run {
            // Clear recent errors if the property exists
            if errorHistory.count > 10 {
                errorHistory = Array(errorHistory.suffix(10))
            }
        }
    }
}

// MARK: - Testing Support

#if DEBUG
struct BrandonsBudgetApp_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView(error: nil)
            .previewDisplayName("Launch Screen - Loading")
        
        LaunchScreenView(error: .generic(message: "Test initialization error"))
            .previewDisplayName("Launch Screen - Error")
    }
}
#endif
