//
//  ThemeManager.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//


//
//  ThemeManager.swift
//  Brandon's Budget
//
//  Extracted from SharedTypes.swift for better code organization
//

import SwiftUI
import Foundation

// MARK: - Theme Manager
@MainActor
public final class ThemeManager: ObservableObject {
    // MARK: - Types
    public struct ColorOption: Identifiable, Hashable, Codable {
        public let id: UUID
        let name: String
        let colorComponents: ColorComponents
        
        var color: Color {
            Color(
                red: colorComponents.red,
                green: colorComponents.green,
                blue: colorComponents.blue,
                opacity: colorComponents.opacity
            )
        }
        
        init(name: String, color: Color) {
            self.id = UUID()
            self.name = name
            self.colorComponents = ColorComponents(from: color)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: ColorOption, rhs: ColorOption) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public struct ColorComponents: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
        
        init(from color: Color) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.opacity = Double(a)
        }
    }
    
    // MARK: - Constants
    public static let defaultPrimaryColor = ColorOption(name: "Blue", color: .blue)
    
    public static let availableColors: [ColorOption] = [
        ColorOption(name: "Blue", color: .blue),
        ColorOption(name: "Purple", color: .purple),
        ColorOption(name: "Green", color: .green),
        ColorOption(name: "Orange", color: .orange),
        ColorOption(name: "Pink", color: .pink),
        ColorOption(name: "Teal", color: .teal),
        ColorOption(name: "Indigo", color: .indigo),
        ColorOption(name: "Red", color: .red)
    ]
    
    // MARK: - Published Properties
    @Published public var primaryColor: Color {
        didSet {
            saveColorPreference()
            updateGlobalAppearance()
        }
    }
    
    @Published public var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: StorageKeys.isDarkMode)
        }
    }
    
    // MARK: - Storage Keys
    private enum StorageKeys {
        static let primaryColorName = "primaryColorName"
        static let isDarkMode = "isDarkMode"
    }
    
    // MARK: - Category Colors
    private let categoryColors: [Color] = [
        Color(red: 0.16, green: 0.50, blue: 0.73), // Blue
        Color(red: 0.56, green: 0.27, blue: 0.68), // Purple
        Color(red: 0.15, green: 0.68, blue: 0.38), // Green
        Color(red: 0.83, green: 0.33, blue: 0.00), // Orange
        Color(red: 0.75, green: 0.22, blue: 0.17), // Red
        Color(red: 0.17, green: 0.24, blue: 0.31), // Dark Blue
        Color(red: 0.50, green: 0.55, blue: 0.55)  // Gray
    ]
    
    // MARK: - Initialization
    public static let shared = ThemeManager()
    
    private init() {
        // Load saved color preference
        if let colorName = UserDefaults.standard.string(forKey: StorageKeys.primaryColorName),
           let storedColor = ThemeManager.availableColors.first(where: { $0.name == colorName }) {
            self.primaryColor = storedColor.color
        } else {
            self.primaryColor = ThemeManager.defaultPrimaryColor.color
        }
        
        // Load dark mode preference
        self.isDarkMode = UserDefaults.standard.bool(forKey: StorageKeys.isDarkMode)
        
        // Apply initial appearance
        updateGlobalAppearance()
    }
    
    // MARK: - Public Methods
    
    /// Reset theme to default values
    public func resetToDefaults() {
        primaryColor = ThemeManager.defaultPrimaryColor.color
        isDarkMode = false
    }
    
    /// Get a consistent color for a category
    /// - Parameter category: Category name
    /// - Returns: Color for the category
    public func colorForCategory(_ category: String) -> Color {
        let index = abs(category.hashValue) % categoryColors.count
        return categoryColors[index]
    }
    
    /// Create a gradient with the primary color
    /// - Returns: Linear gradient using primary color
    public func primaryGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Get the current color option
    /// - Returns: The current color option
    public var currentColorOption: ColorOption {
        ThemeManager.availableColors.first { $0.color == primaryColor } ?? ThemeManager.defaultPrimaryColor
    }
    
    /// Update theme color with option
    /// - Parameter colorOption: The color option to apply
    public func updateTheme(with colorOption: ColorOption) {
        primaryColor = colorOption.color
    }
    
    // MARK: - Private Methods
    
    private func saveColorPreference() {
        let colorOption = currentColorOption
        UserDefaults.standard.set(colorOption.name, forKey: StorageKeys.primaryColorName)
    }
    
    private func updateGlobalAppearance() {
        // Update navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(primaryColor)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Update tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - Theme Extensions

public extension ThemeManager {
    /// Get semantic colors based on theme
    var semanticColors: SemanticColors {
        SemanticColors(primaryColor: primaryColor)
    }
}

public struct SemanticColors {
    let primaryColor: Color
    
    var success: Color { .green }
    var warning: Color { .orange }
    var error: Color { .red }
    var info: Color { primaryColor }
    
    var backgroundPrimary: Color { Color(.systemBackground) }
    var backgroundSecondary: Color { Color(.secondarySystemBackground) }
    var backgroundTertiary: Color { Color(.tertiarySystemBackground) }
    
    var textPrimary: Color { Color(.label) }
    var textSecondary: Color { Color(.secondaryLabel) }
    var textTertiary: Color { Color(.tertiaryLabel) }
}

// MARK: - Color Extension

extension Color {
    init(_ components: ColorComponents) {
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.opacity
        )
    }
}

// MARK: - Testing Support

#if DEBUG
extension ThemeManager {
    /// Create a test theme manager with custom settings
    static func createTestManager() -> ThemeManager {
        let manager = ThemeManager()
        return manager
    }
    
    /// Reset to default theme for testing
    func resetForTesting() {
        primaryColor = ThemeManager.defaultPrimaryColor.color
        isDarkMode = false
        updateGlobalAppearance()
    }
    
    /// Apply random theme for testing
    func applyRandomTheme() {
        let randomColor = ThemeManager.availableColors.randomElement() ?? ThemeManager.defaultPrimaryColor
        primaryColor = randomColor.color
        isDarkMode = Bool.random()
    }
}

// MARK: - Preview Support
struct ThemeManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Primary color examples
            HStack {
                ForEach(ThemeManager.availableColors, id: \.id) { colorOption in
                    Circle()
                        .fill(colorOption.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(colorOption.name.prefix(1))
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            }
            
            // Category colors example
            let themeManager = ThemeManager.shared
            HStack {
                ForEach(["Groceries", "Entertainment", "Transport", "Dining"], id: \.self) { category in
                    VStack {
                        Circle()
                            .fill(themeManager.colorForCategory(category))
                            .frame(width: 40, height: 40)
                        Text(category)
                            .font(.caption)
                    }
                }
            }
            
            // Semantic colors example
            let semanticColors = themeManager.semanticColors
            HStack {
                Rectangle()
                    .fill(semanticColors.success)
                    .frame(width: 50, height: 30)
                    .overlay(Text("✓").foregroundColor(.white))
                
                Rectangle()
                    .fill(semanticColors.warning)
                    .frame(width: 50, height: 30)
                    .overlay(Text("⚠").foregroundColor(.white))
                
                Rectangle()
                    .fill(semanticColors.error)
                    .frame(width: 50, height: 30)
                    .overlay(Text("✗").foregroundColor(.white))
                
                Rectangle()
                    .fill(semanticColors.info)
                    .frame(width: 50, height: 30)
                    .overlay(Text("i").foregroundColor(.white))
            }
        }
        .padding()
        .environmentObject(ThemeManager.shared)
    }
}
#endif