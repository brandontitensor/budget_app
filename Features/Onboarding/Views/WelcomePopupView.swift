//
//  WelcomePopupView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//

import SwiftUI
import Foundation

/// Enhanced view for handling initial app onboarding and setup with comprehensive error handling and validation
struct WelcomePopupView: View {
    // MARK: - Environment
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    // MARK: - State Management
    @State private var name: String = ""
    @State private var selectedCurrency: String = "USD"
    @State private var selectedThemeColor: ThemeManager.ColorOption = ThemeManager.defaultPrimaryColor
    @State private var enableNotifications: Bool = true
    @State private var enableHapticFeedback: Bool = true
    
    // MARK: - UI State
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAnimating = false
    @State private var isProcessing = false
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var showingNotificationDialog = false
    @State private var completedSteps: Set<OnboardingStep> = []
    
    // MARK: - Accessibility
    @AccessibilityFocusState private var focusedField: FormField?
    
    // MARK: - Types
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case personalization = 1
        case preferences = 2
        case notifications = 3
        case completion = 4
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Brandon's Budget!"
            case .personalization: return "Let's Personalize"
            case .preferences: return "Your Preferences"
            case .notifications: return "Stay Updated"
            case .completion: return "All Set!"
            }
        }
        
        var subtitle: String {
            switch self {
            case .welcome: return "Your personal budget companion is ready to help you take control of your finances."
            case .personalization: return "Tell us a bit about yourself to customize your experience."
            case .preferences: return "Choose your preferred settings for the best experience."
            case .notifications: return "Get helpful reminders and insights about your spending."
            case .completion: return "You're ready to start your budget journey!"
            }
        }
        
        var icon: String {
            switch self {
            case .welcome: return "hand.wave.fill"
            case .personalization: return "person.fill"
            case .preferences: return "gearshape.fill"
            case .notifications: return "bell.fill"
            case .completion: return "checkmark.circle.fill"
            }
        }
        
        var progressValue: Double {
            return Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
    }
    
    private enum FormField: Hashable {
        case nameField
        case currencyPicker
        case themePicker
        case notificationToggle
        case hapticToggle
    }
    
    // MARK: - Constants
    private let animationDuration: Double = 0.6
    private let maxNameLength = AppConstants.Validation.maxCategoryNameLength
    private let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF"]
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping background during onboarding
                }
            
            // Main content
            VStack(spacing: 0) {
                progressIndicator
                mainContent
                navigationControls
            }
            .frame(maxWidth: 400)
            .background(backgroundMaterial)
            .cornerRadius(24)
            .shadow(
                color: .black.opacity(0.15),
                radius: 20,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 20)
            .opacity(isAnimating ? 1 : 0)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .animation(.spring(duration: animationDuration), value: isAnimating)
        }
        .onAppear {
            setupInitialState()
        }
        .errorAlert(onRetry: {
            Task<Void, Never>{
                await retryCurrentStep()
            }
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome onboarding")
        .accessibilityHint("Complete the setup process to start using the app")
    }
    
    // MARK: - View Components
    
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: currentStep.progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.primaryColor))
                .scaleEffect(y: 2)
                .padding(.horizontal, 24)
                .accessibilityLabel("Setup progress")
                .accessibilityValue("\(Int(currentStep.progressValue * 100)) percent complete")
            
            // Step indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? themeManager.primaryColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                contentSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: 400)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: currentStep.icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(themeManager.primaryColor)
                .symbolEffect(.bounce, value: currentStep)
            
            // Title
            Text(currentStep.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            // Subtitle
            Text(currentStep.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.5), value: currentStep)
    }
    
    private var contentSection: some View {
        Group {
            switch currentStep {
            case .welcome:
                welcomeContent
            case .personalization:
                personalizationContent
            case .preferences:
                preferencesContent
            case .notifications:
                notificationsContent
            case .completion:
                completionContent
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentStep)
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 20) {
            FeatureHighlight(
                icon: "chart.pie.fill",
                title: "Smart Budget Tracking",
                description: "Keep track of your spending across different categories with intelligent insights."
            )
            
            FeatureHighlight(
                icon: "bell.fill",
                title: "Helpful Reminders",
                description: "Get notified when you're close to your budget limits or need to log expenses."
            )
            
            FeatureHighlight(
                icon: "lock.shield.fill",
                title: "Privacy First",
                description: "Your financial data stays on your device and is never shared with third parties."
            )
        }
    }
    
    private var personalizationContent: some View {
        VStack(spacing: 20) {
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("What should we call you?")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    if !name.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                TextField("Enter your name", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.next)
                    .accessibilityFocused($focusedField, equals: .nameField)
                    .onChange(of: name) { oldValue, newValue in
                        validateNameInput(newValue)
                    }
                    .onSubmit {
                        validateAndContinue()
                    }
                
                if !name.isEmpty && name.count < 2 {
                    Text("Name should be at least 2 characters")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Currency selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select your currency")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(supportedCurrencies, id: \.self) { currency in
                        HStack {
                            Text(currency)
                            Text(currencySymbol(for: currency))
                                .foregroundColor(.secondary)
                        }
                        .tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityFocused($focusedField, equals: .currencyPicker)
            }
        }
    }
    
    private var preferencesContent: some View {
        VStack(spacing: 20) {
            // Theme selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose your theme color")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(ThemeManager.availableColors, id: \.id) { colorOption in
                        ThemeColorButton(
                            colorOption: colorOption,
                            isSelected: selectedThemeColor.id == colorOption.id,
                            action: {
                                selectedThemeColor = colorOption
                                themeManager.updateTheme(with: colorOption)
                                
                                // Haptic feedback
                                if enableHapticFeedback {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        )
                    }
                }
                .accessibilityFocused($focusedField, equals: .themePicker)
            }
            
            // Feature toggles
            VStack(spacing: 16) {
                FeatureToggle(
                    title: "Haptic Feedback",
                    description: "Feel subtle vibrations for button taps and interactions",
                    icon: "iphone.radiowaves.left.and.right",
                    isOn: $enableHapticFeedback
                )
                .accessibilityFocused($focusedField, equals: .hapticToggle)
            }
        }
    }
    
    private var notificationsContent: some View {
        VStack(spacing: 20) {
            // Notification explanation
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.primaryColor)
                
                Text("Stay on top of your budget with smart notifications that help you make better financial decisions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Notification features
            VStack(spacing: 16) {
                NotificationFeature(
                    icon: "cart.fill",
                    title: "Purchase Reminders",
                    description: "Get reminded to log your expenses"
                )
                
                NotificationFeature(
                    icon: "exclamationmark.triangle.fill",
                    title: "Budget Alerts",
                    description: "Know when you're approaching your limits"
                )
                
                NotificationFeature(
                    icon: "calendar.circle.fill",
                    title: "Monthly Reviews",
                    description: "Receive insights about your spending patterns"
                )
            }
            
            // Toggle
            FeatureToggle(
                title: "Enable Notifications",
                description: "You can change this later in Settings",
                icon: "bell.fill",
                isOn: $enableNotifications
            )
            .accessibilityFocused($focusedField, equals: .notificationToggle)
        }
    }
    
    private var completionContent: some View {
        VStack(spacing: 24) {
            // Success animation
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(themeManager.primaryColor)
                    .symbolEffect(.bounce, value: currentStep == .completion)
            }
            
            // Summary
            VStack(spacing: 12) {
                Text("Welcome, \(name.isEmpty ? "there" : name)! 👋")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Your budget app is ready to help you achieve your financial goals.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Setup summary
            VStack(spacing: 8) {
                SummaryRow(label: "Currency", value: selectedCurrency)
                SummaryRow(label: "Theme", value: selectedThemeColor.name)
                SummaryRow(label: "Notifications", value: enableNotifications ? "Enabled" : "Disabled")
                SummaryRow(label: "Haptic Feedback", value: enableHapticFeedback ? "Enabled" : "Disabled")
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    private var navigationControls: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep.rawValue > 0 {
                Button("Back") {
                    navigateBack()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isProcessing)
            }
            
            Spacer()
            
            // Next/Complete button
            Button(nextButtonTitle) {
                validateAndContinue()
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: isProcessing))
            .disabled(!canProceed || isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var backgroundMaterial: some View {
        Group {
            if #available(iOS 15.0, *) {
                Color.clear.background(.regularMaterial)
            } else {
                colorScheme == .dark
                    ? Color(.systemGray6)
                    : Color(.systemBackground)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct FeatureHighlight: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
    }
    
    private struct ThemeColorButton: View {
        let colorOption: ThemeManager.ColorOption
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Circle()
                    .fill(colorOption.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? .white : .clear,
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.black.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.3), value: isSelected)
            }
            .accessibilityLabel("\(colorOption.name) theme color")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    }
    
    private struct FeatureToggle: View {
        let title: String
        let description: String
        let icon: String
        @Binding var isOn: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
        }
    }
    
    private struct NotificationFeature: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    
    private struct SummaryRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Button Styles
    
    private struct PrimaryButtonStyle: ButtonStyle {
        let isLoading: Bool
        @EnvironmentObject private var themeManager: ThemeManager
        
        func makeBody(configuration: Configuration) -> some View {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                configuration.label
                    .opacity(isLoading ? 0 : 1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.primaryColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    private struct SecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .frame(height: 48)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemFill))
                        .opacity(configuration.isPressed ? 0.8 : 1.0)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    private struct CustomTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemFill))
                )
        }
    }
    
    // MARK: - Computed Properties
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .personalization, .preferences, .notifications: return "Continue"
        case .completion: return "Start Budgeting"
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .welcome: return true
        case .personalization: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count >= 2
        case .preferences: return true
        case .notifications: return true
        case .completion: return true
        }
    }
    
    // MARK: - Methods
    
    private func setupInitialState() {
        withAnimation(.spring(duration: animationDuration)) {
            isAnimating = true
        }
        
        // Load any existing values
        selectedCurrency = settingsManager.defaultCurrency
        selectedThemeColor = themeManager.currentColorOption
        enableHapticFeedback = settingsManager.enableHapticFeedback
        
        // Set focus to first field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if currentStep == .personalization {
                focusedField = .nameField
            }
        }
    }
    
    private func validateNameInput(_ newValue: String) {
        if newValue.count > maxNameLength {
            name = String(newValue.prefix(maxNameLength))
        }
    }
    
    private func validateAndContinue() {
        guard !isProcessing else { return }
        
        // Haptic feedback
        if enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        Task<Void, Never>{
            await processCurrentStep()
        }
    }
    
    private func processCurrentStep() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            switch currentStep {
            case .welcome:
                await navigateToNext()
                
            case .personalization:
                try await validateAndSavePersonalization()
                await navigateToNext()
                
            case .preferences:
                try await savePreferences()
                await navigateToNext()
                
            case .notifications:
                try await handleNotificationSetup()
                await navigateToNext()
                
            case .completion:
                try await completeOnboarding()
            }
            
        } catch {
            await MainActor.run {
                if let appError = error as? AppError {
                    errorHandler.handle(appError, context: "Onboarding step \(currentStep)")
                } else {
                    errorHandler.handle(AppError.from(error), context: "Onboarding step \(currentStep)")
                }
            }
        }
    }
    
    private func validateAndSavePersonalization() async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        guard !trimmedName.isEmpty else {
            throw AppError.validation(message: "Please enter your name")
        }
        
        guard trimmedName.count >= 2 else {
            throw AppError.validation(message: "Name must be at least 2 characters")
        }
        
        guard trimmedName.count <= maxNameLength else {
            throw AppError.validation(message: "Name is too long")
        }
        
        // Save to settings
        try settingsManager.updateUserName(trimmedName)
        try settingsManager.updateDefaultCurrency(selectedCurrency)
        
        completedSteps.insert(.personalization)
    }
    
    private func savePreferences() async throws {
        // Update theme
        themeManager.updateTheme(with: selectedThemeColor)
        
        // Save haptic feedback preference
        settingsManager.enableHapticFeedback = enableHapticFeedback
        
        completedSteps.insert(.preferences)
    }
    
    private func handleNotificationSetup() async throws {
        if enableNotifications {
            do {
                let granted = try await NotificationManager.shared.requestAuthorization()
                
                // Update settings based on result
                try await settingsManager.updateNotificationSettings(
                    allowed: granted,
                    purchaseEnabled: granted,
                    purchaseFrequency: .daily,
                    budgetEnabled: granted,
                    budgetFrequency: .monthly
                )
                
                if granted {
                    await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
                }
                
            } catch {
                // Handle notification permission errors gracefully
                print("⚠️ WelcomePopup: Notification setup failed - \(error.localizedDescription)")
                
                // Still allow user to continue
                try await settingsManager.updateNotificationSettings(
                    allowed: false,
                    purchaseEnabled: false,
                    purchaseFrequency: .daily,
                    budgetEnabled: false,
                    budgetFrequency: .monthly
                )
            }
        } else {
            // User chose not to enable notifications
            try await settingsManager.updateNotificationSettings(
                allowed: false,
                purchaseEnabled: false,
                purchaseFrequency: .daily,
                budgetEnabled: false,
                budgetFrequency: .monthly
            )
        }
        
        completedSteps.insert(.notifications)
    }
    
    private func completeOnboarding() async throws {
        // Mark onboarding as complete
        settingsManager.isFirstLaunch = false
        
        // Final validation
        guard completedSteps.contains(.personalization) else {
            throw AppError.validation(message: "Please complete the personalization step")
        }
        
        completedSteps.insert(.completion)
        
        // Dismiss with animation
        await dismissOnboarding()
    }
    
    private func navigateToNext() async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                if currentStep.rawValue < OnboardingStep.allCases.count - 1 {
                    currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? currentStep
                }
            }
            
            // Update focus for accessibility
            updateFocusForCurrentStep()
        }
    }
    
    private func navigateBack() {
        withAnimation(.easeInOut(duration: 0.4)) {
            if currentStep.rawValue > 0 {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? currentStep
            }
        }
        
        updateFocusForCurrentStep()
    }
    
    private func updateFocusForCurrentStep() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch currentStep {
            case .personalization:
                focusedField = .nameField
            case .preferences:
                focusedField = .themePicker
            case .notifications:
                focusedField = .notificationToggle
            default:
                focusedField = nil
            }
        }
    }
    
    private func retryCurrentStep() async {
        // Reset any error states
        showingValidationError = false
        validationErrorMessage = ""
        
        // Retry the current step
        await processCurrentStep()
    }
    
    private func dismissOnboarding() async {
        await MainActor.run {
            withAnimation(.spring(duration: animationDuration)) {
                isAnimating = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                isPresented = false
            }
        }
    }
    
    private func currencySymbol(for currencyCode: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }
}

