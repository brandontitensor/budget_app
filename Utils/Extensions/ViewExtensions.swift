//
//  ViewExtensions.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved validation, and better code organization
//

import SwiftUI
import Foundation

// MARK: - Error Handling Extensions

public extension View {
    /// Add standardized error handling with alert presentation
    func errorAlert(onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(onRetry: onRetry))
    }
    
    /// Add comprehensive error handling with inline and alert options
    func errorHandling(
        context: String? = nil,
        showInline: Bool = false,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ComprehensiveErrorHandler(
            context: context,
            showInline: showInline,
            onRetry: onRetry,
            onDismiss: onDismiss
        ))
    }
    
    /// Handle errors with automatic conversion and reporting
    func handleErrors(context: String? = nil) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .errorOccurred)) { notification in
            if let error = notification.object as? Error {
                ErrorHandler.shared.handle(error, context: context)
            }
        }
    }
    
    /// Add error toast notifications
    func errorToast() -> some View {
        modifier(ErrorToastModifier())
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
    
    /// Add pull-to-refresh functionality
    func refreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            return self.refreshable {
                await action()
            }
        } else {
            return self
        }
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
}

// MARK: - Keyboard and Input Extensions

public extension View {
    /// Dismiss keyboard when tapped outside
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
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                    onDone()
                }
            }
        }
    }
    
    /// Handle keyboard appearance/disappearance
    func onKeyboardChange(perform action: @escaping (Bool, CGFloat) -> Void) -> some View {
        modifier(KeyboardObserver(onChange: action))
    }
}

// MARK: - Navigation and Presentation Extensions

public extension View {
    /// Present sheet with enhanced options
    func presentSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .presentationDragIndicator(.visible)
        }
    }
    
    /// Present full screen cover with enhanced options
    func presentFullScreen<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            content()
        }
    }
    
    /// Add navigation link with enhanced styling
    func navigationLink<Destination: View>(
        to destination: Destination,
        isActive: Binding<Bool>? = nil
    ) -> some View {
        if let isActive = isActive {
            return AnyView(
                NavigationLink(destination: destination, isActive: isActive) {
                    self
                }
            )
        } else {
            return AnyView(
                NavigationLink(destination: destination) {
                    self
                }
            )
        }
    }
    
    /// Add back button with custom action
    func backButton(action: @escaping () -> Void) -> some View {
        navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
    }
}

// MARK: - Styling and Appearance Extensions

public extension View {
    /// Apply card-like styling
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = AppConstants.UI.cornerRadius,
        shadowRadius: CGFloat = AppConstants.UI.defaultShadowRadius,
        shadowOpacity: Float = AppConstants.UI.defaultShadowOpacity,
        padding: CGFloat = AppConstants.UI.defaultPadding
    ) -> some View {
        self
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: .black.opacity(Double(shadowOpacity)),
                radius: shadowRadius,
                x: 0,
                y: 2
            )
    }
    
    /// Apply glassmorphism effect
    func glassMorphism(
        blur: CGFloat = 20,
        opacity: Double = 0.3,
        cornerRadius: CGFloat = AppConstants.UI.cornerRadius
    ) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white.opacity(opacity))
            )
    }
    
    /// Apply neumorphism effect
    func neumorphism(
        cornerRadius: CGFloat = AppConstants.UI.cornerRadius,
        distance: CGFloat = 6,
        intensity: CGFloat = 0.15
    ) -> some View {
        self
            .background(
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
                        x: -distance / 2,
                        y: -distance / 2
                    )
            )
    }
    
    /// Apply custom border with gradient
    func gradientBorder(
        colors: [Color],
        width: CGFloat = 2,
        cornerRadius: CGFloat = AppConstants.UI.cornerRadius
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
    
    /// Apply shimmer effect for loading states
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: active))
    }
    
    /// Apply bounce animation
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
    
    /// Apply pulse animation
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
    func iPhone(_ modifier: (Self) -> some View) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return AnyView(modifier(self))
        }
        return AnyView(self)
    }
    
    func iPad(_ modifier: (Self) -> some View) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return AnyView(modifier(self))
        }
        return AnyView(self)
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
        var view = self
        
        if let label = label {
            view = view.accessibilityLabel(label) as! Self
        }
        
        if let hint = hint {
            view = view.accessibilityHint(hint) as! Self
        }
        
        if let value = value {
            view = view.accessibilityValue(value) as! Self
        }
        
        if !traits.isEmpty {
            view = view.accessibilityAddTraits(traits) as! Self
        }
        
        if let identifier = identifier {
            view = view.accessibilityIdentifier(identifier) as! Self
        }
        
        return view
    }
    
    /// Add semantic accessibility information
    func semanticAccessibility(
        role: AccessibilityRole,
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(role == .button ? .isButton : [])
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .if(!isEnabled) { view in
                view.accessibilityAddTraits(.isNotEnabled)
            }
    }
    
    /// Make view accessible for VoiceOver navigation
    func voiceOverAccessible(
        label: String,
        hint: String? = nil,
        sortPriority: Double = 0
    ) -> some View {
        self
            .accessibilityLabel(label)
            .if(hint != nil) { view in
                view.accessibilityHint(hint!)
            }
            .accessibilitySortPriority(sortPriority)
    }
    
    /// Add custom accessibility actions
    func accessibilityActions(_ actions: [AccessibilityAction]) -> some View {
        var view = self
        for action in actions {
            view = view.accessibilityAction(named: action.name, action.handler) as! Self
        }
        return view
    }
}

