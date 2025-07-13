//
//  ColorConstants.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//


import SwiftUI
import Foundation

// MARK: - Color Constants

/// Centralized color definitions for consistent theming throughout the app
public enum ColorConstants {
    
    // MARK: - Primary Brand Colors
    
    /// Main brand colors used throughout the app
    public enum Brand {
        /// Primary brand color - main accent color
        public static let primary = Color("BrandPrimary", bundle: .main) ?? Color.blue
        
        /// Secondary brand color - supporting accent
        public static let secondary = Color("BrandSecondary", bundle: .main) ?? Color.indigo
        
        /// Tertiary brand color - subtle accents
        public static let tertiary = Color("BrandTertiary", bundle: .main) ?? Color.cyan
        
        /// Brand gradient colors
        public static let gradientStart = primary
        public static let gradientEnd = secondary.opacity(0.8)
        
        /// Brand color variants for different states
        public enum Variants {
            public static let light = Brand.primary.lightened(by: 20)
            public static let dark = Brand.primary.darkened(by: 20)
            public static let muted = Brand.primary.opacity(0.6)
            public static let subtle = Brand.primary.opacity(0.1)
        }
    }
    
    // MARK: - Semantic Colors
    
    /// Semantic colors that convey meaning and state
    public enum Semantic {
        // Status Colors
        public static let success = Color(red: 34/255, green: 197/255, blue: 94/255)       // Green
        public static let warning = Color(red: 251/255, green: 191/255, blue: 36/255)     // Amber
        public static let error = Color(red: 239/255, green: 68/255, blue: 68/255)        // Red
        public static let info = Color(red: 59/255, green: 130/255, blue: 246/255)        // Blue
        
        // Budget-specific colors
        public static let income = Color(red: 16/255, green: 185/255, blue: 129/255)      // Emerald
        public static let expense = Color(red: 220/255, green: 38/255, blue: 127/255)     // Pink
        public static let savings = Color(red: 99/255, green: 102/255, blue: 241/255)     // Indigo
        public static let investment = Color(red: 168/255, green: 85/255, blue: 247/255)  // Purple
        
        // Alert levels
        public static let critical = Color(red: 185/255, green: 28/255, blue: 28/255)     // Dark Red
        public static let moderate = Color(red: 217/255, green: 119/255, blue: 6/255)     // Orange
        public static let low = Color(red: 65/255, green: 161/255, blue: 208/255)         // Light Blue
        
        // Status variants
        public enum Variants {
            // Success variants
            public static let successLight = Semantic.success.lightened(by: 30)
            public static let successDark = Semantic.success.darkened(by: 20)
            public static let successSubtle = Semantic.success.opacity(0.1)
            
            // Warning variants
            public static let warningLight = Semantic.warning.lightened(by: 30)
            public static let warningDark = Semantic.warning.darkened(by: 20)
            public static let warningSubtle = Semantic.warning.opacity(0.1)
            
            // Error variants
            public static let errorLight = Semantic.error.lightened(by: 30)
            public static let errorDark = Semantic.error.darkened(by: 20)
            public static let errorSubtle = Semantic.error.opacity(0.1)
            
            // Info variants
            public static let infoLight = Semantic.info.lightened(by: 30)
            public static let infoDark = Semantic.info.darkened(by: 20)
            public static let infoSubtle = Semantic.info.opacity(0.1)
        }
    }
    
    // MARK: - Neutral Colors
    
    /// Neutral colors for backgrounds, text, and borders
    public enum Neutral {
        // Grayscale palette
        public static let white = Color.white
        public static let gray50 = Color(red: 249/255, green: 250/255, blue: 251/255)
        public static let gray100 = Color(red: 243/255, green: 244/255, blue: 246/255)
        public static let gray200 = Color(red: 229/255, green: 231/255, blue: 235/255)
        public static let gray300 = Color(red: 209/255, green: 213/255, blue: 219/255)
        public static let gray400 = Color(red: 156/255, green: 163/255, blue: 175/255)
        public static let gray500 = Color(red: 107/255, green: 114/255, blue: 128/255)
        public static let gray600 = Color(red: 75/255, green: 85/255, blue: 99/255)
        public static let gray700 = Color(red: 55/255, green: 65/255, blue: 81/255)
        public static let gray800 = Color(red: 31/255, green: 41/255, blue: 55/255)
        public static let gray900 = Color(red: 17/255, green: 24/255, blue: 39/255)
        public static let black = Color.black
        
