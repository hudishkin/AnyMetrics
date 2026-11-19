import SwiftUI

extension GenerateMetricView {
    enum Constants {
        /// The robot follows the height left above the keyboard, between these bounds.
        static let robotMaxSize: CGFloat = 168
        static let robotMinSize: CGFloat = 104
        static let robotHeightShare: CGFloat = 0.36
        /// Share of the robot size. The bubble tucks under the chin by this much.
        static let bubbleOverlapShare: CGFloat = 0.33
        /// Share of the robot size. Positive value drops the face below its layout slot.
        static let robotDropShare: CGFloat = 0.14
        static let headerTop: CGFloat = 12
        static let bubbleWidth: CGFloat = 260
        static let horizontalPadding: CGFloat = 20
        static let chipSpacing: CGFloat = 8
        static let glowHeight: CGFloat = 480
        static let glowOpacity: CGFloat = 0.5
        /// Over black the pastel mesh reads as a bright patch, so it stays dim and fades over the full height.
        static let glowOpacityDark: CGFloat = 0.24
        static let composerCorner: CGFloat = 26
        /// Keeps the bottom slot while the field is hidden, so bubbles stay put.
        static let composerSlot: CGFloat = 60
        static let composerMaxLines = 6
        static let sendButtonSize: CGFloat = 36

        static let examplesFont = Font.system(size: 13, weight: .regular)
        static let chipFont = Font.system(size: 15, weight: .regular)
        static let inputFont = Font.system(size: 16, weight: .regular)
        static let bubbleFont = Font.system(size: 14, weight: .regular)

        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let sendIconColor = AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        static let chipFill = AnyMetricsAsset.Assets.secondaryText.swiftUIColor.opacity(0.22)
    }
}
