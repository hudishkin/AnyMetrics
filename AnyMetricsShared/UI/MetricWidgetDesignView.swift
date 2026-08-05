#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftUI

public struct MetricWidgetPalette {
    public var textColor: Color
    public var textErrorColor: Color
    public var textSuccessColor: Color
    public var secondaryText: Color
    public var statusGoodLabel: String
    public var statusBadLabel: String
    public var emptyLabel: String
    public var errorLabel: String

    public init(
        textColor: Color,
        textErrorColor: Color,
        textSuccessColor: Color = Color(red: 0.16, green: 0.52, blue: 0.30),
        secondaryText: Color,
        statusGoodLabel: String = "Good",
        statusBadLabel: String = "Bad",
        emptyLabel: String = "N/A",
        errorLabel: String = "Error"
    ) {
        self.textColor = textColor
        self.textErrorColor = textErrorColor
        self.textSuccessColor = textSuccessColor
        self.secondaryText = secondaryText
        self.statusGoodLabel = statusGoodLabel
        self.statusBadLabel = statusBadLabel
        self.emptyLabel = emptyLabel
        self.errorLabel = errorLabel
    }

    public static let preview = MetricWidgetPalette(
        textColor: .black,
        textErrorColor: .red,
        textSuccessColor: Color(red: 0.16, green: 0.52, blue: 0.30),
        secondaryText: .secondary
    )

    public static func widget(bundle: Bundle = Bundle(for: MetricStore.self)) -> MetricWidgetPalette {
        MetricWidgetPalette(
            textColor: Color("metricText", bundle: bundle),
            textErrorColor: Color("red", bundle: bundle),
            secondaryText: Color("secondaryText", bundle: bundle),
            statusGoodLabel: NSLocalizedString("metric.value.good", bundle: bundle, comment: ""),
            statusBadLabel: NSLocalizedString("metric.value.bad", bundle: bundle, comment: ""),
            emptyLabel: NSLocalizedString("metric.value.empty", bundle: bundle, comment: ""),
            errorLabel: NSLocalizedString("metric.value.error", bundle: bundle, comment: "")
        )
    }
}

/// Small-widget / in-app metric cell. Renders via `WidgetAppearance`.
public struct MetricWidgetDesignView: View {

    public let metric: Metric
    public let palette: MetricWidgetPalette
    public let useGlassEffect: Bool
    public let updatedAt: Date?

    public init(
        metric: Metric,
        palette: MetricWidgetPalette,
        useGlassEffect: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.metric = metric
        self.palette = palette
        self.useGlassEffect = useGlassEffect
        self.updatedAt = updatedAt ?? metric.updated
    }

    private var effectiveGlassEffect: Bool {
        useGlassEffect && !Bundle.isInWidget()
    }

    public var body: some View {
        WidgetAppearanceRenderer(
            metric: metric,
            appearance: metric.resolvedAppearance.small,
            palette: palette,
            sizeKey: .small,
            useGlassEffect: effectiveGlassEffect,
            updatedAt: updatedAt
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
struct MetricWidgetDesignView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MetricWidgetDesignView(metric: Mocks.metricJson, palette: .preview, useGlassEffect: true)
                .frame(width: 200, height: 200)
                .previewDisplayName("Glass Circle")

            MetricWidgetDesignView(
                metric: {
                    var metric = Mocks.metricJson
                    metric.widgetDesign = .plain
                    return metric
                }(),
                palette: .preview
            )
            .frame(width: 200, height: 200)
            .previewDisplayName("Plain")
        }
    }
}
#endif
