import Foundation
import SwiftUI
import AnyMetricsShared

extension MainView {

    enum Constants {
        static let fontTitle: Font = Font.system(size: 19, weight: .heavy, design: .default)
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
            return (UIScreen.main.bounds.width / CGFloat(Constants.collumns.count)) - (Self.spacing * 2)

        }()
        static let heightPlaceholder: CGFloat = (UIScreen.main.bounds.height) - (Self.spacing * 2)
        static let zIndexTitle: CGFloat = 999
        static let titleCorner: CGFloat = 8
        static let topPadding: CGFloat = 58
        static let bottomPadding: CGFloat = 58
        static let scrollViewInset = EdgeInsets(top: 0, leading: Constants.padding, bottom: 0, trailing: Constants.padding)
        static let addButtonPadding: CGFloat = 14
        static let addButtonSize: CGFloat = {  AppConfig.isiOSAppOnMac ? 82 : 62 }()
        static let addButtonCorner: CGFloat = Self.addButtonSize / 2
        static let collumns: [GridItem] = {

            if AppConfig.isiOSAppOnMac {
                return [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
            } else {
                return [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
            }
        }()
    }

}
