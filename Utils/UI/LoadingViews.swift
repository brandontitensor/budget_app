//
//  LoadingViews.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 6/4/25.
//



import SwiftUI

// MARK: - Loading State Views

/// Comprehensive loading state components for the app
public enum LoadingViews {
    // This enum serves as a namespace for loading views
}

// MARK: - Basic Loading View

/// Simple loading indicator with text
public struct BasicLoadingView: View {
        let message: String
        let showProgress: Bool
        @State private var rotation: Double = 0
        
        public init(message: String = "Loading...", showProgress: Bool = false) {
            self.message = message
            self.showProgress = showProgress
        }
        
        public var body: some View {
            VStack(spacing: 16) {
                if showProgress {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.title)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
}

// MARK: - Full Screen Loading

/// Full screen loading overlay
public struct FullScreenLoadingView: View {
        let title: String
        let subtitle: String?
        let progress: Double?
        let showCancel: Bool
        let onCancel: (() -> Void)?
        
        @State private var animationOffset: CGFloat = 0
        @State private var pulseOpacity: Double = 0.3
        
        public init(
            title: String = "Loading",
            subtitle: String? = nil,
            progress: Double? = nil,
            showCancel: Bool = false,
            onCancel: (() -> Void)? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.progress = progress
            self.showCancel = showCancel
            self.onCancel = onCancel
        }
        
        public var body: some View {
            ZStack {
                // Background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                // Loading content
                VStack(spacing: 24) {
                    loadingIndicator
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    if let progress = progress {
                        progressSection(progress)
                    }
                    
                    if showCancel, let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .padding()
            }
        }
        
        private var loadingIndicator: some View {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(.blue.opacity(pulseOpacity))
                    .frame(width: 80, height: 80)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseOpacity = 0.8
                        }
                    }
                
                // Spinning indicator
                if progress == nil {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
                } else {
                    Image(systemName: "checkmark")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
        }
        
        private func progressSection(_ progress: Double) -> some View {
            VStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 8)
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
}

// MARK: - Skeleton Loading

/// Skeleton loading placeholder
public struct SkeletonView: View {
        let height: CGFloat
        let cornerRadius: CGFloat
        @State private var shimmerOffset: CGFloat = -200
        
        public init(height: CGFloat = 20, cornerRadius: CGFloat = 4) {
            self.height = height
            self.cornerRadius = cornerRadius
        }
        
        public var body: some View {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: height)
                .cornerRadius(cornerRadius)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.6),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: shimmerOffset)
                )
                .clipped()
                .onAppear {
                    shimmerOffset = 200
                }
        }
}

// MARK: - List Loading

/// Loading placeholder for list items
public struct ListLoadingView: View {
        let itemCount: Int
        let itemHeight: CGFloat
        
        public init(itemCount: Int = 5, itemHeight: CGFloat = 60) {
            self.itemCount = itemCount
            self.itemHeight = itemHeight
        }
        
        public var body: some View {
            LazyVStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { index in
                    ListItemSkeleton(height: itemHeight)
                        .animation(.easeInOut.delay(Double(index) * 0.1), value: index)
                }
            }
            .padding()
        }
}

/// Individual list item skeleton
public struct ListItemSkeleton: View {
        let height: CGFloat
        
        public init(height: CGFloat = 60) {
            self.height = height
        }
        
        public var body: some View {
            HStack(spacing: 12) {
                // Leading icon placeholder
                SkeletonView(height: 40, cornerRadius: 20)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title placeholder
                    SkeletonView(height: 16, cornerRadius: 8)
                        .frame(maxWidth: .infinity)
                    
                    // Subtitle placeholder
                    SkeletonView(height: 12, cornerRadius: 6)
                        .frame(width: 120)
                }
                
                Spacer()
                
                // Trailing content placeholder
                SkeletonView(height: 20, cornerRadius: 10)
                    .frame(width: 60)
            }
            .frame(height: height)
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
        }
}

// MARK: - Card Loading

/// Loading placeholder for card views
public struct CardLoadingView: View {
        let showHeader: Bool
        let showFooter: Bool
        
        public init(showHeader: Bool = true, showFooter: Bool = true) {
            self.showHeader = showHeader
            self.showFooter = showFooter
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if showHeader {
                    // Header section
                    HStack {
                        SkeletonView(height: 24, cornerRadius: 12)
                            .frame(width: 120)
                        
                        Spacer()
                        
                        SkeletonView(height: 20, cornerRadius: 10)
                            .frame(width: 80)
                    }
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonView(height: 20, cornerRadius: 10)
                        .frame(maxWidth: .infinity)
                    
                    SkeletonView(height: 16, cornerRadius: 8)
                        .frame(width: 200)
                    
                    SkeletonView(height: 16, cornerRadius: 8)
                        .frame(width: 150)
                }
                
                if showFooter {
                    // Footer section
                    HStack {
                        SkeletonView(height: 14, cornerRadius: 7)
                            .frame(width: 100)
                        
                        Spacer()
                        
                        SkeletonView(height: 32, cornerRadius: 16)
                            .frame(width: 80)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
}

// MARK: - Chart Loading

/// Loading placeholder for charts
public struct ChartLoadingView: View {
        let chartType: ChartType
        @State private var animationPhase: CGFloat = 0
        
        public enum ChartType {
            case line
            case bar
            case pie
        }
        
        public init(chartType: ChartType = .line) {
            self.chartType = chartType
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Chart title placeholder
                HStack {
                    SkeletonView(height: 20, cornerRadius: 10)
                        .frame(width: 150)
                    
                    Spacer()
                    
                    SkeletonView(height: 16, cornerRadius: 8)
                        .frame(width: 80)
                }
                
                // Chart area
                chartPlaceholder
                
                // Legend placeholder
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                            
                            SkeletonView(height: 12, cornerRadius: 6)
                                .frame(width: 60)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        
        @ViewBuilder
        private var chartPlaceholder: some View {
            switch chartType {
            case .line:
                lineChartPlaceholder
            case .bar:
                barChartPlaceholder
            case .pie:
                pieChartPlaceholder
            }
        }
        
        private var lineChartPlaceholder: some View {
            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        Spacer()
                    }
                }
                
                // Animated line
                Path { path in
                    let width: CGFloat = 280
                    let height: CGFloat = 150
                    
                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                    path.addLine(to: CGPoint(x: width * 0.3, y: height * 0.4))
                    path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.8))
                    path.addLine(to: CGPoint(x: width, y: height * 0.3))
                }
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                .frame(width: 280, height: 150)
            }
        }
        
        private var barChartPlaceholder: some View {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 30, height: CGFloat.random(in: 30...120))
                }
            }
            .frame(height: 150)
        }
        
        private var pieChartPlaceholder: some View {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
            }
        }
}