        // Semantic neutral colors
        public static let background = Color(.systemBackground)
        public static let secondaryBackground = Color(.secondarySystemBackground)
        public static let tertiaryBackground = Color(.tertiarySystemBackground)
        public static let groupedBackground = Color(.systemGroupedBackground)
        
        // Text colors
        public static let text = Color(.label)
        public static let secondaryText = Color(.secondaryLabel)
        public static let tertiaryText = Color(.tertiaryLabel)
        public static let placeholderText = Color(.placeholderText)
        
        // Separator colors
        public static let separator = Color(.separator)
        public static let opaqueSeparator = Color(.opaqueSeparator)
        
        // Border colors
        public static let border = gray300
        public static let focusedBorder = Brand.primary
        public static let errorBorder = Semantic.error
    }
    
    // MARK: - Category Colors
    
    /// Predefined colors for budget categories with good contrast and accessibility
    public enum Category {
        private static let categoryPalette: [Color] = [
            Color(red: 239/255, green: 68/255, blue: 68/255),   // Red
            Color(red: 34/255, green: 197/255, blue: 94/255),   // Green
            Color(red: 59/255, green: 130/255, blue: 246/255),  // Blue
            Color(red: 251/255, green: 191/255, blue: 36/255),  // Amber
            Color(red: 168/255, green: 85/255, blue: 247/255),  // Purple
            Color(red: 236/255, green: 72/255, blue: 153/255),  // Pink
            Color(red: 6/255, green: 182/255, blue: 212/255),   // Cyan
            Color(red: 245/255, green: 101/255, blue: 101/255), // Rose
            Color(red: 139/255, green: 69/255, blue: 19/255),   // Brown
            Color(red: 75/255, green: 85/255, blue: 99/255),    // Gray
            Color(red: 16/255, green: 185/255, blue: 129/255),  // Emerald
            Color(red: 99/255, green: 102/255, blue: 241/255),  // Indigo
            Color(red: 245/255, green: 158/255, blue: 11/255),  // Orange
            Color(red: 20/255, green: 184/255, blue: 166/255),  // Teal
            Color(red: 217/255, green: 70/255, blue: 239/255),  // Fuchsia
            Color(red: 132/255, green: 204/255, blue: 22/255),  // Lime
        ]
        
        /// Get a consistent color for a category name
        /// - Parameter categoryName: The name of the category
        /// - Returns: A color that will always be the same for this category name
        public static func color(for categoryName: String) -> Color {
            let hash = categoryName.stableHash
            let index = abs(hash) % categoryPalette.count
            return categoryPalette[index]
        }
        
        /// Get a light variant of the category color
        /// - Parameter categoryName: The name of the category
        /// - Returns: A lightened version of the category color
        public static func lightColor(for categoryName: String) -> Color {
            return color(for: categoryName).lightened(by: 30)
        }
        
        /// Get a subtle background color for the category
        /// - Parameter categoryName: The name of the category
        /// - Returns: A very light, subtle version of the category color
        public static func subtleColor(for categoryName: String) -> Color {
            return color(for: categoryName).opacity(0.1)
        }
        
        /// Get all available category colors
        public static var allColors: [Color] {
            return categoryPalette
        }
        
        /// Get the color at a specific index (for preview/testing)
        /// - Parameter index: The index in the color palette
        /// - Returns: The color at that index, or the first color if index is out of bounds
        public static func colorAt(index: Int) -> Color {
            guard index >= 0 && index < categoryPalette.count else {
                return categoryPalette[0]
            }
            return categoryPalette[index]
        }
    }
    
    // MARK: - Chart Colors
    
    /// Colors specifically designed for charts and data visualization
    public enum Chart {
        // Primary chart colors with good contrast
        public static let primary = Brand.primary
        public static let secondary = Color(red: 16/255, green: 185/255, blue: 129/255)   // Emerald
        public static let tertiary = Color(red: 251/255, green: 191/255, blue: 36/255)    // Amber
        public static let quaternary = Color(red: 168/255, green: 85/255, blue: 247/255) // Purple
        
        // Chart color palette for multiple data series
        public static let palette: [Color] = [
            primary,
            secondary,
            tertiary,
            quaternary,
            Color(red: 239/255, green: 68/255, blue: 68/255),   // Red
            Color(red: 6/255, green: 182/255, blue: 212/255),   // Cyan
            Color(red: 236/255, green: 72/255, blue: 153/255),  // Pink
            Color(red: 132/255, green: 204/255, blue: 22/255),  // Lime
        ]
        
        // Specific chart types
        public enum PieChart {
            public static let colors = Chart.palette
            public static let strokeColor = Neutral.white
            public static let strokeWidth: CGFloat = 2
        }
        
