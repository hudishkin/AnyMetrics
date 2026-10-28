import Foundation
import AnyMetricsShared

enum StarterMetric {
    /// People in Space — gallery preset `a3b4c5d6-e7f8-4a9b-0c1d-2e3f4a5b6c7d`.
    static let id = UUID(uuidString: "A3B4C5D6-E7F8-4A9B-0C1D-2E3F4A5B6C7D")!
    /// Former default Quote of the Day; still treated as a starter for review prompts.
    static let quoteOfTheDayID = UUID(uuidString: "B9E3E57C-A3AA-46D9-8537-0E5C22C07E3A")!
    /// Former default Picture of the Day; still treated as a starter for review prompts.
    static let pictureOfTheDayID = UUID(uuidString: "81C8A603-E56E-486F-8A81-B7EF404482EC")!
    static let legacyID = UUID(uuidString: "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")!

    static func isStarter(_ id: UUID) -> Bool {
        id == Self.id || id == quoteOfTheDayID || id == pictureOfTheDayID || id == legacyID
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
                url: URL(string: "http://api.open-notify.org/astros.json")!
            ),
            formatter: MetricValueFormatter(format: .currency, fraction: 0),
            rules: ParseRules(parseRules: "number"),
            author: "Open Notify",
            website: URL(string: "http://open-notify.org")!,
            interval: 21600,
            widgetDesign: WidgetDesign.roundedCard,
            widgetAppearance: appearance(for: .space)
        )
    }

    /// Backgrounds offered for the starter widget. `mono` is the only colorless option.
    enum QuoteStyle: String, CaseIterable, Identifiable {
        case space
        case haze
        case wave
        case tide
        case gleam
        case nebula
        case comet
        case eclipse
        case dusk
        case sunset
        case ocean
        case aurora
        case mono

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .space: return AnyMetricsStrings.Onboarding.Gradient.space
            case .haze: return AnyMetricsStrings.Onboarding.Gradient.haze
            case .wave: return AnyMetricsStrings.Onboarding.Gradient.wave
            case .tide: return AnyMetricsStrings.Onboarding.Gradient.tide
            case .gleam: return AnyMetricsStrings.Onboarding.Gradient.gleam
            case .nebula: return AnyMetricsStrings.Onboarding.Gradient.nebula
            case .comet: return AnyMetricsStrings.Onboarding.Gradient.comet
            case .eclipse: return AnyMetricsStrings.Onboarding.Gradient.eclipse
            case .dusk: return AnyMetricsStrings.Onboarding.Gradient.dusk
            case .sunset: return AnyMetricsStrings.Onboarding.Gradient.sunset
            case .ocean: return AnyMetricsStrings.Onboarding.Gradient.ocean
            case .aurora: return AnyMetricsStrings.Onboarding.Gradient.aurora
            case .mono: return AnyMetricsStrings.Onboarding.Gradient.mono
            }
        }

        /// Field, mid, accent. Accent stays in a corner so white type keeps a dark center.
        var colors: [String] {
            switch self {
            case .space:
                // Void, indigo, atmospheric cyan.
                return ["#020617", "#312E81", "#22D3EE"]
            case .haze:
                return ["#E9D5FF", "#FDBA74", "#FB923C"]
            case .wave:
                return ["#FFE6C4", "#FFE14A", "#FF2D78"]
            case .tide:
                return ["#A5F3FC", "#1D4ED8", "#6B3058"]
            case .gleam:
                return ["#4C1D95", "#D946EF", "#2563EB"]
            case .nebula:
                return ["#0B1026", "#4C1D95", "#DB2777"]
            case .comet:
                return ["#020617", "#0C4A6E", "#38BDF8"]
            case .eclipse:
                return ["#0C0A09", "#7C2D12", "#EA580C"]
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

        var mesh: WidgetMeshVariant? {
            switch self {
            case .space: return .cosmos
            case .haze: return .haze
            case .wave: return .wave
            case .tide: return .tide
            case .gleam: return .gleam
            case .nebula: return .bloom
            case .comet: return .ribbon
            case .eclipse: return .orbit
            case .dusk, .sunset, .ocean, .aurora, .mono: return nil
            }
        }

        /// Light meshes need dark type. The value sits in the bright part of the field.
        var usesDarkText: Bool {
            switch self {
            case .haze, .wave: return true
            default: return false
            }
        }
    }

    /// Gallery presets ship without a look. Give each one a designed gradient instead of the flat status fill.
    static func applyingCollectionGradient(to metric: Metric) -> Metric {
        guard metric.widgetAppearance == nil else { return metric }
        var copy = metric
        copy.widgetAppearance = appearance(for: collectionStyle(for: metric.id))
        copy.widgetDesign = .roundedCard
        return copy
    }

    /// Same metric keeps the same background. People in Space matches the starter.
    static func collectionStyle(for id: UUID) -> QuoteStyle {
        if id == Self.id { return .space }
        let styles = QuoteStyle.allCases.filter { $0 != .mono }
        let uuid = id.uuid
        let bytes: [UInt8] = [
            uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15
        ]
        let hash = bytes.reduce(UInt32(2166136261)) { ($0 ^ UInt32($1)) &* 16777619 }
        return styles[Int(hash % UInt32(styles.count))]
    }

    static func appearance(for style: QuoteStyle) -> WidgetAppearance {
        var appearance = WidgetAppearance.roundedCard
        let gradient = WidgetGradientSpec(
            colors: style.colors.map { .hex($0) },
            startX: 1,
            startY: 0,
            endX: 0,
            endY: 1,
            mesh: style.mesh
        )
        appearance.small.background.fill = .gradient(gradient)
        appearance.medium.background.fill = .gradient(gradient)
        appearance.small.elements = tinted(appearance.small.elements, style: style)
        appearance.medium.elements = tinted(appearance.medium.elements, style: style)
        appearance.presetId = WidgetAppearancePreset.custom.rawValue
        return appearance
    }

    private static func tinted(_ elements: [WidgetElementSpec], style: QuoteStyle) -> [WidgetElementSpec] {
        let primary = style.usesDarkText ? "#1C1917" : "#FFFFFF"
        let secondary = style.usesDarkText ? "#B31C1917" : "#E6FFFFFF"
        return elements.map { element in
            var copy = element
            switch element.kind {
            case .title, .value:
                copy.color = .hex(primary)
            case .measure, .updated:
                copy.color = .hex(secondary)
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
