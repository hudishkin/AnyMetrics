import Foundation
import AnyMetricsShared

class DI {
    static let shared = {
        DI(
            metricStore: MetricStore(),
            personalMetricStore: MetricStore(key: AppConfig.personalMetricsKey)
        )
    }()

    let metricStore: MetricStore
    let personalMetricStore: MetricStore

    init(metricStore: MetricStore, personalMetricStore: MetricStore? = nil) {
        self.metricStore = metricStore
        self.personalMetricStore = personalMetricStore ?? MetricStore(
            defaults: UserDefaults(suiteName: "AnyMetrics.PersonalCatalog.\(UUID().uuidString)"),
            key: AppConfig.personalMetricsKey
        )
    }
}
