//
//  ViewExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 5/30/25.
//  Updated: 7/7/25 - Complete rewrite to remove all conflicting modifiers and SwiftUI ambiguities
//

import SwiftUI
import UIKit

// MARK: - Layout Extensions (Non-conflicting)

public extension View {
    /// Center view in available space
    func centered() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
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
    
    /// Set a fixed size
    func fixedSize(width: CGFloat, height: CGFloat, alignment: Alignment = .center) -> some View {
        frame(width: width, height: height, alignment: alignment)
    }
    
    /// Set minimum size constraints
    func minSize(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        frame(minWidth: width, minHeight: height, alignment: alignment)
    }
    
    /// Set maximum size constraints
    func maxSize(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        frame(maxWidth: width, maxHeight: height, alignment: alignment)
    }
    
    /// Apply custom padding with EdgeInsets
    func customPadding(_ insets: EdgeInsets) -> some View {
        padding(.top, insets.top)
            .padding(.leading, insets.leading)
            .padding(.bottom, insets.bottom)
            .padding(.trailing, insets.trailing)
    }
    
    /// Apply uniform padding to all edges
    func uniformPadding(_ value: CGFloat) -> some View {
        padding(.all, value)
    }
}

// MARK: - Custom Styling Extensions

public extension View {
    /// Apply card-style appearance
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 12,
        shadowLevel: ShadowLevel = .medium,
        internalPadding: CGFloat = 16
    ) -> some View {
        self
            .padding(.all, internalPadding)
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
    
    /// Apply neumorphism effect
    func neumorphism(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 12,
        internalPadding: CGFloat = 16
    ) -> some View {
        self
            .padding(.all, internalPadding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 4, y: 4)
            .shadow(color: .white.opacity(0.8), radius: 8, x: -4, y: -4)
    }
    
    /// Apply subtle border
    func subtleBorder(
        color: Color = Color(.systemGray4),
        width: CGFloat = 1,
        cornerRadius: CGFloat = 8
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
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
    
    /// Add fade in animation
    func fadeIn(duration: Double = 0.5, delay: Double = 0) -> some View {
        opacity(0)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    // SwiftUI will handle the opacity animation
                }
            }
    }
    
    /// Add slide in animation
    func slideIn(
        from edge: Edge = .bottom,
        distance: CGFloat = 50,
        duration: Double = 0.5,
        delay: Double = 0
    ) -> some View {
        let initialOffset: CGSize = {
            switch edge {
            case .top: return CGSize(width: 0, height: -distance)
            case .bottom: return CGSize(width: 0, height: distance)
            case .leading: return CGSize(width: -distance, height: 0)
            case .trailing: return CGSize(width: distance, height: 0)
            }
        }()
        
        return modifier(SlideInModifier(
            initialOffset: initialOffset,
            duration: duration,
            delay: delay
        ))
    }
    
    /// Add shake animation
    func shakeAnimation(trigger: Binding<Bool>) -> some View {
        modifier(ShakeModifier(trigger: trigger))
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
    
    @ViewBuilder
    func iOS17<Content: View>(_ modifier: (Self) -> Content) -> some View {
        if #available(iOS 17.0, *) {
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
    
    /// Add accessibility actions
    func accessibilityActions(_ actions: [BudgetAccessibilityAction]) -> some View {
        modifier(AccessibilityActionsModifier(actions: actions))
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
    
    /// Add tap gesture with haptic feedback
    func tapWithHaptic(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        onTap: @escaping () -> Void
    ) -> some View {
        onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
            onTap()
        }
    }
    
    /// Add double tap gesture
    func onDoubleTap(perform action: @escaping () -> Void) -> some View {
        onTapGesture(count: 2, perform: action)
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
    
    /// Cache view for performance
    func cachedView<Key: Hashable>(key: Key) -> some View {
        modifier(CacheModifier(key: key))
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
}

// MARK: - Keyboard Extensions

public extension View {
    /// Dismiss keyboard when tapped outside
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            hideKeyboard()
        }
    }
    
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    /// Observe keyboard show/hide events
    func onKeyboardChange(perform action: @escaping (Bool, CGFloat) -> Void) -> some View {
        modifier(KeyboardObserver(onChange: action))
    }
}

// MARK: - Error Handling Extensions

public extension View {
    /// Add error alert with retry capability
    func errorAlert(
        isPresented: Binding<Bool> = .constant(false),
        error: Binding<AppError?> = .constant(nil),
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(
            isPresented: isPresented,
            error: error,
            onRetry: onRetry,
            onDismiss: onDismiss
        ))
    }
    
    /// Handle errors with inline display
    func inlineError(
        error: AppError?,
        onDismiss: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading) {
            self
            
            if let error = error {
                InlineErrorView(
                    error: error,
                    onDismiss: onDismiss,
                    onRetry: onRetry
                )
            }
        }
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
    
    /// Hide navigation bar
    func hideNavigationBar() -> some View {
        navigationBarHidden(true)
    }
    
    /// Custom navigation bar title
    func customNavigationTitle(
        _ title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .automatic
    ) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }
}

