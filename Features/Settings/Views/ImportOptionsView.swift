//
//  ImportOptionsView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//
import SwiftUI

/// View for handling data import options and configuration
struct ImportOptionsView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Bindings
    @Binding var showingImportBudgetPicker: Bool
    @Binding var showingImportPurchasePicker: Bool
    
    // MARK: - State
    @State private var showingBudgetFormat = false
    @State private var showingPurchaseFormat = false
    @State private var selectedImportType: ImportType?
    
    // MARK: - Types
    private enum ImportType {
        case budget
        case purchases
    }
    
    // MARK: - Constants
    private let maxFileSize = AppConstants.Data.maxImportFileSize
    private let supportedFormats = AppConstants.Data.supportedImportFormats
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                formatSection
                importOptionsSection
                notesSection
            }
            .navigationTitle("Import Data")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert(
                "Select File",
                isPresented: .constant(selectedImportType != nil)
            ) {
                Button("Import") {
                    handleImport()
                }
                Button("Cancel", role: .cancel) {
                    selectedImportType = nil
                }
            } message: {
                Text("Choose a CSV file to import")
            }
        }
    }
    
    // MARK: - View Components
    private var formatSection: some View {
        Section(header: Text("CSV Format Information")) {
            formatButton(
                title: "Budget Data Format",
                isExpanded: $showingBudgetFormat,
                format: """
                Year,Month,Category,Amount,IsHistorical
                2024,7,Groceries,500.00,false
                2024,7,Rent,1200.00,false
                """
            )
            
            formatButton(
                title: "Purchase Data Format",
                isExpanded: $showingPurchaseFormat,
                format: """
                Date,Amount,Category,Note
                2024-07-01,45.67,Groceries,Weekly shopping
                2024-07-02,15.00,Transportation,Bus fare
                """
            )
        }
    }
    
    private var importOptionsSection: some View {
        Section(header: Text("Import Options")) {
            Button {
                selectedImportType = .budget
            } label: {
                ImportOptionRow(
                    title: "Import Budget Data",
                    subtitle: "Import your budget categories and amounts",
                    iconName: "chart.pie.fill"
                )
            }
            
            Button {
                selectedImportType = .purchases
            } label: {
                ImportOptionRow(
                    title: "Import Purchase Data",
                    subtitle: "Import your transaction history",
                    iconName: "cart.fill"
                )
            }
        }
    }
    
    private var notesSection: some View {
        Section(
            header: Text("Important Notes"),
            footer: Text("Make sure your CSV file matches the expected format exactly.")
        ) {
            ImportNoteRow(
                icon: "exclamationmark.triangle",
                text: "Existing data will not be overwritten"
            )
            ImportNoteRow(
                icon: "arrow.up.doc",
                text: "Maximum file size: \(formatFileSize(maxFileSize))"
            )
            ImportNoteRow(
                icon: "doc.text",
                text: "UTF-8 encoding required"
            )
        }
    }
    
    private func formatButton(
        title: String,
        isExpanded: Binding<Bool>,
        format: String
    ) -> some View {
        VStack(alignment: .leading) {
            Button(title) {
                withAnimation {
                    isExpanded.wrappedValue.toggle()
                }
            }
            
            if isExpanded.wrappedValue {
                Text(format)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .textSelection(.enabled)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleImport() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch selectedImportType {
            case .budget:
                showingImportBudgetPicker = true
            case .purchases:
                showingImportPurchasePicker = true
            case .none:
                break
            }
            selectedImportType = nil
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Supporting Views
struct ImportOptionRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ImportNoteRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ImportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ImportOptionsView(
            showingImportBudgetPicker: .constant(false),
            showingImportPurchasePicker: .constant(false)
        )
        .environmentObject(ThemeManager.shared)
        
        ImportOptionsView(
            showingImportBudgetPicker: .constant(false),
            showingImportPurchasePicker: .constant(false)
        )
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
    }
}
#endif
