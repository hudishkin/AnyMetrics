import SwiftUI
import AnyMetricsShared

fileprivate enum Constants {
    static let titleInset = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    static let lineWidth: CGFloat = 1
    static let cornerParam: CGFloat = { Bundle.isInWidget() ? 12 : 20 }()
    static let fontValue: Font = {
        Font.system(
            size: Bundle.isInWidget() ? 28 : 34,
            weight: .heavy,
            design: .default)
    }()

    static func fontValue(size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: (size < 25 ? .regular : .light),
            design: .default)
    }
    static let fontTitle: Font = {
        Font.system(size: Bundle.isInWidget() ? 17 : 19, weight: .bold, design: .default)
    }()
    static let fontParam: Font = {
        Font.system(size: Bundle.isInWidget() ? 12 : 14, weight: .regular, design: .default)
    }()
    static let paramsInset = EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30)
    static let valueFrameHeight: CGFloat = {
        Bundle.isInWidget() ? 29 : 40
    }()

    static let labelOffset: CGFloat = {
        Bundle.isInWidget() ? 48 : 54
    }()
    static let spacing: CGFloat = 20
    #if WIDGET_EXTENSION
    static let textColor = WidgetExtensionAsset.metricText.swiftUIColor
    static let textErrorColor = WidgetExtensionAsset.red.swiftUIColor
    static let strokeColor = WidgetExtensionAsset.metricText.swiftUIColor
    static let titleBackground = WidgetExtensionAsset.metricParamBackground.swiftUIColor
    static let secondaryText = WidgetExtensionAsset.secondaryText.swiftUIColor
    #else
    static let textColor = AnyMetricsAsset.Assets.metricText.swiftUIColor
    static let textErrorColor = AnyMetricsAsset.Assets.red.swiftUIColor
    static let strokeColor = AnyMetricsAsset.Assets.metricText.swiftUIColor
    static let titleBackground = AnyMetricsAsset.Assets.metricParamBackground.swiftUIColor
    static let secondaryText = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    #endif
    static let valuePaddingInset = EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)

    static let titlePaddingInset = EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30)

    static let defaultCircleGradient: LinearGradient = {
        let colors = [
            Color(red: 0.961, green: 0.835, blue: 0.808),
            Color(red: 0.98, green: 0.89, blue: 0.714),
            Color(red: 0.911, green: 0.992, blue: 0.847),
            Color(red: 0.886, green: 0.949, blue: 0.973)
        ]
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: UnitPoint.topTrailing, endPoint: UnitPoint.bottomLeading)
    }()

    static let goodCircleGradient: LinearGradient = {
        let colors = [
            Color(red: 0.873, green: 0.962, blue: 0.802),
            Color(red: 0.709, green: 0.871, blue: 0.577)
        ]
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: UnitPoint.topTrailing, endPoint: UnitPoint.bottomLeading)
    }()

    static let badCircleGradient: LinearGradient = {
        let colors = [
            Color(red: 1, green: 0.908, blue: 0.887),
            Color(red: 0.917, green: 0.716, blue: 0.672)
        ]
        return LinearGradient(gradient: Gradient(colors: colors), startPoint: UnitPoint.topTrailing, endPoint: UnitPoint.bottomLeading)
    }()

    static let paramLines: Int = 2
}

struct MetricContentView: View {

    var metric: Metric
    
    var body: some View {
        ZStack(alignment: .center, content: {
            glassCircle()
            Text(metric.title)
                .foregroundColor(Constants.textColor)
                .font(Constants.fontTitle)
                .offset(y: -Constants.labelOffset)
                .lineLimit(Constants.paramLines)
                .padding(Constants.titlePaddingInset)
            MetricValue()
            Text(metric.measure)
                .font(Constants.fontParam)
                .lineLimit(Constants.paramLines)
                .multilineTextAlignment(.center)
                .foregroundColor(Constants.textColor)
                .padding(Constants.paramsInset)
                .offset(y: Constants.labelOffset)
        })
        .contentShape(Circle())
    }

    @ViewBuilder
    private func glassCircle() -> some View {
        if #available(iOS 16.0, *) {
            Circle()
                .fill(circleGradient())
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.45)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.7),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        } else {
            Circle()
                .fill(circleGradient())
        }
    }

    @ViewBuilder
    func MetricValue() -> some View {
        if metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none) {
            Text(
                metric.resultWithError ? metricValueBad() : metricValueGood())
            .frame(height: Constants.valueFrameHeight, alignment: .center)
                .font(Constants.fontValue)
                .multilineTextAlignment(.center)
                .foregroundColor(Constants.textColor)
                .padding(Constants.valuePaddingInset)
        } else {
            Text(metric.result)
                .multilineTextAlignment(.center)
                .lineLimit(Constants.paramLines)
                .frame(height: Constants.valueFrameHeight, alignment: .center)
                .font(dynamicFont())
                .foregroundColor(metric.resultWithError ? Constants.textErrorColor : Constants.textColor)
                .padding(Constants.valuePaddingInset)
        }
    }

    private func circleGradient() -> LinearGradient {
        if metric.type != .checkStatus && ((metric.rules?.type ?? ParseRules.RuleType.none) == .none) {
            return Constants.defaultCircleGradient
        }
        if metric.resultWithError {
            return Constants.badCircleGradient
        }
        return Constants.goodCircleGradient
    }

    private func metricValueBad() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Value.bad
        #else
        AnyMetricsStrings.Metric.Value.bad
        #endif
    }

    private func metricValueGood() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Value.good
        #else
        AnyMetricsStrings.Metric.Value.good
        #endif
    }


    private func dynamicFont() -> Font {
        if metric.result.count < 4 {
            return Constants.fontValue(size: 42)
        }
        if metric.result.count < 6 {
            return Constants.fontValue(size: 40)
        }
        if metric.result.count < 10 {
            if Bundle.isInWidget() {
                return Constants.fontValue(size: 30)
            }
            return Constants.fontValue(size: 34)
        }
        if metric.result.count < 15 {
            return Constants.fontValue(size: 24)
        }
        return Constants.fontValue(size: 19)
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