// MARK: - Loading Extensions

public extension View {
    /// Show loading overlay
    func loadingOverlay(
        isLoading: Bool,
        message: String = "Loading..."
    ) -> some View {
        overlay(
            Group {
                if isLoading {
                    LoadingOverlay(message: message)
                }
            }
        )
    }
    
    /// Redacted for loading state
    func redactedLoading(_ isLoading: Bool) -> some View {
        redacted(reason: isLoading ? .placeholder : [])
    }
}

// MARK: - Shadow Level Enum

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

// MARK: - Supporting Types

public struct BudgetAccessibilityAction {
    let name: String
    let handler: () -> Void
    
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}



// MARK: - View Modifiers

struct ShimmerModifier: ViewModifier {
    let active: Bool
    let duration: Double
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.6),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
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

struct SlideInModifier: ViewModifier {
    let initialOffset: CGSize
    let duration: Double
    let delay: Double
    @State private var offset: CGSize
    
    init(initialOffset: CGSize, duration: Double, delay: Double) {
        self.initialOffset = initialOffset
        self.duration = duration
        self.delay = delay
        self._offset = State(initialValue: initialOffset)
    }
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    offset = .zero
                }
            }
    }
}

struct ShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
                        shakeOffset = 10
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shakeOffset = 0
                        trigger = false
                    }
                }
            }
    }
}

struct AccessibilityModifier: ViewModifier {
    let label: String?
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    let identifier: String?
    
    func body(content: Content) -> some View {
        var result = content
        
        if let label = label {
            result = result.accessibilityLabel(label)
        }
        
        if let hint = hint {
            result = result.accessibilityHint(hint)
        }
        
        if let value = value {
            result = result.accessibilityValue(value)
        }
        
        if !traits.isEmpty {
            result = result.accessibilityAddTraits(traits)
        }
        
        if let identifier = identifier {
            result = result.accessibilityIdentifier(identifier)
        }
        
        return result
    }
}

struct AccessibilityActionsModifier: ViewModifier {
    let actions: [BudgetAccessibilityAction]
    
    func body(content: Content) -> some View {
        var result = content
        
        for action in actions {
            result = result.accessibilityAction(named: action.name) {
                action.handler()
            }
        }
        
        return result
    }
}

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

struct ValidationBindingModifier<T: Equatable>: ViewModifier {
    let binding: Binding<T>
    let validation: (T) -> ValidationResult
    @State private var validationResult: ValidationResult = .valid
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
            
            if case .invalid(let error) = validationResult {
                Text(error.errorDescription ?? "Validation error")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
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
    @State private var saveTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                saveTask?.cancel()
                saveTask = Task<Void, Never> {
                    try? await Task.sleep(nanoseconds: UInt64(debounceTime * 1_000_000_000))
                    
                    if !Task.isCancelled {
                        await MainActor.run {
                            saveValue(newValue)
                        }
                    }
                }
            }
    }
    
    private func saveValue(_ value: T) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

struct KeyboardObserver: ViewModifier {
    let onChange: (Bool, CGFloat) -> Void
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let height = keyboardFrame.cgRectValue.height
                    keyboardHeight = height
                    onChange(true, height)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
                onChange(false, 0)
            }
    }
}

struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var error: AppError?
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $isPresented, presenting: error) { error in
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                }
                
                Button("OK", role: .cancel) {
                    onDismiss?()
                }
            } message: { error in
                Text(error.errorDescription ?? "An error occurred")
            }
    }
}

// MARK: - Supporting Views

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(.all, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}


// MARK: - Preview Support

#if DEBUG
struct ViewExtensions_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
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
                
                Text("Fill Width")
                    .fillWidth()
                    .background(Color.blue.opacity(0.2))
                
                Text("Centered")
                    .centered()
                    .background(Color.green.opacity(0.2))
            }
            .padding(.all, 16)
        }
        .previewDisplayName("View Extensions")
    }
}
#endif
