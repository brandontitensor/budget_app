//
//  BrandonsBudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
//

import SwiftUI

@main
struct BrandonsBudgetApp: App {
    // MARK: - State Objects
    @StateObject private var budgetManager = BudgetManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager(userDefaults: .standard, notificationManager: .shared)
    
    // MARK: - Scene Configuration
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetManager)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onAppear {
                    setupAppearance()
                    setupNotifications()
                    registerForAppStateNotifications()
                }
                .onDisappear {
                    removeAppStateNotifications()
                }
        }
    }
    
    // MARK: - Setup Methods
    private func setupAppearance() {
        // Configure global UI appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(themeManager.primaryColor)
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor(themeManager.primaryColor)
        ]
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
    
    private func setupNotifications() {
        Task {
            do {
                try await NotificationManager.shared.requestAuthorization()
                await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
            } catch {
                print("Failed to setup notifications: \(error.localizedDescription)")
            }
        }
    }
    
    private func registerForAppStateNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Just let Core Data's auto-save handle background transitions
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Load fresh data from Core Data storage
            Task {
                do {
                    let entries = try await CoreDataManager.shared.getAllEntries()
                    // Core Data will automatically merge changes into the main context
                } catch {
                    print("Failed to reload data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func removeAppStateNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Preview Testing Support
#if DEBUG
extension BrandonsBudgetApp {
    /// Create a testable version of the app
    static func createPreview() -> BrandonsBudgetApp {
        return BrandonsBudgetApp()
    }
}
#endif
