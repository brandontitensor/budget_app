//
//  BudgetWidget.swift
//  Brandon's Budget
//
//  Created by Brandon Titensor on 7/3/24.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry
struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let monthlyBudget: Double
    let remainingBudget: Double
    
    var isOverBudget: Bool {
        remainingBudget < 0
    }
    
    var percentageRemaining: Double {
        guard monthlyBudget > 0 else { return 0 }
        return (remainingBudget / monthlyBudget) * 100
    }
}

// MARK: - Provider
struct BudgetWidgetProvider: TimelineProvider {
    private let sharedDataManager = SharedDataManager.shared
    private let calendar = Calendar.current
    
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(
            date: Date(),
            monthlyBudget: 2000,
            remainingBudget: 1000
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        let entry = BudgetWidgetEntry(
            date: Date(),
            monthlyBudget: sharedDataManager.getMonthlyBudget(),
            remainingBudget: sharedDataManager.getRemainingBudget()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let currentDate = Date()
        let nextUpdate = calendar.date(
            byAdding: .hour,
            value: 1,
            to: currentDate
        ) ?? currentDate.addingTimeInterval(3600)
        
        let entry = BudgetWidgetEntry(
            date: currentDate,
            monthlyBudget: sharedDataManager.getMonthlyBudget(),
            remainingBudget: sharedDataManager.getRemainingBudget()
        )
        
        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextUpdate)
        )
        completion(timeline)
    }
}

// MARK: - Widget
@main
struct BudgetWidget: Widget {
    private let kind = "BudgetWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BudgetWidgetProvider()
        ) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Status")
        .description("Shows your monthly budget and remaining balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Views
struct BudgetWidgetView: View {
    let entry: BudgetWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallBudgetWidget(entry: entry)
        case .systemMedium:
            MediumBudgetWidget(entry: entry)
        default:
            EmptyView()
        }
    }
}

// MARK: - Small Widget
struct SmallBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            budgetSection
            remainingSection
        }
        .padding()
        .widgetURL(URL(string: "brandonsbudget://addPurchase"))
    }
    
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Budget")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(entry.monthlyBudget.asCurrency)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.blue)
        }
    }
    
    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remaining")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(entry.remainingBudget.asCurrency)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(entry.isOverBudget ? .red : .green)
                .accessibilityLabel(createAccessibilityLabel())
        }
        .padding(.top, 8)
    }
}

// MARK: - Medium Widget
struct MediumBudgetWidget: View {
    let entry: BudgetWidgetEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                budgetSection
                remainingSection
            }
            
            Spacer()
            
            addTransactionButton
        }
        .padding()
        .widgetURL(URL(string: "brandonsbudget://addPurchase"))
    }
    
    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly Budget")
                .font(.title3)
                .foregroundColor(.secondary)
            Text(entry.monthlyBudget.asCurrency)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.blue)
        }
    }
    
    private var remainingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remaining")
                .font(.title3)
                .foregroundColor(.secondary)
            Text(entry.remainingBudget.asCurrency)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(entry.isOverBudget ? .red : .green)
        }
        .padding(.top, 8)
    }
    
    private var addTransactionButton: some View {
        Link(destination: URL(string: "brandonsbudget://addPurchase")!) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 88))
            }
            .foregroundColor(.blue)
            .accessibilityLabel("Add new transaction")
        }
    }
    
    private func createAccessibilityLabel() -> String {
        let status = entry.isOverBudget ? "Over budget" : "\(entry.percentageRemaining.formatted(.percent)) remaining"
        return "Monthly budget: \(entry.monthlyBudget.asCurrency). \(status)"
    }
}

// MARK: - Preview Provider
#if DEBUG
struct BudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small Widget - Under Budget
            SmallBudgetWidget(entry: BudgetWidgetEntry(
                date: Date(),
                monthlyBudget: 2000,
                remainingBudget: 1000
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Under Budget")
            
            // Small Widget - Over Budget
            SmallBudgetWidget(entry: BudgetWidgetEntry(
                date: Date(),
                monthlyBudget: 2000,
                remainingBudget: -500
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Over Budget")
            
            // Medium Widget
            MediumBudgetWidget(entry: BudgetWidgetEntry(
                date: Date(),
                monthlyBudget: 2000,
                remainingBudget: 1000
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
        }
    }
}
#endif
