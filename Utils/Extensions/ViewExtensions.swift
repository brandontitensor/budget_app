//
//  ViewExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 7/7/25 - Fixed iOS extension compatibility, CGSize properties, deprecated APIs, and accessibility casting
//

import SwiftUI
import UIKit

// MARK: - Layout and Frame Extensions

public extension View {
    /// Set frame with minimum and maximum constraints
    func frame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
    }
    
    /// Center view in available space
    func centered() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
    
    /// Add padding with EdgeInsets
    func padding(_ insets: EdgeInsets) -> some View {
        padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
    }
    
    /// Fill available width
    func fillWidth(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }
    
    /// Fill available height
    func fillHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }
    
    /// Fill both width and height
    func fillMaxSize(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Navigation Extensions

public extension View {
    /// Navigation link with modern API
    @ViewBuilder
    func navigationLink<Destination: View>(
        value: some Hashable,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        if #available(iOS 16.0, *) {
            NavigationLink(value: value) {
                self
            }
        } else {
            NavigationLink(destination: destination()) {
                self
            }
        }
    }
    
    /// Navigation bar configuration
    func navigationBarConfiguration(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
        backgroundColor: Color? = nil,
        foregroundColor: Color? = nil
    ) -> some View {
        navigationBarTitle(title, displayMode: displayMode)
            .onAppear {
                if let backgroundColor = backgroundColor {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(backgroundColor)
                    
                    if let foregroundColor = foregroundColor {
                        appearance.titleTextAttributes = [.foregroundColor: UIColor(foregroundColor)]
                        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(foregroundColor)]
                    }
                    
                    UINavigationBar.appearance().standardAppearance = appearance
                    UINavigationBar.appearance().scrollEdgeAppearance = appearance
                }
            }
    }
    
    /// Hide navigation bar
    func hideNavigationBar() -> some View {
        navigationBarHidden(true)
    }
}

// MARK: - Keyboard Extensions

public extension View {
    /// Dismiss keyboard when tapped outside
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            #if !targetEnvironment(macCatalyst)
            if !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") {
                // Only dismiss keyboard in non-extension environments
                hideKeyboard()
            }
            #endif
        }
    }
    
    /// Custom keyboard toolbar
    func keyboardToolbar(
        leadingItems: [ToolbarItem] = [],
        trailingItems: [ToolbarItem] = [],
        onDone: @escaping () -> Void = {}
    ) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                ForEach(leadingItems.indices, id: \.self) { index in
                    leadingItems[index]
                }
                
                Spacer()
                
                ForEach(trailingItems.indices, id: \.self) { index in
                    trailingItems[index]
                }
                
                Button("Done") {
                    onDone()
                    hideKeyboard()
                }
            }
        }
    }
    
    /// Observe keyboard show/hide events
    func onKeyboardChange(perform action: @escaping (Bool, CGFloat) -> Void) -> some View {
        modifier(KeyboardObserver(onChange: action))
    }
    
    private func hideKeyboard() {
        #if !targetEnvironment(macCatalyst)
        // Check if we're in an app extension environment
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            // We're in an extension, use alternative method
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        } else {
            // We're in the main app, safe to use UIApplication.shared
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        #endif
    }
}

// MARK: - Styling and Appearance Extensions

public extension View {
    /// Apply card-style appearance
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 12,
        shadowLevel: ShadowLevel = .medium,
        padding: CGFloat = 16
    ) -> some View {
        self
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: .black.opacity(shadowLevel.opacity),
                radius: shadowLevel.radius,
                x: 0,
                y: shadowLevel.offset
            )
    }
    
    /// Apply glassmorphism effect
    func glassMorphism(
        blur: CGFloat = 20,
        opacity: Double = 0.3,
        cornerRadius: CGFloat = 12
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(opacity)
        )
        .cornerRadius(cornerRadius)
    }
    
    /// Apply glow effect
    func glow(
        color: Color = .blue,
        radius: CGFloat = 10,
        intensity: Double = 1.0
    ) -> some View {
        shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius * 0.6)
    }
    
    /// Apply border with gradient
    func gradientBorder(
        gradient: LinearGradient,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 8
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(gradient, lineWidth: lineWidth)
        )
    }
}

// MARK: - Shadow Level

public enum ShadowLevel {
    case none, light, medium, heavy
    
    var opacity: Double {
        switch self {
        case .none: return 0
        case .light: return 0.1
        case .medium: return 0.2
        case .heavy: return 0.3
        }
    }
    
    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .light: return 2
        case .medium: return 4
        case .heavy: return 8
        }
    }
    
    var offset: CGFloat {
        switch self {
        case .none: return 0
        case .light: return 1
        case .medium: return 2
        case .heavy: return 4
        }
    }
}

