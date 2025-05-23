//
//  MoneyCalculatorView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/19/24.
//
import SwiftUI

/// A calculator view specifically designed for monetary input
public struct MoneyCalculatorView: View {
    // MARK: - Properties
    @Binding private var amount: Double
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var inputString = "0"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Constants
    private enum Constants {
        static let buttonSize: CGFloat = 70
        static let spacing: CGFloat = 10
        static let maxDigits = 10
        static let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    }
    
    // MARK: - Computed Properties
    private var formattedDisplay: String {
        let numberString = inputString
        let length = numberString.count
        
        switch length {
        case 0: return "$0.00"
        case 1: return "$0.0\(numberString)"
        case 2: return "$0.\(numberString)"
        default:
            let decimalIndex = length - 2
            let dollars = String(numberString.prefix(decimalIndex))
            let cents = String(numberString.suffix(2))
            let formattedDollars = formatWithCommas(dollars)
            return "$\(formattedDollars).\(cents)"
        }
    }
    
    private var isValidAmount: Bool {
        guard let value = Double(inputString) else { return false }
        let amount = value / 100.0
        return amount >= AppConstants.Validation.minimumTransactionAmount &&
               amount <= AppConstants.Validation.maximumTransactionAmount
    }
    
    // MARK: - Initialization
    public init(amount: Binding<Double>) {
        self._amount = amount
        let initialAmount = Int(amount.wrappedValue * 100)
        self._inputString = State(initialValue: String(initialAmount))
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Amount Display
                Text(formattedDisplay)
                    .font(.system(size: 46, weight: .medium))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Current amount: \(formattedDisplay)")
                
                Spacer()
                
                // Calculator Pad
                VStack(spacing: Constants.spacing) {
                    ForEach(0..<3) { row in
                        HStack(spacing: Constants.spacing) {
                            ForEach(1...3, id: \.self) { col in
                                let number = (row * 3) + col
                                calculatorButton(number: number)
                            }
                        }
                    }
                    
                    // Bottom row with 0 and delete
                    HStack(spacing: Constants.spacing) {
                        // Clear button
                        calculatorButton(symbol: "C", color: .red) {
                            clear()
                        }
                        
                        // Zero
                        calculatorButton(number: 0)
                        
                        // Delete button
                        calculatorButton(symbol: "⌫", color: .red) {
                            deleteLastDigit()
                        }
                    }
                }
                .padding()
                
                // Done button
                Button(action: saveAmount) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValidAmount ? themeManager.primaryColor : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isValidAmount)
                .padding()
            }
            .navigationTitle("Enter Amount")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Invalid Amount"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Components
    private func calculatorButton(number: Int) -> some View {
        Button(action: { appendDigit(number) }) {
            Text("\(number)")
                .font(.title)
                .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(Constants.buttonSize/2)
        }
        .accessibilityLabel("Number \(number)")
    }
    
    private func calculatorButton(
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Constants.hapticFeedback.impactOccurred()
            action()
        }) {
            Text(symbol)
                .font(.title)
                .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(Constants.buttonSize/2)
        }
        .accessibilityLabel(symbol == "C" ? "Clear" : "Delete")
    }
    
    // MARK: - Helper Methods
    private func appendDigit(_ digit: Int) {
        Constants.hapticFeedback.impactOccurred()
        
        if inputString.count >= Constants.maxDigits {
            showingAlert = true
            alertMessage = "Maximum amount reached"
            return
        }
        
        if inputString == "0" {
            inputString = "\(digit)"
        } else {
            inputString += "\(digit)"
        }
    }
    
    private func deleteLastDigit() {
        if inputString.count > 1 {
            inputString.removeLast()
        } else {
            inputString = "0"
        }
    }
    
    private func clear() {
        inputString = "0"
    }
    
    private func saveAmount() {
        guard let value = Double(inputString) else { return }
        let newAmount = value / 100.0
        
        if newAmount >= AppConstants.Validation.minimumTransactionAmount &&
           newAmount <= AppConstants.Validation.maximumTransactionAmount {
            amount = newAmount
            dismiss()
        } else {
            showingAlert = true
            alertMessage = "Amount must be between $\(AppConstants.Validation.minimumTransactionAmount) and $\(AppConstants.Validation.maximumTransactionAmount)"
        }
    }
    
    private func formatWithCommas(_ string: String) -> String {
        guard let number = Int(string) else { return string }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? string
    }
}

// MARK: - Preview Provider
#if DEBUG
struct MoneyCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        MoneyCalculatorView(amount: .constant(0.0))
            .environmentObject(ThemeManager.shared)
        
        MoneyCalculatorView(amount: .constant(1234.56))
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
