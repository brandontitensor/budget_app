//
//  ViewExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 7/5/25 - Enhanced with Swift 6 compliance, comprehensive error handling, and modern SwiftUI features
//

import SwiftUI
import Foundation
import Combine

// MARK: - Supporting Types

public enum LoadingStyle: Sendable {
    case spinner
    case dots
    case pulse
    case shimmer
    case skeleton
}



public enum AsyncData<T>: Sendable where T: Sendable {
    case loading
    case loaded(T)
    case failed(Error)
    case empty
    
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    public var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    public var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

public enum ShadowLevel: Sendable {
    case none, low, medium, high, highest
    
    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 2
        case .medium: return 4
        case .high: return 8
        case .highest: return 16
        }
    }
    
    var opacity: Double {
        switch self {
        case .none: return 0
        case .low: return 0.1
        case .medium: return 0.15
        case .high: return 0.2
        case .highest: return 0.25
        }
    }
    
    var offset: CGFloat {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 4
        case .highest: return 8
        }
    }
}



// MARK: - Loading and State Extensions

public extension View {
    /// Add loading overlay with customizable appearance
    func loadingOverlay(
        _ isLoading: Bool,
        message: String = "Loading...",
        style: LoadingStyle = .spinner
    ) -> some View {
        modifier(LoadingOverlayModifier(
            isLoading: isLoading,
            message: message,
            style: style
        ))
    }
    
    /// Add empty state view
    func emptyState(
        isEmpty: Bool,
        title: String,
        message: String,
        systemImage: String = "tray",
        action: (() -> Void)? = nil,
        actionTitle: String = "Retry"
    ) -> some View {
        modifier(EmptyStateModifier(
            isEmpty: isEmpty,
            title: title,
            message: message,
            systemImage: systemImage,
            action: action,
            actionTitle: actionTitle
        ))
    }
    
    /// Add skeleton loading animation
    func skeletonLoading(
        _ isLoading: Bool,
        lines: Int = 3,
        animated: Bool = true
    ) -> some View {
        modifier(SkeletonLoadingModifier(
            isLoading: isLoading,
            lines: lines,
            animated: animated
        ))
    }
    
    /// Handle async data with loading, error, and empty states
    func asyncData<T: Sendable>(
        _ data: AsyncData<T>,
        onRetry: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (T) -> some View
    ) -> some View {
        AsyncDataView(
            data: data,
            onRetry: onRetry,
            content: content
        )
    }
}

// MARK: - Keyboard and Input Extensions

public extension View {
    /// Dismiss keyboard when tapping outside
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
    
