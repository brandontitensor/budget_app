//
//  MoneyCalculatorView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/19/24.
//  Updated: 7/7/25 - Fixed Hashable conformance and private method visibility
//

import SwiftUI

/// A calculator view specifically designed for monetary input with enhanced error handling and accessibility
public struct MoneyCalculatorView: View {
    // MARK: - Properties
    @Binding private var amount: Double
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @State private var inputString = "0"
    @State private var isProcessing = false
    @State private var hasValidInput = true
    @State private var showingConfirmation = false
    
    // MARK: - Constants
    private enum Constants {
        static let buttonSize: CGFloat = 70
        static let spacing: CGFloat = 12
        static let maxDigits = 12
        static let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
        static let errorFeedback = UINotificationFeedbackGenerator()
    }
    
    // MARK: - Button Data
    private let buttonLayout: [[CalculatorButton]] = [
        [.number(7), .number(8), .number(9)],
        [.number(4), .number(5), .number(6)],
        [.number(1), .number(2), .number(3)],
        [.clear, .number(0), .delete]
    ]
    
    private enum CalculatorButton: Equatable, Hashable {
        case number(Int)
        case clear
        case delete
        
        var title: String {
            switch self {
            case .number(let num): return "\(num)"
            case .clear: return "C"
            case .delete: return "⌫"
            }
        }
        
        var color: Color {
            switch self {
            case .number: return .primary
            case .clear: return .red
            case .delete: return .red
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .number(let num): return "Number \(num)"
            case .clear: return "Clear all"
            case .delete: return "Delete last digit"
            }
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDisplay: String {
        let value = Double(inputString) ?? 0
        let amount = value / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private var currentAmount: Double {
        guard let value = Double(inputString) else { return 0 }
        return value / 100.0
    }
    
    private var canSave: Bool {
        hasValidInput && !isProcessing && currentAmount > 0
    }
    
    private var validationMessage: String? {
        let amount = currentAmount
        
        if amount < AppConstants.Validation.minimumTransactionAmount && amount > 0 {
            return "Amount must be at least \(AppConstants.Validation.minimumTransactionAmount.asCurrency)"
        } else if amount > AppConstants.Validation.maximumTransactionAmount {
            return "Amount cannot exceed \(AppConstants.Validation.maximumTransactionAmount.asCurrency)"
        }
        
        return nil
    }
    
    // MARK: - Initializer
    public init(amount: Binding<Double>) {
        self._amount = amount
        let initialValue = Int(amount.wrappedValue * 100)
        self._inputString = State(initialValue: initialValue > 0 ? "\(initialValue)" : "0")
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Header with close button
                headerView
                
                // Amount display
                amountDisplay
                
                // Calculator pad
                calculatorPad
                
                // Action buttons
                actionButtons
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            setupInitialAmount()
        }
        .confirmationDialog(
            "Large Amount",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm \(currentAmount.asCurrency)") {
                Task<Void, Never>{ await saveAmount() }
            }
            Button("Edit Amount", role: .cancel) {
                showingConfirmation = false
            }
        } message: {
            Text("This is a large amount. Are you sure you want to continue?")
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("Enter Amount")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .foregroundColor(themeManager.primaryColor)
        }
    }
    
