import SwiftUI

public struct MetricContentView: View {

    public var metric: Metric

    public init(metric: Metric) {
        self.metric = metric
    }

    public var body: some View {
        MetricWidgetDesignView(
            metric: metric,
            palette: .widget(),
            useGlassEffect: (metric.widgetDesign ?? .default) == .glassCircle && !Bundle.isInWidget()
        )
    }
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