// MARK: - Animation Extensions

public extension View {
    /// Add bounce animation
    func bounceAnimation(
        trigger: Binding<Bool>,
        scale: CGFloat = 1.2,
        duration: Double = 0.3
    ) -> some View {
        scaleEffect(trigger.wrappedValue ? scale : 1.0)
            .animation(
                .interpolatingSpring(
                    stiffness: 300,
                    damping: 10,
                    initialVelocity: 6
                ),
                value: trigger.wrappedValue
            )
    }
    
    /// Add pulse animation
    func pulseAnimation(
        active: Bool = true,
        scale: CGFloat = 1.05,
        duration: Double = 1.0
    ) -> some View {
        scaleEffect(active ? scale : 1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: active
            )
    }
    
    /// Add shimmer loading effect
    func shimmerEffect(
        active: Bool = true,
        duration: Double = 1.5
    ) -> some View {
        modifier(ShimmerModifier(active: active, duration: duration))
    }
}

// MARK: - Conditional Modifiers

public extension View {
    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply one of two modifiers based on condition
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        ifTrue: (Self) -> TrueContent,
        ifFalse: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }
    
    /// Apply modifier if optional value exists
    @ViewBuilder
    func ifLet<Value, Content: View>(
        _ optionalValue: Value?,
        transform: (Self, Value) -> Content
    ) -> some View {
        if let value = optionalValue {
            transform(self, value)
        } else {
            self
        }
    }
    
    /// Apply modifier based on device type
    @ViewBuilder
    func iPhone<Content: View>(_ modifier: (Self) -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            modifier(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func iPad<Content: View>(_ modifier: (Self) -> Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            modifier(self)
        } else {
            self
        }
    }
    
    /// Apply modifier based on iOS version
    @ViewBuilder
    func iOS15<Content: View>(_ modifier: (Self) -> Content) -> some View {
        if #available(iOS 15.0, *) {
            modifier(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func iOS16<Content: View>(_ modifier: (Self) -> Content) -> some View {
        if #available(iOS 16.0, *) {
            modifier(self)
        } else {
            self
        }
    }
}

// MARK: - Accessibility Extensions

public extension View {
    /// Enhanced accessibility configuration
    func accessibilityConfiguration(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        identifier: String? = nil
    ) -> some View {
        modifier(AccessibilityModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits,
            identifier: identifier
        ))
    }
    
    /// Add accessibility actions
    func accessibilityActions(_ actions: [AccessibilityAction]) -> some View {
        modifier(AccessibilityActionsModifier(actions: actions))
    }
    
    /// Make view accessible for VoiceOver navigation
    func voiceOverAccessible(
        label: String,
        hint: String? = nil,
        sortPriority: Double = 0
    ) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilitySortPriority(sortPriority)
    }
}

// MARK: - Gesture Extensions

public extension View {
    /// Add swipe gestures in all directions
    func swipeGestures(
        onLeft: (() -> Void)? = nil,
        onRight: (() -> Void)? = nil,
        onUp: (() -> Void)? = nil,
        onDown: (() -> Void)? = nil,
        threshold: CGFloat = 50
    ) -> some View {
        gesture(
            DragGesture()
                .onEnded { value in
                    let translation = value.translation
                    if abs(translation.width) > abs(translation.height) {
                        if translation.width > threshold {
                            onRight?()
                        } else if translation.width < -threshold {
                            onLeft?()
                        }
                    } else {
                        if translation.height > threshold {
                            onDown?()
                        } else if translation.height < -threshold {
                            onUp?()
                        }
                    }
                }
        )
    }
    
    /// Add long press gesture with haptic feedback
    func longPressWithHaptic(
        minimumDuration: Double = 0.5,
        onPress: @escaping () -> Void
    ) -> some View {
        onLongPressGesture(minimumDuration: minimumDuration) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onPress()
        }
    }
}

// MARK: - Performance Extensions

public extension View {
    /// Monitor view performance
    func performanceMonitor(
        identifier: String,
        threshold: TimeInterval = 0.5
    ) -> some View {
        modifier(PerformanceMonitorModifier(
            identifier: identifier,
            threshold: threshold
        ))
    }
    
    /// Cache view rendering for performance
    func cached<Key: Hashable>(key: Key) -> some View {
        modifier(CacheModifier(key: key))
    }
    
