//
//  ContentView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//

import SwiftUI
import WidgetKit

/// Main container view for the app with enhanced data persistence and lifecycle management
struct ContentView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @EnvironmentObject private var appStateMonitor: AppStateMonitor
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var showingAddPurchase = false
    @State private var showingUpdateBudget = false
    @State private var showingWelcomePopup = false
    @State private var isAppReady = false
    @State private var lastSaveDate: Date?
    @State private var dataLoadingState: DataLoadingState = .idle
    @State private var pendingDeepLink: URL?
    
    // MARK: - Error State
    @State private var currentError: AppError?
    @State private var showingErrorRecovery = false
    
    // MARK: - UI State
    @State private var showingActionButtons = false
    @State private var isAnimating = false
    
    // MARK: - Constants
    private let tabItems: [(String, String, AnyView)] = [
        ("Overview", "chart.pie.fill", AnyView(BudgetOverviewView())),
        ("Purchases", "cart.fill", AnyView(PurchasesView())),
        ("History", "clock.fill", AnyView(BudgetHistoryView())),
        ("Settings", "gear", AnyView(SettingsView()))
    ]
    
    // MARK: - Data Loading State
    private enum DataLoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(AppError)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
        
        var hasError: Bool {
            if case .failed = self { return true }
            return false
        }
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if !isAppReady {
                loadingView
            } else if showingErrorRecovery {
                errorRecoveryView
            } else {
                mainContentView
            }
        }
        .onAppear {
            Task<Void, Never>{
                await loadInitialData()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            Task<Void, Never>{
                await handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
        .onReceive(errorHandler.$currentError) { error in
            handleGlobalError(error)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(isPresented: $showingAddPurchase) {
            PurchaseEntryView()
        }
        .sheet(isPresented: $showingUpdateBudget) {
            BudgetView()
        }
        .sheet(isPresented: $showingWelcomePopup) {
            WelcomePopupView()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your budget...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if case .failed(let error) = dataLoadingState {
                VStack(spacing: 12) {
                    Text("Error loading data")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task<Void, Never>{
                            await loadInitialData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Error Recovery View
    private var errorRecoveryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let error = currentError {
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("Try Recovery") {
                    Task<Void, Never>{
                        await performGlobalRecovery()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Restart App") {
                    restartApp()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    tabItems[index].2
                        .tabItem {
                            Image(systemName: tabItems[index].1)
                            Text(tabItems[index].0)
                        }
                        .tag(index)
                }
            }
            .accentColor(themeManager.primaryColor)
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    if showingActionButtons {
                        VStack(spacing: 16) {
                            ActionButton(
                                title: "Add Purchase",
                                systemImage: "cart.badge.plus",
                                color: .blue
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingActionButtons = false
                                }
                                showingAddPurchase = true
                            }
                            
                            ActionButton(
                                title: "Update Budget",
                                systemImage: "slider.horizontal.3",
                                color: .green
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingActionButtons = false
                                }
                                showingUpdateBudget = true
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    FloatingActionButton(
                        showingOptions: showingActionButtons,
                        isAnimating: isAnimating,
                        isEnabled: isAppReady
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingActionButtons.toggle()
                        }
                        
                        // Haptic feedback
                        if settingsManager.enableHapticFeedback {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Task<Void, Never>{
                await refreshTabData(index: newValue)
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    
    /// Load initial app data
    private func loadInitialData() async {
        await MainActor.run {
            dataLoadingState = .loading
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading initial app data",
            errorTransform: { .dataLoad(underlying: $0) }
        ) {
            // Load budget manager data
            await budgetManager.loadData()
            return true
        }
        
        await MainActor.run {
            if result != nil {
                dataLoadingState = .loaded
                isAppReady = true
                
                // Handle pending deep link
                if let pendingLink = pendingDeepLink {
                    handleDeepLink(pendingLink)
                    pendingDeepLink = nil
                }
                
                // Show welcome popup for first-time users
                if !settingsManager.hasSeenWelcome {
                    showingWelcomePopup = true
                    settingsManager.hasSeenWelcome = true
                }
            } else {
                dataLoadingState = .failed(.generic(message: "Failed to load app data"))
            }
        }
    }
    
    /// Handle scene phase changes
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) async {
        switch newPhase {
        case .active:
            await handleAppBecameActive()
        case .inactive:
            await saveAppData(context: "App became inactive")
        case .background:
            await saveAppData(context: "App entered background")
            // Schedule background app refresh if needed
            await scheduleBackgroundRefresh()
        @unknown default:
            break
        }
    }
    
    /// Handle app becoming active
    private func handleAppBecameActive() async {
        // Refresh data if needed based on app state monitoring
        if appStateMonitor.shouldRefreshData() {
            await refreshAppData()
        }
    }
    
    // MARK: - Data Management
    
    /// Save app data with context
    private func saveAppData(context: String) async {
        let result = await AsyncErrorHandler.execute(
            context: context,
            errorTransform: { .dataSave(underlying: $0) }
        ) {
            try await budgetManager.saveCurrentState()
            return true
        }
        
        if result != nil {
            await MainActor.run {
                lastSaveDate = Date()
                print("✅ ContentView: Data saved successfully - \(context)")
            }
        }
    }
    
    /// Refresh app data
    private func refreshAppData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing app data"
        ) {
            await budgetManager.refreshData()
            // Widget data is updated automatically by BudgetManager
            return true
        }
        
        if result != nil {
            print("✅ ContentView: Data refreshed successfully")
        }
    }
    
    /// Refresh specific tab data
    private func refreshTabData(index: Int) async {
        let tabName = tabItems[index].0
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing \(tabName) tab data"
        ) {
            // Refresh specific tab data based on index
            switch index {
            case 0: // Overview
                await budgetManager.refreshOverviewData()
            case 1: // Purchases
                await budgetManager.refreshPurchaseData()
            case 2: // History
                await budgetManager.refreshHistoryData()
            case 3: // Settings
                // Settings don't need explicit loading
                break
            default:
                break
            }
            return true
        }
        
        if result != nil {
            print("✅ ContentView: \(tabName) tab data refreshed")
        }
    }
    
    /// Schedule background refresh
    private func scheduleBackgroundRefresh() async {
        let result = await AsyncErrorHandler.execute(
            context: "Scheduling background refresh"
        ) {
            await appStateMonitor.scheduleBackgroundRefresh()
            return true
        }
        
        if result != nil {
            print("✅ ContentView: Background refresh scheduled")
        }
    }
    
    // MARK: - Error Handling
    
    /// Handle global errors
    private func handleGlobalError(_ error: AppError?) {
        guard let error = error else {
            currentError = nil
            showingErrorRecovery = false
            return
        }
        
        currentError = error
        
        // Show recovery overlay for critical errors
        if error.severity == .critical {
            showingErrorRecovery = true
        }
    }
    
    /// Perform global recovery
    private func performGlobalRecovery() async {
        await MainActor.run {
            showingErrorRecovery = false
            dataLoadingState = .loading
        }
        
        let result = await AsyncErrorHandler.execute(
            context: "Global error recovery"
        ) {
            // Clear error state
            errorHandler.clearError()
            
            // Reload all data
            await budgetManager.reloadAllData()
            
            // Validate data integrity
            let isValid = await budgetManager.validateDataIntegrity()
            guard isValid else {
                throw AppError.generic(message: "Data integrity check failed")
            }
            
            return true
        }
        
        await MainActor.run {
            if result != nil {
                dataLoadingState = .loaded
                currentError = nil
                print("✅ ContentView: Global recovery completed successfully")
            } else {
                dataLoadingState = .failed(.generic(message: "Recovery failed"))
            }
        }
    }
    
    /// Restart the app
    private func restartApp() {
        Task<Void, Never>{
            await MainActor.run {
                isAppReady = false
                showingErrorRecovery = false
                currentError = nil
                dataLoadingState = .idle
            }
            
            // Small delay before restarting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await loadInitialData()
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep links
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "brandonsbudget" else { return }
        
        if !isAppReady {
            pendingDeepLink = url
            return
        }
        
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
        
        print("📱 ContentView: Handled deep link - \(url)")
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let showingOptions: Bool
    let isAnimating: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: .black.opacity(0.2),
                        radius: showingOptions ? 12 : 8,
                        x: 0,
                        y: showingOptions ? 6 : 4
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
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

// MARK: - Preview Provider

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode - Ready State
            ContentView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .environmentObject(AppStateMonitor.shared)
                .previewDisplayName("Light Mode - Ready")
            
            // Dark Mode - Ready State
            ContentView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .environmentObject(AppStateMonitor.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode - Ready")
        }
    }
}
#endif
