#if canImport(WidgetKit)
import WidgetKit

private struct WidgetAccentableModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.widgetAccentable()
        } else {
            content
        }
    }
}

private extension View {
    func accentableOnLockScreen() -> some View {
        modifier(WidgetAccentableModifier())
    }
}
#endif
import SwiftUI

public enum MetricWidgetLayout: Sendable {
    case small
    case medium
    case lockCircular
    case lockRectangular
    case lockInline

#if canImport(WidgetKit)
    @available(iOS 16.0, *)
    public static func from(family: WidgetFamily) -> MetricWidgetLayout {
        switch family {
        case .systemMedium:
            return .medium
        case .accessoryCircular:
            return .lockCircular
        case .accessoryRectangular:
            return .lockRectangular
        case .accessoryInline:
            return .lockInline
        default:
            return .small
        }
    }
#endif
}

public struct MetricWidgetAdaptiveView: View {

    public let metric: Metric
    public let palette: MetricWidgetPalette
    public let layout: MetricWidgetLayout
    public let useGlassEffect: Bool
    public let updatedAt: Date?

    @Environment(\.colorScheme) private var colorScheme

    public init(
        metric: Metric,
        palette: MetricWidgetPalette,
        layout: MetricWidgetLayout = .small,
        useGlassEffect: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.metric = metric
        self.palette = palette
        self.layout = layout
        self.useGlassEffect = useGlassEffect
        self.updatedAt = updatedAt ?? metric.updated
    }

    public var body: some View {
        switch layout {
        case .small:
            MetricWidgetDesignView(
                metric: metric,
                palette: palette,
                useGlassEffect: useGlassEffect,
                updatedAt: updatedAt
            )
        case .medium:
            mediumLayout
        case .lockCircular:
            lockCircularLayout
        case .lockRectangular:
            lockRectangularLayout
        case .lockInline:
            lockInlineLayout
        }
    }

    private var valueText: String {
        MetricDisplayHelpers.valueString(
            for: metric,
            goodLabel: palette.statusGoodLabel,
            badLabel: palette.statusBadLabel,
            emptyLabel: palette.emptyLabel,
            errorLabel: palette.errorLabel
        )
    }

    private var isStatusMetric: Bool {
        metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
    }

    private var valueColor: Color {
        if isStatusMetric {
            return metric.resultWithError ? palette.textErrorColor : palette.textSuccessColor
        }
        if showsValueError {
            return palette.textErrorColor
        }
        return palette.textColor
    }

    /// Error styling only when there is no retained value to show.
    private var showsValueError: Bool {
        metric.resultWithError && metric.result.isEmpty
    }

    private var updatedLabel: String? {
        MetricDisplayHelpers.relativeUpdatedString(for: updatedAt)
    }

    private var mediumUsesGradient: Bool {
        (metric.widgetDesign ?? .default).usesMediumGradient
    }

    private var mediumOnDarkGradient: Bool {
        mediumUsesGradient && colorScheme == .dark
    }

    private var mediumTitleColor: Color {
        mediumOnDarkGradient ? Color.white.opacity(0.92) : palette.textColor
    }

    private var mediumSecondaryColor: Color {
        if mediumOnDarkGradient {
            return Color.white.opacity(0.6)
        }
        // Light pastel fill — keep secondary dark for contrast in both themes.
        return mediumUsesGradient ? Color(white: 0.32) : palette.secondaryText
    }

    private var mediumErrorColor: Color {
        if mediumOnDarkGradient {
            return palette.textErrorColor
        }
        // Light pastel fill needs a darker red for contrast.
        return mediumUsesGradient
            ? Color(red: 0.78, green: 0.16, blue: 0.16)
            : palette.textErrorColor
    }

    private var mediumValueColor: Color {
        if isStatusMetric {
            return metric.resultWithError ? mediumErrorColor : palette.textSuccessColor
        }
        if showsValueError {
            return mediumErrorColor
        }
        return mediumOnDarkGradient ? Color.white : palette.textColor
    }

