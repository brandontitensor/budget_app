//
//  ContentView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI

/// Main container view for the app with enhanced data persistence and lifecycle management
struct ContentView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showingAddPurchase = false
    @State private var showingUpdateBudget = false
    @State private var showingWelcomePopup = false
    @State private var showingNotificationAlert = false
    @State private var isProcessing = false
    @State private var lastSaveDate: Date?
    @State private var showingDataSaveError = false
    @State private var dataSaveErrorMessage = ""
    @State private var appStateMonitor = AppStateMonitor.shared
    
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
        .overlay {
            if isProcessing {
                loadingOverlay
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
        .alert("Data Save Error", isPresented: $showingDataSaveError) {
            Button("Retry") {
                Task {
                    await forceSaveData()
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(dataSaveErrorMessage)
        }
        .onAppear {
            setupInitialState()
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .environmentObject(appStateMonitor)
    }
    
    // MARK: - View Components
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let lastSave = lastSaveDate {
                    Text("Last saved: \(formatLastSaveTime(lastSave))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Helper Methods
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }
    
    private func setupInitialState() {
        if settingsManager.isFirstLaunch {
            showingWelcomePopup = true
        } else {
            checkNotificationPermissions()
        }
        
        // Initial data load
        Task {
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        isProcessing = true
        
        // Performance monitoring
        PerformanceMonitor.measure("Initial Data Load") {
            budgetManager.loadData()
        }
        
        // Give UI time to update
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        } catch {
            // Sleep cancellation is not critical for this operation
        }
        
        isProcessing = false
    }
    
    private func handleDeepLink(url: URL) {
        guard url.scheme == "brandonsbudget" else { return }
        
        switch url.host {
        case "addPurchase":
            showingAddPurchase = true
        case "updateBudget":
            showingUpdateBudget = true
        case "overview":
            selectedTab = 0
        case "purchases":
            selectedTab = 1
        case "history":
            selectedTab = 2
        case "settings":
            selectedTab = 3
        default:
            break
        }
    }
    
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
    
    private func handleAppEnteringBackground() {
        print("App entering background - saving data")
        appStateMonitor.isInBackground = true
        
        Task {
            await forceSaveData()
            budgetManager.updateWidgetData()
        }
    }
    
    private func handleAppBecamingInactive() {
        print("App becoming inactive - saving data")
        appStateMonitor.isActive = false
        
        Task {
            await forceSaveData()
        }
    }
    
    private func handleAppBecamingActive(from oldPhase: ScenePhase) {
        print("App becoming active - refreshing data")
        appStateMonitor.isActive = true
        appStateMonitor.isInBackground = false
        
        // Refresh data when returning from background
        if oldPhase == .background {
            Task {
                await refreshDataFromBackground()
            }
        }
    }
    
    private func forceSaveData() async {
        do {
            try await PerformanceMonitor.measureAsync("Force Save Data") {
                try await CoreDataManager.shared.forceSave()
                await MainActor.run {
                    lastSaveDate = Date()
                    print("✅ Successfully saved data at \(Date())")
                }
            }
        } catch {
            await MainActor.run {
                dataSaveErrorMessage = "Failed to save data: \(error.localizedDescription)"
                showingDataSaveError = true
                print("❌ Failed to save data: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshDataFromBackground() async {
        PerformanceMonitor.measure("Background Data Refresh") {
            budgetManager.loadData()
        }
        
        // Check for any unsaved changes after data load
        do {
            let hasUnsavedChanges = await CoreDataManager.shared.hasUnsavedChanges()
            if hasUnsavedChanges {
                try await CoreDataManager.shared.forceSave()
            }
            lastSaveDate = Date()
            print("🔄 Successfully refreshed data from background")
        } catch {
            print("❌ Failed to save unsaved changes: \(error.localizedDescription)")
        }
    }
    
    private func checkNotificationPermissions() {
        Task {
            let isAuthorized = await NotificationManager.shared.checkNotificationStatus()
            if !isAuthorized && !settingsManager.notificationsAllowed {
                await MainActor.run {
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
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func formatLastSaveTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    @Binding var showingAddPurchase: Bool
    @Binding var showingUpdateBudget: Bool
    let isEnabled: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingOptions = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showingOptions {
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingOptions = false
                        }
                    }
                    .ignoresSafeArea()
            }
            
            VStack(alignment: .trailing, spacing: 15) {
                if showingOptions {
                    ActionButton(
                        title: "Add Purchase",
                        systemImage: "cart.fill.badge.plus",
                        color: themeManager.primaryColor
                    ) {
                        showingAddPurchase = true
                        withAnimation(.spring()) {
                            showingOptions = false
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                    
                    ActionButton(
                        title: "Update Budget",
                        systemImage: "dollarsign.circle.fill",
                        color: .green
                    ) {
                        showingUpdateBudget = true
                        withAnimation(.spring()) {
                            showingOptions = false
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                mainActionButton
            }
        }
    }
    
    private var mainActionButton: some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingOptions.toggle()
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        } label: {
            Image(systemName: showingOptions ? "xmark.circle.fill" : "plus.circle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(isEnabled ? themeManager.primaryColor : Color.gray)
                .background(
                    Circle()
                        .fill(.white)
                        .shadow(
                            color: .black.opacity(0.15),
                            radius: showingOptions ? 12 : 8,
                            x: 0,
                            y: showingOptions ? 6 : 4
                        )
                )
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .rotationEffect(.degrees(showingOptions ? 45 : 0))
        }
        .disabled(!isEnabled)
        .accessibilityLabel(showingOptions ? "Close menu" : "Open action menu")
        .accessibilityHint("Double tap to \(showingOptions ? "close" : "open") quick actions")
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(
                color: color.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to \(title.lowercased())")
    }
}

// MARK: - Data Persistence Helper
private struct DataPersistenceHelper {
    /// Save data with retry mechanism
    static func saveWithRetry(maxRetries: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try await CoreDataManager.shared.forceSave()
                print("✅ Data saved successfully on attempt \(attempt)")
                return
            } catch {
                lastError = error
                print("❌ Save attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Wait briefly before retrying
                    do {
                        try await Task.sleep(nanoseconds: UInt64(attempt * 100_000_000)) // 0.1s, 0.2s, 0.3s
                    } catch {
                        // Sleep cancellation is not critical, continue with retry
                    }
                }
            }
        }
        
        throw lastError ?? NSError(domain: "DataPersistenceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save after \(maxRetries) attempts"])
    }
    
    /// Check and report data health
    static func checkDataHealth() async -> (isHealthy: Bool, issues: [String]) {
        var issues: [String] = []
        
        // Check for unsaved changes
        let hasUnsavedChanges = await CoreDataManager.shared.hasUnsavedChanges()
        if hasUnsavedChanges {
            issues.append("Unsaved changes detected")
        }
        
        // Check data statistics from BudgetManager
        let stats = await BudgetManager.shared.getDataStatistics()
        if stats.entryCount == 0 && stats.budgetCount == 0 {
            issues.append("No data found - this might be a new installation")
        }
        
        return (isHealthy: issues.isEmpty, issues: issues)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode
            ContentView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .previewDisplayName("Light Mode")
            
            // Dark Mode
            ContentView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // With Test Data
            ContentView()
                .environmentObject({
                    let manager = BudgetManager.shared
                    manager.loadTestData()
                    return manager
                }())
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .previewDisplayName("With Test Data")
        }
    }
}
#endif