// MARK: - Performance and Optimization Extensions

public extension View {
    /// Add performance monitoring
    func performanceMonitored(
        identifier: String,
        threshold: TimeInterval = 0.1
    ) -> some View {
        modifier(PerformanceMonitorModifier(
            identifier: identifier,
            threshold: threshold
        ))
    }
    
    /// Optimize for large lists
    func listOptimized() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(PlainButtonStyle())
    }
    
    /// Add view caching for expensive computations
    func cached<Key: Hashable>(
        key: Key,
        computation: @escaping () -> some View
    ) -> some View {
        CachedView(key: key, content: computation)
    }
    
    /// Lazy loading for expensive views
    func lazyLoaded(
        threshold: CGFloat = 100,
        placeholder: AnyView = AnyView(ProgressView())
    ) -> some View {
        LazyLoadingView(
            content: AnyView(self),
            threshold: threshold,
            placeholder: placeholder
        )
    }
}

// MARK: - Animation Extensions

public extension View {
    /// Spring animation with preset configurations
    func springAnimation(
        preset: SpringPreset = .default,
        value: some Equatable
    ) -> some View {
        animation(preset.animation, value: value)
    }
    
    /// Staggered animation for lists
    func staggeredAnimation(
        delay: Double,
        duration: Double = 0.5
    ) -> some View {
        modifier(StaggeredAnimationModifier(
            delay: delay,
            duration: duration
        ))
    }
    
    /// Parallax scroll effect
    func parallaxScroll(
        offsetMultiplier: CGFloat = 0.5
    ) -> some View {
        modifier(ParallaxScrollModifier(offsetMultiplier: offsetMultiplier))
    }
    
    /// Custom transition effects
    func customTransition(
        _ transition: AnyTransition,
        isVisible: Bool
    ) -> some View {
        Group {
            if isVisible {
                self.transition(transition)
            }
        }
    }
}

// MARK: - Data and State Extensions

public extension View {
    /// Handle async data loading with states
    func asyncData<T>(
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
    
    /// Bind to published values with error handling
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
}

// MARK: - Theme and Appearance Extensions

public extension View {
    /// Apply current theme styling
    func themedStyle() -> some View {
        environmentObject(ThemeManager.shared)
    }
    
    /// Apply adaptive color scheme
    func adaptiveColors(
        light: Color,
        dark: Color
    ) -> some View {
        foregroundColor(Color.dynamicColor(light: light, dark: dark))
    }
    
    /// Apply dynamic type scaling
    func dynamicTypeSize(
        min: DynamicTypeSize = .small,
        max: DynamicTypeSize = .accessibility5
    ) -> some View {
        dynamicTypeSize(min...max)
    }
    
    /// Material design elevation
    func elevation(_ level: ElevationLevel) -> some View {
        shadow(
            color: .black.opacity(level.opacity),
            radius: level.radius,
            x: 0,
            y: level.offset
        )
    }
}

// MARK: - Gesture Extensions

public extension View {
    /// Enhanced tap gesture with haptic feedback
    func tapWithFeedback(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        action: @escaping () -> Void
    ) -> some View {
        onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
            action()
        }
    }
    
    /// Long press with customizable duration and feedback
    func longPressWithFeedback(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        action: @escaping () -> Void
    ) -> some View {
        onLongPressGesture(
            minimumDuration: minimumDuration,
            maximumDistance: maximumDistance
        ) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }
    }
    
    /// Swipe gestures with feedback
    func swipeGestures(
        onLeft: (() -> Void)? = nil,
        onRight: (() -> Void)? = nil,
        onUp: (() -> Void)? = nil,
        onDown: (() -> Void)? = nil
    ) -> some View {
        simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    
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
    
    /// Pull to refresh gesture
    func pullToRefresh(
        coordinateSpace: CoordinateSpace = .named("pullToRefresh"),
        onRefresh: @escaping () async -> Void
    ) -> some View {
        modifier(PullToRefreshModifier(
            coordinateSpace: coordinateSpace,
            onRefresh: onRefresh
        ))
    }
}

// MARK: - Custom Modifiers

// MARK: - Error Handling Modifiers

struct ComprehensiveErrorHandler: ViewModifier {
    let context: String?
    let showInline: Bool
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @ObservedObject private var errorHandler = ErrorHandler.shared
    
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
    @ObservedObject private var errorHandler = ErrorHandler.shared
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
                
                if newError != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingToast = false
                    }
                }
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
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                switch style {
                                case .spinner:
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                case .dots:
                                    DotsLoadingView()
                                case .pulse:
                                    PulseLoadingView()
                                }
                                
                                Text(message)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .transition(.opacity)
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
                VStack(spacing: 24) {
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<lines, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 16)
                            .frame(maxWidth: index == lines - 1 ? .infinity * 0.7 : .infinity)
                    }
                }
                .if(animated) { view in
                    view.shimmer()
                }
            } else {
                content
            }
        }
    }
}

