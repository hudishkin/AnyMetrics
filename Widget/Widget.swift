//
//  Widget.swift
//  Widget
//
//  Created by Simon Hudishkin on 19.06.2022.
//


import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {

    let store = MetricStore()

    func placeholder(in context: Context) -> AMEntry {
        AMEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            metric: store.metrics.values.first ?? Mocks.metricJson)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (AMEntry) -> ()) {

        var metric: Metric?
        if let _metric = store.metrics.values.first(where: { $0.id.uuidString == configuration.dataSourceType?.identifier }) {
            metric = _metric
        }else {
            metric = Mocks.metricJson
        }

        let entry = AMEntry(date: Date(), configuration: configuration, metric: metric!)
        completion(entry)

    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [AMEntry] = []

        if let id = configuration.dataSourceType?.identifier, let metric = store.metrics[id] {

            Fetcher.updateMetric(metric: metric) { newMetric in
                store.metrics[id] = newMetric
                let currentDate = Date()
                entries.append(AMEntry(date: currentDate, configuration: configuration, metric: metric))
                let timeline = Timeline(entries: entries, policy: .atEnd)
                completion(timeline)
            }

        }else {
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct AMEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let metric: Metric
}


struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color("WidgetBackground")
            MetricContentView(metric: entry.metric)
                .frame(width: 156, height: 156, alignment: .center)
        }


    }
}

@main
struct AMWidget: Widget {
    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: Provider()) { entry in
                WidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Widgets")
            .description("Add widget to home screen with your metric")
            .supportedFamilies([.systemSmall])
    }
}

#if DEBUG
struct AMWidget_Previews: PreviewProvider {
    static var previews: some View {
        WidgetEntryView(entry: AMEntry(date: Date(), configuration: ConfigurationIntent(), metric: Mocks.metricCheck))
            .environment(\.sizeCategory, .small)
    }
}

#endif
