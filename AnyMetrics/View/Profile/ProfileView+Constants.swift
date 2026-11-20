import SwiftUI

extension ProfileView {
    enum Constants {
        static let avatarSize: CGFloat = 72
        static let iconSize: CGFloat = 96
        static let iconCorner: CGFloat = 22
        static let cardCorner: CGFloat = 18
        static let buttonCorner: CGFloat = 30
        static let horizontalPadding: CGFloat = 24
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let fontTitle = Font.system(size: 28, weight: .semibold, design: .default)
        static let fontBody = Font.system(size: 16, weight: .regular, design: .default)
        static let fontRow = Font.system(size: 17, weight: .medium, design: .default)
        static let fontValue = Font.system(size: 15, weight: .regular, design: .default)
        static let avatarInitial = Color(red: 0.18, green: 0.12, blue: 0.08)
        static let avatarGradient = LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.90, blue: 0.74),
                Color(red: 0.98, green: 0.82, blue: 0.32),
                Color(red: 1.0, green: 0.52, blue: 0.24),
                Color(red: 0.55, green: 0.84, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