    private var mediumLayout: some View {
        mediumContent
            .modifier(MediumWidgetSurfaceModifier(usesGradient: mediumUsesGradient, metric: metric))
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.title)
                .font(MediumWidgetStyle.titleFont)
                .foregroundColor(mediumTitleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text(valueText)
                .font(mediumValueFont())
                .foregroundColor(mediumValueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            mediumFooterRow
        }
        .padding(MediumWidgetStyle.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var mediumFooterRow: some View {
        let showUpdatedTime = Bundle.isInWidget() && updatedLabel != nil

        if !metric.measure.isEmpty || showUpdatedTime {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !metric.measure.isEmpty {
                    Text(metric.measure)
                        .font(MediumWidgetStyle.measureFont)
                        .foregroundColor(mediumSecondaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                if showUpdatedTime, let updatedLabel {
                    Text(updatedLabel)
                        .font(MediumWidgetStyle.updatedFont)
                        .foregroundColor(mediumSecondaryColor)
                        .lineLimit(1)
                }
            }
            .padding(.top, 4)
        }
    }

    private func mediumValueFont() -> Font {
        let length = valueText.count
        let size: CGFloat
        switch length {
        case ..<4:
            size = MediumWidgetStyle.valueFontSizeLarge
        case ..<6:
            size = MediumWidgetStyle.valueFontSizeMedium
        case ..<10:
            size = MediumWidgetStyle.valueFontSizeSmall
        case ..<15:
            size = MediumWidgetStyle.valueFontSizeCompact
        default:
            size = MediumWidgetStyle.valueFontSizeTiny
        }
        return .system(
            size: size,
            weight: .semibold,
            design: isStatusMetric ? .rounded : .monospaced
        )
    }

    private var lockCircularLayout: some View {
        Text(valueText)
            .font(.system(size: 13, weight: .semibold, design: isStatusMetric ? .rounded : .monospaced))
            .foregroundColor(valueColor)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .accentableOnLockScreen()
    }

    private var lockRectangularLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.caption)
                .foregroundColor(palette.secondaryText)
                .lineLimit(1)
            Text(valueText)
                .font(.system(size: 17, weight: .semibold, design: isStatusMetric ? .rounded : .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accentableOnLockScreen()
            if !metric.measure.isEmpty {
                Text(metric.measure)
                    .font(.caption2)
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var lockInlineLayout: some View {
        Text("\(metric.title): \(valueText)")
            .foregroundColor(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accentableOnLockScreen()
    }
}

private enum MediumWidgetStyle {
    static let titleFont: Font = .system(
        size: Bundle.isInWidget() ? 16 : 17,
        weight: .semibold,
        design: .default
    )

    static let measureFont: Font = .system(
        size: Bundle.isInWidget() ? 12 : 13,
        weight: .medium,
        design: .default
    )

    static let updatedFont: Font = .system(
        size: Bundle.isInWidget() ? 10 : 11,
        weight: .medium,
        design: .default
    )

    static let valueFontSizeLarge: CGFloat = Bundle.isInWidget() ? 44 : 48
    static let valueFontSizeMedium: CGFloat = Bundle.isInWidget() ? 38 : 42
    static let valueFontSizeSmall: CGFloat = Bundle.isInWidget() ? 32 : 36
    static let valueFontSizeCompact: CGFloat = Bundle.isInWidget() ? 26 : 30
    static let valueFontSizeTiny: CGFloat = Bundle.isInWidget() ? 20 : 24

    static let contentPadding = EdgeInsets(
        top: Bundle.isInWidget() ? 14 : 16,
        leading: Bundle.isInWidget() ? 16 : 18,
        bottom: Bundle.isInWidget() ? 12 : 14,
        trailing: Bundle.isInWidget() ? 16 : 18
    )

    static func backgroundGradient(for metric: Metric, colorScheme: ColorScheme) -> LinearGradient {
        let isDark = colorScheme == .dark
        let hasStatusRule = metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
        let showsValueError = metric.resultWithError && metric.result.isEmpty

        if hasStatusRule || metric.type == .checkStatus {
            if metric.resultWithError {
                return isDark ? darkBadGradient : lightBadGradient
            }
            return isDark ? darkGoodGradient : lightGoodGradient
        }

        if showsValueError {
            return isDark ? darkBadGradient : lightBadGradient
        }

        return isDark ? darkDefaultGradient : lightDefaultGradient
    }

    private static let lightDefaultGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.95, blue: 0.75),
            Color(red: 0.88, green: 0.96, blue: 0.82),
            Color(red: 0.96, green: 0.84, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let darkDefaultGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.12, blue: 0.10),
            Color(red: 0.08, green: 0.22, blue: 0.14),
            Color(red: 0.28, green: 0.10, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let lightGoodGradient = LinearGradient(
        colors: [
            Color(red: 0.87, green: 0.96, blue: 0.80),
            Color(red: 0.71, green: 0.87, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let darkGoodGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.22, blue: 0.12),
            Color(red: 0.14, green: 0.28, blue: 0.16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let lightBadGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.91, blue: 0.89),
            Color(red: 0.92, green: 0.72, blue: 0.67)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let darkBadGradient = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.12, blue: 0.10),
            Color(red: 0.32, green: 0.14, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct MediumWidgetSurfaceModifier: ViewModifier {
    let usesGradient: Bool
    let metric: Metric

    @Environment(\.colorScheme)
    private var colorScheme

    func body(content: Content) -> some View {
        guard Bundle.isInWidget() else {
            return AnyView(
                content.background(appBackground)
            )
        }

        if #available(iOS 17.0, *) {
            return AnyView(
                content.modifier(MediumWidgetSurfaceModifierIOS17(
                    usesGradient: usesGradient,
                    metric: metric,
                    colorScheme: colorScheme
                ))
            )
        }

        return AnyView(
            content.background(widgetBackground)
        )
    }

    @ViewBuilder
    private var appBackground: some View {
        if usesGradient {
            MediumWidgetStyle.backgroundGradient(for: metric, colorScheme: colorScheme)
        } else {
            Color(uiColor: .secondarySystemBackground)
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if usesGradient {
            MediumWidgetStyle.backgroundGradient(for: metric, colorScheme: colorScheme)
        } else {
            Color("WidgetBackground")
        }
    }
}

@available(iOS 17.0, *)
private struct MediumWidgetSurfaceModifierIOS17: ViewModifier {
    let usesGradient: Bool
    let metric: Metric
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        if usesGradient {
            content.containerBackground(
                MediumWidgetStyle.backgroundGradient(for: metric, colorScheme: colorScheme),
                for: .widget
            )
        } else {
            content.containerBackground(Color("WidgetBackground"), for: .widget)
        }
    }
}

#if DEBUG
struct MetricWidgetAdaptiveView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MetricWidgetAdaptiveView(
                metric: Mocks.metricJson,
                palette: .preview,
                layout: .medium,
                updatedAt: Date().addingTimeInterval(-120)
            )
            .frame(width: 329, height: 155)
            .previewDisplayName("Medium Gradient")

            MetricWidgetAdaptiveView(
                metric: {
                    var metric = Mocks.metricJson
                    metric.widgetDesign = .plain
                    return metric
                }(),
                palette: .preview,
                layout: .medium,
                updatedAt: Date().addingTimeInterval(-3600)
            )
            .frame(width: 329, height: 155)
            .previewDisplayName("Medium Plain")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
