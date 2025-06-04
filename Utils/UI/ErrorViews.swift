//
//  ErrorViews.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//


//
//  ErrorViews.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//

import SwiftUI

// MARK: - Error State Views

/// Comprehensive error display components for the app
public struct ErrorViews {
    
    // MARK: - Basic Error View
    
    /// Simple error message view with icon and text
    public struct BasicErrorView: View {
        let error: AppError
        let onDismiss: (() -> Void)?
        let onRetry: (() -> Void)?
        
        public init(
            error: AppError,
            onDismiss: (() -> Void)? = nil,
            onRetry: (() -> Void)? = nil
        ) {
            self.error = error
            self.onDismiss = onDismiss
            self.onRetry = onRetry
        }
        
        public var body: some View {
            VStack(spacing: 16) {
                Image(systemName: error.severity.icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(error.severity.color))
                
                VStack(spacing: 8) {
                    Text(error.errorDescription ?? "Unknown Error")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                buttonSection
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(error.severity.color).opacity(0.3), lineWidth: 1)
            )
        }
        
        @ViewBuilder
        private var buttonSection: some View {
            HStack(spacing: 12) {
                if let onRetry = onRetry, error.isRetryable {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let onDismiss = onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Full Screen Error View
    
    /// Full screen error view for critical failures
    public struct FullScreenErrorView: View {
        let error: AppError
        let onRetry: (() -> Void)?
        let onSupport: (() -> Void)?
        @Environment(\.dismiss) private var dismiss
        
        public init(
            error: AppError,
            onRetry: (() -> Void)? = nil,
            onSupport: (() -> Void)? = nil
        ) {
            self.error = error
            self.onRetry = onRetry
            self.onSupport = onSupport
        }
        
        public var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                        
                        errorIcon
                        
                        errorContent
                        
                        actionButtons
                        
                        if error.severity == .critical {
                            troubleshootingSection
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("Error")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        
        private var errorIcon: some View {
            Image(systemName: error.severity.icon)
                .font(.system(size: 80))
                .foregroundColor(Color(error.severity.color))
        }
        
        private var errorContent: some View {
            VStack(spacing: 16) {
                Text(error.errorDescription ?? "An unexpected error occurred")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if error.severity == .critical {
                    Text("This is a critical error that may require app restart or data recovery.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
        }
        
        @ViewBuilder
        private var actionButtons: some View {
            VStack(spacing: 12) {
                if let onRetry = onRetry, error.isRetryable {
                    Button("Try Again") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                if let onSupport = onSupport {
                    Button("Contact Support") {
                        onSupport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Button("Report Issue") {
                    reportIssue()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        
        @ViewBuilder
        private var troubleshootingSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Troubleshooting Steps")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    TroubleshootingRow(
                        icon: "arrow.clockwise",
                        text: "Force close and restart the app"
                    )
                    TroubleshootingRow(
                        icon: "wifi",
                        text: "Check your internet connection"
                    )
                    TroubleshootingRow(
                        icon: "externaldrive",
                        text: "Ensure sufficient storage space"
                    )
                    TroubleshootingRow(
                        icon: "gear",
                        text: "Check app permissions in Settings"
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        
        private func reportIssue() {
            // Implementation would integrate with crash reporting or support system
            print("📝 Reporting issue: \(error.errorDescription ?? "Unknown error")")
        }
    }
    
    // MARK: - Inline Error Banner
    
    /// Compact error banner for inline display
    public struct InlineErrorBanner: View {
        let error: AppError
        let onDismiss: (() -> Void)?
        let onRetry: (() -> Void)?
        @State private var isVisible = true
        
        public init(
            error: AppError,
            onDismiss: (() -> Void)? = nil,
            onRetry: (() -> Void)? = nil
        ) {
            self.error = error
            self.onDismiss = onDismiss
            self.onRetry = onRetry
        }
        
        public var body: some View {
            if isVisible {
                HStack(spacing: 12) {
                    Image(systemName: error.severity.icon)
                        .foregroundColor(Color(error.severity.color))
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.errorDescription ?? "Error")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    actionButtonsCompact
                }
                .padding()
                .background(Color(error.severity.color).opacity(0.1))
                .overlay(
                    Rectangle()
                        .frame(width: 4)
                        .foregroundColor(Color(error.severity.color)),
                    alignment: .leading
                )
                .cornerRadius(8)
                .transition(.slide.combined(with: .opacity))
            }
        }
        
        @ViewBuilder
        private var actionButtonsCompact: some View {
            HStack(spacing: 8) {
                if let onRetry = onRetry, error.isRetryable {
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button(action: dismissBanner) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        
        private func dismissBanner() {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            onDismiss?()
        }
    }
    
    // MARK: - Network Error View
    
    /// Specialized view for network-related errors
    public struct NetworkErrorView: View {
        let onRetry: (() -> Void)?
        let onSettings: (() -> Void)?
        @State private var isCheckingConnection = false
        
        public init(
            onRetry: (() -> Void)? = nil,
            onSettings: (() -> Void)? = nil
        ) {
            self.onRetry = onRetry
            self.onSettings = onSettings
        }
        
        public var body: some View {
            VStack(spacing: 24) {
                connectionIcon
                
                VStack(spacing: 12) {
                    Text("No Internet Connection")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please check your internet connection and try again.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    if let onRetry = onRetry {
                        Button(action: {
                            checkConnection()
                            onRetry()
                        }) {
                            HStack {
                                if isCheckingConnection {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Try Again")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCheckingConnection)
                    }
                    
                    if let onSettings = onSettings {
                        Button("Open Settings") {
                            onSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                troubleshootingTips
            }
            .padding()
        }
        
        private var connectionIcon: some View {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.red)
            }
        }
        
        private var troubleshootingTips: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Troubleshooting Tips:")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                TroubleshootingRow(
                    icon: "wifi",
                    text: "Check Wi-Fi or cellular connection"
                )
                TroubleshootingRow(
                    icon: "airplane",
                    text: "Turn off Airplane Mode if enabled"
                )
                TroubleshootingRow(
                    icon: "arrow.clockwise",
                    text: "Restart your router or modem"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        
        private func checkConnection() {
            isCheckingConnection = true
            
            // Simulate connection check
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isCheckingConnection = false
            }
        }
    }
    
    // MARK: - Empty State Error View
    
    /// View for when data is empty or unavailable
    public struct EmptyStateView: View {
        let title: String
        let message: String
        let systemImage: String
        let actionTitle: String?
        let onAction: (() -> Void)?
        
        public init(
            title: String,
            message: String,
            systemImage: String = "tray",
            actionTitle: String? = nil,
            onAction: (() -> Void)? = nil
        ) {
            self.title = title
            self.message = message
            self.systemImage = systemImage
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
        
        public var body: some View {
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let actionTitle = actionTitle, let onAction = onAction {
                    Button(actionTitle) {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Permission Error View
    
    /// View for permission-related errors
    public struct PermissionErrorView: View {
        let permissionType: AppError.PermissionType
        let onOpenSettings: (() -> Void)?
        let onDismiss: (() -> Void)?
        
        public init(
            permissionType: AppError.PermissionType,
            onOpenSettings: (() -> Void)? = nil,
            onDismiss: (() -> Void)? = nil
        ) {
            self.permissionType = permissionType
            self.onOpenSettings = onOpenSettings
            self.onDismiss = onDismiss
        }
        
        public var body: some View {
            VStack(spacing: 24) {
                permissionIcon
                
                VStack(spacing: 12) {
                    Text(permissionType.description)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(permissionType.recoverySuggestion)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    if let onOpenSettings = onOpenSettings {
                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if let onDismiss = onDismiss {
                        Button("Maybe Later") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                permissionInstructions
            }
            .padding()
        }
        
        private var permissionIcon: some View {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: permissionIconName)
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
        }
        
        private var permissionIconName: String {
            switch permissionType {
            case .notifications: return "bell.slash"
            case .fileAccess: return "folder.badge.minus"
            case .camera: return "camera.fill"
            case .photos: return "photo.on.rectangle"
            }
        }
        
        @ViewBuilder
        private var permissionInstructions: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("How to enable:")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                switch permissionType {
                case .notifications:
                    InstructionRow(step: "1", text: "Open iPhone Settings")
                    InstructionRow(step: "2", text: "Find 'Brandon's Budget'")
                    InstructionRow(step: "3", text: "Tap 'Notifications'")
                    InstructionRow(step: "4", text: "Turn on 'Allow Notifications'")
                    
                case .fileAccess:
                    InstructionRow(step: "1", text: "Open iPhone Settings")
                    InstructionRow(step: "2", text: "Find 'Brandon's Budget'")
                    InstructionRow(step: "3", text: "Enable file access permissions")
                    
                case .camera:
                    InstructionRow(step: "1", text: "Open iPhone Settings")
                    InstructionRow(step: "2", text: "Tap 'Privacy & Security'")
                    InstructionRow(step: "3", text: "Tap 'Camera'")
                    InstructionRow(step: "4", text: "Enable for 'Brandon's Budget'")
                    
                case .photos:
                    InstructionRow(step: "1", text: "Open iPhone Settings")
                    InstructionRow(step: "2", text: "Tap 'Privacy & Security'")
                    InstructionRow(step: "3", text: "Tap 'Photos'")
                    InstructionRow(step: "4", text: "Enable for 'Brandon's Budget'")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Error Toast
    
    /// Temporary toast notification for errors
    public struct ErrorToast: View {
        let error: AppError
        @State private var isVisible = false
        @State private var dragOffset: CGSize = .zero
        let onDismiss: (() -> Void)?
        
        public init(error: AppError, onDismiss: (() -> Void)? = nil) {
            self.error = error
            self.onDismiss = onDismiss
        }
        
        public var body: some View {
            HStack(spacing: 12) {
                Image(systemName: error.severity.icon)
                    .foregroundColor(.white)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.errorDescription ?? "Error")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button(action: dismissToast) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(error.severity.color))
            .cornerRadius(10)
            .shadow(radius: 5)
            .offset(y: isVisible ? 0 : -100)
            .offset(dragOffset)
            .opacity(isVisible ? 1 : 0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.y < 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.y < -50 {
                            dismissToast()
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onAppear {
                withAnimation(.spring()) {
                    isVisible = true
                }
                
                // Auto-dismiss after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    dismissToast()
                }
            }
        }
        
        private func dismissToast() {
            withAnimation(.spring()) {
                isVisible = false
                dragOffset = CGSize(width: 0, height: -100)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss?()
            }
        }
    }
}

// MARK: - Supporting Views

/// Row for troubleshooting instructions
private struct TroubleshootingRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

/// Row for step-by-step instructions
private struct InstructionRow: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 24, height: 24)
                
                Text(step)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Error View Modifier

/// View modifier to handle errors with automatic UI
public struct ErrorHandling: ViewModifier {
    let context: String
    let showInline: Bool
    let onRetry: (() -> Void)?
    
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var showingErrorSheet = false
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showInline, let error = errorHandler.currentError {
                    ErrorViews.InlineErrorBanner(
                        error: error,
                        onDismiss: {
                            errorHandler.clearError()
                        },
                        onRetry: onRetry
                    )
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingErrorSheet) {
                if let error = errorHandler.currentError {
                    ErrorViews.FullScreenErrorView(
                        error: error,
                        onRetry: onRetry,
                        onSupport: {
                            openSupportPage()
                        }
                    )
                }
            }
            .onChange(of: errorHandler.currentError) { oldError, newError in
                if let error = newError, error.severity == .critical && !showInline {
                    showingErrorSheet = true
                }
            }
    }
    
    private func openSupportPage() {
        if let url = URL(string: "https://www.example.com/support") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Add error handling with customizable options
    public func errorHandling(
        context: String,
        showInline: Bool = true,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorHandling(
            context: context,
            showInline: showInline,
            onRetry: onRetry
        ))
    }
    
    /// Show error toast overlay
    public func errorToast(
        error: Binding<AppError?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        overlay(alignment: .top) {
            if let currentError = error.wrappedValue {
                ErrorViews.ErrorToast(error: currentError) {
                    error.wrappedValue = nil
                    onDismiss?()
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Predefined Error Views

extension ErrorViews {
    /// Network connection error
    public static func networkError(onRetry: @escaping () -> Void) -> some View {
        NetworkErrorView(onRetry: onRetry) {
            openSystemSettings()
        }
    }
    
    /// No data available
    public static func noDataAvailable(
        title: String = "No Data Available",
        message: String = "There's nothing to show right now.",
        actionTitle: String? = "Refresh",
        onAction: (() -> Void)? = nil
    ) -> some View {
        EmptyStateView(
            title: title,
            message: message,
            systemImage: "tray",
            actionTitle: actionTitle,
            onAction: onAction
        )
    }
    
    /// Budget data error
    public static func budgetDataError(onRetry: @escaping () -> Void) -> some View {
        BasicErrorView(
            error: AppError.dataLoad(underlying: NSError(
                domain: "BudgetError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load budget data"]
            )),
            onRetry: onRetry
        )
    }
    
    /// Import/Export error
    public static func importExportError(
        _ error: AppError,
        onRetry: @escaping () -> Void
    ) -> some View {
        BasicErrorView(
            error: error,
            onRetry: onRetry
        )
    }
    
    private static func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension ErrorViews {
    public struct TestErrorViews: View {
        @State private var showingToast = false
        @State private var currentError: AppError?
        
        public var body: some View {
            NavigationView {
                List {
                    Section("Error Types") {
                        Button("Show Network Error") {
                            currentError = AppError.network(underlying: URLError(.notConnectedToInternet))
                            showingToast = true
                        }
                        
                        Button("Show Validation Error") {
                            currentError = AppError.validation(message: "Amount must be greater than zero")
                            showingToast = true
                        }
                        
                        Button("Show Critical Error") {
                            currentError = AppError.dataLoad(underlying: NSError(
                                domain: "TestError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Critical system failure"]
                            ))
                            showingToast = true
                        }
                        
                        Button("Show Permission Error") {
                            currentError = AppError.permission(type: .notifications)
                            showingToast = true
                        }
                    }
                    
                    Section("Error Components") {
                        NavigationLink("Basic Error View") {
                            BasicErrorView(
                                error: AppError.validation(message: "Test error message"),
                                onRetry: { print("Retry tapped") }
                            )
                            .padding()
                        }
                        
                        NavigationLink("Network Error View") {
                            NetworkErrorView(
                                onRetry: { print("Retry tapped") }
                            )
                        }
                        
                        NavigationLink("Empty State View") {
                            EmptyStateView(
                                title: "No Transactions",
                                message: "You haven't added any transactions yet.",
                                systemImage: "cart",
                                actionTitle: "Add Transaction",
                                onAction: { print("Add tapped") }
                            )
                        }
                        
                        NavigationLink("Permission Error View") {
                            PermissionErrorView(
                                permissionType: .notifications,
                                onOpenSettings: { print("Settings tapped") }
                            )
                        }
                    }
                }
                .navigationTitle("Error Views Test")
            }
            .errorToast(error: $currentError)
        }
    }
}
#endif