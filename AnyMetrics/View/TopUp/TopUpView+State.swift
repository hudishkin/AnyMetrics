import Foundation
import VVSI

extension TopUpView {

    struct VState: StateProtocol {
        var balance: Int
        var paid: Bool
        var offers: [CreditOffer] = []
        var selectedID: String?
        var isLoading = true
        var isPurchasing = false
        var loadFailed = false
    }

    enum VAction: ActionProtocol {
        case load
        case select(String)
        case purchase
    }

    enum VNotification: NotificationProtocol {
        case error(String)
        case purchased
    }
}
