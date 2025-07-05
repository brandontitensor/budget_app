//
//  CommonComponents.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//


//
//  CommonComponents.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//

import SwiftUI

// MARK: - Common UI Components

/// Collection of reusable UI components for the app
public struct CommonComponents {
    
    // MARK: - Card Components
    
    /// Reusable card container with consistent styling
    public struct CardView<Content: View>: View {
        let content: Content
        let padding: EdgeInsets
        let cornerRadius: CGFloat
        let shadowRadius: CGFloat
        let backgroundColor: Color
        
        public init(
            padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            cornerRadius: CGFloat = AppConstants.UI.cornerRadius,
            shadowRadius: CGFloat = AppConstants.UI.defaultShadowRadius,
            backgroundColor: Color = Color(.secondarySystemBackground),
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.shadowRadius = shadowRadius
            self.backgroundColor = backgroundColor
        }
        
        public var body: some View {
            content
                .padding(padding)
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .shadow(
                    color: .black.opacity(Double(AppConstants.UI.defaultShadowOpacity)),
                    radius: shadowRadius,
                    x: 0,
                    y: 2
                )
        }
    }
    
    /// Stats card for displaying key metrics
    public struct StatsCard: View {
        let title: String
        let value: String
        let subtitle: String?
        let icon: String?
        let color: Color
        let trend: Trend?
        
        public enum Trend {
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
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(value)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(color)
                        }
                        