    /// Add keyboard toolbar with done button
    func keyboardToolbar(onDone: @escaping () -> Void = {}) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    onDone()
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }
    
    /// Observe keyboard show/hide events
    func onKeyboardChange(perform action: @escaping (Bool, CGFloat) -> Void) -> some View {
        modifier(KeyboardObserver(onChange: action))
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
    
    /// Apply neumorphism effect
    func neumorphism(
        cornerRadius: CGFloat = 12,
        distance: CGFloat = 6,
        intensity: CGFloat = 0.15
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: .black.opacity(intensity),
                    radius: distance,
                    x: distance,
                    y: distance
                )
                .shadow(
                    color: .white.opacity(intensity * 2),
                    radius: distance,
                    x: -distance,
                    y: -distance
                )
        )
    }
    
    /// Add gradient border
    func gradientBorder(
        colors: [Color],
        width: CGFloat = 2,
        cornerRadius: CGFloat = 12
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: width
                )
        )
    }
    
    /// Add shimmer animation effect
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
    
    /// Add bounce animation
    func bounceAnimation(
        trigger: Binding<Bool>,
        scale: CGFloat = 1.2,
        duration: Double = 0.6
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
                    if abs(value.translation.x) > abs(value.translation.y) {
                        if value.translation.x > threshold {
                            onRight?()
                        } else if value.translation.x < -threshold {
                            onLeft?()
                        }
                    } else {
                        if value.translation.y > threshold {
                            onDown?()
                        } else if value.translation.y < -threshold {
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

// MARK: - Data and State Extensions

public extension View {
    /// Bind to published values with validation
    func bindingWithValidation<T>(
        _ binding: Binding<T>,
        validation: @escaping (T) -> ValidationResult
    ) -> some View {
        modifier(ValidationBindingModifier(
            binding: binding,
            validation: validation
        ))
    }
    
    /// Auto-save state changes
    func autoSave<T: Codable>(
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
    
    /// Track scroll position
    func onScrollPositionChanged(_ action: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollPositionModifier(onChange: action))
    }
}

// MARK: - Navigation Extensions

public extension View {
    /// Navigate with custom transitions
    func customNavigation<Destination: View>(
        to destination: Destination,
        isActive: Binding<Bool>,
        transition: AnyTransition = .slide
    ) -> some View {
        background(
            NavigationLink(
                destination: destination.transition(transition),
                isActive: isActive
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    /// Add navigation bar styling
    func navigationBarStyling(
        backgroundColor: Color = Color(.systemBackground),
        foregroundColor: Color = Color(.label),
        hideBackButton: Bool = false
    ) -> some View {
        modifier(NavigationBarStylingModifier(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            hideBackButton: hideBackButton
        ))
    }
}

// MARK: - Custom Modifiers Implementation

// MARK: - Error Handling Modifiers

struct ComprehensiveErrorHandler: ViewModifier {
    let context: String?
    let showInline: Bool
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @StateObject private var errorHandler = ErrorHandlerProxy()
    
    func body(content: Content) -> some View {
        VStack {
            content
            
            if showInline, let error = errorHandler.currentError {
                InlineErrorView(
                    error: error,
                    onDismiss: {
                        errorHandler.clearError()
                        onDismiss?()
                    },
                    onRetry: onRetry
                )
                .padding(.horizontal)
                .transition(.slide)
            }
        }
        .errorAlert(onRetry: onRetry)
    }
}

struct ErrorToastModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandlerProxy()
    @State private var showingToast = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showingToast, let error = errorHandler.currentError {
                        VStack {
                            ErrorToast(error: error) {
                                showingToast = false
                            }
                            Spacer()
                        }
                        .padding(.top, 60)
                        .animation(.spring(), value: showingToast)
                    }
                }
            )
            .onChange(of: errorHandler.currentError) { _, newError in
                showingToast = newError != nil
            }
    }
}

// MARK: - Loading Modifiers

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    let style: LoadingStyle
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isLoading {
                        LoadingOverlayView(message: message, style: style)
                    }
                }
            )
    }
}

struct EmptyStateModifier: ViewModifier {
    let isEmpty: Bool
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String
    
    func body(content: Content) -> some View {
        Group {
            if isEmpty {
                EmptyStateView(
                    title: title,
                    message: message,
                    systemImage: systemImage,
                    action: action,
                    actionTitle: actionTitle
                )
            } else {
                content
            }
        }
    }
}

struct SkeletonLoadingModifier: ViewModifier {
    let isLoading: Bool
    let lines: Int
    let animated: Bool
    
    func body(content: Content) -> some View {
        Group {
            if isLoading {
                SkeletonView(lines: lines, animated: animated)
            } else {
                content
            }
        }
    }
}

// MARK: - Input and Keyboard Modifiers

struct KeyboardObserver: ViewModifier {
    let onChange: (Bool, CGFloat) -> Void
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height
                onChange(true, keyboardHeight)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
                onChange(false, keyboardHeight)
            }
    }
}

// MARK: - Styling Modifiers

struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.6),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .opacity(active ? 1 : 0)
                    .animation(
                        active ?
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false) :
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
        var view = content
        
        if let label = label {
            view = view.accessibilityLabel(label) as! Content
        }
        
        if let hint = hint {
            view = view.accessibilityHint(hint) as! Content
        }
        
        if let value = value {
            view = view.accessibilityValue(value) as! Content
        }
        
        if !traits.isEmpty {
            view = view.accessibilityAddTraits(traits) as! Content
        }
        
        if let identifier = identifier {
            view = view.accessibilityIdentifier(identifier) as! Content
        }
        
        return view
    }
}

struct AccessibilityActionsModifier: ViewModifier {
    let actions: [AccessibilityAction]
    
    func body(content: Content) -> some View {
        var view = content
        
        for action in actions {
            view = view.accessibilityAction(named: action.name) {
                action.handler()
            } as! Content
        }
        
        return view
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

struct ValidationBindingModifier<T>: ViewModifier {
    let binding: Binding<T>
    let validation: (T) -> ValidationResult
    @State private var validationResult: ValidationResult = .valid
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading) {
            content
            
            if case .invalid(let message) = validationResult {
                Text(message)
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

struct AutoSaveModifier<T: Codable>: ViewModifier {
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

struct ScrollPositionModifier: ViewModifier {
    let onChange: (CGFloat) -> Void
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            scrollOffset = geometry.frame(in: .global).minY
                            onChange(scrollOffset)
                        }
                        .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                            scrollOffset = newValue
                            onChange(scrollOffset)
                        }
                }
            )
    }
}

// MARK: - Navigation Modifiers

struct NavigationBarStylingModifier: ViewModifier {
    let backgroundColor: Color
    let foregroundColor: Color
    let hideBackButton: Bool
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(hideBackButton)
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.backgroundColor = UIColor(backgroundColor)
                appearance.titleTextAttributes = [.foregroundColor: UIColor(foregroundColor)]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(foregroundColor)]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

// MARK: - Support Views

struct LoadingOverlayView: View {
    let message: String
    let style: LoadingStyle
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                loadingIndicator
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .spinner:
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        case .dots:
            DotsLoadingView()
        case .pulse:
            PulseLoadingView()
        case .shimmer:
            ShimmerLoadingView()
        case .skeleton:
            SkeletonView(lines: 1, animated: true)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SkeletonView: View {
    let lines: Int
    let animated: Bool
    @State private var opacity: Double = 0.6
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<lines, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(height: 20)
                    .opacity(opacity)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.3
                }
            }
        }
    }
}

struct DotsLoadingView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .scaleEffect(
                        abs(sin((animationOffset + Double(index) * 0.5) * .pi)) * 0.5 + 0.5
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationOffset = 2 * .pi
            }
        }
    }
}

struct PulseLoadingView: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 40, height: 40)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.3
                }
            }
    }
}

struct ShimmerLoadingView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray4))
            .frame(width: 60, height: 20)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 100
                }
            }
    }
}



struct AsyncDataView<T: Sendable, Content: View>: View {
    let data: AsyncData<T>
    let onRetry: () -> Void
    let content: (T) -> Content
    
    var body: some View {
        switch data {
        case .loading:
            ProgressView("Loading...")
        case .loaded(let value):
            content(value)
        case .failed(let error):
            VStack {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                Button("Retry", action: onRetry)
            }
        case .empty:
            Text("No data available")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Accessibility Support

public struct AccessibilityAction {
    public let name: String
    public let handler: () -> Void
    
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}

// MARK: - Mock Dependencies (for standalone compilation)

@MainActor
private class ErrorHandlerProxy: ObservableObject {
    @Published var currentError: AppError?
    
    func handle(_ error: AppError, context: String) {
        currentError = error
    }
    
    func clearError() {
        currentError = nil
    }
}

// Mock AppError if not available
public enum AppError: LocalizedError, Equatable, Sendable {
    case unknown
    case validation(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .unknown: return "Unknown error"
        case .validation(let message): return message
        }
    }
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case (.validation(let lhs), .validation(let rhs)): return lhs == rhs
        default: return false
        }
    }
}


