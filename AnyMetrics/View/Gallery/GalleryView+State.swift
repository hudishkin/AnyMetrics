import VVSI
import Foundation

extension GalleryView {
    struct VState: StateProtocol {
        var galleryItems: [GalleryItem] = []
        var showLoading: Bool = false
        var showSendRequestMetric: Bool = false
    }

    enum VAction: ActionProtocol {
        case onAppear
        case search(String)
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}
