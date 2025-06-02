//
//  SpendingPieChart.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 11/8/24.
//  Updated: 6/1/25 - Enhanced with centralized error handling, improved interactivity, and better performance
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
    
    // MARK: - Configuration
    private let innerRadiusRatio: CGFloat = 0.618 // Golden ratio for aesthetics
    private let angularInset: CGFloat = 1.5
    private let cornerRadius: CGFloat = 5
    private let animationDuration: Double = 1.2
    private let hoverAnimationDuration: Double = 0.3
    private let maxDisplayedCategories = 8
    
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
    
    private struct ChartMetrics {
        let totalAmount: Double
        let averageAmount: Double
        let categoryCount: Int
        let largestCategory: SpendingData?
        let smallestCategory: SpendingData?
        
        init(data: [SpendingData]) {
            self.totalAmount = data.reduce(0) { $0 + $1.amount }
            self.averageAmount = data.isEmpty ? 0 : totalAmount / Double(data.count)
            self.categoryCount = data.count
            self.largestCategory = data.max(by: { $0.amount < $1.amount })
            self.smallestCategory = data.min(by: { $0.amount < $1.amount })
        }
    }
    
    private struct SliceInfo: Identifiable {
        let id = UUID()
        let data: SpendingData
        let startAngle: Angle
        let endAngle: Angle
        let midAngle: Angle
        let isSelected: Bool
        let isHovered: Bool
        let scale: CGFloat
        
        init(
            data: SpendingData,
            startAngle: Angle,
            endAngle: Angle,
            isSelected: Bool,
            isHovered: Bool
        ) {
            self.data = data
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.midAngle = Angle(degrees: (startAngle.degrees + endAngle.degrees) / 2)
            self.isSelected = isSelected
            self.isHovered = isHovered
            self.scale = isSelected ? 1.05 : (isHovered ? 1.02 : 1.0)
        }
    }
    
    // MARK: - Computed Properties
    private var processedData: [SpendingData] {
        guard !spendingData.isEmpty else { return [] }
        
        // Sort by amount descending and limit to max categories
        let sortedData = spendingData.sorted { $0.amount > $1.amount }
        
        if sortedData.count <= maxDisplayedCategories {
            return sortedData
        }
        
        // Group smaller categories into "Others"
        let mainCategories = Array(sortedData.prefix(maxDisplayedCategories - 1))
        let otherCategories = Array(sortedData.suffix(from: maxDisplayedCategories - 1))
        
        let otherAmount = otherCategories.reduce(0) { $0 + $1.amount }
        let otherPercentage = otherCategories.reduce(0) { $0 + $1.percentage }
        
        guard otherAmount > 0 else { return mainCategories }
        
        do {
            let othersData = try SpendingData(
                category: "Others",
                amount: otherAmount,
                percentage: otherPercentage,
                color: themeManager.semanticColors.textTertiary
            )
            return mainCategories + [othersData]
        } catch {
            // If we can't create the "Others" category, just return main categories
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
        return processedData.map { data in
            let startAngle = Angle(degrees: currentAngle)
            let sliceAngle = (data.amount / totalSpending) * 360
            let endAngle = Angle(degrees: currentAngle + sliceAngle)
            currentAngle += sliceAngle
            
            return SliceInfo(
                data: data,
                startAngle: startAngle,
                endAngle: endAngle,
                isSelected: selectedData?.id == data.id,
                isHovered: hoveredSlice?.id == data.id
            )
        }
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
        }
        .onAppear {
            animateChart()
        }
        .onChange(of: spendingData) { oldData, newData in
            handleDataChange(from: oldData, to: newData)
        }
        .sheet(isPresented: $showingDetailView) {
            if let selected = selectedData {
                SpendingDetailSheet(data: selected)
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
                    Text("Total: \(totalSpending.asCurrency)")
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                        .accessibilityLabel("Total spending: \(totalSpending.asCurrency)")
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
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                }
                .accessibilityLabel("Clear selection")
            }
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
                
                // Main pie chart
                Chart {
                    ForEach(sliceInfos, id: \.id) { sliceInfo in
                        SectorMark(
                            angle: .value("Amount", sliceInfo.data.amount * animationProgress),
                            innerRadius: .ratio(innerRadiusRatio),
                            angularInset: angularInset
                        )
                        .cornerRadius(cornerRadius)
                        .foregroundStyle(sliceInfo.data.color.opacity(sliceOpacity(for: sliceInfo)))
                        .scaleEffect(sliceInfo.scale)
                        .opacity(sliceInfo.isSelected || selectedData == nil ? 1.0 : 0.6)
                    }
                }
                .frame(width: size * 0.9, height: size * 0.9)
                .chartBackground { proxy in
                    chartInteractionOverlay(proxy: proxy, center: center, size: size)
                }
                
                // Center information
                centerInfoView(size: size)
            }
            .onAppear {
                chartSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                chartSize = newSize
            }
        }
        .frame(height: 280)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(createChartAccessibilityLabel())
    }
    
    private func chartInteractionOverlay(proxy: ChartProxy, center: CGPoint, size: CGFloat) -> some View {
        Color.clear
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleChartInteraction(at: value.location, center: center, size: size)
                    }
                    .onEnded { _ in
                        handleInteractionEnd()
                    }
            )
            .onTapGesture { location in
                handleChartTap(at: location, center: center, size: size)
            }
    }
    
    private func centerInfoView(size: CGFloat) -> some View {
        VStack(spacing: 4) {
            if let selected = selectedData ?? hoveredSlice {
                // Selected/hovered category info
                Text(selected.category)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(selected.amount.asCurrency)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(selected.color)
                
                Text("\(selected.percentage.formatted(.number.precision(.fractionLength(1))))%")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
            } else {
                // Total spending info
                Text("Total")
                    .font(.headline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                
                Text(totalSpending.asCurrency)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryColor)
                
                Text("\(chartMetrics.categoryCount) categories")
                    .font(.caption)
                    .foregroundColor(themeManager.semanticColors.textTertiary)
            }
        }
        .frame(width: size * innerRadiusRatio * 0.8)
        .animation(.easeInOut(duration: 0.3), value: selectedData?.id)
        .animation(.easeInOut(duration: 0.3), value: hoveredSlice?.id)
    }
    
    private var legendSection: some View {
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
                HStack {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(themeManager.semanticColors.textTertiary)
                    
                    Text("\(processedData.count - 6) more")
                        .font(.caption)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .scale))
    }
    
    private func legendItem(for data: SpendingData) -> some View {
        Button(action: {
            selectCategory(data)
        }) {
            HStack(spacing: 8) {
                // Color indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(data.color)
                    .frame(width: 12, height: 12)
                    .scaleEffect(selectedData?.id == data.id ? 1.2 : 1.0)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.category)
                        .font(.caption)
                        .fontWeight(selectedData?.id == data.id ? .semibold : .medium)
                        .foregroundColor(themeManager.semanticColors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(data.amount.asCurrency)
                            .font(.caption2)
                            .foregroundColor(themeManager.semanticColors.textSecondary)
                        
                        Text("(\(data.percentage.formatted(.number.precision(.fractionLength(1))))%)")
                            .font(.caption2)
                            .foregroundColor(data.color)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        selectedData?.id == data.id ?
                            data.color.opacity(0.1) :
                            Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedData?.id == data.id ?
                            data.color.opacity(0.3) :
                            Color.clear,
                        lineWidth: 1
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
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                .scaleEffect(1.2)
            
            Text("Loading spending data...")
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ error: AppError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: error.severity.icon)
                .font(.system(size: 48))
                .foregroundColor(error.severity.color)
            
            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Chart Error")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.subheadline)
                        .foregroundColor(themeManager.semanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if error.isRetryable {
                Button("Try Again") {
                    chartError = nil
                    animateChart()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.primaryColor)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 64))
                .foregroundColor(themeManager.semanticColors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Spending Data")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.semanticColors.textPrimary)
                
                Text("Add some purchases to see your spending breakdown")
                    .font(.subheadline)
                    .foregroundColor(themeManager.semanticColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add Purchase") {
                NotificationCenter.default.post(name: .openAddPurchase, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.primaryColor)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Interaction Handling
    
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
            let startDegrees = sliceInfo.startAngle.degrees
            let endDegrees = sliceInfo.endAngle.degrees
            
            if endDegrees > startDegrees {
                return degrees >= startDegrees && degrees <= endDegrees
            } else {
                // Handle wrap-around case
                return degrees >= startDegrees || degrees <= endDegrees
            }
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hoveredSlice = selectedSlice?.data
        }
        
        // Provide haptic feedback when hovering over different slices
        if let newHovered = hoveredSlice,
           let oldHovered = hoveredSlice,
           newHovered.id != oldHovered.id,
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
            hoveredSlice = nil
            interactionState = .idle
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
    }
    
    // MARK: - Animation and Effects
    
    private func animateChart() {
        guard !isEmpty else { return }
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            animationProgress = 1.0
        }
    }
    
    private func handleDataChange(from oldData: [SpendingData], to newData: [SpendingData]) {
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
        } catch {
            chartError = AppError.from(error)
        }
    }
    
    private func validateChartData(_ data: [SpendingData]) throws {
        guard !data.isEmpty else { return }
        
        for item in data {
            guard item.amount >= 0 else {
                throw AppError.validation(message: "Spending amounts cannot be negative")
            }
            
            guard !item.category.isEmpty else {
                throw AppError.validation(message: "Category names cannot be empty")
            }
        }
        
        let totalPercentage = data.reduce(0) { $0 + $1.percentage }
        guard totalPercentage <= 105 else { // Allow small margin for rounding
            throw AppError.validation(message: "Total percentage exceeds 100%")
        }
    }
    
    private func sliceOpacity(for sliceInfo: SliceInfo) -> Double {
        if selectedData == nil {
            return 1.0 // All slices fully visible when none selected
        } else if sliceInfo.isSelected {
            return 1.0 // Selected slice fully visible
        } else {
            return 0.6 // Non-selected slices dimmed
        }
    }
    
    // MARK: - Accessibility
    
    private func createChartAccessibilityLabel() -> String {
        guard !isEmpty else { return "Empty spending chart" }
        
        let items = processedData.prefix(5).map { data in
            "\(data.category): \(data.amount.asCurrency) (\(data.percentage.formatted(.number.precision(.fractionLength(1))))%)"
        }
        
        var label = "Spending breakdown chart. Total spending: \(totalSpending.asCurrency). "
        label += "Categories: " + items.joined(separator: ", ")
        
        if processedData.count > 5 {
            label += " and \(processedData.count - 5) more categories"
        }
        
        return label
    }
}