                        Spacer()
                        
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(color)
                        }
                    }
                    
                    // Footer
                    if let subtitle = subtitle || trend != nil {
                        HStack {
                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let trend = trend {
                                HStack(spacing: 4) {
                                    Image(systemName: trend.icon)
                                        .font(.caption)
                                    Text(trend.text)
                                        .font(.caption)
                                }
                                .foregroundColor(trend.color)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - List Components
    
    /// Reusable list row component
    public struct ListRow<Leading: View, Trailing: View>: View {
        let leading: Leading
        let trailing: Trailing
        let title: String
        let subtitle: String?
        let onTap: (() -> Void)?
        
        public init(
            title: String,
            subtitle: String? = nil,
            onTap: (() -> Void)? = nil,
            @ViewBuilder leading: () -> Leading = { EmptyView() },
            @ViewBuilder trailing: () -> Trailing = { EmptyView() }
        ) {
            self.title = title
            self.subtitle = subtitle
            self.onTap = onTap
            self.leading = leading()
            self.trailing = trailing()
        }
        
        public var body: some View {
            Button(action: onTap ?? {}) {
                HStack(spacing: 12) {
                    leading
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    trailing
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
        }
    }
    
    /// Transaction row component
    public struct TransactionRow: View {
        let transaction: BudgetEntry
        let showCategory: Bool
        let onTap: (() -> Void)?
        @EnvironmentObject private var themeManager: ThemeManager
        
        public init(
            transaction: BudgetEntry,
            showCategory: Bool = true,
            onTap: (() -> Void)? = nil
        ) {
            self.transaction = transaction
            self.showCategory = showCategory
            self.onTap = onTap
        }
        
        public var body: some View {
            ListRow(
                title: FormatHelpers.TextFormatter.formatTransactionNote(transaction.note),
                subtitle: subtitleText,
                onTap: onTap
            ) {
                // Leading - Category icon
                CategoryIcon(
                    category: transaction.category,
                    color: themeManager.colorForCategory(transaction.category)
                )
            } trailing: {
                // Trailing - Amount and date
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.amount.formattedAsCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(transaction.date.formattedForTransaction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        private var subtitleText: String? {
            if showCategory {
                return transaction.category
            } else {
                return transaction.date.formattedRelative
            }
        }
    }
    
    // MARK: - Button Components
    
    /// Primary action button with consistent styling
    public struct PrimaryButton: View {
        let title: String
        let icon: String?
        let isLoading: Bool
        let isEnabled: Bool
        let action: () -> Void
        
        public init(
            title: String,
            icon: String? = nil,
            isLoading: Bool = false,
            isEnabled: Bool = true,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.isLoading = isLoading
            self.isEnabled = isEnabled
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else if let icon = icon {
                        Image(systemName: icon)
                    }
                    
                    Text(isLoading ? "Loading..." : title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppConstants.UI.minimumTouchHeight)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled || isLoading)
        }
    }
    
    /// Secondary action button
    public struct SecondaryButton: View {
        let title: String
        let icon: String?
        let action: () -> Void
        
        public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppConstants.UI.minimumTouchHeight)
            }
            .buttonStyle(.bordered)
        }
    }
    
    /// Floating action button
    public struct FloatingActionButton: View {
        let icon: String
        let action: () -> Void
        @EnvironmentObject private var themeManager: ThemeManager
        @State private var isPressed = false
        
        public init(icon: String = "plus", action: @escaping () -> Void) {
            self.icon = icon
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(themeManager.primaryColor)
                    .clipShape(Circle())
                    .shadow(
                        color: themeManager.primaryColor.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
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
    
    // MARK: - Input Components
    
    /// Custom text field with validation
    public struct ValidatedTextField: View {
        let title: String
        let placeholder: String
        @Binding var text: String
        let validation: (String) -> ValidationResult
        let keyboardType: UIKeyboardType
        let autocapitalization: TextInputAutocapitalization
        let isSecure: Bool
        
        @State private var validationResult: ValidationResult = .valid
        @FocusState private var isFocused: Bool
    
        
        public init(
            title: String,
            placeholder: String = "",
            text: Binding<String>,
            validation: @escaping (String) -> ValidationResult = { _ in .valid },
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
                    textValue = FormatHelpers.NumberFormatter.formatDecimal(amount)
                }
            }
            .onChange(of: textValue) { oldValue, newValue in
                let cleaned = FormatHelpers.ValidationFormatter.cleanCurrencyInput(newValue)
                if cleaned != newValue {
                    textValue = cleaned
                }
                amount = Double(cleaned) ?? 0.0
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                }
            }
        }
        
        private func validateCurrency(_ input: String) -> ValidatedTextField.ValidationResult {
            if isRequired && input.isEmpty {
                return .invalid("Amount is required")
            }
            
            if let value = Double(input) {
                if value < 0 {
                    return .invalid("Amount cannot be negative")
                }
                if value > AppConstants.Validation.maximumTransactionAmount {
                    return .invalid("Amount exceeds maximum allowed")
                }
                return .valid
            } else if !input.isEmpty {
                return .invalid("Invalid amount format")
            }
            
            return .valid
        }
    }
    
    // MARK: - Selection Components
    
    /// Custom picker with search
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
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $isPresented) {
                SearchablePickerSheet(
                    title: title,
                    items: items,
                    selection: $selection,
                    allowsCustomEntry: allowsCustomEntry,
                    isPresented: $isPresented
                )
            }
        }
    }
    
    /// Category picker specifically for budget categories
    public struct CategoryPicker: View {
        @Binding var selectedCategory: String
        let availableCategories: [String]
        
        public init(selectedCategory: Binding<String>, availableCategories: [String]) {
            self._selectedCategory = selectedCategory
            self.availableCategories = availableCategories
        }
        
        public var body: some View {
            SearchablePicker(
                title: "Category",
                items: availableCategories,
                selection: Binding(
                    get: { selectedCategory.isEmpty ? nil : selectedCategory },
                    set: { selectedCategory = $0 ?? "" }
                ),
                allowsCustomEntry: true
            )
        }
    }
    
    // MARK: - Display Components
    
    /// Category icon with consistent styling
    public struct CategoryIcon: View {
        let category: String
        let color: Color
        let size: CGFloat
        
        public init(category: String, color: Color, size: CGFloat = 40) {
            self.category = category
            self.color = color
            self.size = size
        }
        
        public var body: some View {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: size, height: size)
                
                Image(systemName: iconName)
                    .font(.system(size: size * 0.5))
                    .foregroundColor(color)
            }
        }
        
        private var iconName: String {
            switch category.lowercased() {
            case "groceries", "food": return "cart.fill"
            case "transportation", "transport": return "car.fill"
            case "entertainment": return "tv.fill"
            case "utilities": return "bolt.fill"
            case "housing", "rent": return "house.fill"
            case "healthcare", "medical": return "cross.fill"
            case "education": return "book.fill"
            case "savings": return "piggybank.fill"
            case "dining", "restaurants": return "fork.knife"
            case "shopping": return "bag.fill"
            default: return "folder.fill"
            }
        }
    }
    
    /// Progress bar with percentage
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
            showPercentage: Bool = true
        ) {
            self.progress = progress
            self.total = total
            self.color = color
            self.height = height
            self.showPercentage = showPercentage
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: height)
                        
                        // Progress
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * animatedProgress, height: height)
                    }
                    .cornerRadius(height / 2)
                }
                .frame(height: height)
                
                if showPercentage {
                    HStack {
                        Text("\(Int(animatedProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(FormatHelpers.CurrencyFormatter().format(progress)) of \(FormatHelpers.CurrencyFormatter().format(total))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animatedProgress = min(progress / total, 1.0)
                }
            }
            .onChange(of: progress) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedProgress = min(newValue / total, 1.0)
                }
            }
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
            let (statusText, statusColor) = FormatHelpers.BudgetFormatter.formatBudgetStatus(
                spent: spent,
                budget: budget
            )
            
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(statusColor))
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Navigation Components
    
    /// Custom navigation bar with consistent styling
    public struct CustomNavigationBar<Leading: View, Trailing: View>: View {
        let title: String
        let leading: Leading
        let trailing: Trailing
        @Environment(\.dismiss) private var dismiss
        
        public init(
            title: String,
            @ViewBuilder leading: () -> Leading = { EmptyView() },
            @ViewBuilder trailing: () -> Trailing = { EmptyView() }
        ) {
            self.title = title
            self.leading = leading()
            self.trailing = trailing()
        }
        
        public var body: some View {
            HStack {
                leading
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                trailing
            }
            .padding(.horizontal)
            .frame(height: 44)
            .background(.ultraThinMaterial)
        }
    }
    
    /// Tab bar item with badge support
    public struct TabBarItem: View {
        let title: String
        let icon: String
        let badge: Int?
        let isSelected: Bool
        let action: () -> Void
        
        public init(
            title: String,
            icon: String,
            badge: Int? = nil,
            isSelected: Bool,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.badge = badge
            self.isSelected = isSelected
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .symbolVariant(isSelected ? .fill : .none)
                        
                        if let badge = badge, badge > 0 {
                            Text("\(badge)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(10)
                                .offset(x: 12, y: -12)
                        }
                    }
                    
                    Text(title)
                        .font(.caption2)
                }
                .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
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
                case .info: return "info.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                case .success: return "checkmark.circle.fill"
                }
            }
        }
        
        public struct AlertButton {
            let title: String
            let style: Style
            let action: () -> Void
            
            public enum Style {
                case `default`
                case destructive
                case cancel
            }
            
            public init(title: String, style: Style = .default, action: @escaping () -> Void) {
                self.title = title
                self.style = style
                self.action = action
            }
        }
        
        public init(
            title: String,
            message: String,
            alertType: AlertType,
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
                // Icon
                Image(systemName: alertType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(alertType.color)
                
                // Content
                VStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button(primaryButton.title) {
                        primaryButton.action()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(buttonColor(for: primaryButton.style))
                    
                    if let secondaryButton = secondaryButton {
                        Button(secondaryButton.title) {
                            secondaryButton.action()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding()
        }
        
        private func buttonColor(for style: AlertButton.Style) -> Color {
            switch style {
            case .default: return .blue
            case .destructive: return .red
            case .cancel: return .gray
            }
        }
    }
}

// MARK: - Supporting Views

/// Sheet for searchable picker
private struct SearchablePickerSheet<T: Hashable & CustomStringConvertible>: View {
    let title: String
    let items: [T]
    @Binding var selection: T?
    let allowsCustomEntry: Bool
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var customEntry = ""
    @State private var showingCustomEntry = false
    
    var filteredItems: [T] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search \(title.lowercased())...")
                
                List {
                    // Custom entry option
                    if allowsCustomEntry && !searchText.isEmpty && !items.contains(where: { $0.description.localizedCaseInsensitiveCompare(searchText) == .orderedSame }) {
                        Button("Add \"\(searchText)\"") {
                            if let newItem = searchText as? T {
                                selection = newItem
                                isPresented = false
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Existing items
                    ForEach(filteredItems, id: \.self) { item in
                        Button(action: {
                            selection = item
                            isPresented = false
                        }) {
                            HStack {
                                Text(item.description)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selection?.description == item.description {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/// Search bar component
private struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling
    public func cardStyle(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = AppConstants.UI.cornerRadius,
        shadowRadius: CGFloat = AppConstants.UI.defaultShadowRadius,
        backgroundColor: Color = Color(.secondarySystemBackground)
    ) -> some View {
        self
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: .black.opacity(Double(AppConstants.UI.defaultShadowOpacity)),
                radius: shadowRadius,
                x: 0,
                y: 2
            )
    }
    
    /// Apply consistent list row styling
    public func listRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.systemBackground))
    }
}

// MARK: - Predefined Components

extension CommonComponents {
    /// Quick add transaction button
    public static func quickAddButton(onTap: @escaping () -> Void) -> some View {
        PrimaryButton(
            title: "Add Transaction",
            icon: "plus",
            action: onTap
        )
    }
    
    /// Budget overview card
    public static func budgetOverviewCard(
        budgeted: Double,
        spent: Double,
        remaining: Double
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Monthly Budget")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(FormatHelpers.CurrencyFormatter().format(budgeted))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                ProgressBar(
                    progress: spent,
                    total: budgeted,
                    color: spent > budgeted ? .red : .blue
                )
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(FormatHelpers.CurrencyFormatter().format(spent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(FormatHelpers.CurrencyFormatter().format(remaining))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(remaining < 0 ? .red : .green)
                    }
                }
            }
        }
    }
    
    /// Empty state view
    public static func emptyState(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
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
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding()
    }
}

// MARK: - Testing Support

#if DEBUG
extension CommonComponents {
    public struct TestComponents: View {
        @State private var selectedCategory = ""
        @State private var amount: Double = 0
        @State private var textInput = ""
        @State private var showingAlert = false
        
        public var body: some View {
            NavigationView {
                List {
                    Section("Cards") {
                        StatsCard(
                            title: "Total Spent",
                            value: "$1,234.56",
                            subtitle: "This month",
                            icon: "creditcard.fill",
                            color: .blue,
                            trend: .up("12%")
                        )
                        
                        budgetOverviewCard(
                            budgeted: 2500,
                            spent: 1750,
                            remaining: 750
                        )
                    }
                    
                    Section("Inputs") {
                        ValidatedTextField(
                            title: "Description",
                            placeholder: "Enter description",
                            text: $textInput,
                            validation: { text in
                                text.isEmpty ? .invalid("Description is required") : .valid
                            }
                        )
                        
                        CurrencyTextField(
                            title: "Amount",
                            amount: $amount
                        )
                        
                        CategoryPicker(
                            selectedCategory: $selectedCategory,
                            availableCategories: ["Groceries", "Transportation", "Entertainment"]
                        )
                    }
                    
                    Section("Buttons") {
                        PrimaryButton(title: "Primary Action") {
                            print("Primary action tapped")
                        }
                        
                        SecondaryButton(title: "Secondary Action", icon: "gear") {
                            print("Secondary action tapped")
                        }
                        
                        LoadingViews.LoadingButton(
                            title: "Loading Button",
                            isLoading: false
                        ) {
                            print("Loading button tapped")
                        }
                    }
                    
                    Section("Progress") {
                        ProgressBar(
                            progress: 1750,
                            total: 2500,
                            color: .blue
                        )
                        
                        BudgetStatusIndicator(
                            spent: 1750,
                            budget: 2500,
                            category: "Groceries"
                        )
                    }
                    
                    Section("Lists") {
                        TransactionRow(
                            transaction: try! BudgetEntry(
                                amount: 45.67,
                                category: "Groceries",
                                date: Date(),
                                note: "Weekly shopping"
                            )
                        )
                    }
                    
                    Section("Alerts") {
                        Button("Show Alert") {
                            showingAlert = true
                        }
                    }
                }
                .navigationTitle("Component Test")
            }
            .overlay {
                if showingAlert {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingAlert = false
                        }
                    
                    AlertView(
                        title: "Delete Transaction",
                        message: "Are you sure you want to delete this transaction? This action cannot be undone.",
                        alertType: .warning,
                        primaryButton: AlertView.AlertButton(title: "Delete", style: .destructive) {
                            showingAlert = false
                        },
                        secondaryButton: AlertView.AlertButton(title: "Cancel", style: .cancel) {
                            showingAlert = false
                        }
                    )
                }
            }
        }
    }
}
#endif
