//
//  ContentView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    @State private var showingAddPurchase = false
    @State private var showingUpdateBudget = false
    @State private var showingWelcomePopup = false
    @State private var showingNotificationAlert = false
    
    private let tabItems: [(String, String, AnyView)] = [
        ("Overview", "chart.pie.fill", AnyView(BudgetOverviewView())),
        ("Purchases", "cart.fill", AnyView(PurchasesView())),
        ("History", "clock.fill", AnyView(BudgetHistoryView())),
        ("Settings", "gear", AnyView(SettingsView()))
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    NavigationView {
                        tabItems[index].2
                    }
                    .tabItem {
                        Label(tabItems[index].0, systemImage: tabItems[index].1)
                    }
                    .tag(index)
                }
            }
            .accentColor(themeManager.primaryColor)
            
            if selectedTab != 3 {
                FloatingActionButton(
                    showingAddPurchase: $showingAddPurchase,
                    showingUpdateBudget: $showingUpdateBudget
                )
                .padding(.bottom, 60) // Add padding to avoid overlap with tab bar
            }
        }
        .sheet(isPresented: $showingAddPurchase) {
            PurchaseEntryView()
        }
        .sheet(isPresented: $showingUpdateBudget) {
            UpdateBudgetView()
        }
        .sheet(isPresented: $showingWelcomePopup) {
            WelcomePopupView(isPresented: $showingWelcomePopup)
        }
        .alert("Enable Notifications", isPresented: $showingNotificationAlert) {
            Button("Yes") {
                requestNotificationPermission()
            }
            Button("Not Now") {
                settingsManager.notificationsAllowed = false
            }
        } message: {
            Text("Would you like to receive notifications about your budget and purchases?")
        }
        .onAppear {
            checkFirstLaunchAndNotifications()
        }
    }
    
    private func checkFirstLaunchAndNotifications() {
        if settingsManager.isFirstLaunch {
            showingWelcomePopup = true
        } else if !settingsManager.notificationsAllowed {
            NotificationManager.shared.checkNotificationStatus { isAuthorized in
                DispatchQueue.main.async {
                    if !isAuthorized {
                        showingNotificationAlert = true
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                settingsManager.notificationsAllowed = granted
                if granted {
                    settingsManager.purchaseNotificationsEnabled = true
                    settingsManager.budgetTotalNotificationsEnabled = true
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                } else {
                    settingsManager.purchaseNotificationsEnabled = false
                    settingsManager.budgetTotalNotificationsEnabled = false
                }
            }
        }
    }
}

struct FloatingActionButton: View {
    @Binding var showingAddPurchase: Bool
    @Binding var showingUpdateBudget: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingOptions = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 15) {
            if showingOptions {
                ActionButton(title: "Add Purchase", systemImage: "cart.fill.badge.plus") {
                    showingAddPurchase = true
                    showingOptions = false
                }
                
                ActionButton(title: "Update Budget", systemImage: "dollarsign.circle.fill") {
                    showingUpdateBudget = true
                    showingOptions = false
                }
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    showingOptions.toggle()
                }
            }) {
                Image(systemName: showingOptions ? "xmark.circle.fill" : "plus.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(themeManager.primaryColor)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.spring(), value: showingOptions)
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(20)
            .shadow(radius: 2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BudgetManager())
            .environmentObject(ThemeManager())
            .environmentObject(SettingsManager())
    }
}
