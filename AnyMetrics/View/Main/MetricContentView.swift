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
    static let textColor = R.color.metricText.color
    static let textErrorColor = R.color.red.color
    static let strokeColor = R.color.metricText.color
    static let titleBackground = R.color.metricParamBackground.color
    static let secondaryText = R.color.secondaryText.color
    static let valuePaddingInset = EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)

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
            Circle()
                .fill(circleGradient())
            Text(metric.title)
                .foregroundColor(Constants.textColor)
                .font(Constants.fontTitle)
                .offset(y: -Constants.labelOffset)
            MetricValue()
            Text(metric.paramName)
                .font(Constants.fontParam)
                .lineLimit(Constants.paramLines)
                .multilineTextAlignment(.center)
                .foregroundColor(Constants.textColor)
                .padding(Constants.paramsInset)
                .offset(y: Constants.labelOffset)
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
            Text(metric.value)
                .multilineTextAlignment(.center)
                .lineLimit(Constants.paramLines)
                .frame(height: Constants.valueFrameHeight, alignment: .center)
                .font(dynamicFont())
                .foregroundColor(metric.hasError ? Constants.textErrorColor : Constants.textColor)
                .padding(Constants.valuePaddingInset)
        }
    }

    private func circleGradient() -> LinearGradient {
        if metric.type != .checker {
            return Constants.defaultCircleGradient
        }
        if metric.hasError {
            return Constants.badCircleGradient
        }
        return Constants.goodCircleGradient
    }


    private func dynamicFont() -> Font {
        if metric.value.count < 4 {
            return Constants.fontValue(size: 42)
        }
        if metric.value.count < 6 {
            return Constants.fontValue(size: 40)
        }
        if metric.value.count < 10 {
            if Bundle.isInWidget() {
                return Constants.fontValue(size: 30)
            }
            return Constants.fontValue(size: 38)
        }
        if metric.value.count < 15 {
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
