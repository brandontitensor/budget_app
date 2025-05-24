//
//  WelcomePopupView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//
import SwiftUI
import Foundation

/// View for handling initial app onboarding and setup
struct WelcomePopupView: View {
    // MARK: - Environment
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    
    // MARK: - State
    @State private var name: String = ""
    @State private var showingNotificationAlert = false
    @State private var isAnimating = false
    @State private var currentStep = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // MARK: - Constants
    private let animationDuration = 0.5
    private let maxNameLength = 50
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            welcomeHeader
            stepContent
            navigationButtons
        }
        .padding(24)
        .frame(width: 320)
        .background(backgroundStyle)
        .cornerRadius(20)
        .shadow(radius: 10)
        .opacity(isAnimating ? 1 : 0)
        .scaleEffect(isAnimating ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(duration: animationDuration)) {
                isAnimating = true
            }
        }
        .alert("Enable Notifications", isPresented: $showingNotificationAlert) {
            Button("Yes") {
                requestNotificationPermission()
            }
            Button("Not Now") {
                handleNotificationDenial()
            }
        } message: {
            Text("Would you like to receive notifications about your budget and purchases?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Text("Welcome to Budget!")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Let's get started by personalizing your experience.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var stepContent: some View {
        switch currentStep {
        case 0:
            return AnyView(nameInputSection)
        case 1:
            return AnyView(currencySection)
        case 2:
            return AnyView(themeSection)
        default:
            return AnyView(EmptyView())
        }
    }
    
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What should we call you?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .onChange(of: name) { newValue in
                    if newValue.count > maxNameLength {
                        name = String(newValue.prefix(maxNameLength))
                    }
                }
        }
    }
    
    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select your currency")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Currency", selection: $settingsManager.defaultCurrency) {
                ForEach(["USD", "EUR", "GBP", "JPY"], id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose your theme")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeManager.availableColors, id: \.self) { colorOption in
                        colorButton(for: colorOption)
                    }
                }
            }
        }
    }
    
    private func colorButton(for colorOption: ThemeManager.ColorOption) -> some View {
        Button {
            withAnimation {
                themeManager.primaryColor = colorOption.color
            }
        } label: {
            Circle()
                .fill(colorOption.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(
                            themeManager.primaryColor == colorOption.color ? .white : .clear,
                            lineWidth: 2
                        )
                )
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }
            
            Spacer()
            
            Button(currentStep == 2 ? "Get Started" : "Next") {
                handleNavigation()
            }
            .disabled(currentStep == 0 && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private var backgroundStyle: some View {
        colorScheme == .dark
            ? Color(white: 0.2)
            : Color.white
    }
    
    // MARK: - Helper Methods
    private func handleNavigation() {
        if currentStep == 0 {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                errorMessage = "Please enter your name"
                showingError = true
                return
            }
            settingsManager.userName = trimmedName
            withAnimation {
                currentStep += 1
            }
        } else if currentStep == 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        settingsManager.isFirstLaunch = false
        showingNotificationAlert = true
    }
    
    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await NotificationManager.shared.requestAuthorization()
                await MainActor.run {
                    settingsManager.notificationsAllowed = granted
                    configureNotificationSettings(granted)
                    dismissView()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func handleNotificationDenial() {
        settingsManager.notificationsAllowed = false
        configureNotificationSettings(false)
        dismissView()
    }
    
    private func configureNotificationSettings(_ notificationsEnabled: Bool) {
        settingsManager.purchaseNotificationsEnabled = notificationsEnabled
        settingsManager.budgetTotalNotificationsEnabled = notificationsEnabled
        
        if notificationsEnabled {
            Task {
                await NotificationManager.shared.updateNotificationSchedule(settings: settingsManager)
            }
        }
    }
    
    private func dismissView() {
        withAnimation(.spring(duration: animationDuration)) {
            isAnimating = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            isPresented = false
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct WelcomePopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .previewDisplayName("Light Mode")
            
            WelcomePopupView(isPresented: .constant(true))
                .environmentObject(SettingsManager.shared)
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