// MARK: - Animation Modifiers

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
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
                            .rotationEffect(.degrees(45))
                            .offset(x: phase)
                            .clipped()
                    }
                }
            )
            .onAppear {
                if isActive {
                    withAnimation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = 400
                    }
                }
            }
    }
}

struct StaggeredAnimationModifier: ViewModifier {
    let delay: Double
    let duration: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: duration)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct ParallaxScrollModifier: ViewModifier {
    let offsetMultiplier: CGFloat
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: scrollOffset * offsetMultiplier)
            .onReceive(NotificationCenter.default.publisher(for: .scrollViewDidScroll)) { notification in
                if let scrollView = notification.object as? UIScrollView {
                    scrollOffset = scrollView.contentOffset.y
                }
            }
    }
}

// MARK: - Performance Modifiers

struct PerformanceMonitorModifier: ViewModifier {
    let identifier: String
    let threshold: TimeInterval
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.startTiming(identifier)
            }
            .onDisappear {
                if let duration = PerformanceMonitor.endTiming(identifier) {
                    if duration > threshold {
                        print("⚠️ Performance: View '\(identifier)' took \(String(format: "%.2f", duration * 1000))ms to render")
                    }
                }
            }
    }
}

// MARK: - Keyboard Modifier

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

// MARK: - Data Handling Modifiers

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
                    save(newValue)
                }
            }
    }
    
    private func save(_ value: T) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to auto-save: \(error)")
        }
    }
}

struct PullToRefreshModifier: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let onRefresh: () async -> Void
    @State private var isRefreshing = false
    
    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: coordinateSpace)
            .refreshable {
                await onRefresh()
            }
    }
}

// MARK: - Supporting Types and Views

public enum LoadingStyle {
    case spinner
    case dots
    case pulse
}

public enum SpringPreset {
    case `default`
    case bouncy
    case smooth
    case snappy
    
    var animation: Animation {
        switch self {
        case .default:
            return .spring()
        case .bouncy:
            return .spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)
        case .smooth:
            return .spring(response: 0.9, dampingFraction: 1.0, blendDuration: 0)
        case .snappy:
            return .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
        }
    }
}

public enum ElevationLevel {
    case none
    case low
    case medium
    case high
    case highest
    
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

public enum ValidationResult {
    case valid
    case invalid(String)
}

public enum AsyncData<T> {
    case loading
    case loaded(T)
    case failed(Error)
    case empty
}

public struct AccessibilityAction {
    let name: String
    let handler: () -> Void
    
    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
    }
}

// MARK: - Custom Views for Modifiers

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

struct CachedView<Key: Hashable, Content: View>: View {
    let key: Key
    let content: () -> Content
    
    private static var cache: [AnyHashable: AnyView] {
        get { _cache }
        set { _cache = newValue }
    }
    private static var _cache: [AnyHashable: AnyView] = [:]
    
    var body: some View {
        if let cachedView = Self.cache[AnyHashable(key)] {
            cachedView
        } else {
            let view = AnyView(content())
            let _ = { Self.cache[AnyHashable(key)] = view }()
            view
        }
    }
}

struct LazyLoadingView: View {
    let content: AnyView
    let threshold: CGFloat
    let placeholder: AnyView
    @State private var isVisible = false
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                content
            } else {
                placeholder
                    .onAppear {
                        // Check if view is within threshold distance of viewport
                        if geometry.frame(in: .global).minY < UIScreen.main.bounds.height + threshold {
                            isVisible = true
                        }
                    }
            }
        }
    }
}

struct AsyncDataView<T, Content: View>: View {
    let data: AsyncData<T>
    let onRetry: () -> Void
    let content: (T) -> Content
    
    var body: some View {
        switch data {
        case .loading:
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loaded(let value):
            content(value)
            
        case .failed(let error):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Failed to load data")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No data available")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let scrollViewDidScroll = Notification.Name("scrollViewDidScroll")
}

// MARK: - Testing Support

#if DEBUG
public extension View {
    /// Add debug border for layout debugging
    func debugBorder(_ color: Color = .red, width: CGFloat = 1) -> some View {
        overlay(
            Rectangle()
                .stroke(color, lineWidth: width)
        )
    }
    
    /// Print view hierarchy for debugging
    func debugPrint(_ message: String = "") -> some View {
        onAppear {
            print("🐛 Debug: \(message) - View appeared")
        }
        .onDisappear {
            print("🐛 Debug: \(message) - View disappeared")
        }
    }
    
    /// Measure view size for debugging
    func debugSize(label: String = "View") -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        print("📐 \(label) size: \(geometry.size)")
                    }
            }
        )
    }
    
    /// Test accessibility
    func debugAccessibility() -> some View {
        onAppear {
            // Check if view has accessibility information
            let mirror = Mirror(reflecting: self)
            print("♿ Accessibility debug for \(type(of: self))")
            // Additional accessibility debugging could be added here
        }
    }
}
#endif
