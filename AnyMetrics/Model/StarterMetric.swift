import Foundation
import AnyMetricsShared

enum StarterMetric {
    /// Quote of the Day — gallery preset `b9e3e57c-a3aa-46d9-8537-0e5c22c07e3a`.
    static let id = UUID(uuidString: "B9E3E57C-A3AA-46D9-8537-0E5C22C07E3A")!
    /// Former default Picture of the Day; still treated as a starter for review prompts.
    static let pictureOfTheDayID = UUID(uuidString: "81C8A603-E56E-486F-8A81-B7EF404482EC")!
    static let legacyID = UUID(uuidString: "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")!

    static func isStarter(_ id: UUID) -> Bool {
        id == Self.id || id == pictureOfTheDayID || id == legacyID
    }

    static func make() -> Metric {
        Metric(
            id: id,
            title: AnyMetricsStrings.StarterMetric.title,
            measure: AnyMetricsStrings.StarterMetric.measure,
            type: .json,
            request: RequestData(
                headers: [:],
                method: "GET",
                url: URL(string: "https://zenquotes.io/api/today")!
            ),
            rules: ParseRules(parseRules: "0.q"),
            author: "ZenQuotes",
            website: URL(string: "https://zenquotes.io/")!,
            interval: 86400,
            widgetDesign: WidgetDesign.roundedCard,
            widgetAppearance: .preset(WidgetDesign.roundedCard)
        )
    }

    @discardableResult
    static func installIfNeeded(_ metric: Metric = make(), in store: MetricStore) -> Metric {
        if let existing = store.metrics[metric.id] {
            return existing
        }

        store.addMetric(metric: metric)
        return metric
    }
}
