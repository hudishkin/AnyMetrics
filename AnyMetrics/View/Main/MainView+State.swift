import VVSI
import AnyMetricsShared
import Foundation

extension MainView {

    struct VState: StateProtocol {
        var metrics: Metrics = [:]
    }

    enum VAction: ActionProtocol {
        case onAppear
        // case openSheet(ActiveSheet)
        case addMetric(Metric)
        case removeMetric(UUID)
        case refreshMetric(UUID)
        case refreshAllMetrics
        case syncMetrics
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}
