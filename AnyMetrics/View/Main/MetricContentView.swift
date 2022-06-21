//
//  MetricContentView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 18.06.2022.
//

import SwiftUI


fileprivate enum Constants {
    static let titleInset = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    static let lineWidth: CGFloat = 1
    static let cornerParam: CGFloat = { Bundle.isInWidget() ? 12 : 20 }()
    static let fontValue: Font = {
        Font.system(
            size: Bundle.isInWidget() ? 21 : 24,
            weight: .heavy,
            design: .default)
    }()

    static func fontValue(size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: .light,
            design: .default)
    }
    static let fontTitle: Font = {
        Font.system(size: Bundle.isInWidget() ? 17 : 19, weight: .bold, design: .default)
    }()
    static let fontParam: Font = {
        Font.system(size: Bundle.isInWidget() ? 12 : 15, weight: .bold, design: .default)
    }()
    static let valueFrameHeight: CGFloat = {
        Bundle.isInWidget() ? 29 : 42
    }()
    static let spacing: CGFloat = 20
    static let textColor = R.color.metricText.color
    static let strokeColor = R.color.metricText.color
    static let titleBackground = R.color.metricParamBackground.color
    static let secondaryText = R.color.secondaryText.color
    static let valuePaddingInset = EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)
}

struct MetricContentView: View {

    var metric: Metric
    
    var body: some View {
        ZStack(alignment: .center, content: {
            Circle()
                .fill(circleColor())
            VStack(alignment: .center, spacing: Constants.spacing) {

                Text(metric.title)
                    .foregroundColor(Constants.textColor)
                    .font(Constants.fontTitle)
                MetricValue()
                Text(metric.paramName)
                    .font(Constants.fontParam)
                    .foregroundColor(Constants.secondaryText)
                    .multilineTextAlignment(.center)
            }
        })
    }

    @ViewBuilder
    func MetricValue() -> some View {
        if metric.type == .checker {
            Text(
                metric.hasError ? R.string.localizable.metricValueBad() : R.string.localizable.metricValueGood())
            .frame(height: Constants.valueFrameHeight, alignment: .center)
                .font(Constants.fontValue)
                .multilineTextAlignment(.center)
                .foregroundColor(Constants.textColor)
                .padding(Constants.valuePaddingInset)
        } else {
            let value = metric.formattedValue
            Text(value)
                .multilineTextAlignment(.center)
                .lineLimit(0)
                .frame(height: Constants.valueFrameHeight, alignment: .center)
                .font(dynamicFont(for: value))
                .foregroundColor(Constants.textColor)
                .padding(Constants.valuePaddingInset)
        }
    }

    private func circleColor() -> Color {
        if metric.type == .json {
            return R.color.metricDefault.color
        }
        if metric.hasError {
            return R.color.metricBad.color
        }
        return R.color.metricGood.color
    }

    private func dynamicFont(for value: String) -> Font {
        if value.count < 4 {
            return Constants.fontValue(size: 46)
        }
        if value.count < 6 {
            return Constants.fontValue(size: 42)
        }
        if value.count < 10 {
            if Bundle.isInWidget() {
                return Constants.fontValue(size: 34)
            }
            return Constants.fontValue(size: 38)
        }
        if value.count < 15 {
            return Constants.fontValue(size: 24)
        }
        return Constants.fontValue(size: 19)
    }
}

#if DEBUG
struct MetricContentView_Previews: PreviewProvider {
    static var previews: some View {
        MetricContentView(metric: Mocks.metricJson)
            .previewLayout(.sizeThatFits)
            .frame(width: 200, height: 200, alignment: .center)
    }
}
#endif
