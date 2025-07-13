//
//  SpendingPieChart.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//

import SwiftUI
import Charts

/// A comprehensive pie chart component for displaying spending data with enhanced interactivity and error handling
struct SpendingPieChart: View {
    // MARK: - Properties
    let spendingData: [SpendingData]
    @Binding var selectedData: SpendingData?
    
    // MARK: - Environment
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var errorHandler: ErrorHandler
    @EnvironmentObject private var settingsManager: SettingsManager
    
    // MARK: - State Management
    @State private var animationProgress: Double = 0
    @State private var hoveredSlice: SpendingData?
    @State private var showingDetailView = false
    @State private var chartError: AppError?
    @State private var isLoading = false
    @State private var showingLegend = true
    @State private var chartSize: CGSize = .zero
    @State private var interactionState: InteractionState = .idle
    @State private var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Configuration
    private let innerRadiusRatio: CGFloat = 0.618 // Golden ratio for aesthetics
    private let angularInset: CGFloat = 1.5
    private let cornerRadius: CGFloat = 5
    private let animationDuration: Double = 1.2
    private let hoverAnimationDuration: Double = 0.3
    private let maxDisplayedCategories = 8
    private let minimumSlicePercentage: Double = 1.0 // Minimum percentage to show as separate slice
    
    // MARK: - Supporting Types
    private enum InteractionState {
        case idle
        case hovering(SpendingData)
        case selected(SpendingData)
        case dragging
        
        var isInteractive: Bool {
            switch self {
            case .idle: return false
            default: return true
            }
        }
    }
    
    private struct PerformanceMetrics {
        var renderTime: TimeInterval = 0
        var interactionLatency: TimeInterval = 0
        var dataProcessingTime: TimeInterval = 0
        var lastUpdate: Date = Date()
        
        mutating func recordRenderTime(_ time: TimeInterval) {
            renderTime = time
            lastUpdate = Date()
        }
        
        mutating func recordInteractionLatency(_ time: TimeInterval) {
            interactionLatency = time
            lastUpdate = Date()
        }
        
        mutating func recordDataProcessingTime(_ time: TimeInterval) {
            dataProcessingTime = time
            lastUpdate = Date()
        }
    }
    
    private struct ChartMetrics {
        let totalAmount: Double
        let averageAmount: Double
        let categoryCount: Int
        let largestCategory: SpendingData?
        let smallestCategory: SpendingData?
        let diversityIndex: Double // Shannon diversity index
        
        init(data: [SpendingData]) {
            self.totalAmount = data.reduce(0) { $0 + $1.amount }
            self.averageAmount = data.isEmpty ? 0 : totalAmount / Double(data.count)
            self.categoryCount = data.count
            self.largestCategory = data.max(by: { $0.amount < $1.amount })
            self.smallestCategory = data.min(by: { $0.amount < $1.amount })
            
            // Calculate Shannon diversity index
            if data.isEmpty || totalAmount == 0 {
                self.diversityIndex = 0
            } else {
                let entropy = data.reduce(0.0) { result, item in
                    let proportion = item.amount / totalAmount
                    return proportion > 0 ? result - (proportion * log2(proportion)) : result
                }
                self.diversityIndex = entropy
            }
        }
        
        var isBalanced: Bool {
            diversityIndex > log2(Double(max(categoryCount, 1))) * 0.7
        }
    }
    
    struct SliceInfo: Identifiable {
        let id = UUID()
        let data: SpendingData
        let startAngle: Angle
        let endAngle: Angle
        let midAngle: Angle
        let isSelected: Bool
        let isHovered: Bool
        let scale: CGFloat
        let animationDelay: Double
        
        init(
            data: SpendingData,
            startAngle: Angle,
            endAngle: Angle,
            isSelected: Bool,
            isHovered: Bool,
            animationDelay: Double = 0
        ) {
            self.data = data
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.midAngle = Angle(degrees: (startAngle.degrees + endAngle.degrees) / 2)
            self.isSelected = isSelected
            self.isHovered = isHovered
            self.scale = isSelected ? 1.05 : (isHovered ? 1.02 : 1.0)
            self.animationDelay = animationDelay
        }
        
        var labelPosition: CGPoint {
            let radius: CGFloat = 100 // Base radius for label positioning
            let labelRadius = radius * 0.85
            let angle = midAngle.radians
            return CGPoint(
                x: cos(angle) * labelRadius,
                y: sin(angle) * labelRadius
            )
        }
    }
    
    // MARK: - Computed Properties
    private var processedData: [SpendingData] {
        let startTime = Date()
        defer {
            performanceMetrics.recordDataProcessingTime(Date().timeIntervalSince(startTime))
        }
        
        guard !spendingData.isEmpty else { return [] }
        
        // Sort by amount descending
        let sortedData = spendingData.sorted { $0.amount > $1.amount }
        
        // Group small categories into "Others" if needed
        if sortedData.count <= maxDisplayedCategories {
            return sortedData
        }
        
        let mainCategories = Array(sortedData.prefix(maxDisplayedCategories - 1))
        let otherCategories = Array(sortedData.suffix(from: maxDisplayedCategories - 1))
        
        let otherAmount = otherCategories.reduce(0) { $0 + $1.amount }
        let otherPercentage = otherCategories.reduce(0) { $0 + $1.percentage }
        
        guard otherAmount > 0 else { return mainCategories }
        
        do {
            let othersData = try SpendingData(
                category: "Others (\(otherCategories.count))",
                amount: otherAmount,
                percentage: otherPercentage,
                color: themeManager.semanticColors.textTertiary
            )
            return mainCategories + [othersData]
        } catch {
            chartError = AppError.from(error)
            return mainCategories
        }
    }
    
    private var chartMetrics: ChartMetrics {
        ChartMetrics(data: processedData)
    }
    
    private var totalSpending: Double {
        chartMetrics.totalAmount
    }
    
    private var isEmpty: Bool {
        processedData.isEmpty || totalSpending == 0
    }
    
    private var sliceInfos: [SliceInfo] {
        guard !isEmpty else { return [] }
        
        var currentAngle: Double = 0
        return processedData.enumerated().map { index, data in
            let startAngle = Angle(degrees: currentAngle)
            let sliceAngle = (data.amount / totalSpending) * 360
            let endAngle = Angle(degrees: currentAngle + sliceAngle)
            currentAngle += sliceAngle
            
            return SliceInfo(
                data: data,
                startAngle: startAngle,
                endAngle: endAngle,
                isSelected: selectedData?.id == data.id,
                isHovered: hoveredSlice?.id == data.id,
                animationDelay: Double(index) * 0.1
            )
        }
    }
    