// MARK: - SpendingDetailSheet

private struct SpendingDetailSheet: View {
    let data: SpendingData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Circle()
                        .fill(data.color)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(data.category.prefix(2)))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(spacing: 8) {
                        Text(data.category)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.semanticColors.textPrimary)
                        
                        Text(data.amount.asCurrency)
                            .font(.title2)
                            .foregroundColor(data.color)
                    }
                }
                
                // Details
                VStack(spacing: 16) {
                    DetailRow(
                        title: "Percentage of Total",
                        value: "\(data.percentage.formatted(.number.precision(.fractionLength(1))))%",
                        color: data.color
                    )
                    
                    DetailRow(
                        title: "Amount Spent",
                        value: data.amount.asCurrency,
                        color: themeManager.semanticColors.textPrimary
                    )
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budget Progress")
                            .font(.headline)
                            .foregroundColor(themeManager.semanticColors.textPrimary)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(themeManager.semanticColors.backgroundTertiary)
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(data.color)
                                    .frame(
                                        width: geometry.size.width * min(data.percentage / 100, 1.0),
                                        height: 8
                                    )
                                    .animation(.easeInOut(duration: 0.8), value: data.percentage)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    let color: Color
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(themeManager.semanticColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
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
            .previewDisplayName("With Data")
            
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
            
            // Dark Mode
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
            
            // Loading State
            SpendingPieChart(
                spendingData: [],
                selectedData: .constant(nil)
            )
            .environmentObject(ThemeManager.shared)
            .environmentObject(ErrorHandler.shared)
            .environmentObject(SettingsManager.shared)
            .onAppear {
                // Simulate loading state
            }
            .padding()
            .previewDisplayName("Loading State")
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
            spendingData: [],
            selectedData: .constant(nil)
        )
        // Would need to simulate error state here
        return chart
    }
}
#endif

