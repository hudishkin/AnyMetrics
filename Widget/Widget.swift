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

        // Opening the app already refreshed this metric and called reloadAllTimelines().
        // Fetching again here leaves the previous lock-screen entry (with the stale mark)
        // up until the extension's own request returns.
        if metric.isReadyForWidgetDisplay() {
            completion(Self.timeline(metric: metric, configuration: configuration, at: Date()))
            return
        }

        Fetcher.updateMetric(metric: metric) { fetched in
            Metric.materializeWidgetBackgrounds(fetched) { resolved in
                let saved = store.saveRefresh(resolved)
                let display = store.metrics[saved.id] ?? saved
                completion(Self.timeline(metric: display, configuration: configuration, at: Date()))
            }
        }
    }

    private static func timeline(metric: Metric, configuration: ConfigurationIntent, at date: Date) -> Timeline<AMEntry> {
        let entry = AMEntry(date: date, configuration: configuration, metric: metric)
        let policy: TimelineReloadPolicy
        if let interval = metric.interval, interval > 0 {
            policy = .after(date.addingTimeInterval(TimeInterval(interval)))
        } else {
            policy = .atEnd
        }
        return Timeline(entries: [entry], policy: policy)
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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetContainerBackground()
    }

    @ViewBuilder
    private var content: some View {
        if showsRobotPlaceholder {
            EmptyMetricWidget()
        } else {
            MetricWidgetAdaptiveView(
                metric: entry.metric,
                palette: .widget(),
                layout: widgetLayout,
                useGlassEffect: glassEffect,
                updatedAt: entry.metric.updated
            )
        }
    }

    /// Unconfigured home-screen widget: no title and no value yet.
    private var showsRobotPlaceholder: Bool {
        guard isHomeScreen else { return false }
        let metric = entry.metric
        return metric.title.isEmpty
            && metric.result.isEmpty
            && metric.resultImagePath == nil
            && !metric.refreshFailed
            && !metric.resultWithError
    }

    private var isHomeScreen: Bool {
        switch family {
        case .systemSmall, .systemMedium:
            return true
        default:
            return false
        }
    }

    private var widgetLayout: MetricWidgetLayout {
        MetricWidgetLayout.from(family: family)
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
        [
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ]
    }
}

private struct EmptyMetricWidget: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                WidgetGradientFill(colors: Self.hazeFallback, mesh: .haze)
                RobotFaceView(size: side * 0.84, kind: .glance, ink: .white, filled: false, animated: false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AnyMetrics")
    }

    /// Linear ramp for systems without mesh gradients (before iOS 18).
    private static let hazeFallback: [Color] = [
        Color(red: 0.91, green: 0.84, blue: 1.0),
        Color(red: 0.99, green: 0.73, blue: 0.45),
        Color(red: 0.98, green: 0.57, blue: 0.24)
    ]
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
        WidgetEntryView(entry: AMEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            metric: Metric(id: UUID(), title: "", measure: "", type: .json, result: "")
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .previewDisplayName("Empty")
    }
}
#endif
