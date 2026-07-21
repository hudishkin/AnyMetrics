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
        let store = MetricStore()
        let metric = store.metrics.values.first(where: { $0.id.uuidString == configuration.dataSourceType?.identifier })
            ?? store.metrics.values.first
            ?? Mocks.metricEmpty
        completion(AMEntry(date: Date(), configuration: configuration, metric: metric))
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

struct WidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily)
    private var family

    var body: some View {
        MetricWidgetAdaptiveView(
            metric: entry.metric,
            palette: .widget(),
            layout: widgetLayout,
            useGlassEffect: false,
            updatedAt: entry.date
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetContainerBackground(for: family)
    }

    private var widgetLayout: MetricWidgetLayout {
        if #available(iOS 16.0, *) {
            return MetricWidgetLayout.from(family: family)
        }
        return family == .systemMedium ? .medium : .small
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
            .supportedFamilies(supportedFamilies)
            .contentMarginsDisabled()
    }

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [
                .systemSmall,
                .systemMedium,
                .accessoryCircular,
                .accessoryRectangular,
                .accessoryInline
            ]
        }
        return [.systemSmall, .systemMedium]
    }
}

private extension View {
    func widgetContainerBackground(for family: WidgetFamily) -> some View {
        self
    }
}

#if DEBUG
struct AMWidget_Previews: PreviewProvider {
    static var previews: some View {
        WidgetEntryView(entry: AMEntry(date: Date(), configuration: ConfigurationIntent(), metric: Mocks.metricJson))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        WidgetEntryView(entry: AMEntry(date: Date(), configuration: ConfigurationIntent(), metric: Mocks.metricJson))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif
