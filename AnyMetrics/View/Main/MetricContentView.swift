import SwiftUI
import AnyMetricsShared

struct MetricContentView: View {

    var metric: Metric

    var body: some View {
        MetricWidgetDesignView(
            metric: metric,
            palette: .init(
                textColor: Constants.textColor,
                textErrorColor: Constants.textErrorColor,
                secondaryText: Constants.secondaryText,
                statusGoodLabel: Constants.statusGoodLabel,
                statusBadLabel: Constants.statusBadLabel
            ),
            useGlassEffect: (metric.widgetDesign ?? .default) == .glassCircle
        )
    }
}

fileprivate enum Constants {
    #if WIDGET_EXTENSION
    static let textColor = WidgetExtensionAsset.metricText.swiftUIColor
    static let textErrorColor = WidgetExtensionAsset.red.swiftUIColor
    static let secondaryText = WidgetExtensionAsset.secondaryText.swiftUIColor
    static let statusGoodLabel = WidgetExtensionStrings.Metric.Value.good
    static let statusBadLabel = WidgetExtensionStrings.Metric.Value.bad
    #else
    static let textColor = AnyMetricsAsset.Assets.metricText.swiftUIColor
    static let textErrorColor = AnyMetricsAsset.Assets.red.swiftUIColor
    static let secondaryText = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let statusGoodLabel = AnyMetricsStrings.Metric.Value.good
    static let statusBadLabel = AnyMetricsStrings.Metric.Value.bad
    #endif
}

#if DEBUG
struct MetricContentView_Previews: PreviewProvider {
    static var previews: some View {
        MetricContentView(metric: Mocks.metricJsonWithError)
            .previewLayout(.sizeThatFits)
            .frame(width: 200, height: 200, alignment: .center)
        MetricContentView(metric: Mocks.metricJson)
            .previewLayout(.sizeThatFits)
            .frame(width: 200, height: 200, alignment: .center)

        MetricContentView(metric: Mocks.metricCheckWithError)
            .previewLayout(.sizeThatFits)
            .frame(width: 200, height: 200, alignment: .center)

        MetricContentView(metric: Mocks.metricCheck)
            .previewLayout(.sizeThatFits)
            .frame(width: 200, height: 200, alignment: .center)
    }
}
#endif
