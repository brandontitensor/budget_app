//
//  SettingsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
//
//  SettingsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/30/24.
//
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
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
    
    var body: some View {
        Form {
            userSection
            dataManagementSection
            appearanceSection
            notificationsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(exportTimePeriod: $exportTimePeriod, onExport: performExport)
        }
        .sheet(isPresented: $showingImportOptions) {
                    ImportOptionsView(
                        importBudgetData: { showingImportBudgetPicker = true },
                        importPurchaseData: { showingImportPurchasePicker = true }
                    )
                }
        .fileImporter(
                    isPresented: $showingImportBudgetPicker,
                    allowedContentTypes: [.commaSeparatedText],
                    allowsMultipleSelection: false
                ) { result in
                    handleImportResult(result, isbudget: true)
                }
        .fileImporter(
                            isPresented: $showingImportPurchasePicker,
                            allowedContentTypes: [.commaSeparatedText],
                            allowsMultipleSelection: false
                        ) { result in
                            handleImportResult(result, isbudget: false)
                        }
        .alert(isPresented: $showingImportResult) {
            Alert(
                title: Text("Import Result"),
                message: Text(importResultMessage + (importErrorDetails.isEmpty ? "" : "\n\nError details:\n\(importErrorDetails)")),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Reset App Data", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive, action: resetAppData)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to reset all app data? This action cannot be undone.")
        }
    }
    
    private var userSection: some View {
        Section(header: Text("User Settings")) {
            TextField("Your Name", text: $settingsManager.userName)
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
            
            Button("Reset App Data") {
                showingResetConfirmation = true
            }
            .foregroundColor(.red)
        }
    }
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme Color", selection: $themeManager.primaryColor) {
                ForEach(ThemeManager.availableColors, id: \.self) { colorOption in
                    Text(colorOption.name).tag(colorOption.color)
                }
            }
            Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
        }
    }
    
    private var notificationsSection: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enter Purchases Notifications", isOn: $settingsManager.purchaseNotificationsEnabled)
                .onChange(of: settingsManager.purchaseNotificationsEnabled) { _, newValue in
                    if newValue {
                        requestNotificationPermissionIfNeeded()
                    } else {
                        NotificationManager.shared.cancelAllNotifications()
                    }
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                }
            
            if settingsManager.purchaseNotificationsEnabled {
                Picker("Enter Purchases Notification Frequency", selection: $settingsManager.purchaseNotificationFrequency) {
                    ForEach(SettingsManager.PurchaseNotificationFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .onChange(of: settingsManager.purchaseNotificationFrequency) { _, _ in
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                }
            }
            
            Toggle("Enter Budget Notifications", isOn: $settingsManager.budgetTotalNotificationsEnabled)
                .onChange(of: settingsManager.budgetTotalNotificationsEnabled) { _, newValue in
                    if newValue {
                        requestNotificationPermissionIfNeeded()
                    } else {
                        NotificationManager.shared.cancelAllNotifications()
                    }
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                }
            
            if settingsManager.budgetTotalNotificationsEnabled {
                Picker("Enter Budget Notification Frequency", selection: $settingsManager.budgetTotalNotificationFrequency) {
                    ForEach(SettingsManager.BudgetTotalNotificationFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .onChange(of: settingsManager.budgetTotalNotificationFrequency) { _, _ in
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                }
            }
        }
    }
    
    private var aboutSection: some View {
        Section(header: Text("About")) {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            Link("Privacy Policy", destination: URL(string: "https://www.example.com/privacy-policy")!)
            Link("Terms of Service", destination: URL(string: "https://www.example.com/terms-of-service")!)
        }
    }
    
    private func performExport() {
        let result = CSVExport.exportToCSV(entries: budgetManager.entries, timePeriod: exportTimePeriod)
        switch result {
        case .success(let url):
            exportedFileURL = url
            exportResultMessage = "Export successful! File saved at \(url.path)"
        case .failure(let error):
            exportResultMessage = "Export failed: \(error.localizedDescription)"
        }
        showingExportResult = true
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>, isbudget: Bool) {
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    importResultMessage = "No file selected"
                    showingImportResult = true
                    return
                }
                
                guard url.startAccessingSecurityScopedResource() else {
                    importResultMessage = "Failed to access the file"
                    showingImportResult = true
                    return
                }
                
                defer { url.stopAccessingSecurityScopedResource() }
                
                if isbudget {
                    importBudgetData(from: url)
                } else {
                    importPurchaseData(from: url)
                }
                
            case .failure(let error):
                importResultMessage = "Import failed"
                importErrorDetails = error.localizedDescription
                showingImportResult = true
            }
        }
  
    private func importBudgetData(from url: URL) {
        let result = budgetManager.importBudgetData(from: url)
        switch result {
        case .success(let count):
            importResultMessage = "Successfully imported \(count) budget categories"
            importErrorDetails = ""
        case .failure(let error):
            importResultMessage = "Import failed"
            if let importError = error as? BudgetManager.ImportError {
                switch importError {
                case .invalidFileFormat:
                    importErrorDetails = "The file format is invalid. Please ensure the CSV file has the correct headers and structure."
                case .dataParsingError(let details):
                    importErrorDetails = details
                case .fileAccessError:
                    importErrorDetails = "Failed to access the selected file. Please check the file permissions and try again."
                }
            } else {
                importErrorDetails = error.localizedDescription
            }
        }
        showingImportResult = true
    }
    
    private func importPurchaseData(from url: URL) {
        let result = budgetManager.importPurchaseData(from: url)
        switch result {
        case .success(let count):
            importResultMessage = "Successfully imported \(count) purchase entries"
            importErrorDetails = ""
        case .failure(let error):
            importResultMessage = "Import failed"
            if let importError = error as? BudgetManager.ImportError {
                switch importError {
                case .invalidFileFormat:
                    importErrorDetails = "The file format is invalid. Please ensure the CSV file has the correct headers and structure."
                case .dataParsingError(let details):
                    importErrorDetails = details
                case .fileAccessError:
                    importErrorDetails = "Failed to access the selected file. Please check the file permissions and try again."
                }
            } else {
                importErrorDetails = error.localizedDescription
            }
        }
        showingImportResult = true
    }
    
    private func resetAppData() {
        budgetManager.resetAllData()
        settingsManager.resetToDefaults()
        themeManager.resetToDefaults()
        NotificationManager.shared.cancelAllNotifications()
    }
    
    private func requestNotificationPermissionIfNeeded() {
        NotificationManager.shared.checkNotificationStatus { isAuthorized in
            if !isAuthorized {
                NotificationManager.shared.requestAuthorization { granted in
                    DispatchQueue.main.async {
                        settingsManager.notificationsAllowed = granted
                        if !granted {
                            settingsManager.purchaseNotificationsEnabled = false
                            settingsManager.budgetTotalNotificationsEnabled = false
                        }
                    }
                }
            }
        }
    }
}

