//
//  CustomColors.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

// Fix for SharedTypes.swift - Add this extension at the top of the file

import SwiftUI

// MARK: - Color Extension Fix
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

// MARK: - ColorComponents struct
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

// MARK: - Color Extensions
public extension Color {
    /// Thread-safe UIColor conversion with caching
    private static let colorCache = NSCache<NSString, UIColor>()
    
    /// Initialize color with RGB values (0-255)
    /// - Parameters:
    ///   - r: Red component (0-255)
    ///   - g: Green component (0-255)
    ///   - b: Blue component (0-255)
    ///   - opacity: Opacity value (0-1)
    init(r: Double, g: Double, b: Double, opacity: Double = 1) {
        self.init(
            red: r.clamped(to: 0...255) / 255,
            green: g.clamped(to: 0...255) / 255,
            blue: b.clamped(to: 0...255) / 255,
            opacity: opacity.clamped(to: 0...1)
        )
    }
    
    /// Initialize color from hex string with validation
    /// - Parameter hex: Hex string (e.g., "#FF0000" or "FF0000")
    init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6,
              let rgb = UInt64(hexSanitized, radix: 16) else {
            return nil
        }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    /// Get hex string representation of the color
    var hexString: String {
        let uiColor = UIColor(self)
        let components = uiColor.cgColor.components ?? [0, 0, 0, 0]
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
    
    /// Get RGBA components of the color
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return (Double(r), Double(g), Double(b), Double(a))
    }
    
    /// Custom color palette with semantic naming
    static let customColors = CustomColors()
    
    /// Custom color palette structure
    struct CustomColors {
        // MARK: - Theme Colors
        let primary = Color("PrimaryColor", bundle: nil)
        let secondary = Color("SecondaryColor", bundle: nil)
        let accent = Color("AccentColor", bundle: nil)
        let background = Color("BackgroundColor", bundle: nil)
        
        // MARK: - Semantic Colors
        let expense = Color(r: 231, g: 76, b: 60)    // Red for expenses
        let income = Color(r: 46, g: 204, b: 113)    // Green for income
        let warning = Color(r: 241, g: 196, b: 15)   // Yellow for warnings
        let success = Color(r: 39, g: 174, b: 96)    // Green for success
        let error = Color(r: 192, g: 57, b: 43)      // Red for errors
        let info = Color(r: 41, g: 128, b: 185)      // Blue for info
        
        // MARK: - Category Colors
        let categoryColors: [Color] = [
            Color(r: 41, g: 128, b: 185),   // Blue
            Color(r: 142, g: 68, b: 173),   // Purple
            Color(r: 39, g: 174, b: 96),    // Green
            Color(r: 211, g: 84, b: 0),     // Orange
            Color(r: 192, g: 57, b: 43),    // Red
            Color(r: 44, g: 62, b: 80),     // Dark Blue
            Color(r: 127, g: 140, b: 141)   // Gray
        ]
        
        /// Get a consistent color for a category
        /// - Parameter category: Category name
        /// - Returns: Color for the category
        func colorForCategory(_ category: String) -> Color {
            let index = abs(category.hashValue) % categoryColors.count
            return categoryColors[index]
        }
    }
}

// MARK: - Color Modifiers
public extension Color {
    /// Get color with specific opacity
    /// - Parameter opacity: Opacity value (0-1)
    /// - Returns: New color with specified opacity
    func withOpacity(_ opacity: Double) -> Color {
        self.opacity(opacity.clamped(to: 0...1))
    }
    
    /// Get color lightened by percentage
    /// - Parameter percentage: Percentage to lighten (0-100)
    /// - Returns: Lightened color
    func lightened(by percentage: Double) -> Color {
        let amount = percentage.clamped(to: 0...100) / 100
        let components = self.components
        
        return Color(
            red: min(components.red + amount, 1),
            green: min(components.green + amount, 1),
            blue: min(components.blue + amount, 1),
            opacity: components.alpha
        )
    }
    
    /// Get color darkened by percentage
    /// - Parameter percentage: Percentage to darken (0-100)
    /// - Returns: Darkened color
    func darkened(by percentage: Double) -> Color {
        let amount = percentage.clamped(to: 0...100) / 100
        let components = self.components
        
        return Color(
            red: max(components.red - amount, 0),
            green: max(components.green - amount, 0),
            blue: max(components.blue - amount, 0),
            opacity: components.alpha
        )
    }
    
    /// Create a gradient with this color
    /// - Returns: Linear gradient from this color
    func asGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [self, self.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Numeric Extension
private extension Double {
    /// Clamp value to range
    /// - Parameter range: Valid range for value
    /// - Returns: Clamped value
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Testing Support
#if DEBUG
extension Color {
    /// Create a random color (for testing)
    static func random(opacity: Double = 1) -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1),
            opacity: opacity.clamped(to: 0...1)
        )
    }
    
    /// Convert to CSS hex string (for testing)
    var cssHexString: String {
        let components = self.components
        return String(
            format: "#%02X%02X%02X",
            Int(components.red * 255),
            Int(components.green * 255),
            Int(components.blue * 255)
        )
    }
}
#endif
