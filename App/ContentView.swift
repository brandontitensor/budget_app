//
//  ContentView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

/// Main container view for the app
struct ContentView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showingAddPurchase = false
    @State private var showingUpdateBudget = false
    @State private var showingWelcomePopup = false
    @State private var showingNotificationAlert = false
    @State private var isProcessing = false
    
    // MARK: - Constants
    private let tabItems: [(String, String, AnyView)] = [
        ("Overview", "chart.pie.fill", AnyView(BudgetOverviewView())),
        ("Purchases", "cart.fill", AnyView(PurchasesView())),
        ("History", "clock.fill", AnyView(BudgetHistoryView())),
        ("Settings", "gear", AnyView(SettingsView()))
    ]
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    NavigationView {
                        tabItems[index].2
                    }
                    .tint(themeManager.primaryColor)
                    .tabItem {
                        Label(tabItems[index].0, systemImage: tabItems[index].1)
                            .environment(\.symbolVariants, selectedTab == index ? .fill : .none)
                    }
                    .tag(index)
                }
            }
            .onAppear {
                configureTabBarAppearance()
            }
            .tint(themeManager.primaryColor)
            .disabled(isProcessing)
            
            // FAB for Overview and History tabs
            if selectedTab == 0 || selectedTab == 2 {
                FloatingActionButton(
                    showingAddPurchase: $showingAddPurchase,
                    showingUpdateBudget: $showingUpdateBudget,
                    isEnabled: !isProcessing
                )
                .padding(.bottom, 85)
                .padding(.trailing, 20)
            }
        }
        .sheet(isPresented: $showingAddPurchase) {
            PurchaseEntryView()
        }
        .sheet(isPresented: $showingUpdateBudget) {
            BudgetView()
        }
        .sheet(isPresented: $showingWelcomePopup) {
            WelcomePopupView(isPresented: $showingWelcomePopup)
        }
        .alert("Enable Notifications", isPresented: $showingNotificationAlert) {
            Button("Yes") {
                requestNotificationPermission()
            }
            Button("Not Now") {
                settingsManager.updateNotificationSettings(
                    allowed: false,
                    purchaseEnabled: false,
                    purchaseFrequency: .daily,
                    budgetEnabled: false,
                    budgetFrequency: .monthly
                )
            }
        } message: {
            Text("Would you like to receive notifications about your budget and purchases?")
        }
        .onAppear {
            checkFirstLaunchAndNotifications()
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    // MARK: - Helper Methods
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "brandonsbudget" else { return }
        
        switch url.host {
        case "addPurchase":
            showingAddPurchase = true
        case "updateBudget":
            showingUpdateBudget = true
        default:
            break
        }
    }
    
    private func checkFirstLaunchAndNotifications() {
        if settingsManager.isFirstLaunch {
            showingWelcomePopup = true
        } else {
            Task {
                let isAuthorized = await NotificationManager.shared.checkNotificationStatus()
                if !isAuthorized {
                    showingNotificationAlert = true
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        isProcessing = true
        
        Task {
            do {
                let granted = try await NotificationManager.shared.requestAuthorization()
                await MainActor.run {
                    // Update settings using the proper method
                    settingsManager.updateNotificationSettings(
                        allowed: granted,
                        purchaseEnabled: granted,
                        purchaseFrequency: .daily,
                        budgetEnabled: granted,
                        budgetFrequency: .monthly
                    )
                    
                    if granted {
                        Task {
                            await NotificationManager.shared.updateNotificationSchedule(
                                settings: settingsManager
                            )
                        }
                    }
                }
            } catch {
                print("Failed to request notification authorization: \(error.localizedDescription)")
            }
            
            isProcessing = false
        }
    }
}

// Rest of the file remains the same...

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    @Binding var showingAddPurchase: Bool
    @Binding var showingUpdateBudget: Bool
    let isEnabled: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingOptions = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showingOptions {
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            showingOptions = false
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
            }
            
            VStack(alignment: .trailing, spacing: 15) {
                if showingOptions {
                    ActionButton(
                        title: "Add Purchase",
                        systemImage: "cart.fill.badge.plus"
                    ) {
                        showingAddPurchase = true
                        showingOptions = false
                    }
                    
                    ActionButton(
                        title: "Update Budget",
                        systemImage: "dollarsign.circle.fill"
                    ) {
                        showingUpdateBudget = true
                        showingOptions = false
                    }
                }
                
                Button {
                    withAnimation(.spring()) {
                        showingOptions.toggle()
                    }
                } label: {
                    Image(systemName: showingOptions ? "xmark.circle.fill" : "plus.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(themeManager.primaryColor)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                }
                .disabled(!isEnabled)
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(SettingsManager.shared)
        
        ContentView()
            .environmentObject(BudgetManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(SettingsManager.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