struct ExportOptionsView: View {
    @Binding var exportTimePeriod: TimePeriod
    let onExport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Time Period")) {
                    Picker("Time Period", selection: $exportTimePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    
                    if case .custom = exportTimePeriod {
                        DatePicker("Start Date", selection: .constant(Date()), displayedComponents: .date)
                        DatePicker("End Date", selection: .constant(Date()), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Export Options")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        onExport()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImportOptionsView: View {
    let importBudgetData: () -> Void
    let importPurchaseData: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingBudgetFormat = false
    @State private var showingPurchaseFormat = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("CSV Format Information")) {
                    Button("Budget Data Format") {
                        showingBudgetFormat.toggle()
                    }
                    if showingBudgetFormat {
                        Text("Year,Month,Category,Amount,IsHistorical\n2024,7,Groceries,500.00,false\n2024,7,Rent,1200.00,false")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Purchase Data Format") {
                        showingPurchaseFormat.toggle()
                    }
                    if showingPurchaseFormat {
                        Text("Date,Amount,Category,Note\n2024-07-01,45.67,Groceries,Weekly shopping\n2024-07-02,15.00,Transportation,Bus fare")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Import Options")) {
                    Button("Import Budget Data") {
                        importBudgetData()
                        dismiss()
                    }
                    Button("Import Purchase Data") {
                        importPurchaseData()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Import Options")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