    private var spendingInsights: [SpendingInsight] {
        getSpendingInsights()
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader
            
            if isLoading {
                loadingView
            } else if let error = chartError {
                errorView(error)
            } else if isEmpty {
                emptyStateView
            } else {
                chartContent
            }
            
            if !isEmpty && showingLegend {
                legendSection
            }
            
            if !spendingInsights.isEmpty && !isEmpty {
                insightsSection
            }
        }
        .onAppear {
            setupChart()
        }
        .onChange(of: spendingData) { oldData, newData in
            handleDataChange(from: oldData, to: newData)
        }
        .sheet(isPresented: $showingDetailView) {
            if let selected = selectedData {
                SpendingDetailSheet(
                    data: selected,
                    totalSpending: totalSpending,
                    insights: getInsightsForCategory(selected)
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chartDataChanged)) { _ in
            Task<Void, Never>{
                await refreshChart()
            }
        }
    }
    
    // MARK: - View Components
    
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spending Breakdown")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                
                if !isEmpty {
                    HStack(spacing: 8) {
                        Text("Total: \(totalSpending.asCurrency)")
                            .font(.subheadline)
                            .foregroundColor(themeManager.semanticColors.textSecondary)
                        
                        if chartMetrics.isBalanced {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(themeManager.semanticColors.success)
                                .accessibilityLabel("Well balanced spending")
                        }
                    }
                    
                    Text("\(chartMetrics.categoryCount) categories")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textTertiary)
                }
            }
            
            Spacer()
            
            if !isEmpty {
                chartControls
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var chartControls: some View {
        HStack(spacing: 12) {
            // Legend toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingLegend.toggle()
                }
                
                // Haptic feedback
                if settingsManager.enableHapticFeedback {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }) {
                Image(systemName: showingLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeManager.primaryColor)
            }
            .accessibilityLabel(showingLegend ? "Hide legend" : "Show legend")
            
            // Detail view button
            if selectedData != nil {
                Button(action: {
                    showingDetailView = true
                    
                    if settingsManager.enableHapticFeedback {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.primaryColor)
                }
                .accessibilityLabel("Show category details")
            }
            
            // Reset selection button
            if selectedData != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedData = nil
                        hoveredSlice = nil
                        interactionState = .idle
                    }
                    
                    if settingsManager.enableHapticFeedback {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
                .accessibilityLabel("Clear selection")
            }
            
            // Performance info (debug only)
            #if DEBUG
            if AppConstants.Features.enableDebugLogging {
                Button(action: {
                    printPerformanceMetrics()
                }) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.semanticColors.textTertiary)
                }
                .accessibilityLabel("Show performance metrics")
            }
            #endif
        }
    }
    
    private var chartContent: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Background circle for visual context
                Circle()
                    .stroke(
                        themeManager.semanticColors.backgroundTertiary,
                        lineWidth: 1
                    )
                    .frame(width: size * 0.9, height: size * 0.9)
                    .opacity(0.3)
                
                // Main pie chart
                Chart(sliceInfos, id: \.id) { sliceInfo in
                    SectorMark(
                        angle: .value("Amount", sliceInfo.data.amount * animationProgress),
                        innerRadius: .ratio(innerRadiusRatio),
                        angularInset: angularInset
                    )
                    .cornerRadius(cornerRadius)
                    .foregroundStyle(
                        sliceInfo.data.color
                            .opacity(sliceOpacity(for: sliceInfo))
                    )
                    .scaleEffect(sliceInfo.scale)
                    .opacity(sliceVisibility(for: sliceInfo))
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.8)
                            .delay(sliceInfo.animationDelay),
                        value: animationProgress
                    )
                    .animation(
                        .easeInOut(duration: hoverAnimationDuration),
                        value: sliceInfo.isHovered
                    )
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7),
                        value: sliceInfo.isSelected
                    )
                }
                .frame(width: size * 0.9, height: size * 0.9)
                .chartBackground { proxy in
                    chartInteractionOverlay(proxy: proxy, center: center, size: size)
                }
                
                // Center information
                centerInfoView(size: size)
                
                // Slice labels for larger slices
                if animationProgress > 0.8 {
                    sliceLabelsView(center: center, radius: size * 0.4)
                }
            }
            .onAppear {
                chartSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                chartSize = newSize
            }
        }
        .frame(height: 300)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createChartAccessibilityLabel())
        .accessibilityHint("Double tap to select categories, swipe to navigate between slices")
    }
    
    private func chartInteractionOverlay(proxy: ChartProxy, center: CGPoint, size: CGFloat) -> some View {
        Color.clear
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startTime = Date()
                        handleChartInteraction(at: value.location, center: center, size: size)
                        performanceMetrics.recordInteractionLatency(Date().timeIntervalSince(startTime))
                    }
                    .onEnded { _ in
                        handleInteractionEnd()
                    }
            )
            .onTapGesture { location in
                handleChartTap(at: location, center: center, size: size)
            }
            .accessibilityAction(.default) {
                cycleThroughCategories()
            }
            .accessibilityAction(.escape) {
                clearSelection()
            }
    }
    
    private func centerInfoView(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            if let selected = selectedData ?? hoveredSlice {
                // Selected/hovered category info
                Group {
                    Text(selected.category)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.semanticColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(selected.amount.asCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(selected.color)
                    
                    Text("\(selected.percentage.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    if selected.amount > 0 && totalSpending > 0 {
                        let dailyAverage = selected.amount / 30 // Assume monthly data
                        Text("~\(dailyAverage.asCurrency)/day")
                            .font(.caption)
                            .foregroundColor(themeManager.semanticColors.textTertiary)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // Total spending info
                Group {
                    Text("Total Spending")
                        .font(.headline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    Text(totalSpending.asCurrency)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryColor)
                    
                    Text("\(chartMetrics.categoryCount) categories")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textTertiary)
                    
                    if chartMetrics.averageAmount > 0 {
                        Text("Avg: \(chartMetrics.averageAmount.asCurrency)")
                            .font(.caption2)
                            .foregroundColor(themeManager.semanticColors.textTertiary)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .frame(width: size * innerRadiusRatio * 0.85)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedData?.id)
        .animation(.easeInOut(duration: 0.3), value: hoveredSlice?.id)
    }
    
    private func sliceLabelsView(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            ForEach(sliceInfos.filter { $0.data.percentage > 10 }, id: \.id) { sliceInfo in
                let labelRadius = radius * 1.15
                let angle = sliceInfo.midAngle.radians
                let position = CGPoint(
                    x: center.x + cos(angle) * labelRadius,
                    y: center.y + sin(angle) * labelRadius
                )
                
                Text("\(sliceInfo.data.percentage.formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(sliceInfo.data.color)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 24, height: 24)
                    )
                    .position(position)
                    .opacity(sliceInfo.data.percentage > 10 ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 0.5).delay(sliceInfo.animationDelay + 0.8),
                        value: animationProgress
                    )
            }
        }
    }
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Spacer()
                
                if processedData.count > 6 {
                    Text("\(min(6, processedData.count)) of \(processedData.count)")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
            }
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                ForEach(processedData.prefix(6), id: \.id) { data in
                    legendItem(for: data)
                }
                
                // Show remaining count if there are more items
                if processedData.count > 6 {
                    Button(action: {
                        // Show all categories in a sheet or expanded view
                        showAllCategories()
                    }) {
                        HStack {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(themeManager.primaryColor)
                            
                            Text("\(processedData.count - 6) more")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryColor)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private func legendItem(for data: SpendingData) -> some View {
        Button(action: {
            selectCategory(data)
        }) {
            HStack(spacing: 10) {
                // Color indicator with animation
                RoundedRectangle(cornerRadius: 4)
                    .fill(data.color)
                    .frame(width: 14, height: 14)
                    .scaleEffect(selectedData?.id == data.id ? 1.3 : 1.0)
                    .shadow(
                        color: selectedData?.id == data.id ? data.color.opacity(0.5) : .clear,
                        radius: 4
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.category)
                        .font(.caption)
                        .fontWeight(selectedData?.id == data.id ? .semibold : .medium)
                        .foregroundColor(themeManager.semanticColors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(data.amount.asCurrency)
                            .font(.caption2)
                            .foregroundColor(themeManager.semanticColors.textSecondary)
                        
                        Text("(\(data.percentage.formatted(.number.precision(.fractionLength(1))))%)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(data.color)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Selection indicator
                if selectedData?.id == data.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(data.color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        selectedData?.id == data.id ?
                            data.color.opacity(0.1) :
                            Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedData?.id == data.id ?
                            data.color.opacity(0.4) :
                            Color.clear,
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(hoveredSlice?.id == data.id ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: hoverAnimationDuration)) {
                hoveredSlice = isHovering ? data : nil
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(data.category): \(data.amount.asCurrency), \(data.percentage.formatted(.number.precision(.fractionLength(1))))% of total spending")
        .accessibilityHint("Double tap to select this category")
        .accessibilityValue(selectedData?.id == data.id ? "Selected" : "Not selected")
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryColor)
                
                Text("Spending Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(spendingInsights.prefix(3), id: \.id) { insight in
                    insightCard(insight)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func insightCard(_ insight: SpendingInsight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: insight.systemImageName)
                .font(.system(size: 20))
                .foregroundColor(insight.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(12)
        .background(insight.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(insight.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("Loading spending data...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Analyzing your spending patterns")
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ error: AppError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: error.severity.icon)
                .font(.system(size: 48))
                .foregroundColor(error.severity.color)
            
            VStack(spacing: 12) {
                Text(error.errorDescription ?? "Chart Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            HStack(spacing: 12) {
                if error.isRetryable {
                    Button("Try Again") {
                        chartError = nil
                        Task<Void, Never>{
                            await refreshChart()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.primaryColor)
                }
                
                Button("Dismiss") {
                    chartError = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .padding()
        .background(error.severity.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 64))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            VStack(spacing: 12) {
                Text("No Spending Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Add some purchases to see your spending breakdown and insights")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button("Add Purchase") {
                NotificationCenter.default.post(name: .openAddPurchase, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Interaction Handling
    
    private func setupChart() {
        guard !isEmpty else { return }
        
        // Validate data before setup
        do {
            try validateChartData(spendingData)
            chartError = nil
            animateChart()
        } catch {
            chartError = AppError.from(error)
            errorHandler.handle(chartError!, context: "Setting up pie chart")
        }
    }
    
    private func animateChart() {
        guard !isEmpty else { return }
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            animationProgress = 1.0
        }
    }
    
    private func refreshChart() async {
        isLoading = true
        defer { isLoading = false }
        
        // Add small delay to show loading state
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await MainActor.run {
            chartError = nil
            animationProgress = 0
            selectedData = nil
            hoveredSlice = nil
            interactionState = .idle
            
            // Re-animate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateChart()
            }
        }
    }
    
    private func handleChartInteraction(at location: CGPoint, center: CGPoint, size: CGFloat) {
        guard !isEmpty else { return }
        
        let radius = size * 0.45
        let distance = sqrt(pow(location.x - center.x, 2) + pow(location.y - center.y, 2))
        
        // Check if touch is within the chart area
        guard distance <= radius && distance >= radius * innerRadiusRatio else {
            hoveredSlice = nil
            return
        }
        
        // Calculate angle from center
        let angle = atan2(location.y - center.y, location.x - center.x)
        let normalizedAngle = angle < 0 ? angle + 2 * .pi : angle
        let degrees = normalizedAngle * 180 / .pi
        
        // Find which slice contains this angle
        let selectedSlice = sliceInfos.first { sliceInfo in
            ChartMath.isAngleInSlice(
                degrees,
                startAngle: sliceInfo.startAngle.degrees,
                endAngle: sliceInfo.endAngle.degrees
            )
        }
        
        let newHovered = selectedSlice?.data
        let oldHovered = hoveredSlice
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hoveredSlice = newHovered
        }
        
        // Provide haptic feedback when hovering over different slices
        if let new = newHovered,
           let old = oldHovered,
           new.id != old.id,
           settingsManager.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func handleChartTap(at location: CGPoint, center: CGPoint, size: CGFloat) {
        guard !isEmpty else { return }
        
        handleChartInteraction(at: location, center: center, size: size)
        
        if let hovered = hoveredSlice {
            selectCategory(hovered)
        }
    }
    
    private func handleInteractionEnd() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if case .hovering = interactionState {
                hoveredSlice = nil
                interactionState = .idle
            }
        }
    }
    
    private func selectCategory(_ data: SpendingData) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if selectedData?.id == data.id {
                // Deselect if already selected
                selectedData = nil
                interactionState = .idle
            } else {
                // Select new category
                selectedData = data
                interactionState = .selected(data)
            }
        }
        
        // Provide haptic feedback
        if settingsManager.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // Post notification for external listeners
        NotificationCenter.default.post(
            name: .chartCategorySelected,
            object: data,
            userInfo: ["totalSpending": totalSpending]
        )
    }
    
    private func cycleThroughCategories() {
        guard !processedData.isEmpty else { return }
        
        if let currentIndex = processedData.firstIndex(where: { $0.id == selectedData?.id }) {
            let nextIndex = (currentIndex + 1) % processedData.count
            selectCategory(processedData[nextIndex])
        } else {
            selectCategory(processedData.first!)
        }
    }
    
    private func clearSelection() {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedData = nil
            hoveredSlice = nil
            interactionState = .idle
        }
    }
    
    private func showAllCategories() {
        // Implementation for showing all categories in expanded view
        // This could open a sheet or navigate to a detailed view
        NotificationCenter.default.post(
            name: .showAllCategories,
            object: processedData
        )
    }
    
    // MARK: - Data Validation and Processing
    
    private func handleDataChange(from oldData: [SpendingData], to newData: [SpendingData]) {
        let startTime = Date()
        
        // Reset animation for new data
        animationProgress = 0
        selectedData = nil
        hoveredSlice = nil
        chartError = nil
        
        // Validate new data
        do {
            try validateChartData(newData)
            
            // Animate in new data
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateChart()
            }
            
            performanceMetrics.recordDataProcessingTime(Date().timeIntervalSince(startTime))
        } catch {
            chartError = AppError.from(error)
            errorHandler.handle(chartError!, context: "Processing chart data change")
        }
        
        // Post data change notification
        NotificationCenter.default.post(
            name: .chartDataChanged,
            object: newData,
            userInfo: ["oldData": oldData]
        )
    }
    
    private func validateChartData(_ data: [SpendingData]) throws {
        guard !data.isEmpty else { return }
        
        // Validate individual items
        for (index, item) in data.enumerated() {
            guard item.amount >= 0 else {
                throw AppError.validation(message: "Spending amount at index \(index) cannot be negative")
            }
            
            guard !item.category.isEmpty else {
                throw AppError.validation(message: "Category name at index \(index) cannot be empty")
            }
            
            guard item.percentage >= 0 && item.percentage <= 100 else {
                throw AppError.validation(message: "Percentage at index \(index) must be between 0 and 100")
            }
        }
        
        // Validate totals
        let totalAmount = data.reduce(0) { $0 + $1.amount }
        guard totalAmount > 0 else {
            throw AppError.validation(message: "Total spending amount must be greater than zero")
        }
        
        let totalPercentage = data.reduce(0) { $0 + $1.percentage }
        guard totalPercentage <= 105 else { // Allow small margin for rounding
            throw AppError.validation(message: "Total percentage (\(totalPercentage.formatted(.number.precision(.fractionLength(1))))%) exceeds reasonable bounds")
        }
        
        // Check for duplicate categories
        let categoryNames = data.map { $0.category }
        let uniqueCategories = Set(categoryNames)
        guard categoryNames.count == uniqueCategories.count else {
            throw AppError.validation(message: "Duplicate category names found")
        }
    }
    
    // MARK: - Visual Calculations
    
    private func sliceOpacity(for sliceInfo: SliceInfo) -> Double {
        if selectedData == nil {
            return 1.0 // All slices fully visible when none selected
        } else if sliceInfo.isSelected {
            return 1.0 // Selected slice fully visible
        } else {
            return 0.6 // Non-selected slices dimmed
        }
    }
    
    private func sliceVisibility(for sliceInfo: SliceInfo) -> Double {
        if sliceInfo.isSelected {
            return 1.0
        } else if selectedData == nil {
            return 1.0
        } else {
            return 0.7
        }
    }
    
    // MARK: - Insights Generation
    
    private func getSpendingInsights() -> [SpendingInsight] {
        guard !isEmpty else { return [] }
        
        var insights: [SpendingInsight] = []
        
        // Dominant category insight
        if let largest = chartMetrics.largestCategory, largest.percentage > 40 {
            insights.append(.dominantCategory(largest.category, largest.percentage))
        }
        
        // Balanced spending insight
        if chartMetrics.isBalanced && processedData.count >= 4 {
            insights.append(.balancedSpending(chartMetrics.diversityIndex))
        }
        
        // Small expenses insight
        let smallExpenses = processedData.filter { $0.percentage < 5 }
        if smallExpenses.count >= 3 {
            let totalSmall = smallExpenses.reduce(0) { $0 + $1.amount }
            insights.append(.manySmallExpenses(smallExpenses.count, totalSmall))
        }
        
        // Top three insight
        if processedData.count >= 3 {
            let topThree = Array(processedData.prefix(3))
            let topThreeTotal = topThree.reduce(0) { $0 + $1.percentage }
            if topThreeTotal > 70 {
                insights.append(.topThreeDominant(topThreeTotal, topThree.map { $0.category }))
            }
        }
        
        // Budget efficiency insight
        if let largest = chartMetrics.largestCategory,
           let smallest = chartMetrics.smallestCategory {
            let ratio = largest.amount / smallest.amount
            if ratio > 10 {
                insights.append(.highVariability(ratio, largest.category, smallest.category))
            }
        }
        
        // Spending concentration insight
        let topHalf = processedData.prefix(processedData.count / 2)
        let topHalfTotal = topHalf.reduce(0) { $0 + $1.percentage }
        if topHalfTotal > 80 {
            insights.append(.concentratedSpending(topHalfTotal))
        }
        
        return insights
    }
    
    private func getInsightsForCategory(_ category: SpendingData) -> [CategoryInsight] {
        var insights: [CategoryInsight] = []
        
        // Relative size
        if category.percentage > 30 {
            insights.append(.majorCategory(category.percentage))
        } else if category.percentage < 5 {
            insights.append(.minorCategory(category.percentage))
        } else {
            insights.append(.moderateCategory(category.percentage))
        }
        
        // Comparison to average
        let avgPercentage = 100.0 / Double(max(processedData.count, 1))
        if category.percentage > avgPercentage * 1.5 {
            insights.append(.aboveAverage(category.percentage / avgPercentage))
        } else if category.percentage < avgPercentage * 0.5 {
            insights.append(.belowAverage(avgPercentage / category.percentage))
        }
        
        // Monthly projection
        let dailyAverage = category.amount / 30 // Assume monthly data
        insights.append(.dailyAverage(dailyAverage))
        
        return insights
    }
    
    // MARK: - Accessibility
    
    private func createChartAccessibilityLabel() -> String {
        guard !isEmpty else { return "Empty spending chart. No data to display." }
        
        let items = processedData.prefix(5).map { data in
            "\(data.category): \(data.amount.asCurrency) representing \(data.percentage.formatted(.number.precision(.fractionLength(1))))% of total"
        }
        
        var label = "Spending breakdown pie chart. Total spending: \(totalSpending.asCurrency). "
        label += "Data shows \(chartMetrics.categoryCount) categories. "
        
        if chartMetrics.isBalanced {
            label += "Spending is well balanced across categories. "
        } else if let dominant = chartMetrics.largestCategory, dominant.percentage > 40 {
            label += "\(dominant.category) dominates at \(dominant.percentage.formatted(.number.precision(.fractionLength(1))))% of spending. "
        }
        
        label += "Categories include: " + items.joined(separator: ", ")
        
        if processedData.count > 5 {
            label += " and \(processedData.count - 5) additional categories"
        }
        
        if let selected = selectedData {
            label += ". Currently selected: \(selected.category)"
        }
        
        return label
    }
    
    // MARK: - Performance Monitoring
    
    private func printPerformanceMetrics() {
        #if DEBUG
        print("📊 SpendingPieChart Performance Metrics:")
        print("   Render Time: \(String(format: "%.2f", performanceMetrics.renderTime * 1000))ms")
        print("   Interaction Latency: \(String(format: "%.2f", performanceMetrics.interactionLatency * 1000))ms")
        print("   Data Processing: \(String(format: "%.2f", performanceMetrics.dataProcessingTime * 1000))ms")
        print("   Last Update: \(performanceMetrics.lastUpdate.formatted())")
        print("   Chart Size: \(chartSize.width)x\(chartSize.height)")
        print("   Data Points: \(processedData.count)")
        print("   Animation Progress: \(animationProgress)")
        #endif
    }
}

// MARK: - Supporting Types

extension SpendingPieChart {
    enum SpendingInsight: Identifiable {
        case dominantCategory(String, Double)
        case balancedSpending(Double)
        case manySmallExpenses(Int, Double)
        case topThreeDominant(Double, [String])
        case highVariability(Double, String, String)
        case concentratedSpending(Double)
        
        var id: String {
            switch self {
            case .dominantCategory(let category, _): return "dominant_\(category)"
            case .balancedSpending: return "balanced"
            case .manySmallExpenses(let count, _): return "small_\(count)"
            case .topThreeDominant: return "top_three"
            case .highVariability: return "variability"
            case .concentratedSpending: return "concentrated"
            }
        }
        
        var title: String {
            switch self {
            case .dominantCategory(let category, _):
                return "\(category) Dominates"
            case .balancedSpending:
                return "Well-Balanced Spending"
            case .manySmallExpenses(let count, _):
                return "\(count) Small Categories"
            case .topThreeDominant:
                return "Top 3 Categories Rule"
            case .highVariability:
                return "High Spending Variability"
            case .concentratedSpending:
                return "Concentrated Spending"
            }
        }
        
        var description: String {
            switch self {
            case .dominantCategory(let category, let percentage):
                return "\(category) accounts for \(percentage.formatted(.number.precision(.fractionLength(1))))% of your spending. Consider if this aligns with your priorities."
            case .balancedSpending(let diversity):
                return "Your spending is well-distributed across categories (diversity score: \(diversity.formatted(.number.precision(.fractionLength(2))))), indicating good budget balance."
            case .manySmallExpenses(let count, let total):
                return "\(count) categories under 5% each total \(total.asCurrency). Consider consolidating to simplify tracking."
            case .topThreeDominant(let percentage, let categories):
                return "Your top 3 categories (\(categories.joined(separator: ", "))) represent \(percentage.formatted(.number.precision(.fractionLength(1))))% of spending."
            case .highVariability(let ratio, let highest, let lowest):
                return "Large spending gap: \(highest) is \(ratio.formatted(.number.precision(.fractionLength(1))))x larger than \(lowest). Review if this balance works for you."
            case .concentratedSpending(let percentage):
                return "Half your categories account for \(percentage.formatted(.number.precision(.fractionLength(1))))% of spending, suggesting concentrated habits."
            }
        }
        
        var color: Color {
            switch self {
            case .dominantCategory: return .orange
            case .balancedSpending: return .green
            case .manySmallExpenses: return .blue
            case .topThreeDominant: return .purple
            case .highVariability: return .red
            case .concentratedSpending: return .yellow
            }
        }
        
        var systemImageName: String {
            switch self {
            case .dominantCategory: return "exclamationmark.triangle.fill"
            case .balancedSpending: return "checkmark.circle.fill"
            case .manySmallExpenses: return "square.grid.3x3.fill"
            case .topThreeDominant: return "crown.fill"
            case .highVariability: return "arrow.up.arrow.down.circle.fill"
            case .concentratedSpending: return "target"
            }
        }
    }
    
    enum CategoryInsight: Identifiable {
        case majorCategory(Double)
        case minorCategory(Double)
        case moderateCategory(Double)
        case aboveAverage(Double)
        case belowAverage(Double)
        case dailyAverage(Double)
        
        var id: String {
            switch self {
            case .majorCategory: return "major"
            case .minorCategory: return "minor"
            case .moderateCategory: return "moderate"
            case .aboveAverage: return "above_avg"
            case .belowAverage: return "below_avg"
            case .dailyAverage: return "daily_avg"
            }
        }
        
        var title: String {
            switch self {
            case .majorCategory: return "Major Expense Category"
            case .minorCategory: return "Minor Expense Category"
            case .moderateCategory: return "Moderate Expense Category"
            case .aboveAverage: return "Above Average Spending"
            case .belowAverage: return "Below Average Spending"
            case .dailyAverage: return "Daily Spending Average"
            }
        }
        
        var description: String {
            switch self {
            case .majorCategory(let percentage):
                return "This category represents \(percentage.formatted(.number.precision(.fractionLength(1))))% of your total spending, making it a significant expense area."
            case .minorCategory(let percentage):
                return "This category represents only \(percentage.formatted(.number.precision(.fractionLength(1))))% of your spending, a relatively small portion."
            case .moderateCategory(let percentage):
                return "This category represents \(percentage.formatted(.number.precision(.fractionLength(1))))% of your spending, a moderate portion of your budget."
            case .aboveAverage(let ratio):
                return "This category is \(ratio.formatted(.number.precision(.fractionLength(1))))x higher than the average category spending."
            case .belowAverage(let ratio):
                return "This category is \(ratio.formatted(.number.precision(.fractionLength(1))))x lower than the average category spending."
            case .dailyAverage(let amount):
                return "Based on monthly data, you spend approximately \(amount.asCurrency) per day in this category."
            }
        }
    }
}

// MARK: - SpendingDetailSheet

private struct SpendingDetailSheet: View {
    let data: SpendingData
    let totalSpending: Double
    let insights: [SpendingPieChart.CategoryInsight]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Metrics section
                    metricsSection
                    
                    // Progress visualization
                    progressSection
                    
                    // Insights section
                    if !insights.isEmpty {
                        insightsSection
                    }
                    
                    // Comparison section
                    comparisonSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(themeManager.semanticColors.backgroundPrimary)
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        
                        if settingsManager.enableHapticFeedback {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category icon
            ZStack {
                Circle()
                    .fill(data.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(data.color)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(data.category.prefix(2)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(spacing: 8) {
                Text(data.category)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(data.amount.asCurrency)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(data.color)
                
                Text("\(data.percentage.formatted(.number.precision(.fractionLength(1))))% of total spending")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(spacing: 16) {
            Text("Spending Metrics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Amount",
                    value: data.amount.asCurrency,
                    color: data.color,
                    systemImage: "dollarsign.circle.fill"
                )
                
                MetricCard(
                    title: "Percentage",
                    value: "\(data.percentage.formatted(.number.precision(.fractionLength(1))))%",
                    color: themeManager.primaryColor,
                    systemImage: "percent"
                )
                
                MetricCard(
                    title: "Daily Average",
                    value: (data.amount / 30).asCurrency,
                    color: themeManager.semanticColors.info,
                    systemImage: "calendar"
                )
                
                MetricCard(
                    title: "vs Total",
                    value: "1 of \(Int(100 / max(data.percentage, 0.1)))",
                    color: themeManager.semanticColors.success,
                    systemImage: "chart.bar.fill"
                )
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Distribution")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            VStack(spacing: 8) {
                HStack {
                    Text(data.category)
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(data.percentage.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(data.color)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeManager.semanticColors.backgroundTertiary)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [data.color.opacity(0.8), data.color]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(data.percentage / 100, 1.0),
                                height: 12
                            )
                            .animation(.easeInOut(duration: 1.0), value: data.percentage)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("Other Categories")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    Spacer()
                    
                    Text("\((100 - data.percentage).formatted(.number.precision(.fractionLength(1))))%")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Insights")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            LazyVStack(spacing: 8) {
                ForEach(insights, id: \.id) { insight in
                    InsightRow(insight: insight)
                }
            }
        }
    }
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Comparisons")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            VStack(spacing: 12) {
                ComparisonRow(
                    title: "Share of Total Budget",
                    thisValue: data.percentage,
                    otherValue: 100 - data.percentage,
                    thisLabel: data.category,
                    otherLabel: "Other Categories",
                    color: data.color
                )
                
                if totalSpending > 0 {
                    ComparisonRow(
                        title: "Amount vs Remaining",
                        thisValue: data.amount,
                        otherValue: totalSpending - data.amount,
                        thisLabel: data.category,
                        otherLabel: "Other Spending",
                        color: data.color,
                        formatter: .currency
                    )
                }
            }
        }
        .padding()
        .background(themeManager.semanticColors.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Detail Sheet Components

private struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(themeManager.semanticColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct InsightRow: View {
    let insight: SpendingPieChart.CategoryInsight
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(12)
        .background(themeManager.primaryColor.opacity(0.05))
        .cornerRadius(8)
    }
}

private struct ComparisonRow: View {
    let title: String
    let thisValue: Double
    let otherValue: Double
    let thisLabel: String
    let otherLabel: String
    let color: Color
    let formatter: ComparisonFormatter
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    enum ComparisonFormatter {
        case percentage
        case currency
        
        func format(_ value: Double) -> String {
            switch self {
            case .percentage:
                return "\(value.formatted(.number.precision(.fractionLength(1))))%"
            case .currency:
                return value.asCurrency
            }
        }
    }
    
    init(
        title: String,
        thisValue: Double,
        otherValue: Double,
        thisLabel: String,
        otherLabel: String,
        color: Color,
        formatter: ComparisonFormatter = .percentage
    ) {
        self.title = title
        self.thisValue = thisValue
        self.otherValue = otherValue
        self.thisLabel = thisLabel
        self.otherLabel = otherLabel
        self.color = color
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.semanticColors.textPrimary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thisLabel)
                        .font(.caption)
                        .foregroundColor(color)
                    
                    Text(formatter.format(thisValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Text("vs")
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textTertiary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(otherLabel)
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    Text(formatter.format(otherValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
            }
            
            // Visual comparison bar
            GeometryReader { geometry in
                let total = thisValue + otherValue
                let thisRatio = total > 0 ? thisValue / total : 0
                
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * thisRatio)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(themeManager.semanticColors.backgroundTertiary)
                        .frame(width: geometry.size.width * (1 - thisRatio))
                }
                .frame(height: 6)
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Mathematical Utilities

private struct ChartMath {
    /// Convert point to polar coordinates relative to center
    static func pointToPolar(_ point: CGPoint, center: CGPoint) -> (radius: Double, angle: Double) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx)
        return (Double(radius), Double(angle))
    }
    
    /// Normalize angle to 0-360 degrees
    static func normalizeAngle(_ angle: Double) -> Double {
        var normalizedAngle = angle
        while normalizedAngle < 0 {
            normalizedAngle += 2 * .pi
        }
        while normalizedAngle >= 2 * .pi {
            normalizedAngle -= 2 * .pi
        }
        return normalizedAngle * 180 / .pi
    }
    
    /// Check if angle is within slice range
    static func isAngleInSlice(
        _ angle: Double,
        startAngle: Double,
        endAngle: Double
    ) -> Bool {
        if endAngle > startAngle {
            return angle >= startAngle && angle <= endAngle
        } else {
            // Handle wrap-around case (crosses 0 degrees)
            return angle >= startAngle || angle <= endAngle
        }
    }
    
    /// Calculate optimal label position to avoid overlaps
    static func calculateLabelPositions(
        for slices: [SpendingPieChart.SliceInfo],
        radius: CGFloat,
        minimumSeparation: CGFloat = 20
    ) -> [CGPoint] {
        // Implementation for collision detection and label positioning
        return slices.map { slice in
            let angle = slice.midAngle.radians
            let labelRadius = radius * 1.2
            return CGPoint(
                x: cos(angle) * labelRadius,
                y: sin(angle) * labelRadius
            )
        }
    }
}

// MARK: - Color Utilities

private extension Color {
    /// Create harmonious color variations for chart slices
    func chartVariation(index: Int, total: Int) -> Color {
        let hue = Double(index) / Double(total)
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
    
    /// Get contrasting text color for accessibility
    var contrastingTextColor: Color {
        let components = self.components
        let luminance = 0.299 * components.red + 0.587 * components.green + 0.114 * components.blue
        return luminance > 0.5 ? .black : .white
    }
    
    /// Get lighter variant of the color
    func lighter(by amount: Double = 0.2) -> Color {
        let components = self.components
        return Color(
            red: min(components.red + amount, 1.0),
            green: min(components.green + amount, 1.0),
            blue: min(components.blue + amount, 1.0),
            opacity: components.alpha
        )
    }
    
    /// Get darker variant of the color
    func darker(by amount: Double = 0.2) -> Color {
        let components = self.components
        return Color(
            red: max(components.red - amount, 0.0),
            green: max(components.green - amount, 0.0),
            blue: max(components.blue - amount, 0.0),
            opacity: components.alpha
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let chartCategorySelected = Notification.Name("chartCategorySelected")
    static let chartDataChanged = Notification.Name("chartDataChanged")
    static let chartErrorOccurred = Notification.Name("chartErrorOccurred")
    static let showAllCategories = Notification.Name("showAllCategories")
}

// MARK: - Extensions for Enhanced Functionality

extension SpendingPieChart {
    /// Initialize with custom configuration
    init(
        spendingData: [SpendingData],
        selectedData: Binding<SpendingData?>,
        showLegend: Bool = true,
        maxCategories: Int = 8,
        innerRadius: CGFloat = 0.618,
        enableInsights: Bool = true
    ) {
        self.spendingData = spendingData
        self._selectedData = selectedData
        self._showingLegend = State(initialValue: showLegend)
        // Store configuration in instance variables if needed
    }
    
    /// Export chart data as text summary
    func exportSummary() -> String {
        guard !isEmpty else { return "No spending data available" }
        
        var summary = "Spending Breakdown Summary\n"
        summary += "Generated: \(Date().formatted())\n"
        summary += "Total: \(totalSpending.asCurrency)\n"
        summary += "Categories: \(chartMetrics.categoryCount)\n"
        summary += "Diversity Index: \(chartMetrics.diversityIndex.formatted(.number.precision(.fractionLength(2))))\n\n"
        
        for (index, data) in processedData.enumerated() {
            summary += "\(index + 1). \(data.category): \(data.amount.asCurrency) (\(data.percentage.formatted(.number.precision(.fractionLength(1))))%)\n"
        }
        
        if !spendingInsights.isEmpty {
            summary += "\nInsights:\n"
            for insight in spendingInsights {
                summary += "• \(insight.title): \(insight.description)\n"
            }
        }
        
        return summary
    }
    
    /// Get chart accessibility summary
    func getAccessibilitySummary() -> String {
        return createChartAccessibilityLabel()
    }
    
    /// Export chart image (conceptual - would require additional implementation)
    func exportAsImage(size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        // Implementation would involve rendering the chart to an image context
        // This is a placeholder for the concept
        return nil
    }
}

// MARK: - Utility Extensions

private extension Array where Element == SpendingData {
    /// Get the category with the highest spending
    var topSpendingCategory: SpendingData? {
        self.max(by: { $0.amount < $1.amount })
    }
    
    /// Get categories above a certain percentage threshold
    func categoriesAbove(percentage threshold: Double) -> [SpendingData] {
        self.filter { $0.percentage > threshold }
    }
    
    /// Get total amount for all categories
    var totalAmount: Double {
        self.reduce(0) { $0 + $1.amount }
    }
    
    /// Check if spending is well-balanced (no single category dominates)
    var isBalanced: Bool {
        guard !isEmpty else { return false }
        let maxPercentage = self.map(\.percentage).max() ?? 0
        return maxPercentage < 35 && count >= 3
    }
    
    /// Calculate Shannon diversity index
    var diversityIndex: Double {
        guard !isEmpty else { return 0 }
        
        let total = totalAmount
        guard total > 0 else { return 0 }
        
        return self.reduce(0.0) { result, item in
            let proportion = item.amount / total
            return proportion > 0 ? result - (proportion * log2(proportion)) : result
        }
    }
    
    /// Get spending distribution characteristics
    var distributionCharacteristics: (isBalanced: Bool, dominantCategory: SpendingData?, concentration: Double) {
        let dominant = topSpendingCategory
        let topThreeTotal = Array(prefix(3)).reduce(0) { $0 + $1.percentage }
        
        return (
            isBalanced: isBalanced,
            dominantCategory: dominant?.percentage ?? 0 > 40 ? dominant : nil,
            concentration: topThreeTotal
        )
    }
}

// MARK: - Performance Optimizations

extension SpendingPieChart {
    /// Determine if chart should use optimized rendering
    private func shouldUseOptimizedRendering() -> Bool {
        return processedData.count > 15 || chartSize.width > 600 || chartSize.height > 600
    }
    
    /// Get optimized slice count for performance
    private func getOptimizedSliceCount() -> Int {
        if shouldUseOptimizedRendering() {
            return min(processedData.count, 12)
        }
        return processedData.count
    }
    
    /// Pre-compute animation timing for better performance
    private func getAnimationTiming(for index: Int) -> Double {
        return min(Double(index) * 0.05, 0.5) // Cap at 0.5 seconds
    }
}

// MARK: - Error Handling Extensions

extension SpendingPieChart {
    /// Handle specific chart rendering errors
    private func handleRenderingError(_ error: Error) {
        let chartError = AppError.from(error)
        self.chartError = chartError
        
        // Log error for debugging
        print("❌ SpendingPieChart: Rendering error - \(error.localizedDescription)")
        
        // Post error notification
        NotificationCenter.default.post(
            name: .chartErrorOccurred,
            object: chartError
        )
        
        // Attempt recovery by resetting chart state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.chartError = nil
            self.animateChart()
        }
    }
    
    /// Validate chart state for consistency
    private func validateChartState() -> Bool {
        guard !spendingData.isEmpty else { return true } // Empty is valid
        
        // Check for data consistency
        let calculatedTotal = spendingData.reduce(0) { $0 + $1.amount }
        let percentageTotal = spendingData.reduce(0) { $0 + $1.percentage }
        
        // Allow some tolerance for floating point arithmetic
        let percentageTolerance = 5.0
        let isPercentageValid = percentageTotal <= (100.0 + percentageTolerance)
        
        return calculatedTotal > 0 && isPercentageValid
    }
}

// MARK: - Animation Utilities

private struct ChartAnimationHelper {
    static func createSliceAnimation(delay: Double = 0) -> Animation {
        .spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0.2)
        .delay(delay)
    }
    
    static func createSelectionAnimation() -> Animation {
        .spring(response: 0.6, dampingFraction: 0.7)
    }
    
    static func createHoverAnimation() -> Animation {
        .easeInOut(duration: 0.2)
    }
    
    static func createProgressAnimation() -> Animation {
        .easeInOut(duration: 1.2)
    }
    
    static func createInsightAnimation(delay: Double = 0) -> Animation {
        .spring(response: 0.6, dampingFraction: 0.8)
        .delay(delay)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct SpendingPieChart_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With Data
            SpendingPieChart(
                spendingData: [
                    try! SpendingData(category: "Groceries", amount: 500, percentage: 35.7, color: .blue),
                    try! SpendingData(category: "Transportation", amount: 300, percentage: 21.4, color: .green),
                    try! SpendingData(category: "Entertainment", amount: 200, percentage: 14.3, color: .orange),
                    try! SpendingData(category: "Dining", amount: 250, percentage: 17.9, color: .purple),
                    try! SpendingData(category: "Utilities", amount: 150, percentage: 10.7, color: .red)
                ],
                selectedData: .constant(nil)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .padding()
            .previewDisplayName("Normal State")
            
            // Empty State
            SpendingPieChart(
                spendingData: [],
                selectedData: .constant(nil)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .padding()
            .previewDisplayName("Empty State")
            
            // Dark Mode with Selection
            SpendingPieChart(
                spendingData: [
                    try! SpendingData(category: "Groceries", amount: 500, percentage: 35.7, color: .blue),
                    try! SpendingData(category: "Transportation", amount: 300, percentage: 21.4, color: .green),
                    try! SpendingData(category: "Entertainment", amount: 200, percentage: 14.3, color: .orange),
                    try! SpendingData(category: "Dining", amount: 250, percentage: 17.9, color: .purple),
                    try! SpendingData(category: "Utilities", amount: 150, percentage: 10.7, color: .red)
                ],
                selectedData: .constant(try! SpendingData(category: "Groceries", amount: 500, percentage: 35.7, color: .blue))
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .preferredColorScheme(.dark)
            .padding()
            .previewDisplayName("Dark Mode - Selected")
            
            // Many Categories
            SpendingPieChart(
                spendingData: (1...12).map { index in
                    try! SpendingData(
                        category: "Category \(index)",
                        amount: Double(100 * index),
                        percentage: Double(index) * 8.33,
                        color: [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan].randomElement() ?? .blue
                    )
                },
                selectedData: .constant(nil)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .padding()
            .previewDisplayName("Many Categories")
            
            // Balanced Spending
            SpendingPieChart(
                spendingData: [
                    try! SpendingData(category: "Housing", amount: 250, percentage: 20.8, color: .blue),
                    try! SpendingData(category: "Food", amount: 200, percentage: 16.7, color: .green),
                    try! SpendingData(category: "Transportation", amount: 180, percentage: 15.0, color: .orange),
                    try! SpendingData(category: "Entertainment", amount: 150, percentage: 12.5, color: .purple),
                    try! SpendingData(category: "Utilities", amount: 120, percentage: 10.0, color: .red),
                    try! SpendingData(category: "Healthcare", amount: 100, percentage: 8.3, color: .pink),
                    try! SpendingData(category: "Shopping", amount: 80, percentage: 6.7, color: .yellow),
                    try! SpendingData(category: "Personal", amount: 70, percentage: 5.8, color: .cyan),
                    try! SpendingData(category: "Education", amount: 50, percentage: 4.2, color: .mint)
                ],
                selectedData: .constant(nil)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .padding()
            .previewDisplayName("Balanced Spending")
        }
    }
}

// MARK: - Test Extensions
extension SpendingPieChart {
    /// Create test chart with mock data
    static func createTestChart() -> SpendingPieChart {
        return SpendingPieChart(
            spendingData: [
                try! SpendingData(category: "Groceries", amount: 450.0, percentage: 25.7, color: .blue),
                try! SpendingData(category: "Transportation", amount: 350.0, percentage: 20.0, color: .green),
                try! SpendingData(category: "Entertainment", amount: 300.0, percentage: 17.1, color: .orange),
                try! SpendingData(category: "Dining", amount: 250.0, percentage: 14.3, color: .purple),
                try! SpendingData(category: "Utilities", amount: 200.0, percentage: 11.4, color: .red),
                try! SpendingData(category: "Shopping", amount: 150.0, percentage: 8.6, color: .pink),
                try! SpendingData(category: "Healthcare", amount: 50.0, percentage: 2.9, color: .cyan)
            ],
            selectedData: .constant(nil)
        )
    }
    
    /// Create test chart with error state
    static func createErrorChart() -> SpendingPieChart {
        let chart = SpendingPieChart(
            spendingData: [
                // Invalid data that would trigger validation errors
            ],
            selectedData: .constant(nil)
        )
        return chart
    }
    
    /// Create balanced spending test chart
    static func createBalancedChart() -> SpendingPieChart {
        return SpendingPieChart(
            spendingData: [
                try! SpendingData(category: "Housing", amount: 250, percentage: 20.8, color: .blue),
                try! SpendingData(category: "Food", amount: 200, percentage: 16.7, color: .green),
                try! SpendingData(category: "Transportation", amount: 180, percentage: 15.0, color: .orange),
                try! SpendingData(category: "Entertainment", amount: 150, percentage: 12.5, color: .purple),
                try! SpendingData(category: "Utilities", amount: 120, percentage: 10.0, color: .red),
                try! SpendingData(category: "Healthcare", amount: 100, percentage: 8.3, color: .pink),
                try! SpendingData(category: "Shopping", amount: 80, percentage: 6.7, color: .yellow),
                try! SpendingData(category: "Personal", amount: 50, percentage: 4.2, color: .cyan)
            ],
            selectedData: .constant(nil)
        )
    }
}

/// Helper function to create test spending data
func createTestSpendingData() -> [SpendingData] {
    return [
        try! SpendingData(category: "Groceries", amount: 450.0, percentage: 30.0, color: .blue),
        try! SpendingData(category: "Transportation", amount: 300.0, percentage: 20.0, color: .green),
        try! SpendingData(category: "Entertainment", amount: 225.0, percentage: 15.0, color: .orange),
        try! SpendingData(category: "Dining", amount: 225.0, percentage: 15.0, color: .purple),
        try! SpendingData(category: "Utilities", amount: 150.0, percentage: 10.0, color: .red),
        try! SpendingData(category: "Shopping", amount: 150.0, percentage: 10.0, color: .pink)
    ]
}
#endif