// MARK: - Error Handling Extension

extension WelcomePopupView {
    private func handleError(_ error: Error, context: String) {
        let appError = AppError.from(error)
        errorHandler.handle(appError, context: context)
        
        // Show specific validation errors inline
        if case .validation(let message) = appError {
            validationErrorMessage = message
            showingValidationError = true
        }
    }
}

// MARK: - Accessibility Extensions

extension WelcomePopupView {
    private var accessibilityAnnouncement: String {
        switch currentStep {
        case .welcome:
            return "Welcome screen. Swipe right to continue."
        case .personalization:
            return "Personalization step. Please enter your name and select currency."
        case .preferences:
            return "Preferences step. Choose your theme and settings."
        case .notifications:
            return "Notifications step. Enable notifications to stay updated."
        case .completion:
            return "Setup complete. Ready to start budgeting."
        }
    }
    
    private func announceStepChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, argument: accessibilityAnnouncement)
        }
    }
}

// MARK: - Performance Optimization

extension WelcomePopupView {
    private func preloadNextStepContent() {
        // Preload images and resources for the next step to ensure smooth transitions
        Task<Void, Never>{
            switch currentStep {
            case .welcome:
                // Preload personalization icons
                _ = UIImage(systemName: "person.fill")
                _ = UIImage(systemName: "dollarsign.circle")
            case .personalization:
                // Preload theme colors
                for colorOption in ThemeManager.availableColors {
                    _ = UIColor(colorOption.color)
                }
            case .preferences:
                // Preload notification icons
                _ = UIImage(systemName: "bell.fill")
                _ = UIImage(systemName: "bell.badge.fill")
            default:
                break
            }
        }
    }
}

