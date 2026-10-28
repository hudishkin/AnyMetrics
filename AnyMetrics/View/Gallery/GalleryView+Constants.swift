import Foundation
import SwiftUI

extension GalleryView {
    enum Constants {
        static let addButtonInset = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        static let addButtonCorner: CGFloat = 20
        static let itemTitleFont = Font.system(size: 17, weight: .semibold, design: .default)
        static let itemDefaultFont = Font.system(size: 12, weight: .regular, design: .default)
        static let itemDefaultBoldFont = Font.system(size: 12, weight: .semibold, design: .default)

        static let itemButtonOffset = CGSize(width: -10, height: 10)
        static let itemButtonSize: CGFloat = 46
        static let itemAddButtonCorner: CGFloat = Self.itemButtonSize / 2
        static let itemButtonLine: CGFloat = 1
        static let bodyTopInset: CGFloat = 8
        static let itemAccessoryTrailing: CGFloat = 52
        static let itemContentSpacing: CGFloat = 4
        static let itemContentPadding: CGFloat = 14
        static let itemCorner: CGFloat = 18
        static let itemRowSpacing: CGFloat = 6
        static let contentInset = EdgeInsets(top: 4, leading: 12, bottom: 0, trailing: 12)
        static let sectionFont = Font.system(size: 17, weight: .semibold, design: .default)
        static let sectionInset = EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
        static let createNewIcon: CGFloat = 16
        static let createNewVSpacing: CGFloat = 16
        static let createNewHSpacing: CGFloat = 12
    }

}
