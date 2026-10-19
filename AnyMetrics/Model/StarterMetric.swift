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
            widgetAppearance: appearance(for: .dusk)
        )
    }

    /// Backgrounds offered for the quote widget. `mono` is the only colorless option.
    enum QuoteStyle: String, CaseIterable, Identifiable {
        case dusk
        case sunset
        case ocean
        case aurora
        case mono

        var id: String { rawValue }

        var localizationKey: String { "onboarding.gradient.\(rawValue)" }

        var colors: [String] {
            switch self {
            case .dusk:
                return ["#7C3AED", "#E11D48", "#312E81"]
            case .sunset:
                return ["#C2410C", "#BE123C", "#4C0519"]
            case .ocean:
                return ["#0F766E", "#1D4ED8", "#0F172A"]
            case .aurora:
                return ["#6D28D9", "#DB2777", "#0E7490"]
            case .mono:
                return ["#636366", "#2C2C2E", "#1C1C1E"]
            }
        }
    }

    static func appearance(for style: QuoteStyle) -> WidgetAppearance {
        var appearance = WidgetAppearance.roundedCard
        let gradient = WidgetGradientSpec(
            colors: style.colors.map { .hex($0) },
            startX: 1,
            startY: 0,
            endX: 0,
            endY: 1
        )
        appearance.small.background.fill = .gradient(gradient)
        appearance.medium.background.fill = .gradient(gradient)
        appearance.small.elements = tintedForGradient(appearance.small.elements)
        appearance.medium.elements = tintedForGradient(appearance.medium.elements)
        appearance.presetId = WidgetAppearancePreset.custom.rawValue
        return appearance
    }

    private static func tintedForGradient(_ elements: [WidgetElementSpec]) -> [WidgetElementSpec] {
        elements.map { element in
            var copy = element
            switch element.kind {
            case .title, .value:
                copy.color = .hex("#FFFFFF")
            case .measure, .updated:
                copy.color = .hex("#E6FFFFFF")
            }
            return copy
        }
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
