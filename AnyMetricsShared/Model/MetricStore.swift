import SwiftUI

public typealias Metrics = [UUID: Metric]

extension Metrics: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode(Metrics.self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

open class MetricStore {
    @AppStorage(AppConfig.metricsKey, store: UserDefaults(suiteName: AppConfig.group)) public var metrics = Metrics()

    public init() {}

    public func addMetric(metric: Metric) {
        var localMetrics = self.metrics
        localMetrics[metric.id] = metric
        self.metrics = localMetrics
    }

    public func removeMetric(id: UUID) {
        var localMetrics = self.metrics
        localMetrics[id] = nil
        self.metrics = localMetrics
    }

    @discardableResult
    public func removeAll() -> Self {
        self.metrics = [:]
        return self
    }
}