// MARK: - Analytics Support

extension WelcomePopupView {
    private func trackOnboardingStep() {
        // Track onboarding progress for analytics (if implemented)
        let stepName = "\(currentStep)".lowercased()
        print("📊 Onboarding: User reached step '\(stepName)'")
        
        // Could integrate with analytics service here
        // Analytics.track("onboarding_step_reached", properties: ["step": stepName])
    }
    
    private func trackOnboardingCompletion() {
        print("📊 Onboarding: User completed onboarding")
        
        // Track completion with user preferences
        let preferences: [String: Any] = [
            "notifications_enabled": enableNotifications,
            "haptic_feedback_enabled": enableHapticFeedback,
            "selected_currency": selectedCurrency,
            "selected_theme": selectedThemeColor.name
        ]
        
        print("📊 Onboarding preferences: \(preferences)")
        
        // Could integrate with analytics service here
        // Analytics.track("onboarding_completed", properties: preferences)
    }
}

// MARK: - Data Validation Helpers

extension WelcomePopupView {
    private func isValidName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 2 && trimmedName.count <= maxNameLength
    }
    
    private func isValidCurrency(_ currency: String) -> Bool {
        return supportedCurrencies.contains(currency)
    }
    
    private func validateAllInputs() -> (isValid: Bool, errorMessage: String?) {
        // Validate name
        if !isValidName(name) {
            return (false, "Please enter a valid name (2-\(maxNameLength) characters)")
        }
        
        // Validate currency
        if !isValidCurrency(selectedCurrency) {
            return (false, "Please select a valid currency")
        }
        
        return (true, nil)
    }
}

