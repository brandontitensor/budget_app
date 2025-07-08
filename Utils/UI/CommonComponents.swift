//
//  CommonComponents.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/1/25.
//  Updated: 7/7/25 - Fixed ValidationResult conflicts, ThemeManager references, and type conversions
//

import SwiftUI
import Foundation

/// Comprehensive UI component library with consistent styling and validation
public struct CommonComponents {
    
    // MARK: - Validation Types
    
    /// Internal validation result for UI components
    public enum ComponentValidationResult: Equatable, Sendable {
        case valid
        case invalid(String)
        
        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        public var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
        
        /// Convert from ValidationHelpers.ValidationResult to ComponentValidationResult
        public static func from(_ result: ValidationResult) -> ComponentValidationResult {
            switch result {
            case .valid:
                return .valid
            case .invalid(let error):
                return .invalid(error.errorDescription ?? "Invalid input")
            }
        }
    }
    
    // MARK: - Card Components
    
    /// Reusable card view with consistent styling
    public struct CardView<Content: View>: View {
        let content: Content
        let backgroundColor: Color
        let cornerRadius: CGFloat
        let shadowRadius: CGFloat
        let shadowOpacity: Double
        
        public init(
            backgroundColor: Color = Color(.systemBackground),
            cornerRadius: CGFloat = 12,
            shadowRadius: CGFloat = 4,
            shadowOpacity: Double = 0.1,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.shadowRadius = shadowRadius
            self.shadowOpacity = shadowOpacity
        }
        
