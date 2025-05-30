//
//  BrandonsBudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 5/30/25 - Added centralized error handling and improved lifecycle management
//

import SwiftUI
import UserNotifications

@main
struct BrandonsBudgetApp: App {
    // MARK: - State Objects
    @StateObject private var budgetManager = BudgetManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    
    // MARK: - App State
    @Environment(\.scenePhase) private var scenePhase
    @State private var appStateMonitor = AppStateMonitor.shared
    
    // MARK: - Scene Configuration
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetManager)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .environmentObject(errorHandler)
                .environmentObject(appStateMonitor)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onAppear {
                    setupAppOnLaunch()
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
                .errorAlert(onRetry: {
                    // Global retry handler - refresh app data
                    Task {
                        await refreshAppData()
                    }
                })
        }
    }
    
    // MARK: - App Lifecycle Methods
    
    /// Setup app on initial launch
    private func setupAppOnLaunch() {
        Task {
            await performInitialSetup()
        }
    }
    
    /// Perform initial app setup
    private func performInitialSetup() async {
        do {
            // Setup appearance
            setupAppearance()
            
            // Setup notifications
            await setupNotifications()
            
            // Load initial data
            await loadInitialData()
            
            // Setup data persistence
            setupDataPersistence()
            
            print("✅ App setup completed successfully")
        } catch {
            await MainActor.run {
                errorHandler.handle(
                    AppError.from(error),
                    context: "App initialization"
                )
            }
        }
    }
    
    /// Setup global UI appearance
    private func setupAppearance() {
        // Configure navigation bar appearance
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithDefaultBackground()
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(themeManager.primaryColor)
        ]
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(themeManager.primaryColor)
        ]
        
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure tint colors
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(themeManager.primaryColor)
    }
    
    /// Setup notification system
    private func setupNotifications() async {
        do {
            let isAuthorized = await NotificationManager.shared.checkNotificationStatus()
            
            if isAuthorized || settingsManager.notificationsAllowed {
                try await NotificationManager.shared.requestAuthorization()
                await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
                print("✅ Notifications setup completed")
            }
        } catch {
            await MainActor.run {
                errorHandler.handle(
                    .permission(type: .notifications),
                    context: "Setting up notifications"
                )
            }
        }
    }
    
    /// Load initial app data
    private func loadInitialData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Loading initial app data"
        ) {
            // Load budget manager data
            budgetManager.loadData()
            
            // Update widget data
            budgetManager.updateWidgetData()
            
            // Clean up old exports
            CSVExport.cleanupOldExports()
        }
        
        if result != nil {
            print("✅ Initial data loaded successfully")
        }
    }
    
    /// Setup data persistence mechanisms
    private func setupDataPersistence() {
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleMemoryWarning()
        }
        
        // Register for background refresh
        NotificationCenter.default.addObserver(
            forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleBackgroundRefreshStatusChange()
        }
    }
    
    // MARK: - Scene Phase Handling
    
    /// Handle scene phase changes
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            handleAppEnteringBackground()
        case .inactive:
            handleAppBecamingInactive()
        case .active:
            handleAppBecamingActive(from: oldPhase)
        @unknown default:
            break
        }
    }
    
    /// Handle app entering background
    private func handleAppEnteringBackground() {
        print("📱 App entering background - saving data")
        
        Task {
            await performBackgroundTasks()
        }
    }
    
    /// Handle app becoming inactive
    private func handleAppBecamingInactive() {
        print("📱 App becoming inactive")
        
        Task {
            await saveAppData(context: "App becoming inactive")
        }
    }
    
    /// Handle app becoming active
    private func handleAppBecamingActive(from oldPhase: ScenePhase) {
        print("📱 App becoming active")
        
        // Update app state
        appStateMonitor.isActive = true
        appStateMonitor.isInBackground = false
        
        // Refresh data if returning from background
        if oldPhase == .background {
            Task {
                await refreshAppData()
            }
        }
    }
    
    /// Handle app will terminate
    private func handleAppWillTerminate() {
        print("📱 App will terminate - performing final save")
        
        // Perform synchronous save for app termination
        do {
            try CoreDataManager.shared.forceSaveSync()
            print("✅ Final save completed successfully")
        } catch {
            print("❌ Failed to perform final save: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Tasks
    
    /// Perform background tasks
    private func performBackgroundTasks() async {
        // Save app data
        await saveAppData(context: "Background tasks")
        
        // Update widget data
        await MainActor.run {
            budgetManager.updateWidgetData()
        }
        
        // Clean up temporary files
        await cleanupTemporaryFiles()
        
        // Update notification schedules if needed
        await updateNotificationSchedules()
    }
    
    /// Save app data with error handling
    private func saveAppData(context: String) async {
        let result = await AsyncErrorHandler.execute(
            context: context,
            errorTransform: { .dataSave(underlying: $0) }
        ) {
            try await CoreDataManager.shared.forceSave()
        }
        
        if result != nil {
            print("✅ App data saved successfully - \(context)")
        }
    }
    
    /// Refresh app data
    private func refreshAppData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing app data"
        ) {
            // Refresh budget manager data
            budgetManager.loadData()
            
            // Check for unsaved changes and save if needed
            let hasUnsavedChanges = await CoreDataManager.shared.hasUnsavedChanges()
            if hasUnsavedChanges {
                try await CoreDataManager.shared.forceSave()
            }
        }
        
        if result != nil {
            print("🔄 App data refreshed successfully")
        }
    }
    
    /// Clean up temporary files
    private func cleanupTemporaryFiles() async {
        await AsyncErrorHandler.execute(
            context: "Cleaning up temporary files"
        ) {
            // Clean up old CSV exports
            CSVExport.cleanupOldExports()
            
            // Clean up cache files if needed
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            if let cacheURL = cacheURL {
                let fileManager = FileManager.default
                let cacheContents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                
                // Remove files older than 7 days
                let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                cacheContents?.forEach { fileURL in
                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                        if let creationDate = attributes[.creationDate] as? Date,
                           creationDate < sevenDaysAgo {
                            try fileManager.removeItem(at: fileURL)
                        }
                    } catch {
                        // Ignore individual file cleanup errors
                    }
                }
            }
        }
    }
    
    /// Update notification schedules
    private func updateNotificationSchedules() async {
        if settingsManager.notificationsAllowed {
            await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
        }
    }
    
    // MARK: - System Event Handlers
    
    /// Handle memory warning
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received")
        
        Task {
            // Save current data
            await saveAppData(context: "Memory warning")
            
            // Clear error history to free memory
            await MainActor.run {
                errorHandler.clearHistory()
            }
            
            // Suggest garbage collection
            autoreleasepool {
                // Force any autorelease objects to be released
            }
        }
    }
    
    /// Handle background refresh status change
    private func handleBackgroundRefreshStatusChange() {
        let status = UIApplication.shared.backgroundRefreshStatus
        print("📱 Background refresh status changed: \(status.rawValue)")
        
        switch status {
        case .available:
            print("✅ Background refresh is available")
        case .denied:
            print("❌ Background refresh is denied")
            // Optionally notify user about impact on data sync
        case .restricted:
            print("⚠️ Background refresh is restricted")
        @unknown default:
            break
        }
    }
    
    // MARK: - Error Recovery
    
    /// Global error recovery method
    private func performErrorRecovery() async {
        print("🔄 Performing error recovery")
        
        // Try to recover from errors by refreshing data
        await refreshAppData()
        
        // Reset error state
        await MainActor.run {
            errorHandler.clearError()
        }
        
        // Update UI
        await MainActor.run {
            budgetManager.objectWillChange.send()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Clean up observers
        NotificationCenter.default.removeObserver(self)
        print("📱 App cleanup completed")
    }
}

// MARK: - App Extensions

extension BrandonsBudgetApp {
    /// Get app version information
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// Get app build number
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// Get app name
    var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Brandon's Budget"
    }
}

// MARK: - Background Task Support

extension BrandonsBudgetApp {
    /// Register background tasks
    private func registerBackgroundTasks() {
        // Register background app refresh task
        #if !targetEnvironment(simulator)
        // Background task registration would go here for production
        #endif
    }
}

// MARK: - Deep Link Handling

extension BrandonsBudgetApp {
    /// Handle deep link URLs
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "brandonsbudget" else { return }
        
        // Deep link handling would be implemented here
        // This would coordinate with ContentView's deep link handling
        print("🔗 Deep link received: \(url)")
    }
}

// MARK: - Preview Support

#if DEBUG
extension BrandonsBudgetApp {
    /// Create a preview-friendly version of the app
    static func createPreview() -> BrandonsBudgetApp {
        let app = BrandonsBudgetApp()
        
        // Setup test data for previews
        Task {
            await app.budgetManager.loadTestData()
        }
        
        return app
    }
}

struct BrandonsBudgetApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(AppStateMonitor.shared)
    }
}
#endif
