import Foundation
import AnyMetricsShared

class DI {
    static let shared = {
        DI(metricStore: MetricStore())
    }()

    let metricStore: MetricStore

    init(metricStore: MetricStore) {
        self.metricStore = metricStore
    }
}
