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

    private static var neutralPlaceholder: Metric {
        Metric(
            id: UUID(),
            title: "",
            measure: "",
            type: .json,
            result: "",
            resultWithError: false
        )
    }

    private func metric(for configuration: ConfigurationIntent, store: MetricStore) -> Metric? {
        guard let id = configuration.dataSourceType?.identifier,
              let uuid = UUID(uuidString: id)
        else { return nil }
        return store.metrics[uuid]
    }

    func placeholder(in context: Context) -> AMEntry {
        // No intent here — never flash an unrelated store metric.
        AMEntry(date: Date(), configuration: ConfigurationIntent(), metric: Self.neutralPlaceholder)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (AMEntry) -> ()) {
        let store = MetricStore()
        let selected = metric(for: configuration, store: store)
        // If a metric was selected but deleted, don't substitute another user's metric.
        var resolved = selected ?? (configuration.dataSourceType == nil ? store.metrics.values.first : nil) ?? Self.neutralPlaceholder
        Metric.materializeWidgetBackgrounds(resolved) { materialized in
            completion(AMEntry(date: Date(), configuration: configuration, metric: materialized))
        }
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let store = MetricStore()
        guard let metric = metric(for: configuration, store: store) else {
            let entry = AMEntry(date: Date(), configuration: configuration, metric: Self.neutralPlaceholder)
            completion(Timeline(entries: [entry], policy: .atEnd))
            return
        }

        Metric.materializeWidgetBackgrounds(metric) { materialized in
            store.addMetric(metric: materialized)

            Fetcher.updateMetric(metric: materialized) { newMetric in
                Metric.materializeWidgetBackgrounds(newMetric) { resolved in
                    store.addMetric(metric: resolved)
                    let currentDate = Date()
                    let entry = AMEntry(date: currentDate, configuration: configuration, metric: resolved)

                    let policy: TimelineReloadPolicy
                    if let interval = resolved.interval, interval > 0 {
                        policy = .after(currentDate.addingTimeInterval(TimeInterval(interval)))
                    } else {
                        policy = .atEnd
                    }
                    completion(Timeline(entries: [entry], policy: policy))
                }
            }
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
            useGlassEffect: glassEffect,
            updatedAt: entry.metric.updated
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetContainerBackground()
    }

    private var widgetLayout: MetricWidgetLayout {
        if #available(iOS 16.0, *) {
            return MetricWidgetLayout.from(family: family)
        }
        return family == .systemMedium ? .medium : .small
    }

    private var glassEffect: Bool {
        let appearance = entry.metric.resolvedAppearance
        switch widgetLayout {
        case .medium:
            return appearance.medium.background.usesGlassEffect
        case .small:
            return appearance.small.background.usesGlassEffect
        case .lockCircular, .lockRectangular, .lockInline:
            return false
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
    /// Required on iOS 17+; without it Home Screen shows "Please adopt containerBackground API".
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            // Clear: designed fills (gradient / photo / glass) draw in content;
            // lock-screen accessories also expect a removable clear container.
            containerBackground(.clear, for: .widget)
        } else {
            self
        }
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
