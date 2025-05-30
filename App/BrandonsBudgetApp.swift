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
    @StateObject private var settingsManager = SettingsManager.shared

    
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
                _ = try await NotificationManager.shared.requestAuthorization()
                await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
            } catch {
                print("Failed to setup notifications: \(error.localizedDescription)")
            }
        }
    }
    
    private func registerForAppStateNotifications() {
        // Save data when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Force save Core Data contexts
            do {
                try CoreDataManager.shared.forceSaveSync()
                print("Successfully saved data before going to background")
            } catch {
                print("Failed to save data before going to background: \(error.localizedDescription)")
            }
        }
        
        // Additional save when entering background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            do {
                try CoreDataManager.shared.forceSaveSync()
                print("Successfully saved data when entering background")
            } catch {
                print("Failed to save data when entering background: \(error.localizedDescription)")
            }
        }
        
        // Save when app will terminate
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            do {
                try CoreDataManager.shared.forceSaveSync()
                print("Successfully saved data before termination")
            } catch {
                print("Failed to save data before termination: \(error.localizedDescription)")
            }
        }
        
        // Refresh data when becoming active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                do {
                    _ = try await CoreDataManager.shared.getAllEntries()
                    print("Successfully refreshed data when becoming active")
                } catch {
                    print("Failed to refresh data when becoming active: \(error.localizedDescription)")
                }
            }
        }
    }

    private func removeAppStateNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
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
