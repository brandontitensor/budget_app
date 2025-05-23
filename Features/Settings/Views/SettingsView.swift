//
//  SettingsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
import UniformTypeIdentifiers

/// Main settings interface for the app
struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var budgetManager: BudgetManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
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
    @State private var pendingImportData: [BudgetManager.PurchaseImportData] = []
    @State private var isProcessing = false
    
    // MARK: - Body
    var body: some View {
        Form {
            userSection
            dataManagementSection
            appearanceSection
            notificationsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .disabled(isProcessing)
        .overlay {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                exportTimePeriod: $exportTimePeriod,
                onExport: performExport
            )
        }
        .sheet(isPresented: $showingImportOptions) {
            ImportOptionsView(
                showingImportBudgetPicker: $showingImportBudgetPicker,
                showingImportPurchasePicker: $showingImportPurchasePicker
            )
        }
        .sheet(isPresented: $showingCategoryMapping) {
            CategoryMappingView(
                categories: unmappedCategories,
                importedData: pendingImportData,
                onComplete: handleCategoryMapping
            )
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
                Task {
                    await resetAppData()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to reset all app data? This action cannot be undone.")
        }
    }
    
    // MARK: - View Sections
    private var userSection: some View {
        Section(header: Text("User Settings")) {
            TextField("Your Name", text: $settingsManager.userName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            
            Picker("Default Currency", selection: $settingsManager.defaultCurrency) {
                ForEach(["USD", "EUR", "GBP", "JPY"], id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            Button("Export Data") {
                showingExportOptions = true
            }
            
            Button("Import Data") {
                showingImportOptions = true
            }
            
            Button("Reset App Data", role: .destructive) {
                showingResetConfirmation = true
            }
        }
    }
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme Color", selection: $themeManager.primaryColor) {
                ForEach(ThemeManager.availableColors, id: \.self) { colorOption in
                    HStack {
                        Circle()
                            .fill(colorOption.color)
                            .frame(width: 20, height: 20)
                        Text(colorOption.name)
                    }
                    .tag(colorOption.color)
                }
            }
            
            Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
        }
    }
    
    private var notificationsSection: some View {
        Section(header: Text("Notifications")) {
            Toggle("Purchase Reminders", isOn: $settingsManager.purchaseNotificationsEnabled)
            
            if settingsManager.purchaseNotificationsEnabled {
                Picker("Reminder Frequency", selection: $settingsManager.purchaseNotificationFrequency) {
                    ForEach(SettingsManager.PurchaseNotificationFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
            }
            
            Toggle("Budget Updates", isOn: $settingsManager.budgetTotalNotificationsEnabled)
            
            if settingsManager.budgetTotalNotificationsEnabled {
                Picker("Update Frequency", selection: $settingsManager.budgetTotalNotificationFrequency) {
                    ForEach(SettingsManager.BudgetTotalNotificationFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section(header: Text("About")) {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            Link("Privacy Policy", destination: AppConstants.URLs.privacyPolicy)
            Link("Terms of Service", destination: AppConstants.URLs.termsOfService)
        }
    }
    
    // MARK: - Helper Properties
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // MARK: - Helper Methods
    private func performExport() {
        isProcessing = true
        
        Task {
            do {
                let url = try await CSVExport.exportToCSV(
                    entries: budgetManager.entries,
                    timePeriod: exportTimePeriod
                )
                await MainActor.run {
                    exportedFileURL = url
                    exportResultMessage = "Export successful!"
                    showingExportResult = true
                }
            } catch {
                await MainActor.run {
                    exportResultMessage = "Export failed: \(error.localizedDescription)"
                    showingExportResult = true
                }
            }
            
            await MainActor.run {
                isProcessing = false
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
        Task {
            await budgetManager.processMappedImport(
                data: pendingImportData,
                categoryMappings: mappings
            )
            
            await MainActor.run {
                importResultMessage = """
                Successfully imported:
                • \(pendingImportData.count) transactions
                • \(Set(pendingImportData.map { mappings[$0.category] ?? $0.category }).count) categories
                • Total amount: \(pendingImportData.reduce(0) { $0 + $1.amount }.asCurrency)
                """
                showingImportResult = true
            }
        }
    }
    
    private func resetAppData() async {
        isProcessing = true
        
        do {
            try await budgetManager.resetAllData()
            settingsManager.resetToDefaults()
            themeManager.resetToDefaults()
            await NotificationManager.shared.cancelAllNotifications()
        } catch {
            importResultMessage = "Reset failed: \(error.localizedDescription)"
            showingImportResult = true
        }
        
        isProcessing = false
    }
}

// MARK: - Preview Provider
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
        }
        
        NavigationView {
            SettingsView()
                .environmentObject(BudgetManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(SettingsManager.shared)
                .preferredColorScheme(.dark)
        }
    }
}
#endif