    private var amountDisplay: some View {
        VStack(spacing: 8) {
            // Main amount display
            Text(formattedDisplay)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(hasValidInput ? themeManager.primaryColor : .red)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Current amount: \(formattedDisplay)")
                .animation(.easeInOut(duration: 0.2), value: formattedDisplay)
            
            // Validation message
            if let message = validationMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
            
            // Amount breakdown (for larger amounts)
            if currentAmount >= 1000 {
                Text(formatAmountBreakdown())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: validationMessage != nil)
    }
    
    // MARK: - Calculator Pad
    private var calculatorPad: some View {
        VStack(spacing: Constants.spacing) {
            ForEach(buttonLayout.indices, id: \.self) { rowIndex in
                HStack(spacing: Constants.spacing) {
                    ForEach(buttonLayout[rowIndex], id: \.self) { button in
                        calculatorButton(button)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func calculatorButton(_ button: CalculatorButton) -> some View {
        Button(action: { handleButtonPress(button) }) {
            Text(button.title)
                .font(.title2.weight(.medium))
                .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemBackground))
                        .overlay(
                            Circle()
                                .stroke(button.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundColor(button.color)
        }
        .disabled(isProcessing)
        .scaleEffect(isProcessing ? 0.95 : 1.0)
        .accessibilityLabel(button.accessibilityLabel)
        .accessibilityHint(getAccessibilityHint(for: button))
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Done button
            Button(action: { handleSaveAction() }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isProcessing ? "Saving..." : "Done")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canSave ? themeManager.primaryColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canSave)
            .accessibilityLabel(canSave ? "Save amount" : "Invalid amount, cannot save")
            
            // Quick amount buttons
            quickAmountButtons
        }
    }
    
    private var quickAmountButtons: some View {
        HStack(spacing: 12) {
            ForEach([5.00, 10.00, 20.00, 50.00], id: \.self) { quickAmount in
                Button(action: { setQuickAmount(quickAmount) }) {
                    Text(quickAmount.asCurrency)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.primaryColor.opacity(0.1))
                        .foregroundColor(themeManager.primaryColor)
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                .accessibilityLabel("Set amount to \(quickAmount.asCurrency)")
            }
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(themeManager.primaryColor)
                
                Text("Processing...")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialAmount() {
        if amount > 0 {
            let initialValue = Int(amount * 100)
            inputString = "\(initialValue)"
        }
    }
    
    private func handleButtonPress(_ button: CalculatorButton) {
        Constants.hapticFeedback.impactOccurred()
        
        switch button {
        case .number(let digit):
            appendDigit(digit)
        case .clear:
            clearInput()
        case .delete:
            deleteLastDigit()
        }
        
        updateValidation()
    }
    
    private func appendDigit(_ digit: Int) {
        guard inputString.count < Constants.maxDigits else {
            showMaxDigitsError()
            return
        }
        
        if inputString == "0" {
            inputString = "\(digit)"
        } else {
            inputString += "\(digit)"
        }
    }
    
    private func clearInput() {
        inputString = "0"
    }
    
    private func deleteLastDigit() {
        if inputString.count > 1 {
            inputString.removeLast()
        } else {
            inputString = "0"
        }
    }
    
    private func setQuickAmount(_ amount: Double) {
        let value = Int(amount * 100)
        inputString = "\(value)"
        updateValidation()
    }
    
    private func updateValidation() {
        hasValidInput = validationMessage == nil
    }
    
    private func handleSaveAction() {
        guard canSave else {
            showValidationError()
            return
        }
        
        // Show confirmation for large amounts
        if currentAmount >= 100 {
            showingConfirmation = true
        } else {
            Task<Void, Never>{
                await saveAmount()
            }
        }
    }
    
    private func saveAmount() async {
        isProcessing = true
        
        do {
            try validateAmount()
            
            // Simulate processing delay for better UX
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                amount = currentAmount
                isProcessing = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isProcessing = false
                errorHandler.handle(AppError.from(error), context: "Saving amount")
            }
        }
    }
    
    private func validateAmount() throws {
        let amount = currentAmount
        
        guard amount >= AppConstants.Validation.minimumTransactionAmount else {
            throw AppError.validation(message: "Amount must be at least \(AppConstants.Validation.minimumTransactionAmount.asCurrency)")
        }
        
        guard amount <= AppConstants.Validation.maximumTransactionAmount else {
            throw AppError.validation(message: "Amount cannot exceed \(AppConstants.Validation.maximumTransactionAmount.asCurrency)")
        }
    }
    
    private func showMaxDigitsError() {
        Constants.errorFeedback.notificationOccurred(.error)
        errorHandler.handle(
            .validation(message: "Maximum number of digits reached"),
            context: "Money Calculator"
        )
    }
    
    private func showValidationError() {
        Constants.errorFeedback.notificationOccurred(.error)
        if let message = validationMessage {
            errorHandler.handle(
                .validation(message: message),
                context: "Money Calculator"
            )
        }
    }
    
    private func formatWithCommas(_ string: String) -> String {
        guard let number = Int(string) else { return string }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? string
    }
    
    private func formatAmountBreakdown() -> String {
        let amount = currentAmount
        let dollars = Int(amount)
        let cents = Int((amount.truncatingRemainder(dividingBy: 1)) * 100)
        
        if cents == 0 {
            return "\(dollars) dollars"
        } else {
            return "\(dollars) dollars and \(cents) cents"
        }
    }
    
    private func getAccessibilityHint(for button: CalculatorButton) -> String {
        switch button {
        case .number(let num):
            return "Add digit \(num) to amount"
        case .clear:
            return "Clear all digits and reset to zero"
        case .delete:
            return "Remove the last digit"
        }
    }
}


// MARK: - Accessibility Extensions

extension MoneyCalculatorView {
    /// Create accessibility-focused version
    private var accessibleBody: some View {
        body
            .accessibilityElement(children: .contain)
            .accessibilityAction(.default) {
                if canSave {
                    Task<Void, Never>{
                        await saveAmount()
                    }
                }
            }
            .accessibilityAction(.escape) {
                dismiss()
            }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct MoneyCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            MoneyCalculatorView(amount: .constant(0.0))
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Empty Amount")
            
            // With existing amount
            MoneyCalculatorView(amount: .constant(1234.56))
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Existing Amount")
            
            // Dark mode
            MoneyCalculatorView(amount: .constant(25.99))
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Large amount
            MoneyCalculatorView(amount: .constant(999999.99))
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Large Amount")
        }
    }
}

// MARK: - Test Helpers
#if DEBUG
extension MoneyCalculatorView {
    /// Initialize with test data
    static func createTestView(initialAmount: Double = 0.0) -> some View {
        MoneyCalculatorView(amount: .constant(initialAmount))
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
    }
    
    /// Get current input for testing
    var currentInputForTesting: String {
        inputString
    }
    
    /// Simulate button press for testing
    mutating func simulateButtonPressForTesting(_ button: CalculatorButton) {
        handleButtonPress(button)
    }
}
#endif
#endif
