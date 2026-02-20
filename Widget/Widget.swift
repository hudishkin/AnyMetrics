//
//  Widget.swift
//  Widget
//
//  Created by Simon Hudishkin on 19.06.2022.
//


import WidgetKit
import SwiftUI
import Intents
import AnyMetricsShared

struct Provider: IntentTimelineProvider {

    func placeholder(in context: Context) -> AMEntry {
        AMEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            metric: MetricStore().metrics.values.first ?? Mocks.metricEmpty)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (AMEntry) -> ()) {

        if let metric = MetricStore().metrics.values.first(where: { $0.id.uuidString == configuration.dataSourceType?.identifier }) {
            let entry = AMEntry(date: Date(), configuration: configuration, metric: metric)
            completion(entry)
        }
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [AMEntry] = []

        let store = MetricStore()
        if
            let id = configuration.dataSourceType?.identifier,
                let uuid = UUID(uuidString: id),
                let metric = store.metrics[uuid] {

            Fetcher.updateMetric(metric: metric) { newMetric in
                store.addMetric(metric: newMetric)
                let currentDate = Date()
                entries.append(AMEntry(date: currentDate, configuration: configuration, metric: newMetric))

                let policy: TimelineReloadPolicy
                if let interval = newMetric.interval, interval > 0 {
                    policy = .after(currentDate.addingTimeInterval(TimeInterval(interval)))
                } else {
                    policy = .atEnd
                }
                let timeline = Timeline(entries: entries, policy: policy)
                completion(timeline)
            }
        } else {
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
            MetricContentView(metric: entry.metric)
                .frame(width: 156, height: 156, alignment: .center)
        }
        .widgetBackground(Color("WidgetBackground"))
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            self
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
