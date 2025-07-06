//
//  ErrorHandlingSystem.swift
//  Brandon's Budget
//
//  Created on 5/30/25.
//  Updated: 7/5/25 - Complete and enhanced error handling system
//

import SwiftUI
import Foundation

// MARK: - Error Types

/// Represents different severity levels for errors
public enum ErrorSeverity: Sendable {
    case info
    case warning
    case error
    case critical
    
    /// UI color for the error severity
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
    
    /// System icon for the error severity
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

/// Application-specific error types with user-friendly messages
public enum AppError: LocalizedError, Identifiable, Equatable, Sendable {
    case dataLoad(underlying: Error)
    case dataSave(underlying: Error)
    case csvImport(underlying: Error)
    case csvExport(underlying: Error)
    case validation(message: String)
    case network(underlying: Error)
    case permission(type: PermissionType)
    case fileAccess(underlying: Error)
    case generic(message: String)
    
    public var id: String {
        switch self {
        case .dataLoad: return "dataLoad"
        case .dataSave: return "dataSave"
        case .csvImport: return "csvImport"
        case .csvExport: return "csvExport"
        case .validation(let message): return "validation_\(message.hashValue)"
        case .network: return "network"
        case .permission(let type): return "permission_\(type)"
        case .fileAccess: return "fileAccess"
        case .generic(let message): return "generic_\(message.hashValue)"
        }
    }
    
