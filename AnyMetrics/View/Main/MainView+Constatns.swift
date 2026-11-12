import Foundation
import SwiftUI
import UIKit
import AnyMetricsShared

extension MainView {

    enum Constants {
        static let fontTitle: Font = Font.system(size: 19, weight: .semibold, design: .default)
        static let fontPlaceholder: Font = Font.system(size: 16, weight: .regular, design: .default)
        static let padding: CGFloat = 10
        static let titleInset = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        static let infoInset = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        static let spacing: CGFloat = {
            AppConfig.isiOSAppOnMac ? 20 : 10
        }()
        static let size: CGFloat = {
            if AppConfig.isiOSAppOnMac {
                return 260
            }
            let columns = CGFloat(collumns.count)
            return (UIScreen.main.bounds.width - spacing * (columns + 1)) / columns
        }()
        static let heightPlaceholder: CGFloat = (UIScreen.main.bounds.height) - (Self.spacing * 2)
        static let titleCorner: CGFloat = 8
        static let bottomPadding: CGFloat = 58
        static let scrollViewInset = EdgeInsets(top: 0, leading: Constants.padding, bottom: 0, trailing: Constants.padding)
        static let addButtonPadding: CGFloat = 14
        static let addButtonSize: CGFloat = {  AppConfig.isiOSAppOnMac ? 82 : 62 }()
        static let addButtonCorner: CGFloat = Self.addButtonSize / 2
        static let gridHorizontalPadding: CGFloat = AppConfig.isiOSAppOnMac ? 0 : spacing

        static func columnCount(for size: CGSize) -> Int {
            if AppConfig.isiOSAppOnMac {
                return macColumnCount(for: size.width)
            }

            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let landscape = size.width > size.height
            let preferred: Int
            if isPad {
                preferred = landscape ? 4 : 3
            } else if landscape {
                preferred = size.width >= 800 ? 4 : 3
            } else {
                preferred = 2
            }

            let minimumSide: CGFloat = 160
            var count = preferred
            while count > 2 && cardSide(for: size.width, columns: count) < minimumSide {
                count -= 1
            }
            return max(count, 1)
        }

        static func cardSide(for width: CGFloat, columns: Int) -> CGFloat {
            if AppConfig.isiOSAppOnMac {
                return 260
            }
            let count = CGFloat(max(columns, 1))
            return (width - spacing * (count + 1)) / count
        }

        static func gridItems(count: Int) -> [GridItem] {
            let item = AppConfig.isiOSAppOnMac
                ? GridItem(.flexible())
                : GridItem(.flexible(), spacing: spacing)
            return Array(repeating: item, count: max(count, 1))
        }

        private static func macColumnCount(for width: CGFloat) -> Int {
            let card: CGFloat = 260
            var count = 1
            guard width > 0 else { return count }
            for candidate in 1...4 {
                let needed = card * CGFloat(candidate) + spacing * CGFloat(candidate - 1)
                if needed <= width {
                    count = candidate
                }
            }
            return count
        }

        static let collumns: [GridItem] = {

            if AppConfig.isiOSAppOnMac {
                return [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
            } else {
                return [
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing)
                ]
            }
        }()
    }

}