        public enum BarChart {
            public static let primary = Chart.primary
            public static let secondary = Chart.secondary
            public static let background = Neutral.gray100
            public static let gridLines = Neutral.gray300
        }
        
        public enum LineChart {
            public static let line = Chart.primary
            public static let fill = Chart.primary.opacity(0.2)
            public static let point = Chart.primary
            public static let grid = Neutral.gray300
        }
        
        /// Get a color from the chart palette by index
        /// - Parameter index: The index in the palette
        /// - Returns: The color at that index, cycling through if index exceeds palette size
        public static func color(at index: Int) -> Color {
            let safeIndex = index % palette.count
            return palette[safeIndex]
        }
    }
    
    // MARK: - Gradient Definitions
    
    /// Predefined gradients for consistent styling
    public enum Gradients {
        // Brand gradients
        public static let primary = LinearGradient(
            colors: [Brand.primary, Brand.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let subtle = LinearGradient(
            colors: [Brand.primary.opacity(0.1), Brand.secondary.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Status gradients
        public static let success = LinearGradient(
            colors: [Semantic.success, Semantic.success.darkened(by: 20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let warning = LinearGradient(
            colors: [Semantic.warning, Semantic.warning.darkened(by: 20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let error = LinearGradient(
            colors: [Semantic.error, Semantic.error.darkened(by: 20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Background gradients
        public static let backgroundLight = LinearGradient(
            colors: [Neutral.gray50, Neutral.white],
            startPoint: .top,
            endPoint: .bottom
        )
        
        public static let backgroundDark = LinearGradient(
            colors: [Neutral.gray900, Neutral.gray800],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Income/Expense gradients
        public static let income = LinearGradient(
            colors: [Semantic.income, Semantic.income.darkened(by: 15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let expense = LinearGradient(
            colors: [Semantic.expense, Semantic.expense.darkened(by: 15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Create a radial gradient for the given color
        /// - Parameter color: The base color for the gradient
        /// - Returns: A radial gradient from the color to its darker variant
        public static func radial(for color: Color) -> RadialGradient {
            return RadialGradient(
                colors: [color, color.darkened(by: 30)],
                center: .center,
                startRadius: 0,
                endRadius: 100
            )
        }
        
        /// Create an angular gradient for the given colors
        /// - Parameter colors: The colors to use in the gradient
        /// - Returns: An angular gradient with the specified colors
        public static func angular(colors: [Color]) -> AngularGradient {
            return AngularGradient(
                colors: colors,
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        }
    }
    
    // MARK: - Accessibility Colors
    
    /// Colors that meet accessibility standards
    public enum Accessibility {
        // High contrast colors for accessibility
        public static let highContrastText = Neutral.black
        public static let highContrastBackground = Neutral.white
        public static let highContrastBorder = Neutral.black
        
        // Focus indicators
        public static let focusRing = Brand.primary
        public static let focusRingWidth: CGFloat = 3
        
        // Error states with sufficient contrast
        public static let errorText = Color(red: 153/255, green: 27/255, blue: 27/255)
        public static let errorBackground = Color(red: 254/255, green: 242/255, blue: 242/255)
        
        // Warning states with sufficient contrast
        public static let warningText = Color(red: 146/255, green: 64/255, blue: 14/255)
        public static let warningBackground = Color(red: 255/255, green: 251/255, blue: 235/255)
        
        // Success states with sufficient contrast
        public static let successText = Color(red: 22/255, green: 101/255, blue: 52/255)
        public static let successBackground = Color(red: 240/255, green: 253/255, blue: 244/255)
        
        /// Check if a color combination meets WCAG AA standards
        /// - Parameters:
        ///   - foreground: The foreground color
        ///   - background: The background color
        /// - Returns: True if the combination meets AA standards (4.5:1 contrast ratio)
        public static func meetsAAStandards(foreground: Color, background: Color) -> Bool {
            return foreground.getContrastRatio(with: background) >= 4.5
        }
        
        /// Check if a color combination meets WCAG AAA standards
        /// - Parameters:
        ///   - foreground: The foreground color
        ///   - background: The background color
        /// - Returns: True if the combination meets AAA standards (7:1 contrast ratio)
        public static func meetsAAAStandards(foreground: Color, background: Color) -> Bool {
            return foreground.getContrastRatio(with: background) >= 7.0
        }
        
        /// Get the best text color for the given background
        /// - Parameter backgroundColor: The background color
        /// - Returns: Either black or white, whichever provides better contrast
        public static func bestTextColor(for backgroundColor: Color) -> Color {
            return backgroundColor.accessibleTextColor
        }
    }
    
    // MARK: - Dark Mode Colors
    
    /// Colors specifically for dark mode support
    public enum DarkMode {
        // Adjusted brand colors for dark mode
        public static let primaryLight = Brand.primary.lightened(by: 20)
        public static let secondaryLight = Brand.secondary.lightened(by: 20)
        
        // Dark mode backgrounds
        public static let background = Color(red: 17/255, green: 24/255, blue: 39/255)
        public static let secondaryBackground = Color(red: 31/255, green: 41/255, blue: 55/255)
        public static let tertiaryBackground = Color(red: 55/255, green: 65/255, blue: 81/255)
        
        // Dark mode text
        public static let text = Color(red: 243/255, green: 244/255, blue: 246/255)
        public static let secondaryText = Color(red: 209/255, green: 213/255, blue: 219/255)
        public static let tertiaryText = Color(red: 156/255, green: 163/255, blue: 175/255)
        
        // Dark mode borders and separators
        public static let border = Color(red: 75/255, green: 85/255, blue: 99/255)
        public static let separator = Color(red: 55/255, green: 65/255, blue: 81/255)
    }
    
    // MARK: - Dynamic Color Support
    
    /// Create colors that adapt to light/dark mode
    public enum Dynamic {
        /// Create a color that adapts between light and dark variants
        /// - Parameters:
        ///   - light: Color for light mode
        ///   - dark: Color for dark mode
        /// - Returns: A dynamic color that switches based on appearance
        public static func color(light: Color, dark: Color) -> Color {
            return Color(.init { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        }
        
        // Pre-defined dynamic colors
        public static let primaryText = color(light: Neutral.text, dark: DarkMode.text)
        public static let secondaryText = color(light: Neutral.secondaryText, dark: DarkMode.secondaryText)
        public static let background = color(light: Neutral.background, dark: DarkMode.background)
        public static let secondaryBackground = color(light: Neutral.secondaryBackground, dark: DarkMode.secondaryBackground)
        public static let border = color(light: Neutral.border, dark: DarkMode.border)
        public static let separator = color(light: Neutral.separator, dark: DarkMode.separator)
    }
    
    // MARK: - Color Utilities
    
    /// Utility functions for color manipulation and validation
    public enum Utils {
        /// Generate a random color from the category palette
        /// - Returns: A random color from the predefined category colors
        public static func randomCategoryColor() -> Color {
            return Category.allColors.randomElement() ?? Brand.primary
        }
        
        /// Get a color with ensured accessibility
        /// - Parameters:
        ///   - color: The desired color
        ///   - background: The background it will be used against
        /// - Returns: The original color if accessible, or an adjusted version if not
        public static func accessibleColor(_ color: Color, on background: Color) -> Color {
            let contrastRatio = color.getContrastRatio(with: background)
            
            if contrastRatio >= 4.5 {
                return color
            } else {
                // Try darkening the color
                let darkened = color.darkened(by: 30)
                if darkened.getContrastRatio(with: background) >= 4.5 {
                    return darkened
                }
                
                // Try lightening the color
                let lightened = color.lightened(by: 30)
                if lightened.getContrastRatio(with: background) >= 4.5 {
                    return lightened
                }
                
                // Fallback to high contrast
                return background.isLight ? Neutral.black : Neutral.white
            }
        }
        
        /// Validate a color palette for accessibility
        /// - Parameter colors: Array of colors to validate
        /// - Returns: Array of validation results for each color pair
        public static func validatePalette(_ colors: [Color]) -> [PaletteValidationResult] {
            var results: [PaletteValidationResult] = []
            
            for i in 0..<colors.count {
                for j in i+1..<colors.count {
                    let color1 = colors[i]
                    let color2 = colors[j]
                    let contrastRatio = color1.getContrastRatio(with: color2)
                    
                    results.append(PaletteValidationResult(
                        color1: color1,
                        color2: color2,
                        contrastRatio: contrastRatio,
                        meetsAA: contrastRatio >= 4.5,
                        meetsAAA: contrastRatio >= 7.0
                    ))
                }
            }
            
            return results
        }
        
        /// Convert a hex string to Color with validation
        /// - Parameter hex: Hex color string (with or without #)
        /// - Returns: Color if valid, nil if invalid
        public static func colorFromHex(_ hex: String) -> Color? {
            return try? Color(hex: hex)
        }
        
        /// Generate a tint for the given color
        /// - Parameters:
        ///   - color: Base color
        ///   - percentage: Percentage to tint (0-100)
        /// - Returns: Tinted color
        public static func tint(_ color: Color, by percentage: Double) -> Color {
            return color.blended(with: .white, ratio: percentage / 100.0)
        }
        
        /// Generate a shade for the given color
        /// - Parameters:
        ///   - color: Base color
        ///   - percentage: Percentage to shade (0-100)
        /// - Returns: Shaded color
        public static func shade(_ color: Color, by percentage: Double) -> Color {
            return color.blended(with: .black, ratio: percentage / 100.0)
        }
    }
}

// MARK: - Supporting Types

/// Result of palette validation for accessibility
public struct PaletteValidationResult {
    public let color1: Color
    public let color2: Color
    public let contrastRatio: Double
    public let meetsAA: Bool
    public let meetsAAA: Bool
    
    public var accessibilityLevel: AccessibilityLevel {
        if meetsAAA {
            return .aaa
        } else if meetsAA {
            return .aa
        } else {
            return .none
        }
    }
    
    public enum AccessibilityLevel: String, CaseIterable {
        case none = "Does not meet standards"
        case aa = "Meets AA standards"
        case aaa = "Meets AAA standards"
    }
}

// MARK: - String Extension for Stable Hashing

private extension String {
    /// Generate a stable hash for consistent color assignment
    var stableHash: Int {
        var hash = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return hash
    }
}

// MARK: - Color Extensions for ColorConstants

public extension Color {
    /// Create color from ColorConstants category
    /// - Parameter category: Category name
    /// - Returns: Consistent color for the category
    static func forCategory(_ category: String) -> Color {
        return ColorConstants.Category.color(for: category)
    }
    
    /// Get semantic color for budget status
    /// - Parameter percentage: Budget usage percentage (0-100+)
    /// - Returns: Appropriate status color
    static func budgetStatus(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return ColorConstants.Semantic.success
        case 50..<75:
            return ColorConstants.Semantic.info
        case 75..<90:
            return ColorConstants.Semantic.warning
        case 90..<100:
            return ColorConstants.Semantic.warning.darkened(by: 20)
        default:
            return ColorConstants.Semantic.error
        }
    }
    
    /// Get income/expense color
    /// - Parameter isIncome: True for income, false for expense
    /// - Returns: Appropriate semantic color
    static func transactionType(isIncome: Bool) -> Color {
        return isIncome ? ColorConstants.Semantic.income : ColorConstants.Semantic.expense
    }
}

// MARK: - SwiftUI Environment Integration

public extension EnvironmentValues {
    /// Custom environment value for theme colors
    var themeColors: ColorConstants.Type {
        get { ColorConstants.self }
    }
}

// MARK: - Testing Support

#if DEBUG
public extension ColorConstants {
    /// Testing utilities for color constants
    enum Testing {
        /// Generate all colors for testing
        static func allTestColors() -> [String: Color] {
            return [
                "brand.primary": Brand.primary,
                "brand.secondary": Brand.secondary,
                "semantic.success": Semantic.success,
                "semantic.warning": Semantic.warning,
                "semantic.error": Semantic.error,
                "semantic.info": Semantic.info,
                "semantic.income": Semantic.income,
                "semantic.expense": Semantic.expense,
                "neutral.text": Neutral.text,
                "neutral.background": Neutral.background,
                "chart.primary": Chart.primary,
                "chart.secondary": Chart.secondary
            ]
        }
        
        /// Test accessibility of all semantic colors
        static func testAccessibility() -> [String: Bool] {
            let colors = allTestColors()
            var results: [String: Bool] = [:]
            
            for (name, color) in colors {
                let whiteContrast = color.getContrastRatio(with: .white)
                let blackContrast = color.getContrastRatio(with: .black)
                results[name] = max(whiteContrast, blackContrast) >= 4.5
            }
            
            return results
        }
        
        /// Generate color palette preview
        static func colorPalettePreview() -> some View {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                    ForEach(Array(allTestColors().keys.sorted()), id: \.self) { key in
                        if let color = allTestColors()[key] {
                            VStack {
                                Rectangle()
                                    .fill(color)
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text(key)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        
        /// Test category color consistency
        static func testCategoryColorConsistency() -> Bool {
            let testCategories = ["Groceries", "Transportation", "Entertainment", "Utilities"]
            
            for category in testCategories {
                let color1 = Category.color(for: category)
                let color2 = Category.color(for: category)
                
                if color1 != color2 {
                    return false
                }
            }
            
            return true
        }
    }
}
#endif
