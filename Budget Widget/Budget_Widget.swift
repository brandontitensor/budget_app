//
//  Budget_Widget.swift
//  Budget Widget
//
//  Created by Brandon Titensor on 7/3/24.
//
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), monthlyBudget: 2000, remainingBudget: 1000)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(),
                                monthlyBudget: SharedDataManager.shared.getMonthlyBudget(),
                                remainingBudget: SharedDataManager.shared.getRemainingBudget())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate,
                                    monthlyBudget: SharedDataManager.shared.getMonthlyBudget(),
                                    remainingBudget: SharedDataManager.shared.getRemainingBudget())
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let monthlyBudget: Double
    let remainingBudget: Double
}

struct BudgetWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Budget")
                    .font(.caption)
                Text("$\(entry.monthlyBudget, specifier: "%.2f")")
                    .font(.headline)
                
                Text("Remaining")
                    .font(.caption)
                    .padding(.top, 4)
                Text("$\(entry.remainingBudget, specifier: "%.2f")")
                    .font(.headline)
            }
            
            Spacer()
            
            if widgetFamily != .systemSmall {
                Link(destination: URL(string: "brandonsbudget://addPurchase") ?? URL(string: "https://example.com/fallback")!) {
                    VStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                        Text("Add")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "brandonsbudget://addPurchase"))
    }
}
@main
struct BudgetWidget: Widget {
    let kind: String = "BudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Status")
        .description("Shows your monthly budget and remaining balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BudgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        BudgetWidgetEntryView(entry: SimpleEntry(date: Date(), monthlyBudget: 2000, remainingBudget: 1000))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        
        BudgetWidgetEntryView(entry: SimpleEntry(date: Date(), monthlyBudget: 2000, remainingBudget: 1000))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