// MARK: - Extensions for Enhanced Functionality

extension SpendingPieChart {
    /// Initialize with custom configuration
    init(
        spendingData: [SpendingData],
        selectedData: Binding<SpendingData?>,
        showLegend: Bool = true,
        maxCategories: Int = 8,
        innerRadius: CGFloat = 0.618
    ) {
        self.spendingData = spendingData
        self._selectedData = selectedData
        self._showingLegend = State(initialValue: showLegend)
        // Note: maxCategories and innerRadius would need to be stored as properties
        // This is a conceptual example of how you might extend initialization
    }
    
    /// Export chart data as text summary
    func exportSummary() -> String {
        guard !isEmpty else { return "No spending data available" }
        
        var summary = "Spending Breakdown Summary\n"
        summary += "Total: \(totalSpending.asCurrency)\n"
        summary += "Categories: \(chartMetrics.categoryCount)\n\n"
        
        for (index, data) in processedData.enumerated() {
            summary += "\(index + 1). \(data.category): \(data.amount.asCurrency) (\(data.percentage.formatted(.number.precision(.fractionLength(1))))%)\n"
        }
        
        return summary
    }
    
    /// Get insights about spending patterns
    func getSpendingInsights() -> [SpendingInsight] {
        guard !isEmpty else { return [] }
        
        var insights: [SpendingInsight] = []
        
        // Dominant category insight
        if let largest = chartMetrics.largestCategory, largest.percentage > 40 {
            insights.append(.dominantCategory(largest.category, largest.percentage))
        }
        
        // Balanced spending insight
        let maxPercentage = processedData.map(\.percentage).max() ?? 0
        if maxPercentage < 30 && processedData.count >= 4 {
            insights.append(.balancedSpending)
        }
        
        // Small expenses insight
        let smallExpenses = processedData.filter { $0.percentage < 5 }
        if smallExpenses.count >= 3 {
            insights.append(.manySmallExpenses(smallExpenses.count))
        }
        
        // Top three insight
        if processedData.count >= 3 {
            let topThree = Array(processedData.prefix(3))
            let topThreeTotal = topThree.reduce(0) { $0 + $1.percentage }
            if topThreeTotal > 70 {
                insights.append(.topThreeDominant(topThreeTotal))
            }
        }
        
        return insights
    }
    
