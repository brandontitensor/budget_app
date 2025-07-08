//
//  SettingsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved architecture, and better state management
//

import SwiftUI
import UniformTypeIdentifiers

/// Main settings interface for the app with enhanced error handling and state management
struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @EnvironmentObject private var notificationManager: NotificationManager
    
    // MARK: - State
    @State private var showingExportOptions = false
    @State private var showingImportOptions = false
    @State private var showingImportBudgetPicker = false
    @State private var showingImportPurchasePicker = false
    @State private var exportTimePeriod: TimePeriod = .thisMonth
    @State private var showingResetConfirmation = false
    @State private var showingExportResult = false
    @State private var showingImportResult = false
    @State private var exportResultMessage = ""
    @State private var importResultMessage = ""
    @State private var importErrorDetails = ""
    @State private var exportedFileURL: URL?
    @State private var showingCategoryMapping = false
    @State private var unmappedCategories: Set<String> = []
    @State private var importedTransactionCount = 0
    @State private var pendingImportData: [CSVImport.PurchaseImportData] = []
    @State private var isProcessing = false
    @State private var showingNotificationSettings = false
    @State private var showingBackupOptions = false
    @State private var showingDataHealth = false
    @State private var showingAdvancedSettings = false
    @State private var showingErrorHistory = false
    @State private var showingAboutView = false
    
    // MARK: - Error State
    @State private var currentError: AppError?
    @State private var showingErrorAlert = false
    @State private var retryAction: (() -> Void)?
    
    // MARK: - Performance State
    @State private var loadingStates: Set<String> = []
    @State private var lastRefreshDate: Date?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                if isProcessing {
                    loadingOverlay
                } else {
                    settingsContent
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Refresh Data") {
                        performRefresh()
                    }
                    
                    Button("Error History") {
                        showingErrorHistory = true
                    }
                    
                    if settingsManager.enableAdvancedFeatures {
                        Button("Advanced Settings") {
                            showingAdvancedSettings = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(themeManager.primaryColor)
                }
            }
        }
        .refreshable {
            await performAsyncRefresh()
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                exportTimePeriod: $exportTimePeriod,
                onExport: performExport
            )
            .errorAlert()
        }
        .sheet(isPresented: $showingImportOptions) {
            ImportOptionsView(
                showingImportBudgetPicker: $showingImportBudgetPicker,
                showingImportPurchasePicker: $showingImportPurchasePicker
            )
            .errorAlert()
        }
        .sheet(isPresented: $showingCategoryMapping) {
            CategoryMappingView(
                categories: unmappedCategories,
                importedData: pendingImportData,
                onComplete: handleCategoryMapping
            )
            .errorAlert()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
                .environmentObject(settingsManager)
                .environmentObject(notificationManager)
                .errorAlert()
        }
        .sheet(isPresented: $showingBackupOptions) {
            BackupOptionsView()
                .environmentObject(settingsManager)
                .errorAlert()
        }
        .sheet(isPresented: $showingDataHealth) {
            DataHealthView()
                .environmentObject(budgetManager)
                .environmentObject(errorHandler)
                .errorAlert()
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView()
                .environmentObject(settingsManager)
                .environmentObject(themeManager)
                .errorAlert()
        }
        .sheet(isPresented: $showingErrorHistory) {
            ErrorHistoryView()
        }
        .sheet(isPresented: $showingAboutView) {
            AboutView()
        }
        .fileImporter(
            isPresented: $showingImportBudgetPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleBudgetImport(result)
        }
        .fileImporter(
            isPresented: $showingImportPurchasePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handlePurchaseImport(result)
        }
        .alert("Import Result", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importResultMessage + (importErrorDetails.isEmpty ? "" : "\n\nError details:\n\(importErrorDetails)"))
        }
        .alert("Export Result", isPresented: $showingExportResult) {
            if let url = exportedFileURL {
                Button("Share") {
                    shareExportFile(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportResultMessage)
        }
        .alert("Reset App Data", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                performReset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to reset all app data? This action cannot be undone.")
        }
        .errorAlert(onRetry: {
            retryAction?()
        })
        .onAppear {
            refreshDataIfNeeded()
        }
    }
    
    // MARK: - Main Content
    private var settingsContent: some View {
        Form {
            if let error = currentError {
                InlineErrorView(
                    error: error,
                    onDismiss: {
                        currentError = nil
                    },
                    onRetry: retryAction
                )
                .listRowBackground(Color.clear)
            }
            
            userSection
            notificationSection
            dataManagementSection
            appearanceSection
            privacySecuritySection
            advancedSection
            aboutSection
            
            if settingsManager.enableAdvancedFeatures {
                debugSection
            }
        }
        .background(themeManager.semanticColors.backgroundPrimary)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
            
            Text(isProcessing ? "Processing..." : "Loading Settings...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.semanticColors.backgroundPrimary.opacity(0.8))
    }
    
    // MARK: - View Sections
    
    private var userSection: some View {
        Section(header: sectionHeader("User Settings", systemImage: "person.circle")) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                TextField("Your Name", text: Binding(
                    get: { settingsManager.userName },
                    set: { newValue in
                        withErrorHandling("Updating user name") {
                            try settingsManager.updateUserName(newValue)
                        }
                    }
                ))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Picker("Default Currency", selection: Binding(
                    get: { settingsManager.defaultCurrency },
                    set: { newValue in
                        withErrorHandling("Updating default currency") {
                            try settingsManager.updateDefaultCurrency(newValue)
                        }
                    }
                )) {
                    ForEach(settingsManager.supportedCurrencies, id: \.code) { currency in
                        Text("\(currency.code) - \(currency.name)")
                            .tag(currency.code)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var notificationSection: some View {
        Section(
            header: sectionHeader("Notifications", systemImage: "bell.circle"),
            footer: notificationFooter
        ) {
            HStack {
                Image(systemName: notificationManager.isEnabled ? "bell.fill" : "bell.slash")
                    .foregroundColor(notificationManager.isEnabled ? themeManager.primaryColor : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Notifications")
                        .font(.subheadline)
                    
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { settingsManager.notificationsAllowed },
                    set: { newValue in
                        handleNotificationToggle(newValue)
                    }
                ))
                .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            if settingsManager.notificationsAllowed {
                NavigationLink(destination: notificationSettingsDestination) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(themeManager.primaryColor)
                            .frame(width: 24)
                        
                        Text("Notification Settings")
                        
                        Spacer()
                        
                        Text(notificationSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section(
            header: sectionHeader("Data Management", systemImage: "externaldrive"),
            footer: Text("Export your data for backup or import data from other sources.")
        ) {
            Button(action: { showingExportOptions = true }) {
                settingsRow(
                    title: "Export Data",
                    subtitle: "Create a backup of your budget data",
                    systemImage: "square.and.arrow.up",
                    isLoading: loadingStates.contains("export")
                )
            }
            .disabled(isProcessing)
            
            Button(action: { showingImportOptions = true }) {
                settingsRow(
                    title: "Import Data",
                    subtitle: "Import budget data from CSV files",
                    systemImage: "square.and.arrow.down",
                    isLoading: loadingStates.contains("import")
                )
            }
            .disabled(isProcessing)
            
            Button(action: { showingBackupOptions = true }) {
                settingsRow(
                    title: "Backup & Sync",
                    subtitle: backupStatusText,
                    systemImage: "icloud.and.arrow.up",
                    isLoading: loadingStates.contains("backup")
                )
            }
            .disabled(isProcessing)
            
            Button(action: { showingDataHealth = true }) {
                let health = budgetManager.getDataStatistics()
                settingsRow(
                    title: "Data Health",
                    subtitle: "Status: \(health.healthStatus.rawValue)",
                    systemImage: dataHealthIcon,
                    isLoading: loadingStates.contains("health"),
                    statusColor: health.healthStatus.color
                )
            }
            
            Button(action: { showingResetConfirmation = true }) {
                settingsRow(
                    title: "Reset App Data",
                    subtitle: "Remove all data and start fresh",
                    systemImage: "trash.circle",
                    isDestructive: true
                )
            }
            .disabled(isProcessing)
        }
    }
    
    private var appearanceSection: some View {
        Section(
            header: sectionHeader("Appearance", systemImage: "paintbrush"),
            footer: Text("Customize the app's look and feel.")
        ) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Picker("Theme Color", selection: $themeManager.primaryColor) {
                    ForEach(ThemeManager.availableColors, id: \.id) { colorOption in
                        HStack {
                            Circle()
                                .fill(colorOption.color)
                                .frame(width: 20, height: 20)
                            Text(colorOption.name)
                        }
                        .tag(colorOption.color)
                    }
                }
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Dark Mode")
                
                Spacer()
                
                Toggle("", isOn: $themeManager.isDarkMode)
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Show Decimal Places")
                
                Spacer()
                
                Toggle("", isOn: $settingsManager.showDecimalPlaces)
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Haptic Feedback")
                
                Spacer()
                
                Toggle("", isOn: $settingsManager.enableHapticFeedback)
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var privacySecuritySection: some View {
        Section(
            header: sectionHeader("Privacy & Security", systemImage: "lock.shield"),
            footer: Text("Control how your data is protected and displayed.")
        ) {
            HStack {
                Image(systemName: settingsManager.privacyMode ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Privacy Mode")
                
                Spacer()
                
                Toggle("", isOn: $settingsManager.privacyMode)
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            if settingsManager.isBiometricAuthAvailable {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundColor(themeManager.primaryColor)
                        .frame(width: 24)
                    
                    Text("Biometric Authentication")
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.biometricAuthEnabled)
                        .tint(themeManager.primaryColor)
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Data Export Format")
                
                Spacer()
                
                Picker("", selection: $settingsManager.defaultExportFormat) {
                    ForEach(SettingsManager.DataExportFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var advancedSection: some View {
        Section(
            header: sectionHeader("Advanced", systemImage: "gearshape.2"),
            footer: Text("Advanced features for power users.")
        ) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                
                Text("Advanced Features")
                
                Spacer()
                
                Toggle("", isOn: $settingsManager.enableAdvancedFeatures)
                    .tint(themeManager.primaryColor)
            }
            .padding(.vertical, 4)
            
            if settingsManager.enableAdvancedFeatures {
                Button(action: { showingAdvancedSettings = true }) {
                    settingsRow(
                        title: "Advanced Settings",
                        subtitle: "Developer and power user options",
                        systemImage: "terminal"
                    )
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section(
            header: sectionHeader("About", systemImage: "info.circle"),
            footer: aboutFooter
        ) {
            settingsInfoRow(title: "Version", value: appVersion)
            settingsInfoRow(title: "Build", value: buildNumber)
            
            Link(destination: AppConstants.URLs.privacyPolicy) {
                settingsRow(
                    title: "Privacy Policy",
                    subtitle: "How we protect your data",
                    systemImage: "hand.raised"
                )
            }
            
            Link(destination: AppConstants.URLs.termsOfService) {
                settingsRow(
                    title: "Terms of Service",
                    subtitle: "Usage terms and conditions",
                    systemImage: "doc.text"
                )
            }
            
            Link(destination: AppConstants.URLs.support) {
                settingsRow(
                    title: "Support",
                    subtitle: "Get help and contact us",
                    systemImage: "questionmark.circle"
                )
            }
            
            Button(action: { showingAboutView = true }) {
                settingsRow(
                    title: "About Brandon's Budget",
                    subtitle: "App information and credits",
                    systemImage: "heart.circle"
                )
            }
        }
    }
    
    private var debugSection: some View {
        Section(
            header: sectionHeader("Debug", systemImage: "ladybug"),
            footer: Text("Debug tools for development and troubleshooting.")
        ) {
            Button(action: performDiagnostics) {
                settingsRow(
                    title: "Run Diagnostics",
                    subtitle: "Check app health and performance",
                    systemImage: "stethoscope",
                    isLoading: loadingStates.contains("diagnostics")
                )
            }
            
            Button(action: { showingErrorHistory = true }) {
                let errorCount = errorHandler.errorHistory.count
                settingsRow(
                    title: "Error History",
                    subtitle: errorCount == 0 ? "No errors" : "\(errorCount) error\(errorCount == 1 ? "" : "s")",
                    systemImage: "exclamationmark.triangle",
                    statusColor: errorCount > 0 ? .orange : .green
                )
            }
            
            Button(action: clearCaches) {
                settingsRow(
                    title: "Clear Caches",
                    subtitle: "Reset app caches and temporary data",
                    systemImage: "trash.circle",
                    isLoading: loadingStates.contains("clearCache")
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(themeManager.primaryColor)
                .font(.caption)
            Text(title)
        }
    }
    
    private func settingsRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isLoading: Bool = false,
        isDestructive: Bool = false,
        statusColor: Color? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(isDestructive ? .red : statusColor ?? themeManager.primaryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Notifications enabled"
        case .denied:
            return "Notifications disabled in Settings"
        case .notDetermined:
            return "Permission not requested"
        case .provisional:
            return "Quiet notifications enabled"
        case .ephemeral:
            return "Temporary notifications"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private var notificationSummary: String {
        var components: [String] = []
        if settingsManager.purchaseNotificationsEnabled {
            components.append("Purchase (\(settingsManager.purchaseNotificationFrequency.rawValue))")
        }
        if settingsManager.budgetTotalNotificationsEnabled {
            components.append("Budget (\(settingsManager.budgetTotalNotificationFrequency.rawValue))")
        }
        return components.isEmpty ? "None active" : components.joined(separator: ", ")
    }
    
    private var backupStatusText: String {
        if settingsManager.enableDataBackup {
            if let lastBackup = settingsManager.lastBackupDate {
                let formatter = RelativeDateTimeFormatter()
                return "Last backup: \(formatter.localizedString(for: lastBackup, relativeTo: Date()))"
            } else {
                return "Backup enabled, never backed up"
            }
        } else {
            return "Backup disabled"
        }
    }
    
    private var dataHealthIcon: String {
        let health = budgetManager.getDataStatistics().healthStatus
        switch health {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.circle"
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var notificationFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable notifications to receive budget reminders and alerts.")
            
            if !notificationManager.isEnabled && settingsManager.notificationsAllowed {
                Text("Notifications are disabled in system settings. Tap to open Settings.")
                    .foregroundColor(.orange)
                    .onTapGesture {
                        notificationManager.openNotificationSettings()
                    }
            }
        }
    }
    
    private var aboutFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brandon's Budget helps you manage your finances with ease.")
            
            if let lastRefresh = lastRefreshDate {
                Text("Last refreshed: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
        }
    }
    
    // MARK: - Navigation Destinations
    
    private var notificationSettingsDestination: some View {
        NotificationSettingsView()
            .environmentObject(settingsManager)
            .environmentObject(notificationManager)
            .errorAlert()
    }
    
    // MARK: - Helper Methods
    
    private func withErrorHandling<T>(_ context: String, operation: () throws -> T) {
        do {
            _ = try operation()
            // Clear any previous errors on success
            currentError = nil
        } catch {
            let appError = AppError.from(error)
            currentError = appError
            errorHandler.handle(appError, context: context)
        }
    }
    
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
           Task<Void, Never>{
                do {
                    let granted = try await notificationManager.requestAuthorization()
                    await MainActor.run {
                        if granted {
                            withErrorHandling("Enabling notifications") {
                                try settingsManager.updateNotificationSettings(
                                    allowed: true,
                                    purchaseEnabled: settingsManager.purchaseNotificationsEnabled,
                                    purchaseFrequency: settingsManager.purchaseNotificationFrequency,
                                    budgetEnabled: settingsManager.budgetTotalNotificationsEnabled,
                                    budgetFrequency: settingsManager.budgetTotalNotificationFrequency
                                )
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        let appError = AppError.from(error)
                        currentError = appError
                        errorHandler.handle(appError, context: "Enabling notifications")
                    }
                }
            }
        } else {
            withErrorHandling("Disabling notifications") {
                try settingsManager.updateNotificationSettings(
                    allowed: false,
                    purchaseEnabled: false,
                    purchaseFrequency: settingsManager.purchaseNotificationFrequency,
                    budgetEnabled: false,
                    budgetFrequency: settingsManager.budgetTotalNotificationFrequency
                )
            }
        }
    }
    
    private func performExport() {
        setLoading("export", true)
        
       Task<Void, Never>{
            do {
                let url = try await CSVExport.exportBudgetEntries(
                    budgetManager.entries,
                    configuration: CSVExport.ExportConfiguration(
                        timePeriod: exportTimePeriod,
                        exportType: .budgetEntries
                    )
                )
                
                await MainActor.run {
                    exportedFileURL = url.fileURL
                    exportResultMessage = "Export successful! \(url.summary)"
                    showingExportResult = true
                    setLoading("export", false)
                }
            } catch {
                await MainActor.run {
                    let appError = AppError.from(error)
                    exportResultMessage = "Export failed: \(appError.errorDescription ?? "Unknown error")"
                    showingExportResult = true
                    currentError = appError
                    errorHandler.handle(appError, context: "Exporting data")
                    setLoading("export", false)
                }
            }
        }
    }
    
    private func shareExportFile(_ url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func handleCategoryMapping(_ mappings: [String: String]) {
        setLoading("import", true)
        
       Task<Void, Never>{
            do {
                let importResults = CSVImport.ImportResults(
                    data: pendingImportData,
                    categories: unmappedCategories,
                    existingCategories: Set(budgetManager.getAvailableCategories()).intersection(unmappedCategories),
                    newCategories: unmappedCategories.subtracting(Set(budgetManager.getAvailableCategories())),
                    totalAmount: pendingImportData.reduce(0) { $0 + $1.amount }
                )
                
                try await budgetManager.processImportedPurchases(importResults, categoryMappings: mappings)
                
                await MainActor.run {
                    let totalAmount = pendingImportData.reduce(0) { $0 + $1.amount }
                    importResultMessage = """
                    Successfully imported:
                    • \(pendingImportData.count) transactions
                    • \(Set(pendingImportData.map { mappings[$0.category] ?? $0.category }).count) categories
                    • Total amount: \(NumberFormatter.formatCurrency(totalAmount))
                    """
                    showingImportResult = true
                    setLoading("import", false)
                    
                    // Clear import data
                    pendingImportData.removeAll()
                    unmappedCategories.removeAll()
                }
            } catch {
                await MainActor.run {
                    let appError = AppError.from(error)
                    importResultMessage = "Import failed: \(appError.errorDescription ?? "Unknown error")"
                    importErrorDetails = appError.recoverySuggestion ?? ""
                    showingImportResult = true
                    currentError = appError
                    errorHandler.handle(appError, context: "Processing imported data")
                    setLoading("import", false)
                }
            }
        }
    }
    
    private func performReset() {
        setLoading("reset", true)
        isProcessing = true
        
       Task<Void, Never>{
            do {
                try await budgetManager.resetAllData()
                try await settingsManager.resetToDefaults()
                await themeManager.resetToDefaults()
                await notificationManager.cancelAllNotifications()
                
                await MainActor.run {
                    importResultMessage = "App data has been successfully reset."
                    showingImportResult = true
                    currentError = nil
                    setLoading("reset", false)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    let appError = AppError.from(error)
                    importResultMessage = "Reset failed: \(appError.errorDescription ?? "Unknown error")"
                    importErrorDetails = appError.recoverySuggestion ?? ""
                    showingImportResult = true
                    currentError = appError
                    errorHandler.handle(appError, context: "Resetting app data")
                    setLoading("reset", false)
                    isProcessing = false
                }
            }
        }
    }
    
    private func performRefresh() {
       Task<Void, Never>{
            await performAsyncRefresh()
        }
    }
    
    private func performAsyncRefresh() async {
        await MainActor.run {
            setLoading("refresh", true)
        }
        
        do {
            // Refresh budget data
            await budgetManager.loadData()
            
            // Update notification status
            await notificationManager.updateNotificationSchedule(settings: settingsManager)
            
            // Validate data integrity
            try await budgetManager.validateDataIntegrity()
            
            await MainActor.run {
                lastRefreshDate = Date()
                currentError = nil
                setLoading("refresh", false)
            }
        } catch {
            await MainActor.run {
                let appError = AppError.from(error)
                currentError = appError
                errorHandler.handle(appError, context: "Refreshing settings data")
                setLoading("refresh", false)
            }
        }
    }
    
    private func refreshDataIfNeeded() {
        if lastRefreshDate == nil ||
           Date().timeIntervalSince(lastRefreshDate!) > 300 { // 5 minutes
            performRefresh()
        }
    }
    
    private func performDiagnostics() {
        setLoading("diagnostics", true)
        
       Task<Void, Never>{
            do {
                // Run notification diagnostics
                let notificationDiagnostic = await notificationManager.performSystemDiagnostic()
                
                // Get data statistics
                let dataStats = budgetManager.getDataStatistics()
                
                // Get settings summary
                let settingsSummary = settingsManager.getSettingsSummary()
                
                // Validate system health
                try await notificationManager.validateSystemHealth()
                try await budgetManager.validateDataIntegrity()
                
                await MainActor.run {
                    let diagnosticsMessage = """
                    Diagnostics completed successfully:
                    
                    Data Health: \(dataStats.healthStatus.rawValue)
                    - \(dataStats.entryCount) entries
                    - \(dataStats.budgetCount) budgets
                    - Integrity score: \(String(format: "%.1f", dataStats.dataIntegrityScore * 100))%
                    
                    Notifications: \(notificationDiagnostic.overallHealth.rawValue)
                    - \(notificationDiagnostic.summary)
                    
                    Settings: Valid configuration
                    """
                    
                    importResultMessage = diagnosticsMessage
                    showingImportResult = true
                    setLoading("diagnostics", false)
                }
            } catch {
                await MainActor.run {
                    let appError = AppError.from(error)
                    importResultMessage = "Diagnostics failed: \(appError.errorDescription ?? "Unknown error")"
                    importErrorDetails = appError.recoverySuggestion ?? ""
                    showingImportResult = true
                    currentError = appError
                    errorHandler.handle(appError, context: "Running diagnostics")
                    setLoading("diagnostics", false)
                }
            }
        }
    }
    
    private func clearCaches() {
        setLoading("clearCache", true)
        
       Task<Void, Never>{
            do {
                // Clear budget manager caches
                budgetManager.invalidateCacheForTesting()
                
                // Clear Core Data caches
                try await CoreDataManager.shared.forceSave()
                
                // Clear CSV export caches
                CSVExport.cleanupOldExports()
                
                // Clear notification caches
                await notificationManager.cleanupOldNotifications()
                
                await MainActor.run {
                    importResultMessage = "Caches cleared successfully."
                    showingImportResult = true
                    setLoading("clearCache", false)
                }
            } catch {
                await MainActor.run {
                    let appError = AppError.from(error)
                    importResultMessage = "Failed to clear caches: \(appError.errorDescription ?? "Unknown error")"
                    showingImportResult = true
                    currentError = appError
                    errorHandler.handle(appError, context: "Clearing caches")
                    setLoading("clearCache", false)
                }
            }
        }
    }
    
    private func setLoading(_ operation: String, _ isLoading: Bool) {
        if isLoading {
            loadingStates.insert(operation)
        } else {
            loadingStates.remove(operation)
        }
    }
    
    // MARK: - File Import Handlers
    
    private func handleBudgetImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            setLoading("import", true)
            isProcessing = true
            
           Task<Void, Never>{
                do {
                    let importResults = try await budgetManager.importBudgets(from: url)
                    
                    try await budgetManager.processImportedBudgets(importResults)
                    
                    await MainActor.run {
                        importResultMessage = """
                        Successfully imported budget data:
                        • \(importResults.data.count) budget entries
                        • \(importResults.categories.count) categories
                        • Total amount: \(NumberFormatter.formatCurrency(importResults.totalAmount))
                        
                        New categories: \(importResults.newCategories.count)
                        """
                        
                        if !importResults.warningMessages.isEmpty {
                            importErrorDetails = "Warnings:\n" + importResults.warningMessages.joined(separator: "\n")
                        }
                        
                        showingImportResult = true
                        setLoading("import", false)
                        isProcessing = false
                    }
                } catch let error as CSVImport.ImportError {
                    await MainActor.run {
                        handleImportError(error)
                        setLoading("import", false)
                        isProcessing = false
                    }
                } catch {
                    await MainActor.run {
                        let appError = AppError.from(error)
                        importResultMessage = "Failed to import budget data"
                        importErrorDetails = appError.errorDescription ?? error.localizedDescription
                        showingImportResult = true
                        currentError = appError
                        errorHandler.handle(appError, context: "Importing budget data")
                        setLoading("import", false)
                        isProcessing = false
                    }
                }
            }
        case .failure(let error):
            let appError = AppError.from(error)
            importResultMessage = "Failed to access file"
            importErrorDetails = appError.errorDescription ?? error.localizedDescription
            showingImportResult = true
            currentError = appError
            errorHandler.handle(appError, context: "Accessing import file")
        }
    }
    
    private func handlePurchaseImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            setLoading("import", true)
            isProcessing = true
            
           Task<Void, Never>{
                do {
                    let importResults = try await budgetManager.importPurchases(from: url)
                    
                    await MainActor.run {
                        pendingImportData = importResults.data
                        unmappedCategories = importResults.newCategories
                        
                        if unmappedCategories.isEmpty {
                            // No new categories, process directly
                           Task<Void, Never>{
                                do {
                                    try await budgetManager.processImportedPurchases(importResults, categoryMappings: [:])
                                    
                                    await MainActor.run {
                                        importResultMessage = """
                                        Successfully imported purchase data:
                                        • \(importResults.data.count) transactions
                                        • \(importResults.categories.count) categories
                                        • Total amount: \(NumberFormatter.formatCurrency(importResults.totalAmount))
                                        """
                                        
                                        if !importResults.warningMessages.isEmpty {
                                            importErrorDetails = "Warnings:\n" + importResults.warningMessages.joined(separator: "\n")
                                        }
                                        
                                        showingImportResult = true
                                        setLoading("import", false)
                                        isProcessing = false
                                    }
                                } catch {
                                    await MainActor.run {
                                        let appError = AppError.from(error)
                                        importResultMessage = "Failed to process imported purchases"
                                        importErrorDetails = appError.errorDescription ?? error.localizedDescription
                                        showingImportResult = true
                                        currentError = appError
                                        errorHandler.handle(appError, context: "Processing imported purchases")
                                        setLoading("import", false)
                                        isProcessing = false
                                    }
                                }
                            }
                        } else {
                            // Show category mapping interface
                            showingCategoryMapping = true
                            setLoading("import", false)
                            isProcessing = false
                        }
                    }
                } catch let error as CSVImport.ImportError {
                    await MainActor.run {
                        handleImportError(error)
                        setLoading("import", false)
                        isProcessing = false
                    }
                } catch {
                    await MainActor.run {
                        let appError = AppError.from(error)
                        importResultMessage = "Failed to import purchase data"
                        importErrorDetails = appError.errorDescription ?? error.localizedDescription
                        showingImportResult = true
                        currentError = appError
                        errorHandler.handle(appError, context: "Importing purchase data")
                        setLoading("import", false)
                        isProcessing = false
                    }
                }
            }
        case .failure(let error):
            let appError = AppError.from(error)
            importResultMessage = "Failed to access file"
            importErrorDetails = appError.errorDescription ?? error.localizedDescription
            showingImportResult = true
            currentError = appError
            errorHandler.handle(appError, context: "Accessing import file")
        }
    }
    
    private func handleImportError(_ error: CSVImport.ImportError) {
        switch error {
        case .emptyFile:
            importResultMessage = "The selected file is empty or contains no data"
        case .invalidFormat(let reason):
            importResultMessage = "Invalid file format"
            importErrorDetails = reason
        case .missingRequiredFields(let fields):
            importResultMessage = "Missing required columns"
            importErrorDetails = "Required: \(fields.joined(separator: ", "))"
        }
        
        showingImportResult = true
        let appError = AppError.from(error)
        currentError = appError
        errorHandler.handle(appError, context: "Processing import file")
    }
}

// MARK: - Supporting Views

struct NotificationSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Purchase Notifications"),
                    footer: Text("Get reminders to log your purchases and stay on top of your spending.")
                ) {
                    Toggle("Enable Purchase Reminders", isOn: $settingsManager.purchaseNotificationsEnabled)
                    
                    if settingsManager.purchaseNotificationsEnabled {
                        Picker("Frequency", selection: $settingsManager.purchaseNotificationFrequency) {
                            ForEach(SettingsManager.PurchaseNotificationFrequency.allCases, id: \.self) { frequency in
                                VStack(alignment: .leading) {
                                    Text(frequency.displayName)
                                    Text(frequency.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(frequency)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section(
                    header: Text("Budget Notifications"),
                    footer: Text("Receive periodic reminders to review and update your budget.")
                ) {
                    Toggle("Enable Budget Updates", isOn: $settingsManager.budgetTotalNotificationsEnabled)
                    
                    if settingsManager.budgetTotalNotificationsEnabled {
                        Picker("Frequency", selection: $settingsManager.budgetTotalNotificationFrequency) {
                            ForEach(SettingsManager.BudgetTotalNotificationFrequency.allCases, id: \.self) { frequency in
                                VStack(alignment: .leading) {
                                    Text(frequency.displayName)
                                    Text(frequency.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(frequency)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section(header: Text("Status")) {
                    let stats = notificationManager.getNotificationStatistics()
                    
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(notificationManager.authorizationStatus.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pending Notifications")
                        Spacer()
                        Text("\(stats.totalPending)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let nextDate = stats.nextScheduledDate {
                        HStack {
                            Text("Next Notification")
                            Spacer()
                            Text(nextDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct BackupOptionsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingBackup = false
    @State private var backupMessage = ""
    @State private var showingBackupResult = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Automatic Backup"),
                    footer: Text("Automatically backup your settings and preferences.")
                ) {
                    Toggle("Enable Automatic Backup", isOn: $settingsManager.enableDataBackup)
                    
                    if settingsManager.enableDataBackup {
                        Picker("Backup Frequency", selection: $settingsManager.backupFrequency) {
                            ForEach(SettingsManager.BackupFrequency.allCases, id: \.self) { frequency in
                                HStack {
                                    Image(systemName: frequency.systemImageName)
                                    Text(frequency.displayName)
                                }
                                .tag(frequency)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section(header: Text("Manual Backup")) {
                    Button(action: createBackup) {
                        HStack {
                            Image(systemName: isCreatingBackup ? "arrow.triangle.2.circlepath" : "square.and.arrow.up")
                            Text(isCreatingBackup ? "Creating Backup..." : "Create Backup Now")
                        }
                    }
                    .disabled(isCreatingBackup)
                }
                
                Section(header: Text("Backup Status")) {
                    let status = settingsManager.getBackupStatus()
                    
                    HStack {
                        Text("Backup Enabled")
                        Spacer()
                        Text(status.enabled ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastBackup = status.lastBackup {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text(lastBackup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let nextBackup = status.nextBackup {
                        HStack {
                            Text("Next Scheduled")
                            Spacer()
                            Text(nextBackup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if status.isInProgress {
                        HStack {
                            Text("Status")
                            Spacer()
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("In Progress")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Backup & Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Backup Result", isPresented: $showingBackupResult) {
                Button("OK") { }
            } message: {
                Text(backupMessage)
            }
        }
    }
    
    private func createBackup() {
        isCreatingBackup = true
        
       Task<Void, Never>{
            do {
                let backupURL = try await settingsManager.createBackup()
                await MainActor.run {
                    backupMessage = "Backup created successfully at \(backupURL.lastPathComponent)"
                    showingBackupResult = true
                    isCreatingBackup = false
                }
            } catch {
                await MainActor.run {
                    backupMessage = "Backup failed: \(error.localizedDescription)"
                    showingBackupResult = true
                    isCreatingBackup = false
                }
            }
        }
    }
}

struct DataHealthView: View {
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let stats = budgetManager.getDataStatistics()
                
                Section(header: Text("Overall Health")) {
                    HStack {
                        Image(systemName: stats.healthStatus.systemImageName)
                            .foregroundColor(stats.healthStatus.color)
                        
                        VStack(alignment: .leading) {
                            Text("Data Health")
                                .font(.headline)
                            Text(stats.healthStatus.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(stats.dataIntegrityScore * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(stats.healthStatus.color)
                    }
                }
                
                Section(header: Text("Data Statistics")) {
                    DataHealthRow(title: "Total Entries", value: "\(stats.entryCount)")
                    DataHealthRow(title: "Total Budgets", value: "\(stats.budgetCount)")
                    DataHealthRow(title: "Categories", value: "\(stats.categoryCount)")
                    DataHealthRow(title: "Total Spent", value: NumberFormatter.formatCurrency(stats.totalSpent))
                    DataHealthRow(title: "Total Budgeted", value: NumberFormatter.formatCurrency(stats.totalBudgeted))
                }
                
                if let oldest = stats.oldestEntry, let newest = stats.newestEntry {
                    Section(header: Text("Date Range")) {
                        DataHealthRow(title: "Oldest Entry", value: oldest.formatted(date: .abbreviated, time: .omitted))
                        DataHealthRow(title: "Newest Entry", value: newest.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                
                Section(header: Text("Error History")) {
                    if errorHandler.errorHistory.isEmpty {
                        Text("No errors recorded")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(errorHandler.errorHistory.prefix(5)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: entry.error.severity.icon)
                                        .foregroundColor(entry.error.severity.color)
                                    Text(entry.error.errorDescription ?? "Unknown error")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let context = entry.context {
                                    Text("Context: \(context)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Data Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DataHealthRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Display"),
                    footer: Text("Advanced display and formatting options.")
                ) {
                    Toggle("Round to Nearest Cent", isOn: $settingsManager.roundToNearestCent)
                    Toggle("Show Decimal Places", isOn: $settingsManager.showDecimalPlaces)
                }
                
                Section(
                    header: Text("Data"),
                    footer: Text("Advanced data handling and export options.")
                ) {
                    Picker("Default Export Format", selection: $settingsManager.defaultExportFormat) {
                        ForEach(SettingsManager.DataExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
                
                Section(
                    header: Text("Performance"),
                    footer: Text("Performance and debugging options.")
                ) {
                    Button("Clear All Caches") {
                        // Handle cache clearing
                    }
                    
                    Button("Validate Data Integrity") {
                        // Handle data validation
                    }
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Brandon's Budget")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Personal Finance Made Simple")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Version Info
                    VStack(spacing: 8) {
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                            .font(.headline)
                        
                        Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                        
                        Text("Brandon's Budget is a simple yet powerful personal finance app designed to help you track your spending, manage your budget, and achieve your financial goals.")
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "chart.pie.fill", text: "Visual spending analysis")
                            FeatureRow(icon: "bell.fill", text: "Smart notifications")
                            FeatureRow(icon: "square.and.arrow.up", text: "Data export & import")
                            FeatureRow(icon: "lock.shield", text: "Privacy-focused design")
                            FeatureRow(icon: "paintbrush.fill", text: "Customizable themes")
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                SettingsView()
                    .environmentObject(BudgetManager.shared)
                    .environmentObject(ThemeManager.shared)
                    .environmentObject(SettingsManager.shared)
                    .environmentObject(ErrorHandler.shared)
                    .environmentObject(NotificationManager.shared)
            }
            .previewDisplayName("Light Mode")
            
            NavigationView {
                SettingsView()
                    .environmentObject(BudgetManager.shared)
                    .environmentObject(ThemeManager.shared)
                    .environmentObject(SettingsManager.shared)
                    .environmentObject(ErrorHandler.shared)
                    .environmentObject(NotificationManager.shared)
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