        public var body: some View {
            content
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 2)
        }
    }
    
    /// Statistics card with trend indicators
    public struct StatsCard: View {
        let title: String
        let value: String
        let subtitle: String?
        let icon: String?
        let color: Color
        let trend: Trend?
        
        public enum Trend: Equatable {
            case up(String)
            case down(String)
            case neutral(String)
            
            var color: Color {
                switch self {
                case .up: return .green
                case .down: return .red
                case .neutral: return .gray
                }
            }
            
            var icon: String {
                switch self {
                case .up: return "arrow.up"
                case .down: return "arrow.down"
                case .neutral: return "minus"
                }
            }
            
            var text: String {
                switch self {
                case .up(let text), .down(let text), .neutral(let text):
                    return text
                }
            }
        }
        
        public init(
            title: String,
            value: String,
            subtitle: String? = nil,
            icon: String? = nil,
            color: Color = .blue,
            trend: Trend? = nil
        ) {
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.icon = icon
            self.color = color
            self.trend = trend
        }
        
        public var body: some View {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(value)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(color)
                        }
                        
                        Spacer()
                        
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(color)
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon)
                                .font(.caption)
                                .foregroundColor(trend.color)
                            
                            Text(trend.text)
                                .font(.caption)
                                .foregroundColor(trend.color)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - List Components
    
    /// Customizable list row
    public struct ListRow<Leading: View, Trailing: View>: View {
        let leading: Leading
        let trailing: Trailing
        let spacing: CGFloat
        let padding: EdgeInsets
        
        public init(
            spacing: CGFloat = 12,
            padding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
            @ViewBuilder leading: () -> Leading,
            @ViewBuilder trailing: () -> Trailing
        ) {
            self.leading = leading()
            self.trailing = trailing()
            self.spacing = spacing
            self.padding = padding
        }
        
        public var body: some View {
            HStack(spacing: spacing) {
                leading
                Spacer()
                trailing
            }
            .padding(padding)
        }
    }
    
    /// Transaction row with consistent styling
    public struct TransactionRow: View {
        let amount: Double
        let category: String
        let date: Date
        let note: String?
        let onTap: (() -> Void)?
        
        public init(
            amount: Double,
            category: String,
            date: Date,
            note: String? = nil,
            onTap: (() -> Void)? = nil
        ) {
            self.amount = amount
            self.category = category
            self.date = date
            self.note = note
            self.onTap = onTap
        }
        
        public var body: some View {
            Button(action: onTap ?? {}) {
                ListRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let note = note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } trailing: {
                    Text(amount.formattedAsCurrency)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            .disabled(onTap == nil)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Input Components
    
    /// Custom text field with validation
    public struct ValidatedTextField: View {
        let title: String
        let placeholder: String
        @Binding var text: String
        let validation: (String) -> ComponentValidationResult
        let keyboardType: UIKeyboardType
        let autocapitalization: TextInputAutocapitalization
        let isSecure: Bool
        
        @State private var validationResult: ComponentValidationResult = .valid
        @FocusState private var isFocused: Bool
        
        public init(
            title: String,
            placeholder: String = "",
            text: Binding<String>,
            validation: @escaping (String) -> ComponentValidationResult = { _ in .valid },
            keyboardType: UIKeyboardType = .default,
            autocapitalization: TextInputAutocapitalization = .sentences,
            isSecure: Bool = false
        ) {
            self.title = title
            self.placeholder = placeholder
            self._text = text
            self.validation = validation
            self.keyboardType = keyboardType
            self.autocapitalization = autocapitalization
            self.isSecure = isSecure
        }
        
        /// Convenience initializer using ValidationHelpers
        public init(
            title: String,
            placeholder: String = "",
            text: Binding<String>,
            validationHelper: @escaping (String) -> ValidationResult,
            keyboardType: UIKeyboardType = .default,
            autocapitalization: TextInputAutocapitalization = .sentences,
            isSecure: Bool = false
        ) {
            self.init(
                title: title,
                placeholder: placeholder,
                text: text,
                validation: { input in
                    ComponentValidationResult.from(validationHelper(input))
                },
                keyboardType: keyboardType,
                autocapitalization: autocapitalization,
                isSecure: isSecure
            )
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .focused($isFocused)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .textFieldStyle(.roundedBorder)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .onChange(of: text) { oldValue, newValue in
                    validationResult = validation(newValue)
                }
                .onSubmit {
                    validationResult = validation(text)
                }
                
                if let errorMessage = validationResult.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
        }
        
        private var borderColor: Color {
            if isFocused {
                return validationResult.isValid ? .blue : .red
            }
            return .clear
        }
    }
    
    /// Currency input field
    public struct CurrencyTextField: View {
        let title: String
        @Binding var amount: Double
        let currencyCode: String
        let isRequired: Bool
        
        @State private var textValue: String = ""
        @FocusState private var isFocused: Bool
        
        public init(
            title: String,
            amount: Binding<Double>,
            currencyCode: String = "USD",
            isRequired: Bool = true
        ) {
            self.title = title
            self._amount = amount
            self.currencyCode = currencyCode
            self.isRequired = isRequired
        }
        
        public var body: some View {
            ValidatedTextField(
                title: title,
                placeholder: "$0.00",
                text: $textValue,
                validation: validateCurrency,
                keyboardType: .decimalPad
            )
            .onAppear {
                if amount > 0 {
                    textValue = String(format: "%.2f", amount)
                }
            }
            .onChange(of: textValue) { oldValue, newValue in
                let cleaned = cleanCurrencyInput(newValue)
                if cleaned != newValue {
                    textValue = cleaned
                }
                amount = Double(cleaned) ?? 0
            }
        }
        
        private func validateCurrency(_ input: String) -> ComponentValidationResult {
            if input.isEmpty && !isRequired {
                return .valid
            }
            
            if input.isEmpty && isRequired {
                return .invalid("Amount is required")
            }
            
            guard let value = Double(input), value >= 0 else {
                return .invalid("Please enter a valid amount")
            }
            
            if value > 999999.99 {
                return .invalid("Amount is too large")
            }
            
            return .valid
        }
        
        private func cleanCurrencyInput(_ input: String) -> String {
            // Remove currency symbols and clean input
            var cleaned = input.replacingOccurrences(of: "$", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            
            // Allow only digits and one decimal point
            let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
            cleaned = String(cleaned.unicodeScalars.filter { allowedCharacters.contains($0) })
            
            // Ensure only one decimal point
            let components = cleaned.components(separatedBy: ".")
            if components.count > 2 {
                cleaned = components[0] + "." + components[1]
            }
            
            // Limit decimal places to 2
            if let dotIndex = cleaned.firstIndex(of: ".") {
                let decimals = cleaned[cleaned.index(after: dotIndex)...]
                if decimals.count > 2 {
                    let endIndex = cleaned.index(dotIndex, offsetBy: 3)
                    cleaned = String(cleaned[..<endIndex])
                }
            }
            
            return cleaned
        }
    }
    
    /// Searchable picker component
    public struct SearchablePicker<T: Hashable & CustomStringConvertible>: View {
        let title: String
        let items: [T]
        @Binding var selection: T?
        let allowsCustomEntry: Bool
        
        @State private var isPresented = false
        @State private var searchText = ""
        
        public init(
            title: String,
            items: [T],
            selection: Binding<T?>,
            allowsCustomEntry: Bool = false
        ) {
            self.title = title
            self.items = items
            self._selection = selection
            self.allowsCustomEntry = allowsCustomEntry
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button(action: { isPresented = true }) {
                    HStack {
                        Text(selection?.description ?? "Select \(title)")
                            .foregroundColor(selection == nil ? .secondary : .primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isPresented) {
                    pickerSheet
                }
            }
        }
        
        private var pickerSheet: some View {
            NavigationView {
                List {
                    if allowsCustomEntry && !searchText.isEmpty {
                        Button("Add \"\(searchText)\"") {
                            // Custom entry logic would go here
                            isPresented = false
                        }
                        .foregroundColor(.blue)
                    }
                    
                    ForEach(filteredItems, id: \.self) { item in
                        Button(action: {
                            selection = item
                            isPresented = false
                        }) {
                            HStack {
                                Text(item.description)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selection == item {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .searchable(text: $searchText)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
            }
        }
        
        private var filteredItems: [T] {
            if searchText.isEmpty {
                return items
            } else {
                return items.filter { item in
                    item.description.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    // MARK: - Button Components
    
    /// Primary button with consistent styling
    public struct PrimaryButton: View {
        let title: String
        let action: () -> Void
        let isEnabled: Bool
        let isLoading: Bool
        let style: ButtonStyle
        
        public enum ButtonStyle {
            case filled
            case outlined
            case text
        }
        
        public init(
            title: String,
            action: @escaping () -> Void,
            isEnabled: Bool = true,
            isLoading: Bool = false,
            style: ButtonStyle = .filled
        ) {
            self.title = title
            self.action = action
            self.isEnabled = isEnabled
            self.isLoading = isLoading
            self.style = style
        }
        
        public var body: some View {
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                    }
                    
                    Text(title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(textColor)
                .background(backgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: style == .outlined ? 1 : 0)
                )
            }
            .disabled(!isEnabled || isLoading)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        
        private var backgroundColor: Color {
            switch style {
            case .filled:
                return .blue
            case .outlined, .text:
                return .clear
            }
        }
        
        private var textColor: Color {
            switch style {
            case .filled:
                return .white
            case .outlined, .text:
                return .blue
            }
        }
        
        private var borderColor: Color {
            switch style {
            case .filled, .text:
                return .clear
            case .outlined:
                return .blue
            }
        }
    }
    
    /// Secondary button variant
    public struct SecondaryButton: View {
        let title: String
        let action: () -> Void
        let isEnabled: Bool
        
        public init(
            title: String,
            action: @escaping () -> Void,
            isEnabled: Bool = true
        ) {
            self.title = title
            self.action = action
            self.isEnabled = isEnabled
        }
        
        public var body: some View {
            PrimaryButton(
                title: title,
                action: action,
                isEnabled: isEnabled,
                style: .outlined
            )
        }
    }
    
    /// Floating action button
    public struct FloatingActionButton: View {
        let icon: String
        let action: () -> Void
        let backgroundColor: Color
        let foregroundColor: Color
        
        @State private var isPressed = false
        
        public init(
            icon: String,
            action: @escaping () -> Void,
            backgroundColor: Color = .blue,
            foregroundColor: Color = .white
        ) {
            self.icon = icon
            self.action = action
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
        }
        
        public var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(foregroundColor)
                    .frame(width: 56, height: 56)
                    .background(backgroundColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { _ in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
            } onPressingChanged: { pressing in
                if !pressing {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            }
        }
    }
    
    // MARK: - Display Components
    
    /// Category icon with consistent styling
    public struct CategoryIcon: View {
        let category: String
        let size: CGFloat
        let backgroundColor: Color?
        
        public init(
            category: String,
            size: CGFloat = 40,
            backgroundColor: Color? = nil
        ) {
            self.category = category
            self.size = size
            self.backgroundColor = backgroundColor ?? Self.colorForCategory(category)
        }
        
        public var body: some View {
            ZStack {
                Circle()
                    .fill(backgroundColor ?? .blue)
                    .frame(width: size, height: size)
                
                Text(String(category.prefix(1).uppercased()))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        
        private static func colorForCategory(_ category: String) -> Color {
            let colors: [Color] = [.blue, .purple, .green, .orange, .red, .pink, .teal]
            let index = abs(category.hashValue) % colors.count
            return colors[index]
        }
    }
    
    /// Progress bar with animation
    public struct ProgressBar: View {
        let progress: Double
        let total: Double
        let color: Color
        let height: CGFloat
        let showPercentage: Bool
        
        @State private var animatedProgress: Double = 0
        
        public init(
            progress: Double,
            total: Double,
            color: Color = .blue,
            height: CGFloat = 8,
            showPercentage: Bool = false
        ) {
            self.progress = progress
            self.total = total
            self.color = color
            self.height = height
            self.showPercentage = showPercentage
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: height)
                            .cornerRadius(height / 2)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: progressWidth(geometry.size.width), height: height)
                            .cornerRadius(height / 2)
                            .animation(.easeInOut(duration: 0.5), value: animatedProgress)
                    }
                }
                .frame(height: height)
                .onAppear {
                    animatedProgress = progressPercentage
                }
                .onChange(of: progress) { _, _ in
                    animatedProgress = progressPercentage
                }
                
                if showPercentage {
                    HStack {
                        Text("\(Int(progressPercentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(progress.formattedAsCurrency) / \(total.formattedAsCurrency)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        
        private var progressPercentage: Double {
            guard total > 0 else { return 0 }
            return min(100, (progress / total) * 100)
        }
        
        private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
            return totalWidth * (animatedProgress / 100)
        }
    }
    
    /// Budget status indicator
    public struct BudgetStatusIndicator: View {
        let spent: Double
        let budget: Double
        let category: String
        
        public init(spent: Double, budget: Double, category: String) {
            self.spent = spent
            self.budget = budget
            self.category = category
        }
        
        public var body: some View {
            HStack(spacing: 8) {
                CategoryIcon(category: category, size: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    ProgressBar(
                        progress: spent,
                        total: budget,
                        color: statusColor,
                        height: 6
                    )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(spent.formattedAsCurrency)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("of \(budget.formattedAsCurrency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        
        private var statusText: String {
            let percentage = budget > 0 ? (spent / budget) * 100 : 0
            
            if spent > budget {
                return "Over budget by \((spent - budget).formattedAsCurrency)"
            } else if percentage >= 80 {
                return "Near budget limit"
            } else {
                return "Within budget"
            }
        }
        
        private var statusColor: Color {
            let percentage = budget > 0 ? (spent / budget) * 100 : 0
            
            if spent > budget {
                return .red
            } else if percentage >= 80 {
                return .orange
            } else {
                return .green
            }
        }
    }
    
    // MARK: - Alert Components
    
    /// Custom alert view
    public struct AlertView: View {
        let title: String
        let message: String
        let alertType: AlertType
        let primaryButton: AlertButton
        let secondaryButton: AlertButton?
        
        public enum AlertType {
            case info
            case warning
            case error
            case success
            
            var color: Color {
                switch self {
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .success: return .green
                }
            }
            
            var icon: String {
                switch self {
                case .info: return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                case .success: return "checkmark.circle"
                }
            }
        }
        
        public struct AlertButton {
            let title: String
            let action: () -> Void
            let style: Style
            
            public enum Style {
                case primary
                case secondary
                case destructive
            }
            
            public init(title: String, style: Style = .primary, action: @escaping () -> Void) {
                self.title = title
                self.style = style
                self.action = action
            }
        }
        
        public init(
            title: String,
            message: String,
            alertType: AlertType = .info,
            primaryButton: AlertButton,
            secondaryButton: AlertButton? = nil
        ) {
            self.title = title
            self.message = message
            self.alertType = alertType
            self.primaryButton = primaryButton
            self.secondaryButton = secondaryButton
        }
        
        public var body: some View {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: alertType.icon)
                        .font(.system(size: 48))
                        .foregroundColor(alertType.color)
                    
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Button(action: primaryButton.action) {
                        Text(primaryButton.title)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonBackgroundColor(for: primaryButton.style))
                            .foregroundColor(buttonTextColor(for: primaryButton.style))
                            .cornerRadius(8)
                    }
                    
                    if let secondaryButton = secondaryButton {
                        Button(action: secondaryButton.action) {
                            Text(secondaryButton.title)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(buttonBackgroundColor(for: secondaryButton.style))
                                .foregroundColor(buttonTextColor(for: secondaryButton.style))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        
        private func buttonBackgroundColor(for style: AlertButton.Style) -> Color {
            switch style {
            case .primary: return alertType.color
            case .secondary: return Color(.systemGray5)
            case .destructive: return .red
            }
        }
        
        private func buttonTextColor(for style: AlertButton.Style) -> Color {
            switch style {
            case .primary, .destructive: return .white
            case .secondary: return .primary
            }
        }
    }
}



// MARK: - Preview Support

#if DEBUG
struct CommonComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Cards
                CommonComponents.StatsCard(
                    title: "Monthly Budget",
                    value: "$2,500.00",
                    subtitle: "Updated today",
                    icon: "dollarsign.circle",
                    color: .blue,
                    trend: .up("5.2%")
                )
                
                // Transaction Row
                CommonComponents.TransactionRow(
                    amount: 45.67,
                    category: "Groceries",
                    date: Date(),
                    note: "Weekly shopping"
                )
                
                // Progress Bar
                CommonComponents.ProgressBar(
                    progress: 1750,
                    total: 2500,
                    color: .blue,
                    height: 8,
                    showPercentage: true
                )
                
                // Budget Status Indicator
                CommonComponents.BudgetStatusIndicator(
                    spent: 1750,
                    budget: 2000,
                    category: "Groceries"
                )
                
                // Primary Button
                CommonComponents.PrimaryButton(
                    title: "Save Changes",
                    action: {}
                )
                
                // Secondary Button
                CommonComponents.SecondaryButton(
                    title: "Cancel",
                    action: {}
                )
            }
            .padding()
        }
    }
}
#endif
