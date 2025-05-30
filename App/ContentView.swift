//
//  ContentView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 5/30/25 - Enhanced with centralized error handling and improved data persistence
//

import SwiftUI

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
    
    // MARK: - Constants
    private let tabItems: [(String, String, AnyView)] = [
        ("Overview", "chart.pie.fill", AnyView(BudgetOverviewView())),
        ("Purchases", "cart.fill", AnyView(PurchasesView())),
        ("History", "clock.fill", AnyView(BudgetHistoryView())),
        ("Settings", "gear", AnyView(SettingsView()))
    ]
    
    // MARK: - Types
    private enum DataLoadingState {
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
        ZStack {
            if isAppReady {
                mainContent
            } else {
                loadingScreen
            }
            
            // Global error overlay
            if showingErrorRecovery {
                errorRecoveryOverlay
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
        .onAppear {
            setupInitialState()
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: errorHandler.currentError) { oldError, newError in
            handleGlobalError(newError)
        }
        .errorAlert(onRetry: {
            Task {
                await performGlobalRecovery()
            }
        })
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    NavigationView {
                        tabItems[index].2
                            .errorHandling(
                                context: "Tab \(tabItems[index].0)",
                                showInline: false,
                                onRetry: {
                                    Task {
                                        await refreshTabData(index: index)
                                    }
                                }
                            )
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
            .disabled(dataLoadingState.isLoading)
            
            // Floating Action Button for Overview and History tabs
            if (selectedTab == 0 || selectedTab == 2) && isAppReady {
                FloatingActionButton(
                    showingAddPurchase: $showingAddPurchase,
                    showingUpdateBudget: $showingUpdateBudget,
                    isEnabled: !dataLoadingState.isLoading
                )
                .padding(.bottom, 85)
                .padding(.trailing, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Loading Screen
    private var loadingScreen: some View {
        VStack(spacing: 24) {
            // App Icon or Logo
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundColor(themeManager.primaryColor)
                .scaleEffect(dataLoadingState.isLoading ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: dataLoadingState.isLoading)
            
            VStack(spacing: 12) {
                Text("Brandon's Budget")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryColor)
                
                Text(loadingMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if dataLoadingState.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                        .scaleEffect(1.2)
                        .padding(.top, 8)
                }
            }
            
            // Error state handling
            if case .failed(let error) = dataLoadingState {
                VStack(spacing: 16) {
                    InlineErrorView(
                        error: error,
                        onDismiss: nil,
                        onRetry: {
                            Task {
                                await loadInitialData()
                            }
                        }
                    )
                    
                    Button("Skip to App") {
                        withAnimation(.spring()) {
                            isAppReady = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 16)
            }
            
            if let lastSave = lastSaveDate {
                Text("Last saved: \(formatLastSaveTime(lastSave))")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Error Recovery Overlay
    private var errorRecoveryOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                VStack(spacing: 12) {
                    Text("Something went wrong")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("We're working to fix the issue. You can try recovering your data or restart the app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                HStack(spacing: 16) {
                    Button("Recover Data") {
                        Task {
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
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    private var loadingMessage: String {
        switch dataLoadingState {
        case .idle:
            return "Getting ready..."
        case .loading:
            return "Loading your budget data..."
        case .loaded:
            return "Ready to go!"
        case .failed:
            return "Something went wrong"
        }
    }
    
    // MARK: - Setup Methods
    private func setupInitialState() {
        Task {
            await loadInitialData()
            await checkFirstLaunch()
        }
    }
    
    private func loadInitialData() async {
        await MainActor.run {
            dataLoadingState = .loading
        }
        
        // Add delay for smooth loading experience
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let result = await AsyncErrorHandler.execute(
            context: "Loading initial app data"
        ) {
            // Load budget data
            budgetManager.loadData()
            
            // Update widget data
            budgetManager.updateWidgetData()
            
            // Check data integrity
            let stats = budgetManager.getDataStatistics()
            print("📊 Loaded \(stats.entryCount) entries and \(stats.budgetCount) budgets")
            
            // Save current state
            try await CoreDataManager.shared.forceSave()
            
            return true
        }
        
        await MainActor.run {
            if result != nil {
                dataLoadingState = .loaded
                lastSaveDate = Date()
                
                // Show app with animation
                withAnimation(.spring(duration: 0.8)) {
                    isAppReady = true
                }
                
                // Handle pending deep link
                if let pendingLink = pendingDeepLink {
                    handleDeepLink(url: pendingLink)
                    pendingDeepLink = nil
                }
            } else if let error = errorHandler.errorHistory.first?.error {
                dataLoadingState = .failed(error)
            } else {
                dataLoadingState = .failed(.generic(message: "Unknown error occurred"))
            }
        }
    }
    
    private func checkFirstLaunch() async {
        await MainActor.run {
            if settingsManager.isFirstLaunch {
                // Delay to allow app to fully load
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingWelcomePopup = true
                }
            }
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }
    
    // MARK: - Deep Link Handling
    private func handleDeepLink(url: URL) {
        // If app isn't ready, store the link for later
        guard isAppReady else {
            pendingDeepLink = url
            return
        }
        
        guard url.scheme == "brandonsbudget" else { return }
        
        // Handle different deep link paths
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
            print("Unknown deep link: \(url)")
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Scene Phase Handling
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
        print("📱 ContentView: App entering background")
        Task {
            await saveAppData(context: "App entering background")
            await MainActor.run {
                budgetManager.updateWidgetData()
            }
        }
    }
    
    private func handleAppBecamingInactive() {
        print("📱 ContentView: App becoming inactive")
        Task {
            await saveAppData(context: "App becoming inactive")
        }
    }
    
    private func handleAppBecamingActive(from oldPhase: ScenePhase) {
        print("📱 ContentView: App becoming active")
        
        // Refresh data if returning from background
        if oldPhase == .background && isAppReady {
            Task {
                await refreshAppData()
            }
        }
    }
    
    // MARK: - Data Management
    private func saveAppData(context: String) async {
        let result = await AsyncErrorHandler.execute(
            context: context,
            errorTransform: { .dataSave(underlying: $0) }
        ) {
            try await CoreDataManager.shared.forceSave()
        }
        
        if result != nil {
            await MainActor.run {
                lastSaveDate = Date()
                print("✅ ContentView: Data saved successfully - \(context)")
            }
        }
    }
    
    private func refreshAppData() async {
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing app data"
        ) {
            // Check for unsaved changes
            let hasUnsavedChanges = await CoreDataManager.shared.hasUnsavedChanges()
            if hasUnsavedChanges {
                try await CoreDataManager.shared.forceSave()
            }
            
            // Refresh budget manager
            budgetManager.loadData()
            
            return true
        }
        
        if result != nil {
            await MainActor.run {
                lastSaveDate = Date()
                print("🔄 ContentView: App data refreshed successfully")
            }
        }
    }
    
    private func refreshTabData(index: Int) async {
        let tabName = tabItems[index].0
        
        let result = await AsyncErrorHandler.execute(
            context: "Refreshing \(tabName) data"
        ) {
            // Refresh specific tab data based on index
            switch index {
            case 0, 2: // Overview and History
                budgetManager.loadData()
            case 1: // Purchases
                budgetManager.loadData()
            case 3: // Settings
                // Settings might need specific refresh logic
                break
            default:
                break
            }
            
            return true
        }
        
        if result != nil {
            print("🔄 ContentView: \(tabName) data refreshed")
        }
    }
    
    // MARK: - Error Handling
    private func handleGlobalError(_ error: AppError?) {
        guard let error = error else {
            showingErrorRecovery = false
            return
        }
        
        // Show recovery overlay for critical errors
        if error.severity == .critical {
            currentError = error
            showingErrorRecovery = true
        }
    }
    
    private func performGlobalRecovery() async {
        showingErrorRecovery = false
        
        await MainActor.run {
            dataLoadingState = .loading
        }
        
        // Try to recover by reloading all data
        let result = await AsyncErrorHandler.execute(
            context: "Global error recovery"
        ) {
            // Force save any pending changes
            try await CoreDataManager.shared.forceSave()
            
            // Reload all data
            budgetManager.loadData()
            
            // Update widget data
            budgetManager.updateWidgetData()
            
            // Clear error state
            errorHandler.clearError()
            
            return true
        }
        
        await MainActor.run {
            if result != nil {
                dataLoadingState = .loaded
                currentError = nil
                lastSaveDate = Date()
                print("✅ ContentView: Global recovery successful")
            } else {
                // If recovery fails, show the error state
                if let latestError = errorHandler.errorHistory.first?.error {
                    dataLoadingState = .failed(latestError)
                }
            }
        }
    }
    
    private func restartApp() {
        // This would typically involve resetting the app state
        // For now, we'll reload the initial data
        Task {
            await MainActor.run {
                isAppReady = false
                showingErrorRecovery = false
                currentError = nil
                dataLoadingState = .idle
                errorHandler.clearError()
                errorHandler.clearHistory()
            }
            
            // Reload from scratch
            await loadInitialData()
        }
    }
    
    // MARK: - Helper Methods
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
                        color: themeManager.semanticColors.success
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
                        .fill(themeManager.semanticColors.backgroundPrimary)
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
            
            // Loading State
            ContentView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .environmentObject(ErrorHandler.shared)
                .environmentObject(AppStateMonitor.shared)
                .onAppear {
                    // Simulate loading state
                }
                .previewDisplayName("Loading State")
        }
    }
}
#endif
