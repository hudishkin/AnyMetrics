import SwiftUI

extension MetricFormView {

    enum Constants {
        static let responseFont = Font.system(size: 12, design: .monospaced)
        static let responseViewMaxHeight: CGFloat = 200
        static let responseViewWidth = UIScreen.main.bounds.width - 42
        static let responseInset = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        static let minusImageName = "minus.circle.fill"
        static let pickerInset = EdgeInsets(top: -20, leading: -20, bottom: -10, trailing: -20)
        static let zero: CGFloat = 0
        static let httpHeadersInset = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)
        static let lengthValueRange = 0...Int.max
        static let mainButtonFont = Font.body.weight(.semibold)

        static let smallFont = Font.system(size: 12, weight: .regular, design: .default)
        static let mainButtonPadding: CGFloat = -16
        static let mainButtonCorner: CGFloat = 40
        static let mainButtonHeight: CGFloat = 52
        static let buttonBackground = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let buttonTextColor = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        static let createNewIcon: CGFloat = 16
        static let requestImage = AnyMetricsAsset.Assets.request.swiftUIImage
        static let imageFAQ = Image(systemName: "questionmark.circle.fill")
        static let faqSize: CGFloat = 20
        static let opacityEnable: CGFloat = 1.0
        static let opacityDisable: CGFloat = 0.4
        static let lengthLabelInset = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        static let lengthLabelBackground = AnyMetricsAsset.Assets.secondaryText.swiftUIColor.opacity(0.5)
        static let lengthLabelCorner: CGFloat = 20
        static let infinityChar = "∞"
        static let circleCheckerSize: CGFloat = 12
        static let circleConfigureSize: CGFloat = 8
        static let checkerGoodBackground = Color.green
        static let checkerBadBackground = Color.red
        static let metricViewSize: CGFloat = 200
        static let metricViewCorner: CGFloat = 42
        static let metricViewPadding: CGFloat = -10
    }
}