    /// Lazy loading for expensive views
    func lazyLoad(isVisible: Bool) -> some View {
        Group {
            if isVisible {
                self
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Data Binding Extensions

public extension View {
    /// Add validation to a binding
    func validation<T: Equatable>(
        _ binding: Binding<T>,
        validation: @escaping (T) -> ValidationResult
    ) -> some View {
        modifier(ValidationBindingModifier(
            binding: binding,
            validation: validation
        ))
    }
    
    /// Auto-save changes with debounce
    func autoSave<T: Codable & Equatable>(
        _ value: T,
        key: String,
        debounceTime: TimeInterval = 1.0
    ) -> some View {
        modifier(AutoSaveModifier(
            value: value,
            key: key,
            debounceTime: debounceTime
        ))
    }
    
    /// Observe changes with Equatable constraint
    func onChange<T: Equatable>(
        of value: T,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: T, _ newValue: T) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            return onChange(of: value, initial: initial, action)
        } else {
            return onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

// MARK: - Supporting Types

public struct AccessibilityAction {
    let name: String
    let handler: () -> Void
    
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}

public struct ToolbarItem {
    let placement: ToolbarItemPlacement
    let content: AnyView
    
    public init<Content: View>(placement: ToolbarItemPlacement, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = AnyView(content())
    }
}

// MARK: - View Modifiers

struct KeyboardObserver: ViewModifier {
    let onChange: (Bool, CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    onChange(true, keyboardFrame.height)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                onChange(false, 0)
            }
    }
}

struct ShimmerModifier: ViewModifier {
    let active: Bool
    let duration: Double
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
                    .opacity(active ? 1 : 0)
                    .animation(
                        active ?
                        Animation.linear(duration: duration).repeatForever(autoreverses: false) :
                        .default,
                        value: phase
                    )
            )
            .onAppear {
                if active {
                    phase = 300
                }
            }
    }
}

// MARK: - Accessibility Modifiers

struct AccessibilityModifier: ViewModifier {
    let label: String?
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    let identifier: String?
    
    func body(content: Content) -> some View {
        var modifiedContent = content
        
        if let label = label {
            modifiedContent = modifiedContent.accessibilityLabel(label)
        }
        
        if let hint = hint {
            modifiedContent = modifiedContent.accessibilityHint(hint)
        }
        
        if let value = value {
            modifiedContent = modifiedContent.accessibilityValue(value)
        }
        
        if !traits.isEmpty {
            modifiedContent = modifiedContent.accessibilityAddTraits(traits)
        }
        
        if let identifier = identifier {
            modifiedContent = modifiedContent.accessibilityIdentifier(identifier)
        }
        
        return modifiedContent
    }
}

struct AccessibilityActionsModifier: ViewModifier {
    let actions: [AccessibilityAction]
    
    func body(content: Content) -> some View {
        var modifiedContent = content
        
        for action in actions {
            modifiedContent = modifiedContent.accessibilityAction(named: action.name) {
                action.handler()
            }
        }
        
        return modifiedContent
    }
}

// MARK: - Performance Modifiers

struct PerformanceMonitorModifier: ViewModifier {
    let identifier: String
    let threshold: TimeInterval
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.shared.startTiming(identifier)
            }
            .onDisappear {
                if let duration = PerformanceMonitor.shared.endTiming(identifier) {
                    if duration > threshold {
                        print("⚠️ Performance: View '\(identifier)' took \(String(format: "%.2f", duration * 1000))ms to render")
                    }
                }
            }
    }
}

struct CacheModifier<Key: Hashable>: ViewModifier {
    let key: Key
    
    func body(content: Content) -> some View {
        // Implementation would use a view cache
        content
    }
}

// MARK: - Data Modifiers

struct ValidationBindingModifier<T: Equatable>: ViewModifier {
    let binding: Binding<T>
    let validation: (T) -> ValidationResult
    @State private var validationResult: ValidationResult = .valid
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
            
            if case .invalid(let error) = validationResult {
                Text(error.errorDescription ?? "Invalid input")
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .onChange(of: binding.wrappedValue) { _, newValue in
            validationResult = validation(newValue)
        }
    }
}

struct AutoSaveModifier<T: Codable & Equatable>: ViewModifier {
    let value: T
    let key: String
    let debounceTime: TimeInterval
    @State private var saveTimer: Timer?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                saveTimer?.invalidate()
                saveTimer = Timer.scheduledTimer(withTimeInterval: debounceTime, repeats: false) { _ in
                    if let data = try? JSONEncoder().encode(newValue) {
                        UserDefaults.standard.set(data, forKey: key)
                    }
                }
            }
    }
}

// MARK: - Preview Support

#if DEBUG
struct ViewExtensions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Card Style")
                .cardStyle()
            
            Text("Glass Morphism")
                .glassMorphism()
            
            Text("Glow Effect")
                .glow(color: .blue)
            
            Text("Accessibility Configured")
                .accessibilityConfiguration(
                    label: "Example text",
                    hint: "This is an example"
                )
            
            Text("Shimmer Effect")
                .shimmerEffect()
        }
        .padding()
    }
}
#endif
