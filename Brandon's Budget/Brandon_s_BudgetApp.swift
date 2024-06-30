//
//  Brandon_s_BudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
//
//  Brandon_s_BudgetApp.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

@main
struct BrandonsBudgetApp: App {
    @StateObject private var budgetManager = BudgetManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var settingsManager = SettingsManager()
    @State private var showingAddPurchase = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(budgetManager)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onAppear {
                    setupAppearance()
                    requestNotificationAuthorization()
                }
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .sheet(isPresented: $showingAddPurchase) {
                    PurchaseEntryView()
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "brandonsbudget" else { return }
        
        if url.host == "addPurchase" {
            DispatchQueue.main.async {
                self.showingAddPurchase = true
            }
        }
    }
    
    private func setupAppearance() {
        // Configure global app appearance here
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.primaryColor)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(themeManager.primaryColor)]
    }
    
    private func requestNotificationAuthorization() {
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                self.settingsManager.notificationsAllowed = granted
                if granted {
                    self.settingsManager.purchaseNotificationsEnabled = true
                    self.settingsManager.budgetTotalNotificationsEnabled = true
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: self.settingsManager)
                } else {
                    self.settingsManager.purchaseNotificationsEnabled = false
                    self.settingsManager.budgetTotalNotificationsEnabled = false
                }
            }
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false {
        didSet {
            updateColors()
        }
    }
    
    @Published var primaryColor: Color = .blue
    @Published var secondaryColor: Color = .green
    @Published var backgroundColor: Color = .white
    @Published var textColor: Color = .black
    
    init() {
        updateColors()
    }
    
    private func updateColors() {
        if isDarkMode {
            backgroundColor = .black
            textColor = .white
        } else {
            backgroundColor = .white
            textColor = .black
        }
    }
    
    struct ColorOption: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let color: Color
    }
    
    static let availableColors: [ColorOption] = [
        ColorOption(name: "Blue", color: .blue),
        ColorOption(name: "Green", color: .green),
        ColorOption(name: "Red", color: .red),
        ColorOption(name: "Purple", color: .purple),
        ColorOption(name: "Orange", color: .orange)
    ]
    
    func resetToDefaults() {
        primaryColor = .blue
        secondaryColor = .green
        isDarkMode = false
        updateColors()
    }
}
class SettingsManager: ObservableObject {
    @AppStorage("userName") var userName: String = "User"
    @AppStorage("defaultCurrency") var defaultCurrency: String = "USD"
    
    @AppStorage("notificationsAllowed") var notificationsAllowed: Bool = false
    @AppStorage("purchaseNotificationsEnabled") var purchaseNotificationsEnabled: Bool = true
    @AppStorage("purchaseNotificationFrequency") var purchaseNotificationFrequency: PurchaseNotificationFrequency = .weekly
    
    @AppStorage("budgetTotalNotificationsEnabled") var budgetTotalNotificationsEnabled: Bool = true
    @AppStorage("budgetTotalNotificationFrequency") var budgetTotalNotificationFrequency: BudgetTotalNotificationFrequency = .monthly
    
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true

    enum PurchaseNotificationFrequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    enum BudgetTotalNotificationFrequency: String, CaseIterable {
        case monthly = "First of the Month"
        case yearly = "First of the Year"
    }
    
    func resetToDefaults() {
        userName = "User"
        defaultCurrency = "USD"
        purchaseNotificationsEnabled = true
        purchaseNotificationFrequency = .weekly
        budgetTotalNotificationsEnabled = true
        budgetTotalNotificationFrequency = .monthly
        isFirstLaunch = true
    }
}