    enum SpendingInsight {
        case dominantCategory(String, Double)
        case balancedSpending
        case manySmallExpenses(Int)
        case topThreeDominant(Double)
        
        var title: String {
            switch self {
            case .dominantCategory(let category, _):
                return "\(category) Dominates Spending"
            case .balancedSpending:
                return "Well-Balanced Spending"
            case .manySmallExpenses(let count):
                return "\(count) Small Expense Categories"
            case .topThreeDominant:
                return "Top 3 Categories Dominate"
            }
        }
        
        var description: String {
            switch self {
            case .dominantCategory(let category, let percentage):
                return "\(category) accounts for \(percentage.formatted(.number.precision(.fractionLength(1))))% of your spending."
            case .balancedSpending:
                return "Your spending is well-distributed across categories."
            case .manySmallExpenses(let count):
                return "You have \(count) categories with small amounts. Consider consolidating."
            case .topThreeDominant(let percentage):
                return "Your top 3 categories represent \(percentage.formatted(.number.precision(.fractionLength(1))))% of spending."
            }
        }
        
        var color: Color {
            switch self {
            case .dominantCategory: return .orange
            case .balancedSpending: return .green
            case .manySmallExpenses: return .blue
            case .topThreeDominant: return .purple
            }
        }
        
        var systemImageName: String {
            switch self {
            case .dominantCategory: return "exclamationmark.triangle"
            case .balancedSpending: return "checkmark.circle"
            case .manySmallExpenses: return "square.grid.3x3"
            case .topThreeDominant: return "crown"
            }
        }
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
}

// MARK: - Performance Optimizations

extension SpendingPieChart {
    /// Pre-compute slice information for better performance
    private func precomputeSlices() -> [SliceInfo] {
        guard !isEmpty else { return [] }
        
        let totalAmount = processedData.reduce(0) { $0 + $1.amount }
        var currentAngle: Double = 0
        
        return processedData.map { data in
            let startAngle = Angle(degrees: currentAngle)
            let sliceAngle = (data.amount / totalAmount) * 360
            let endAngle = Angle(degrees: currentAngle + sliceAngle)
            currentAngle += sliceAngle
            
            return SliceInfo(
                data: data,
                startAngle: startAngle,
                endAngle: endAngle,
                isSelected: selectedData?.id == data.id,
                isHovered: hoveredSlice?.id == data.id
            )
        }
    }
    
