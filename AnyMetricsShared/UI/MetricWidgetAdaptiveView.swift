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
            WidgetAppearanceRenderer(
                metric: metric,
                appearance: metric.resolvedAppearance.medium,
                palette: palette,
                sizeKey: .medium,
                useGlassEffect: false,
                updatedAt: updatedAt
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if metric.resultWithError && metric.result.isEmpty {
            return palette.textErrorColor
        }
        return palette.textColor
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
            if !metric.title.isEmpty {
                Text(metric.title)
                    .font(.caption)
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
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
        Text(metric.title.isEmpty ? valueText : "\(metric.title): \(valueText)")
            .foregroundColor(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accentableOnLockScreen()
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