    // MARK: - Equatable Conformance
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.dataLoad(let lhsError), .dataLoad(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.dataSave(let lhsError), .dataSave(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.csvImport(let lhsError), .csvImport(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.csvExport(let lhsError), .csvExport(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.validation(let lhsMessage), .validation(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.network(let lhsError), .network(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.permission(let lhsType), .permission(let rhsType)):
            return lhsType == rhsType
        case (.fileAccess(let lhsError), .fileAccess(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.generic(let lhsMessage), .generic(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    /// Permission types for permission-related errors
    public enum PermissionType: Equatable, Sendable {
        case notifications
        case fileAccess
        case camera
        case photos
        
        var description: String {
            switch self {
            case .notifications:
                return "Notifications are disabled"
            case .fileAccess:
                return "File access is not allowed"
            case .camera:
                return "Camera access is not allowed"
            case .photos:
                return "Photo library access is not allowed"
            }
        }
        
        var recoverySuggestion: String {
            switch self {
            case .notifications:
                return "Enable notifications in Settings to receive budget reminders."
            case .fileAccess:
                return "Grant file access permission in Settings to import/export data."
            case .camera:
                return "Grant camera permission in Settings to scan receipts."
            case .photos:
                return "Grant photo library permission in Settings to import receipt images."
            }
        }
    }
    
    /// User-facing error description
    public var errorDescription: String? {
        switch self {
        case .dataLoad:
            return "Failed to load data"
        case .dataSave:
            return "Failed to save data"
        case .csvImport:
            return "Failed to import CSV file"
        case .csvExport:
            return "Failed to export CSV file"
        case .validation(let message):
            return message
        case .network:
            return "Network connection error"
        case .permission(let type):
            return type.description
        case .fileAccess:
            return "File access error"
        case .generic(let message):
            return message
        }
    }
    
    /// User-facing recovery suggestion
    public var recoverySuggestion: String? {
        switch self {
        case .dataLoad:
            return "Please try refreshing the data or restart the app."
        case .dataSave:
            return "Please try again or check available storage space."
        case .csvImport:
            return "Please check the file format and try again."
        case .csvExport:
            return "Please check available storage space and try again."
        case .validation:
            return "Please correct the input and try again."
        case .network:
            return "Please check your internet connection and try again."
        case .permission(let type):
            return type.recoverySuggestion
        case .fileAccess:
            return "Please check file permissions and try again."
        case .generic:
            return "Please try again. If the problem persists, contact support."
        }
    }
    
    /// Error severity level
    public var severity: ErrorSeverity {
        switch self {
        case .dataLoad, .dataSave:
            return .critical
        case .csvImport, .csvExport, .fileAccess:
            return .error
        case .network:
            return .warning
        case .permission:
            return .warning
        case .validation:
            return .info
        case .generic:
            return .error
        }
    }
    
    /// Whether the error is retryable
    public var isRetryable: Bool {
        switch self {
        case .dataLoad, .dataSave, .csvImport, .csvExport, .network, .fileAccess:
            return true
        case .validation, .permission, .generic:
            return false
        }
    }
    
    /// Smart error transformation from generic errors
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Handle specific manager errors
        let errorString = String(describing: error)
        if errorString.contains("BudgetManagerError") || errorString.contains("BudgetManager") {
            if errorString.contains("validation") {
                return .validation(message: error.localizedDescription)
            } else if errorString.contains("save") || errorString.contains("write") {
                return .dataSave(underlying: error)
            } else if errorString.contains("load") || errorString.contains("read") {
                return .dataLoad(underlying: error)
            }
        }
        
        // Handle NSError domains
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return .network(underlying: error)
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileWriteFileExistsError {
                    return .fileAccess(underlying: error)
                }
                return .dataLoad(underlying: error)
            case "CSVError", "ImportError":
                return .csvImport(underlying: error)
            case "ExportError":
                return .csvExport(underlying: error)
            default:
                break
            }
        }
        
        // Handle specific error types by string matching
        let errorDescription = error.localizedDescription.lowercased()
        if errorDescription.contains("network") || errorDescription.contains("internet") || errorDescription.contains("connection") {
            return .network(underlying: error)
        } else if errorDescription.contains("permission") || errorDescription.contains("access") || errorDescription.contains("authorization") {
            return .fileAccess(underlying: error)
        } else if errorDescription.contains("csv") || errorDescription.contains("import") {
            return .csvImport(underlying: error)
        } else if errorDescription.contains("export") {
            return .csvExport(underlying: error)
        } else if errorDescription.contains("save") || errorDescription.contains("write") || errorDescription.contains("persist") {
            return .dataSave(underlying: error)
        } else if errorDescription.contains("load") || errorDescription.contains("read") || errorDescription.contains("fetch") {
            return .dataLoad(underlying: error)
        } else if errorDescription.contains("validation") || errorDescription.contains("invalid") {
            return .validation(message: error.localizedDescription)
        }
        
        // Fallback to generic error
        return .generic(message: error.localizedDescription)
    }
}

// MARK: - Error Handler

/// Centralized error handling service
@MainActor
public final class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    @Published public var currentError: AppError?
    @Published public var isShowingError = false
    @Published public var errorHistory: [ErrorEntry] = []
    
    private let maxHistoryCount = 50
    
    /// Error entry for history tracking
    public struct ErrorEntry: Identifiable, Equatable, Sendable {
        public let id = UUID()
        public let error: AppError
        public let timestamp: Date
        public let context: String?
        
        public init(error: AppError, context: String? = nil) {
            self.error = error
            self.timestamp = Date()
            self.context = context
        }
    }
    
    private init() {}
    
    /// Handle an error with optional context
    public func handle(_ error: Error, context: String? = nil) {
        let appError = AppError.from(error)
        handle(appError, context: context)
    }
    
    /// Handle an app error with optional context
    public func handle(_ error: AppError, context: String? = nil) {
        // Add to history
        let entry = ErrorEntry(error: error, context: context)
        errorHistory.insert(entry, at: 0)
        
        // Limit history size
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeLast()
        }
        
        // Log error
        logError(error, context: context)
        
        // Show error to user
        currentError = error
        isShowingError = true
        
        // Send haptic feedback for critical errors
        if error.severity == .critical {
            #if !os(watchOS) && !WIDGET_EXTENSION
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            #endif
        }
    }
    
    /// Clear current error
    public func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    /// Clear error history
    public func clearHistory() {
        errorHistory.removeAll()
    }
    
    /// Get error count for a specific context
    public func getErrorCount(for context: String) -> Int {
        return errorHistory.filter { $0.context?.contains(context) == true }.count
    }
    
    /// Get recent errors (last 10)
    public func getRecentErrors() -> [ErrorEntry] {
        return Array(errorHistory.prefix(10))
    }
    
    /// Check if there are any critical errors in history
    public func hasCriticalErrors() -> Bool {
        return errorHistory.contains { $0.error.severity == .critical }
    }
    
    private func logError(_ error: AppError, context: String?) {
        let contextString = context.map { " [\($0)]" } ?? ""
        let message = "🚨 \(error.errorDescription ?? "Unknown error")\(contextString)"
        
        #if DEBUG
        print(message)
        if let underlying = getUnderlyingError(from: error) {
            print("   Underlying: \(underlying.localizedDescription)")
        }
        #endif
    }
    
    private func getUnderlyingError(from appError: AppError) -> Error? {
        switch appError {
        case .dataLoad(let error), .dataSave(let error),
             .csvImport(let error), .csvExport(let error),
             .network(let error), .fileAccess(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Error Presentation Views

/// Standardized error alert view
public struct ErrorAlert: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    private let onRetry: (() -> Void)?
    
    public init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorDescription ?? "Error",
                isPresented: $errorHandler.isShowingError,
                presenting: errorHandler.currentError
            ) { error in
                // Primary action button
                if error.isRetryable, let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                        errorHandler.clearError()
                    }
                }
                
                // Cancel/OK button
                Button(error.isRetryable ? "Cancel" : "OK", role: .cancel) {
                    errorHandler.clearError()
                }
            } message: { error in
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                }
            }
    }
}

/// Inline error message view
public struct InlineErrorView: View {
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
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .foregroundColor(error.severity.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorDescription ?? "Unknown error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if error.isRetryable, let onRetry = onRetry {
                    Button("Retry", action: onRetry)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(error.severity.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(error.severity.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Toast notification for errors
public struct ErrorToast: View {
    let error: AppError
    let duration: TimeInterval
    let onDismiss: (() -> Void)?
    
    @State private var isVisible = false
    
    public init(
        error: AppError,
        duration: TimeInterval = 3.0,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.duration = duration
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.severity.icon)
                .foregroundColor(.white)
                .font(.title3)
            
            Text(error.errorDescription ?? "Unknown error")
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
        .background(error.severity.color)
        .cornerRadius(10)
        .shadow(radius: 5)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.spring()) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss?()
                }
            }
        }
    }
}

// MARK: - Error History View

/// Error history browser
public struct ErrorHistoryView: View {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            List {
                if errorHandler.errorHistory.isEmpty {
                    Section {
                        Text("No errors recorded")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Section(header: Text("Recent Errors")) {
                        ForEach(errorHandler.errorHistory) { entry in
                            ErrorHistoryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Error History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                if !errorHandler.errorHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            errorHandler.clearHistory()
                        }
                    }
                }
            }
        }
    }
}

