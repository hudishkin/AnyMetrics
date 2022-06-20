//
//  MetricContentView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 18.06.2022.
//

import SwiftUI


fileprivate enum Constants {
    static let paramNameInset = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let lineWidth: CGFloat = 1
    static let cornerParam: CGFloat = { Bundle.isInWidget() ? 12 : 20 }()
    static let fontTitle = Font.system(
        size: 15,
        weight: .heavy,
        design: .default)
    static let fontValue: Font = {
        Font.system(
            size: Bundle.isInWidget() ? 21 : 24,
            weight: .heavy,
            design: .default)
    }()
    static let fontParam = Font.system(size: 12, weight: .semibold, design: .default)

    static let spacing: CGFloat = 20
    static let textColor = R.color.metricText.color
    static let strokeColor = R.color.metricText.color
}

struct MetricContentView: View {

    var metric: Metric
    
    var body: some View {
        ZStack(alignment: .center, content: {
            Circle()
                .fill(circleColor())
            VStack(spacing: Constants.spacing) {
                Text(metric.title)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)
                MetricValue()
                Text(metric.paramName)
                    .foregroundColor(Constants.textColor)
                    .font(Constants.fontParam)
                    .padding(Constants.paramNameInset)
                    .overlay(
                        RoundedRectangle(cornerRadius:Constants.cornerParam)
                            .stroke(Constants.strokeColor, lineWidth: Constants.lineWidth)
                        )

            }
        })
    }

    @ViewBuilder
    func MetricValue() -> some View {
        if metric.type == .checker {
            Text(
                metric.hasError ? R.string.localizable.metricValueBad() : R.string.localizable.metricValueGood())
            .font(Constants.fontValue)
                .foregroundColor(Constants.textColor)
        } else {
            Text(metric.formattedValue)
                .font(Constants.fontValue)
                .foregroundColor(Constants.textColor)
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
}

#if DEBUG
struct MetricContentView_Previews: PreviewProvider {
    static var previews: some View {
        MetricContentView(metric: Mocks.metricCheck).previewLayout(.sizeThatFits).frame(width: 200, height: 200, alignment: .leading)
    }
}
#endif
