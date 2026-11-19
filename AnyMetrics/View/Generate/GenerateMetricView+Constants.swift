import SwiftUI

extension GenerateMetricView {
    enum Constants {
        static let robotSize: CGFloat = 196
        static let bubbleOverlap: CGFloat = 64
        /// Positive value drops the face below its layout slot.
        static let robotDrop: CGFloat = 28
        static let bubbleWidth: CGFloat = 260
        static let horizontalPadding: CGFloat = 20
        static let chipSpacing: CGFloat = 8
        static let glowHeight: CGFloat = 480
        static let composerCorner: CGFloat = 26
        /// Keeps the bottom slot while the field is hidden, so bubbles stay put.
        static let composerSlot: CGFloat = 60
        static let composerMaxLines = 6
        static let sendButtonSize: CGFloat = 36

        static let examplesFont = Font.system(size: 13, weight: .regular)
        static let chipFont = Font.system(size: 15, weight: .regular)
        static let inputFont = Font.system(size: 16, weight: .regular)

        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let sendIconColor = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        static let chipFill = AnyMetricsAsset.Assets.secondaryText.swiftUIColor.opacity(0.22)
    }
}
