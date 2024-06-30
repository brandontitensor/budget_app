//
//  WelcomePopupView.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//

import SwiftUI

struct WelcomePopupView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var showingNotificationAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Budget!")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            
            Text("Let's get started by personalizing your experience.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            
            TextField("Enter your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Get Started") {
                if !name.isEmpty {
                    settingsManager.userName = name
                }
                settingsManager.isFirstLaunch = false
                showingNotificationAlert = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .frame(width: 300, height: 280)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .alert(isPresented: $showingNotificationAlert) {
            Alert(
                title: Text("Enable Notifications"),
                message: Text("Would you like to receive notifications about your budget and purchases?"),
                primaryButton: .default(Text("Yes")) {
                    requestNotificationPermission()
                },
                secondaryButton: .cancel(Text("Not Now")) {
                    settingsManager.notificationsAllowed = false
                    isPresented = false
                }
            )
        }
    }
    
    private func requestNotificationPermission() {
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                settingsManager.notificationsAllowed = granted
                if granted {
                    settingsManager.purchaseNotificationsEnabled = true
                    settingsManager.budgetTotalNotificationsEnabled = true
                    NotificationManager.shared.updateNotificationSchedule(settingsManager: settingsManager)
                } else {
                    settingsManager.purchaseNotificationsEnabled = false
                    settingsManager.budgetTotalNotificationsEnabled = false
                }
                isPresented = false
            }
        }
    }
}

struct WelcomePopupView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomePopupView(isPresented: .constant(true))
            .environmentObject(SettingsManager())
    }
}
