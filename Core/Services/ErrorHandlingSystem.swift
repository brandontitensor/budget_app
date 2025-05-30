//
//  ErrorHandlingSystem.swift
//  Brandon's Budget
//
//  Created on 5/30/25.
//

import SwiftUI
import Foundation

// MARK: - Error Types

/// Standardized error types with user-friendly messages
public enum AppError: LocalizedError, Identifiable {
    case dataLoad(underlying: Error)
    case dataSave(underlying: Error)
    case csvImport(underlying: Error)
    case csvExport(underlying: Error)
    case validation(message: String)
    case network(underlying: Error)
    case permission(type: PermissionType)
    case fileAccess(underlying: Error)
    case generic(message: String)
    
    public enum PermissionType {
        case notifications
        case fileAccess
        case camera
        case photos
    }
    
    public var id: String {
        switch self {
        case .dataLoad: return "dataLoad"
        case .dataSave: return "dataSave"
        case .csvImport: return "csvImport"
        case .csvExport: return "csvExport"
        case .validation: return "validation"
        case .network: return "network"
        case .permission: return "permission"
        case .fileAccess: return "fileAccess"
        case .generic: return "generic"
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .dataLoad:
            return "Unable to load your data"
        case .dataSave:
            return "Unable to save your changes"
        case .csvImport:
            return "Unable to import the selected file"
        case .csvExport:
            return "Unable to export your data"
        case .validation(let message):
            return message
        case .network:
            return "Connection problem"
        case .permission(let type):
            return type.description
        case .fileAccess:
            return "Unable to access the file"
        case .generic(let message):
            return message
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .dataLoad:
            return "Please restart the app and try again."
        case .dataSave:
            return "Check if you have enough storage space and try again."
        case .csvImport:
            return "Make sure the file format is correct and try again."
        case .csvExport:
            return "Check if you have enough storage space and try again."
        case .validation:
            return "Please correct the highlighted fields."
        case .network:
            return "Check your internet connection and try again."
        case .permission(let type):
            return type.recoverySuggestion
        case .fileAccess:
            return "Check file permissions and try again."
        case .generic:
            return "Please try again."
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .validation:
            return .warning
        case .permission, .network:
            return .info
        case .dataLoad, .dataSave:
            return .critical
        default:
            return .error
        }
    }
    
    /// Whether this error should show retry option
    public var isRetryable: Bool {
        switch self {
        case .validation, .permission:
            return false
        default:
            return true
        }
    }
    
    /// Convert system errors to app errors
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map common system errors to app errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError {
                    return .fileAccess(underlying: error)
                }
                return .dataLoad(underlying: error)
            case NSURLErrorDomain:
                return .network(underlying: error)
            default:
                break
            }
        }
        
        // Check for specific error types
        if error is BudgetManager.BudgetManagerError {
            return .dataSave(underlying: error)
        }
        
        if error is CSVImport.ImportError {
            return .csvImport(underlying: error)
        }
        
        if error is CSVExport.ExportError {
            return .csvExport(underlying: error)
        }
        
        return .generic(message: error.localizedDescription)
    }
}

public enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

extension AppError.PermissionType {
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

// MARK: - Error Handler

/// Centralized error handling service
@MainActor
public final class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    @Published public var currentError: AppError?
    @Published public var isShowingError = false
    @Published public var errorHistory: [ErrorEntry] = []
    
    private let maxHistoryCount = 50
    
    public struct ErrorEntry: Identifiable {
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
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
                Text(error.errorDescription ?? "Error")
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
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(error.severity.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Toast notification for errors
public struct ErrorToast: View {
    let error: AppError
    @State private var isVisible = false
    private let duration: TimeInterval
    private let onDismiss: (() -> Void)?
    
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
            
            Text(error.errorDescription ?? "Error")
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
}

// MARK: - Error History View

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
}
#endif
