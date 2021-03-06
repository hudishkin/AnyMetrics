//
//  ObservedStorage.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 18.06.2022.
//

import SwiftUI


typealias Metrics = [UUID: Metric]


extension Metrics: RawRepresentable  {
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

class MetricStore {
    @AppStorage(AppConfig.metricsKey, store: UserDefaults(suiteName: AppConfig.group)) var metrics = Metrics()

    func addMetric(metric: Metric) {
        var _metrics = self.metrics
        _metrics[metric.id] = metric
        self.metrics = _metrics
    }

    func removeMetric(id: UUID) {
        var _metrics = self.metrics
        _metrics[id] = nil
        self.metrics = _metrics
    }

    func removeAll() -> Self {
        self.metrics = [:]
        return self
    }
}
