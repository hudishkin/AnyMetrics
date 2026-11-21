import SwiftUI

extension TopUpView {
    enum Constants {
        static let cardCorner: CGFloat = 18
        static let buttonCorner: CGFloat = 30
        static let horizontalPadding: CGFloat = 24
        static let glowHeight: CGFloat = 360
        static let robotSize: CGFloat = 60
        /// Check mark width plus its spacing, so badges line up with the pack title.
        static let checkColumn: CGFloat = 36
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let buttonText = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        static let chipFill = AnyMetricsAsset.Assets.secondaryText.swiftUIColor.opacity(0.22)
        /// Dark type stays readable on the pastel badge in both color schemes.
        static let badgeInk = Color(red: 0.18, green: 0.12, blue: 0.08)
        static let fontTitle = Font.system(size: 26, weight: .bold, design: .default)
        static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let fontRow = Font.system(size: 18, weight: .semibold, design: .default)
        static let fontPrice = Font.system(size: 18, weight: .semibold, design: .default)
        static let fontCaption = Font.system(size: 14, weight: .regular, design: .default)
        static let fontBenefit = Font.system(size: 14, weight: .regular, design: .default)
        static let fontLegal = Font.system(size: 12, weight: .regular, design: .default)
        static let fontBadge = Font.system(size: 12, weight: .semibold, design: .default)
        static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)

        static let accent = Gradient(colors: [
            Color(red: 0.74, green: 0.84, blue: 0.48),
            Color(red: 0.95, green: 0.84, blue: 0.32),
            Color(red: 0.96, green: 0.74, blue: 0.48)
        ])
    }
}