// MARK: - Theme Transition Helpers

extension WelcomePopupView {
    private func animateThemeChange() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // This will trigger the theme change throughout the view
            themeManager.updateTheme(with: selectedThemeColor)
        }
    }
    
    private func previewThemeChange(_ colorOption: ThemeManager.ColorOption) {
        // Temporarily preview the theme without committing
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedThemeColor = colorOption
        }
        
        // Commit after a brief delay if user doesn't change again
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if selectedThemeColor.id == colorOption.id {
                themeManager.updateTheme(with: colorOption)
            }
        }
    }
}

// MARK: - Keyboard Handling

extension WelcomePopupView {
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Handle keyboard appearance if needed
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Handle keyboard dismissal if needed
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct WelcomePopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Welcome Step")
            
            // Personalization step
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .onAppear {
                    // Simulate being on personalization step
                }
                .previewDisplayName("Personalization Step")
            
            // Dark mode
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Different theme color
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject({
                    let manager = ThemeManager.shared
                    manager.primaryColor = .purple
                    return manager
                }())
                .environmentObject(ErrorHandler.shared)
                .previewDisplayName("Purple Theme")
            
            // Compact size
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .environmentObject(ErrorHandler.shared)
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("Landscape")
        }
    }
}

// Preview helper for different steps
struct WelcomePopupStepPreview: View {
    let step: WelcomePopupView.OnboardingStep
    