/// Individual error history row
struct ErrorHistoryRow: View {
    let entry: ErrorHandler.ErrorEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.error.severity.icon)
                    .foregroundColor(entry.error.severity.color)
                
                Text(entry.error.errorDescription ?? "Unknown error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
            
            if let recovery = entry.error.recoverySuggestion {
                Text(recovery)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - View Extensions

public extension View {
    /// Add standardized error handling with alert
    func errorAlert(onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(onRetry: onRetry))
    }
    
    /// Handle errors with automatic conversion
    func handleErrors(context: String? = nil) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
            if let error = notification.object as? Error {
                ErrorHandler.shared.handle(error, context: context)
            }
        }
    }
}

// MARK: - Error Reporting Extension

public extension Notification.Name {
    static let errorOccurred = Notification.Name("errorOccurred")
}

// MARK: - Async Error Handling

/// Wrapper for async operations with error handling
public struct AsyncErrorHandler {
    /// Execute async operation with automatic error handling
    public static func execute<T>(
        context: String? = nil,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            await MainActor.run {
                ErrorHandler.shared.handle(error, context: context)
            }
            return nil
        }
    }
    
    /// Execute async operation with custom error transformation
    public static func execute<T>(
        context: String? = nil,
        errorTransform: @escaping (Error) -> AppError,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            let appError = errorTransform(error)
            await MainActor.run {
                ErrorHandler.shared.handle(appError, context: context)
            }
            return nil
        }
    }
    
    /// Execute async operation with result handling
    public static func executeWithResult<T>(
        context: String? = nil,
        operation: @escaping () async throws -> T
    ) async -> Result<T, AppError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            let appError = AppError.from(error)
            await MainActor.run {
                ErrorHandler.shared.handle(appError, context: context)
            }
            return .failure(appError)
        }
    }
    
    /// Execute with silent error handling (no UI notification)
    public static func executeSilently<T>(
        context: String? = nil,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            // Log but don't show to user
            #if DEBUG
            print("🚨 Silent error in \(context ?? "unknown"): \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension ErrorHandler {
    /// Create test errors for preview/testing
    public func createTestErrors() {
        handle(.validation(message: "Amount must be greater than zero"))
        handle(.network(underlying: URLError(.notConnectedToInternet)))
        handle(.permission(type: .notifications))
        handle(.dataSave(underlying: NSError(domain: "TestError", code: -1)))
    }
    
    /// Clear all errors for testing
    public func clearAllForTesting() {
        currentError = nil
        isShowingError = false
        errorHistory.removeAll()
    }
    
    /// Get error statistics for testing
    public func getErrorStatistics() -> (total: Int, critical: Int, warnings: Int, recent: Int) {
        let total = errorHistory.count
        let critical = errorHistory.filter { $0.error.severity == .critical }.count
        let warnings = errorHistory.filter { $0.error.severity == .warning }.count
        let recent = errorHistory.filter { $0.timestamp.timeIntervalSinceNow > -300 }.count // Last 5 minutes
        
        return (total: total, critical: critical, warnings: warnings, recent: recent)
    }
    
    /// Simulate different error scenarios for testing
    public func simulateErrorScenario(_ scenario: TestErrorScenario) {
        switch scenario {
        case .networkIssue:
            handle(.network(underlying: URLError(.notConnectedToInternet)), context: "Network test")
        case .dataCorruption:
            handle(.dataLoad(underlying: NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data corruption detected"])), context: "Data test")
        case .validationFailure:
            handle(.validation(message: "Test validation failed"), context: "Validation test")
        case .permissionDenied:
            handle(.permission(type: .fileAccess), context: "Permission test")
        }
    }
    
    public enum TestErrorScenario {
        case networkIssue
        case dataCorruption
        case validationFailure
        case permissionDenied
    }
}

// Preview provider for testing error views
struct ErrorSystemPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            // Inline error view
            InlineErrorView(
                error: .validation(message: "Please enter a valid amount"),
                onDismiss: {},
                onRetry: {}
            )
            .previewDisplayName("Inline Error")
            
            // Error toast
            ErrorToast(
                error: .network(underlying: URLError(.notConnectedToInternet)),
                onDismiss: {}
            )
            .previewDisplayName("Error Toast")
            
            // Error history
            ErrorHistoryView()
                .previewDisplayName("Error History")
        }
    }
}
#endif
