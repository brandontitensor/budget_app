//
//  ColorsExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import Foundation

// MARK: - ColorComponents Structure

/// Codable representation of color components for persistence and data sharing
public struct ColorComponents: Codable, Equatable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
    
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = max(0.0, min(1.0, red))
        self.green = max(0.0, min(1.0, green))
        self.blue = max(0.0, min(1.0, blue))
        self.opacity = max(0.0, min(1.0, opacity))
    }
    
    public init(from color: Color) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        // Use UIColor for safe color component extraction
        if UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.opacity = Double(a)
        } else {
            // Fallback to default values if color extraction fails
            self.red = 0.0
            self.green = 0.0
            self.blue = 0.0
            self.opacity = 1.0
        }
    }
    
    /// Create ColorComponents from RGB values (0-255)
    public init(r: Int, g: Int, b: Int, opacity: Double = 1.0) {
        self.init(
            red: Double(max(0, min(255, r))) / 255.0,
            green: Double(max(0, min(255, g))) / 255.0,
            blue: Double(max(0, min(255, b))) / 255.0,
            opacity: opacity
        )
    }
    
    /// Create ColorComponents from hex string
    public init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6,
              let rgb = UInt64(hexSanitized, radix: 16) else {
            return nil
        }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
    
    /// Convert to hex string representation
    public var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// Get brightness value (0.0 to 1.0)
    public var brightness: Double {
        return (red * 0.299 + green * 0.587 + blue * 0.114)
    }
    
    /// Check if this is a light color
    public var isLight: Bool {
        return brightness > 0.5
    }
    
    /// Get contrasting color for text
    public var contrastingColor: ColorComponents {
        return isLight ? ColorComponents(red: 0, green: 0, blue: 0) : ColorComponents(red: 1, green: 1, blue: 1)
    }
    
    /// Validate color components
    public func validate() throws {
        guard (0.0...1.0).contains(red) else {
            throw ColorError.invalidComponent("Red component must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(green) else {
            throw ColorError.invalidComponent("Green component must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(blue) else {
            throw ColorError.invalidComponent("Blue component must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(opacity) else {
            throw ColorError.invalidComponent("Opacity must be between 0.0 and 1.0")
        }
    }
}

// MARK: - Color Error Types

public enum ColorError: LocalizedError {
    case invalidHexString(String)
    case invalidComponent(String)
    case conversionFailed
    case unsupportedFormat
    
    public var errorDescription: String? {
        switch self {
        case .invalidHexString(let hex):
            return "Invalid hex color string: \(hex)"
        case .invalidComponent(let message):
            return "Invalid color component: \(message)"
        case .conversionFailed:
            return "Color conversion failed"
        case .unsupportedFormat:
            return "Unsupported color format"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidHexString:
            return "Use a valid hex color format like #FF0000 or FF0000"
        case .invalidComponent:
            return "Ensure all color components are between 0.0 and 1.0"
        case .conversionFailed:
            return "Try using a different color format or value"
        case .unsupportedFormat:
            return "Use a supported color format like hex, RGB, or HSB"
        }
    }
}

// MARK: - Color Extensions

public extension Color {
    // MARK: - Initialization Methods
    
    /// Initialize color from ColorComponents
    init(_ components: ColorComponents) {
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.opacity
        )
    }
    
    /// Initialize color with RGB values (0-255) with validation
    static func withValidatedRGB(r: Int, g: Int, b: Int, opacity: Double = 1) throws -> Color {
        guard (0...255).contains(r) else {
            throw ColorError.invalidComponent("Red value must be between 0 and 255")
        }
        guard (0...255).contains(g) else {
            throw ColorError.invalidComponent("Green value must be between 0 and 255")
        }
        guard (0...255).contains(b) else {
            throw ColorError.invalidComponent("Blue value must be between 0 and 255")
        }
        guard (0.0...1.0).contains(opacity) else {
            throw ColorError.invalidComponent("Opacity must be between 0.0 and 1.0")
        }
        
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: opacity
        )
    }
    
    /// Initialize color from hex string with comprehensive validation
    init(hex: String) throws {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        // Support both 6-character and 3-character hex codes
        let finalHex: String
        if hexSanitized.count == 3 {
            // Convert 3-char hex to 6-char (e.g., "F0A" -> "FF00AA")
            finalHex = hexSanitized.map { "\($0)\($0)" }.joined()
        } else if hexSanitized.count == 6 {
            finalHex = hexSanitized
        } else {
            throw ColorError.invalidHexString(hex)
        }
        
        // Validate hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard finalHex.rangeOfCharacter(from: hexCharacterSet.inverted) == nil else {
            throw ColorError.invalidHexString(hex)
        }
        
        guard let rgb = UInt64(finalHex, radix: 16) else {
            throw ColorError.invalidHexString(hex)
        }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    
    /// Create color with HSB values with validation
    static func withValidatedHSB(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1.0) throws -> Color {
        guard (0.0...1.0).contains(hue) else {
            throw ColorError.invalidComponent("Hue must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(saturation) else {
            throw ColorError.invalidComponent("Saturation must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(brightness) else {
            throw ColorError.invalidComponent("Brightness must be between 0.0 and 1.0")
        }
        guard (0.0...1.0).contains(opacity) else {
            throw ColorError.invalidComponent("Opacity must be between 0.0 and 1.0")
        }
        
        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: opacity)
    }
    
    // MARK: - Color Properties
    
    /// Get hex string representation of the color
    var hexString: String {
        let components = colorComponents
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(Float(components.red * 255)),
                     lroundf(Float(components.green * 255)),
                     lroundf(Float(components.blue * 255)))
    }
    
    /// Get RGBA components of the color
    var colorComponents: ColorComponents {
        return ColorComponents(from: self)
    }
    
    /// Get RGBA tuple (for backward compatibility)
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let comp = colorComponents
        return (comp.red, comp.green, comp.blue, comp.opacity)
    }
    
    /// Get brightness value (0.0 to 1.0)
    var brightness: Double {
        return colorComponents.brightness
    }
    
    /// Check if this is a light color
    var isLight: Bool {
        return brightness > 0.5
    }
    
    /// Get contrasting color for text
    var contrastingColor: Color {
        return isLight ? .black : .white
    }
    
    /// Get accessible text color with sufficient contrast
    var accessibleTextColor: Color {
        let contrastRatio = getContrastRatio(with: .black)
        return contrastRatio > 4.5 ? .black : .white
    }
    
    // MARK: - Color Manipulation
    
    /// Get color with specific opacity (safe version)
    func withOpacity(_ opacity: Double) -> Color {
        let clampedOpacity = max(0.0, min(1.0, opacity))
        return self.opacity(clampedOpacity)
    }
    
    /// Get color lightened by percentage
    func lightened(by percentage: Double) -> Color {
        let amount = max(0.0, min(100.0, percentage)) / 100.0
        let components = colorComponents
        
        return Color(
            red: min(components.red + amount, 1.0),
            green: min(components.green + amount, 1.0),
            blue: min(components.blue + amount, 1.0),
            opacity: components.opacity
        )
    }
    
    /// Get color darkened by percentage
    func darkened(by percentage: Double) -> Color {
        let amount = max(0.0, min(100.0, percentage)) / 100.0
        let components = colorComponents
        
        return Color(
            red: max(components.red - amount, 0.0),
            green: max(components.green - amount, 0.0),
            blue: max(components.blue - amount, 0.0),
            opacity: components.opacity
        )
    }
    
    /// Adjust saturation of the color
    func adjustingSaturation(by percentage: Double) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        
        let adjustment = max(-1.0, min(1.0, percentage / 100.0))
        let newSaturation = max(0.0, min(1.0, saturation + CGFloat(adjustment)))
        
        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(brightness), opacity: Double(alpha))
    }
    
    /// Blend two colors with specified ratio
    func blended(with other: Color, ratio: Double) -> Color {
        let clampedRatio = max(0.0, min(1.0, ratio))
        let selfComponents = colorComponents
        let otherComponents = other.colorComponents
        
        return Color(
            red: selfComponents.red * (1.0 - clampedRatio) + otherComponents.red * clampedRatio,
            green: selfComponents.green * (1.0 - clampedRatio) + otherComponents.green * clampedRatio,
            blue: selfComponents.blue * (1.0 - clampedRatio) + otherComponents.blue * clampedRatio,
            opacity: selfComponents.opacity * (1.0 - clampedRatio) + otherComponents.opacity * clampedRatio
        )
    }
    
    /// Get complementary color
    var complementaryColor: Color {
        let components = colorComponents
        return Color(
            red: 1.0 - components.red,
            green: 1.0 - components.green,
            blue: 1.0 - components.blue,
            opacity: components.opacity
        )
    }
    
    // MARK: - Gradient Creation
    
    /// Create a linear gradient with this color
    func asLinearGradient(to endColor: Color? = nil, startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> LinearGradient {
        let finalEndColor = endColor ?? self.opacity(0.8)
        return LinearGradient(
            gradient: Gradient(colors: [self, finalEndColor]),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    /// Create a radial gradient with this color
    func asRadialGradient(to endColor: Color? = nil, center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat = 200) -> RadialGradient {
        let finalEndColor = endColor ?? self.opacity(0.3)
        return RadialGradient(
            gradient: Gradient(colors: [self, finalEndColor]),
            center: center,
            startRadius: startRadius,
            endRadius: endRadius
        )
    }
    
    /// Create an angular gradient with this color
    func asAngularGradient(to endColor: Color? = nil, center: UnitPoint = .center, startAngle: Angle = .zero, endAngle: Angle = .degrees(360)) -> AngularGradient {
        let finalEndColor = endColor ?? self.lightened(by: 20)
        return AngularGradient(
            gradient: Gradient(colors: [self, finalEndColor, self]),
            center: center,
            startAngle: startAngle,
            endAngle: endAngle
        )
    }
    
    // MARK: - Accessibility and Contrast
    
    /// Calculate contrast ratio with another color
    func getContrastRatio(with other: Color) -> Double {
        let selfLuminance = relativeLuminance
        let otherLuminance = other.relativeLuminance
        
        let lighter = max(selfLuminance, otherLuminance)
        let darker = min(selfLuminance, otherLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Get relative luminance for accessibility calculations
    private var relativeLuminance: Double {
        let components = colorComponents
        
        func adjustComponent(_ component: Double) -> Double {
            return component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        
        let r = adjustComponent(components.red)
        let g = adjustComponent(components.green)
        let b = adjustComponent(components.blue)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    /// Check if color meets WCAG AA contrast requirements with another color
    func meetsContrastRequirements(with other: Color, level: ContrastLevel = .aa) -> Bool {
        let ratio = getContrastRatio(with: other)
        switch level {
        case .aa:
            return ratio >= 4.5
        case .aaa:
            return ratio >= 7.0
        case .aaLarge:
            return ratio >= 3.0
        }
    }
    
    // MARK: - Theme Integration
    
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
        let expense = Color(red: 231/255, green: 76/255, blue: 60/255)    // Red for expenses
        let income = Color(red: 46/255, green: 204/255, blue: 113/255)    // Green for income
        let warning = Color(red: 241/255, green: 196/255, blue: 15/255)   // Yellow for warnings
        let success = Color(red: 39/255, green: 174/255, blue: 96/255)    // Green for success
        let error = Color(red: 192/255, green: 57/255, blue: 43/255)      // Red for errors
        let info = Color(red: 41/255, green: 128/255, blue: 185/255)      // Blue for info
        
        // MARK: - Category Colors with Improved Accessibility
        private let categoryColorComponents: [ColorComponents] = [
            ColorComponents(r: 41, g: 128, b: 185),   // Blue
            ColorComponents(r: 142, g: 68, b: 173),   // Purple
            ColorComponents(r: 39, g: 174, b: 96),    // Green
            ColorComponents(r: 211, g: 84, b: 0),     // Orange
            ColorComponents(r: 192, g: 57, b: 43),    // Red
            ColorComponents(r: 44, g: 62, b: 80),     // Dark Blue
            ColorComponents(r: 127, g: 140, b: 141),  // Gray
            ColorComponents(r: 155, g: 89, b: 182),   // Light Purple
            ColorComponents(r: 26, g: 188, b: 156),   // Turquoise
            ColorComponents(r: 230, g: 126, b: 34)    // Light Orange
        ]
        
        var categoryColors: [Color] {
            return categoryColorComponents.map { Color($0) }
        }
        
        /// Get a consistent color for a category with improved distribution
        /// - Parameter category: Category name
        /// - Returns: Color for the category
        func colorForCategory(_ category: String) -> Color {
            let hash = category.stableHash
            let index = abs(hash) % categoryColorComponents.count
            return Color(categoryColorComponents[index])
        }
        
        /// Get a color that contrasts well with the given background
        /// - Parameter backgroundColor: Background color to contrast against
        /// - Returns: Contrasting color
        func contrastingColor(for backgroundColor: Color) -> Color {
            return backgroundColor.accessibleTextColor
        }
        
        /// Get semantic color for budget status
        /// - Parameter percentage: Budget usage percentage (0-100+)
        /// - Returns: Appropriate status color
        func budgetStatusColor(for percentage: Double) -> Color {
            switch percentage {
            case 0..<50:
                return success
            case 50..<75:
                return info
            case 75..<90:
                return warning
            case 90..<100:
                return Color.orange
            default:
                return error
            }
        }
    }
    
    // MARK: - Color Schemes and Themes
    
    /// Generate a harmonious color scheme based on this color
    func generateHarmoniousScheme(type: ColorSchemeType = .monochromatic) -> [Color] {
        let components = colorComponents
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return [self] // Return original color if conversion fails
        }
        
        switch type {
        case .monochromatic:
            return generateMonochromaticScheme(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        case .analogous:
            return generateAnalogousScheme(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        case .complementary:
            return generateComplementaryScheme(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        case .triadic:
            return generateTriadicScheme(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
    }
    
    private func generateMonochromaticScheme(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> [Color] {
        return [
            Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(max(0.2, brightness - 0.3)), opacity: Double(alpha)),
            Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(max(0.3, brightness - 0.1)), opacity: Double(alpha)),
            self,
            Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(min(1.0, brightness + 0.1)), opacity: Double(alpha)),
            Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(min(1.0, brightness + 0.3)), opacity: Double(alpha))
        ]
    }
    
    private func generateAnalogousScheme(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> [Color] {
        return [
            Color(hue: Double(fmod(hue - 0.083, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha)),
            Color(hue: Double(fmod(hue - 0.042, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha)),
            self,
            Color(hue: Double(fmod(hue + 0.042, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha)),
            Color(hue: Double(fmod(hue + 0.083, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
        ]
    }
    
    private func generateComplementaryScheme(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> [Color] {
        let complementaryHue = fmod(hue + 0.5, 1.0)
        return [
            self,
            Color(hue: Double(complementaryHue), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
        ]
    }
    
    private func generateTriadicScheme(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> [Color] {
        return [
            self,
            Color(hue: Double(fmod(hue + 0.333, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha)),
            Color(hue: Double(fmod(hue + 0.667, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
        ]
    }
}

// MARK: - Supporting Types

public enum ContrastLevel {
    case aa          // 4.5:1 contrast ratio
    case aaa         // 7:1 contrast ratio
    case aaLarge     // 3:1 contrast ratio for large text
}

public enum ColorSchemeType {
    case monochromatic
    case analogous
    case complementary
    case triadic
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

// MARK: - Dynamic Color Support

public extension Color {
    /// Create a color that adapts to light/dark mode
    static func dynamicColor(light: Color, dark: Color) -> Color {
        return Color(.init { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    /// Create a color with automatic contrast adjustment
    func adaptiveColor(for backgroundBrightness: Double) -> Color {
        let threshold = 0.5
        if backgroundBrightness > threshold {
            // Light background - use darker version of this color
            return self.darkened(by: 30)
        } else {
            // Dark background - use lighter version of this color
            return self.lightened(by: 30)
        }
    }
}

// MARK: - Convenience Initializers

public extension Color {
    /// Initialize from named color with fallback
    init(_ name: String, fallback: Color = .gray) {
        // Use UIColor to check if the named color exists, then create SwiftUI Color
        if UIColor(named: name) != nil {
            self = Color(name, bundle: nil)
        } else {
            self = fallback
        }
    }
    
    /// Initialize random color for testing/debugging
    static func random(opacity: Double = 1.0) -> Color {
        return Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1),
            opacity: max(0.0, min(1.0, opacity))
        )
    }
    
    /// Initialize from temperature (warm/cool colors)
    static func fromTemperature(_ temperature: Double) -> Color {
        // Temperature range: 0.0 (cool/blue) to 1.0 (warm/red)
        let clampedTemp = max(0.0, min(1.0, temperature))
        
        if clampedTemp < 0.5 {
            // Cool colors (blue to cyan)
            let t = clampedTemp * 2.0
            return Color(red: 0.0, green: t, blue: 1.0)
        } else {
            // Warm colors (yellow to red)
            let t = (clampedTemp - 0.5) * 2.0
            return Color(red: 1.0, green: 1.0 - t, blue: 0.0)
        }
    }
}

// MARK: - Performance Optimizations

public extension Color {
    /// Thread-safe color conversion with caching
    private static let colorCache = NSCache<NSString, UIColor>()
    
    /// Get UIColor with caching for better performance
    var uiColor: UIColor {
        let key = hexString as NSString
        if let cached = Color.colorCache.object(forKey: key) {
            return cached
        }
        
        let uiColor = UIColor(self)
        Color.colorCache.setObject(uiColor, forKey: key)
        return uiColor
    }
}

// MARK: - Testing Support

#if DEBUG
public extension Color {
    /// Convert to CSS hex string (for testing and web integration)
    var cssHexString: String {
        let components = colorComponents
        return String(
            format: "#%02X%02X%02X",
            Int(components.red * 255),
            Int(components.green * 255),
            Int(components.blue * 255)
        )
    }
    
    /// Get detailed color information for debugging
    var debugDescription: String {
        let components = colorComponents
        return """
        Color Debug Info:
        - Hex: \(hexString)
        - RGB: (\(Int(components.red * 255)), \(Int(components.green * 255)), \(Int(components.blue * 255)))
        - RGBA: (\(String(format: "%.3f", components.red)), \(String(format: "%.3f", components.green)), \(String(format: "%.3f", components.blue)), \(String(format: "%.3f", components.opacity)))
        - Brightness: \(String(format: "%.3f", brightness))
        - Is Light: \(isLight)
        - Contrast with black: \(String(format: "%.2f", getContrastRatio(with: .black)))
        - Contrast with white: \(String(format: "%.2f", getContrastRatio(with: .white)))
        """
    }
    
    /// Create test color palette
    static var testPalette: [Color] {
        return [
            .red, .green, .blue, .orange, .purple, .pink, .yellow, .cyan,
            Color(red: 0.2, green: 0.4, blue: 0.8),
            Color(red: 0.8, green: 0.2, blue: 0.4),
            Color(red: 0.4, green: 0.8, blue: 0.2)
        ]
    }
    
    /// Validate color accessibility
    func validateAccessibility() -> AccessibilityReport {
        let contrastWithBlack = getContrastRatio(with: .black)
        let contrastWithWhite = getContrastRatio(with: .white)
        
        var issues: [String] = []
        var recommendations: [String] = []
        
        if contrastWithBlack < 4.5 && contrastWithWhite < 4.5 {
            issues.append("Poor contrast with both black and white text")
            recommendations.append("Consider using a different color or adding a background")
        }
        
        if brightness > 0.9 {
            issues.append("Color may be too bright for comfortable viewing")
            recommendations.append("Consider darkening the color slightly")
        }
        
        if brightness < 0.1 {
            issues.append("Color may be too dark and hard to distinguish")
            recommendations.append("Consider lightening the color slightly")
        }
        
        return AccessibilityReport(
            color: self,
            contrastWithBlack: contrastWithBlack,
            contrastWithWhite: contrastWithWhite,
            meetsAA: max(contrastWithBlack, contrastWithWhite) >= 4.5,
            meetsAAA: max(contrastWithBlack, contrastWithWhite) >= 7.0,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    /// Generate test colors with specific properties
    static func testColor(brightness: Double, saturation: Double = 1.0) -> Color {
        let hue = Double.random(in: 0...1)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// MARK: - Accessibility Report

public struct AccessibilityReport {
    public let color: Color
    public let contrastWithBlack: Double
    public let contrastWithWhite: Double
    public let meetsAA: Bool
    public let meetsAAA: Bool
    public let issues: [String]
    public let recommendations: [String]
    
    public var summary: String {
        if issues.isEmpty {
            return "Color passes accessibility guidelines"
        } else {
            return "\(issues.count) accessibility \(issues.count == 1 ? "issue" : "issues") found"
        }
    }
    
    public var bestTextColor: Color {
        return contrastWithBlack > contrastWithWhite ? .black : .white
    }
}
#endif

// MARK: - Color Harmony and Theory

public extension Color {
    /// Get analogous colors (colors adjacent on the color wheel)
    var analogousColors: [Color] {
        return generateHarmoniousScheme(type: .analogous)
    }
    
    /// Get triadic colors (colors evenly spaced on the color wheel)
    var triadicColors: [Color] {
        return generateHarmoniousScheme(type: .triadic)
    }
    
    /// Get monochromatic variations (same hue, different saturation/brightness)
    var monochromaticColors: [Color] {
        return generateHarmoniousScheme(type: .monochromatic)
    }
    
    /// Get split-complementary colors
    var splitComplementaryColors: [Color] {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return [self]
        }
        
        return [
            self,
            Color(hue: Double(fmod(hue + 0.417, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha)),
            Color(hue: Double(fmod(hue + 0.583, 1.0)), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
        ]
    }
}

// MARK: - Material Design Colors

public extension Color {
    /// Material Design color palette
    struct MaterialColors {
        // Material Design Primary Colors
        static let red50 = Color(red: 255/255, green: 235/255, blue: 238/255)
        static let red100 = Color(red: 255/255, green: 205/255, blue: 210/255)
        static let red500 = Color(red: 244/255, green: 67/255, blue: 54/255)
        static let red900 = Color(red: 183/255, green: 28/255, blue: 28/255)
        
        static let blue50 = Color(red: 227/255, green: 242/255, blue: 253/255)
        static let blue100 = Color(red: 187/255, green: 222/255, blue: 251/255)
        static let blue500 = Color(red: 33/255, green: 150/255, blue: 243/255)
        static let blue900 = Color(red: 13/255, green: 71/255, blue: 161/255)
        
        static let green50 = Color(red: 232/255, green: 245/255, blue: 233/255)
        static let green100 = Color(red: 200/255, green: 230/255, blue: 201/255)
        static let green500 = Color(red: 76/255, green: 175/255, blue: 80/255)
        static let green900 = Color(red: 27/255, green: 94/255, blue: 32/255)
        
        // Material Design Gray Scale
        static let gray50 = Color(red: 250/255, green: 250/255, blue: 250/255)
        static let gray100 = Color(red: 245/255, green: 245/255, blue: 245/255)
        static let gray200 = Color(red: 238/255, green: 238/255, blue: 238/255)
        static let gray300 = Color(red: 224/255, green: 224/255, blue: 224/255)
        static let gray400 = Color(red: 189/255, green: 189/255, blue: 189/255)
        static let gray500 = Color(red: 158/255, green: 158/255, blue: 158/255)
        static let gray600 = Color(red: 117/255, green: 117/255, blue: 117/255)
        static let gray700 = Color(red: 97/255, green: 97/255, blue: 97/255)
        static let gray800 = Color(red: 66/255, green: 66/255, blue: 66/255)
        static let gray900 = Color(red: 33/255, green: 33/255, blue: 33/255)
    }
    
    /// Get Material Design color variants
    func materialVariants() -> [Color] {
        // This would generate Material Design style color variants
        // Implementation would depend on the specific Material Design guidelines
        let components = colorComponents
        
        return [
            Color(red: components.red * 0.95 + 0.05, green: components.green * 0.95 + 0.05, blue: components.blue * 0.95 + 0.05), // 50
            Color(red: components.red * 0.9 + 0.1, green: components.green * 0.9 + 0.1, blue: components.blue * 0.9 + 0.1),   // 100
            Color(red: components.red * 0.8 + 0.2, green: components.green * 0.8 + 0.2, blue: components.blue * 0.8 + 0.2),   // 200
            Color(red: components.red * 0.6 + 0.4, green: components.green * 0.6 + 0.4, blue: components.blue * 0.6 + 0.4),   // 300
            Color(red: components.red * 0.8, green: components.green * 0.8, blue: components.blue * 0.8),                     // 400
            self,                                                                                                               // 500
            Color(red: components.red * 0.9, green: components.green * 0.9, blue: components.blue * 0.9),                     // 600
            Color(red: components.red * 0.8, green: components.green * 0.8, blue: components.blue * 0.8),                     // 700
            Color(red: components.red * 0.7, green: components.green * 0.7, blue: components.blue * 0.7),                     // 800
            Color(red: components.red * 0.6, green: components.green * 0.6, blue: components.blue * 0.6)                      // 900
        ]
    }
}

// MARK: - Color Space Conversions

public extension Color {
    /// Convert to different color spaces for advanced color manipulation
    var hsbComponents: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return (Double(hue), Double(saturation), Double(brightness), Double(alpha))
    }
    
    /// Convert to LAB color space (approximate)
    var labComponents: (l: Double, a: Double, b: Double) {
        let rgb = colorComponents
        
        // Convert RGB to XYZ (simplified)
        let r = rgb.red > 0.04045 ? pow((rgb.red + 0.055) / 1.055, 2.4) : rgb.red / 12.92
        let g = rgb.green > 0.04045 ? pow((rgb.green + 0.055) / 1.055, 2.4) : rgb.green / 12.92
        let b = rgb.blue > 0.04045 ? pow((rgb.blue + 0.055) / 1.055, 2.4) : rgb.blue / 12.92
        
        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
        
        // Convert XYZ to LAB
        let xn = x / 0.95047
        let yn = y / 1.00000
        let zn = z / 1.08883
        
        func f(_ t: Double) -> Double {
            return t > 0.008856 ? pow(t, 1.0/3.0) : (7.787 * t + 16.0/116.0)
        }
        
        let fx = f(xn)
        let fy = f(yn)
        let fz = f(zn)
        
        let l = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let bValue = 200.0 * (fy - fz)
        
        return (l, a, bValue)
    }
}

// MARK: - Advanced Color Operations

public extension Color {
    /// Mix colors using different blend modes
    func mixed(with other: Color, mode: BlendMode, intensity: Double = 1.0) -> Color {
        let selfRGB = colorComponents
        let otherRGB = other.colorComponents
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        var resultRGB: ColorComponents
        
        switch mode {
        case .normal:
            resultRGB = ColorComponents(
                red: selfRGB.red * (1.0 - clampedIntensity) + otherRGB.red * clampedIntensity,
                green: selfRGB.green * (1.0 - clampedIntensity) + otherRGB.green * clampedIntensity,
                blue: selfRGB.blue * (1.0 - clampedIntensity) + otherRGB.blue * clampedIntensity,
                opacity: selfRGB.opacity
            )
        case .multiply:
            resultRGB = ColorComponents(
                red: selfRGB.red * otherRGB.red,
                green: selfRGB.green * otherRGB.green,
                blue: selfRGB.blue * otherRGB.blue,
                opacity: selfRGB.opacity
            )
        case .screen:
            resultRGB = ColorComponents(
                red: 1.0 - (1.0 - selfRGB.red) * (1.0 - otherRGB.red),
                green: 1.0 - (1.0 - selfRGB.green) * (1.0 - otherRGB.green),
                blue: 1.0 - (1.0 - selfRGB.blue) * (1.0 - otherRGB.blue),
                opacity: selfRGB.opacity
            )
        case .overlay:
            func overlayBlend(_ base: Double, _ overlay: Double) -> Double {
                return base < 0.5 ? 2.0 * base * overlay : 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay)
            }
            resultRGB = ColorComponents(
                red: overlayBlend(selfRGB.red, otherRGB.red),
                green: overlayBlend(selfRGB.green, otherRGB.green),
                blue: overlayBlend(selfRGB.blue, otherRGB.blue),
                opacity: selfRGB.opacity
            )
        }
        
        // Apply intensity
        if clampedIntensity < 1.0 {
            resultRGB = ColorComponents(
                red: selfRGB.red * (1.0 - clampedIntensity) + resultRGB.red * clampedIntensity,
                green: selfRGB.green * (1.0 - clampedIntensity) + resultRGB.green * clampedIntensity,
                blue: selfRGB.blue * (1.0 - clampedIntensity) + resultRGB.blue * clampedIntensity,
                opacity: resultRGB.opacity
            )
        }
        
        return Color(resultRGB)
    }
    
    /// Apply color filters/effects
    func filtered(with filter: ColorFilter, intensity: Double = 1.0) -> Color {
        let rgb = colorComponents
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        var filtered: ColorComponents
        
        switch filter {
        case .sepia:
            let r = rgb.red * 0.393 + rgb.green * 0.769 + rgb.blue * 0.189
            let g = rgb.red * 0.349 + rgb.green * 0.686 + rgb.blue * 0.168
            let b = rgb.red * 0.272 + rgb.green * 0.534 + rgb.blue * 0.131
            filtered = ColorComponents(red: min(1.0, r), green: min(1.0, g), blue: min(1.0, b), opacity: rgb.opacity)
            
        case .grayscale:
            let gray = rgb.red * 0.299 + rgb.green * 0.587 + rgb.blue * 0.114
            filtered = ColorComponents(red: gray, green: gray, blue: gray, opacity: rgb.opacity)
            
        case .invert:
            filtered = ColorComponents(red: 1.0 - rgb.red, green: 1.0 - rgb.green, blue: 1.0 - rgb.blue, opacity: rgb.opacity)
            
        case .brighten:
            filtered = ColorComponents(
                red: min(1.0, rgb.red + 0.1),
                green: min(1.0, rgb.green + 0.1),
                blue: min(1.0, rgb.blue + 0.1),
                opacity: rgb.opacity
            )
            
        case .darken:
            filtered = ColorComponents(
                red: max(0.0, rgb.red - 0.1),
                green: max(0.0, rgb.green - 0.1),
                blue: max(0.0, rgb.blue - 0.1),
                opacity: rgb.opacity
            )
        }
        
        // Blend with original based on intensity
        let final = ColorComponents(
            red: rgb.red * (1.0 - clampedIntensity) + filtered.red * clampedIntensity,
            green: rgb.green * (1.0 - clampedIntensity) + filtered.green * clampedIntensity,
            blue: rgb.blue * (1.0 - clampedIntensity) + filtered.blue * clampedIntensity,
            opacity: rgb.opacity
        )
        
        return Color(final)
    }
}

// MARK: - Supporting Enums

public enum BlendMode {
    case normal
    case multiply
    case screen
    case overlay
}

public enum ColorFilter {
    case sepia
    case grayscale
    case invert
    case brighten
    case darken
}