    /// Optimize rendering for large datasets
    private func shouldUseOptimizedRendering() -> Bool {
        return processedData.count > 20 || chartSize.width > 500
    }
}

// MARK: - Error Handling Extensions

extension SpendingPieChart {
    /// Validate chart data and handle common errors
    private func validateAndHandleErrors() {
        do {
            try validateChartData(spendingData)
            chartError = nil
        } catch {
            chartError = AppError.from(error)
            errorHandler.handle(chartError!, context: "Validating pie chart data")
        }
    }
    
    /// Handle specific chart rendering errors
    private func handleRenderingError(_ error: Error) {
        let chartError = AppError.from(error)
        self.chartError = chartError
        
        // Log error for debugging
        print("❌ SpendingPieChart: Rendering error - \(error.localizedDescription)")
        
        // Attempt recovery by resetting chart state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.chartError = nil
            self.animateChart()
        }
    }
}

// MARK: - Accessibility Enhancements

extension SpendingPieChart {
    /// Create detailed accessibility description
    private func createDetailedAccessibilityDescription() -> String {
        guard !isEmpty else { return "Empty spending chart. No data to display." }
        
        var description = "Pie chart showing spending across \(chartMetrics.categoryCount) categories. "
        description += "Total spending: \(totalSpending.asCurrency). "
        
        // Add top categories
        let topCategories = processedData.prefix(3)
        description += "Top categories: "
        description += topCategories.map { data in
            "\(data.category) with \(data.amount.asCurrency) representing \(data.percentage.formatted(.number.precision(.fractionLength(1))))% of total"
        }.joined(separator: ", ")
        
        if let selected = selectedData {
            description += ". Currently selected: \(selected.category) with \(selected.amount.asCurrency)."
        }
        
        return description
    }
    
    /// Provide accessibility actions for chart interaction
    private func accessibilityActions() -> [AccessibilityActionKind: () -> Void] {
        var actions: [AccessibilityActionKind: () -> Void] = [:]
        
        if !processedData.isEmpty {
            actions[.default] = {
                // Cycle through categories
                if let currentIndex = processedData.firstIndex(where: { $0.id == selectedData?.id }) {
                    let nextIndex = (currentIndex + 1) % processedData.count
                    selectedData = processedData[nextIndex]
                } else {
                    selectedData = processedData.first
                }
            }
            
            actions[.escape] = {
                selectedData = nil
            }
        }
        
        return actions
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
        // Simplified contrast calculation
        let components = self.components
        let luminance = 0.299 * components.red + 0.587 * components.green + 0.114 * components.blue
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let chartCategorySelected = Notification.Name("chartCategorySelected")
    static let chartDataChanged = Notification.Name("chartDataChanged")
    static let chartErrorOccurred = Notification.Name("chartErrorOccurred")
}