    var body: some View {
        WelcomePopupView(isPresented: .constant(true))
            .environmentObject(SettingsManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .onAppear {
                // Would set the step here for preview
            }
    }
}
#endif

// MARK: - Supporting Types for Testing

#if DEBUG
extension WelcomePopupView {
    /// Create a welcome popup for testing with specific configuration
    static func createForTesting(
        step: OnboardingStep = .welcome,
        name: String = "",
        currency: String = "USD",
        enableNotifications: Bool = true
    ) -> WelcomePopupView {
        var view = WelcomePopupView(isPresented: .constant(true))
        view.currentStep = step
        view.name = name
        view.selectedCurrency = currency
        view.enableNotifications = enableNotifications
        return view
    }
    
    /// Get current state for testing
    var testingState: (step: OnboardingStep, name: String, currency: String, canProceed: Bool) {
        return (currentStep, name, selectedCurrency, canProceed)
    }
    
    /// Simulate user actions for testing
    mutating func simulateUserInput(name: String, currency: String) {
        self.name = name
        self.selectedCurrency = currency
    }
    
    /// Force step navigation for testing
    mutating func forceNavigateToStep(_ step: OnboardingStep) {
        currentStep = step
    }
}
#endif

// MARK: - Haptic Feedback Helpers

extension WelcomePopupView {
    private func triggerSuccessHaptic() {
        guard enableHapticFeedback else { return }
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    private func triggerErrorHaptic() {
        guard enableHapticFeedback else { return }
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }
    
    private func triggerSelectionHaptic() {
        guard enableHapticFeedback else { return }
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }
    
    private func triggerImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enableHapticFeedback else { return }
        let feedback = UIImpactFeedbackGenerator(style: style)
        feedback.impactOccurred()
    }
}

// MARK: - Localization Support

extension WelcomePopupView {
    private func localizedString(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
    
    private var localizedStrings: LocalizedStrings {
        LocalizedStrings()
    }
    
    private struct LocalizedStrings {
        let welcomeTitle = NSLocalizedString("welcome.title", value: "Welcome to Brandon's Budget!", comment: "Welcome screen title")
        let welcomeSubtitle = NSLocalizedString("welcome.subtitle", value: "Your personal budget companion is ready to help you take control of your finances.", comment: "Welcome screen subtitle")
        let getStartedButton = NSLocalizedString("welcome.get_started", value: "Get Started", comment: "Get started button")
        let continueButton = NSLocalizedString("welcome.continue", value: "Continue", comment: "Continue button")
        let backButton = NSLocalizedString("welcome.back", value: "Back", comment: "Back button")
        let namePrompt = NSLocalizedString("personalization.name_prompt", value: "What should we call you?", comment: "Name input prompt")
        let namePlaceholder = NSLocalizedString("personalization.name_placeholder", value: "Enter your name", comment: "Name input placeholder")
        let currencyPrompt = NSLocalizedString("personalization.currency_prompt", value: "Select your currency", comment: "Currency selection prompt")
        let themePrompt = NSLocalizedString("preferences.theme_prompt", value: "Choose your theme color", comment: "Theme selection prompt")
        let notificationsTitle = NSLocalizedString("notifications.title", value: "Stay Updated", comment: "Notifications step title")
        let notificationsSubtitle = NSLocalizedString("notifications.subtitle", value: "Get helpful reminders and insights about your spending.", comment: "Notifications step subtitle")
        let enableNotifications = NSLocalizedString("notifications.enable", value: "Enable Notifications", comment: "Enable notifications toggle")
        let completionTitle = NSLocalizedString("completion.title", value: "All Set!", comment: "Completion step title")
        let startBudgetingButton = NSLocalizedString("completion.start_budgeting", value: "Start Budgeting", comment: "Start budgeting button")
    }
}

// MARK: - Dynamic Type Support

extension WelcomePopupView {
    private var dynamicTypeSize: DynamicTypeSize {
        DynamicTypeSize(UITraitCollection.current.preferredContentSizeCategory) ?? .medium
    }
    
    private var isLargeContentSize: Bool {
        dynamicTypeSize >= .accessibility1
    }
    
    private var contentSpacing: CGFloat {
        isLargeContentSize ? 32 : 24
    }
    
    private var iconSize: CGFloat {
        isLargeContentSize ? 56 : 48
    }
}

extension ContentSizeCategory {
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .xLarge
        case .extraExtraLarge: return .xxLarge
        case .extraExtraExtraLarge: return .xxxLarge
        case .accessibilityMedium: return .accessibility1
        case .accessibilityLarge: return .accessibility2
        case .accessibilityExtraLarge: return .accessibility3
        case .accessibilityExtraExtraLarge: return .accessibility4
        case .accessibilityExtraExtraExtraLarge: return .accessibility5
        @unknown default: return .large
        }
    }
}

// MARK: - Color Accessibility

extension WelcomePopupView {
    private func accessibleColor(for baseColor: Color) -> Color {
        // Ensure sufficient contrast for accessibility
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Adjust brightness for better accessibility if needed
        let adjustedBrightness = colorScheme == .dark ? max(brightness, 0.6) : min(brightness, 0.8)
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(adjustedBrightness))
    }
}
