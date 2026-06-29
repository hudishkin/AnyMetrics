import Foundation

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
        Self.encodeToJSON(self) ?? "{}"
    }

    fileprivate static func encodeToJSON(_ metrics: Metrics) -> String? {
        guard let data = try? JSONEncoder().encode(metrics),
              let result = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return result
    }

    fileprivate static func decodeFromJSON(_ json: String) -> Metrics? {
        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(Metrics.self, from: data)
        else {
            return nil
        }
        return result
    }
}

open class MetricStore {
    private let defaults: UserDefaults?
    private let key: String

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppConfig.group),
        key: String = AppConfig.metricsKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var metrics: Metrics {
        get {
            guard let json = defaults?.string(forKey: key) else {
                return [:]
            }
            return Metrics.decodeFromJSON(json) ?? [:]
        }
        set {
            guard let json = Metrics.encodeToJSON(newValue) else {
                return
            }
            defaults?.set(json, forKey: key)
        }
    }

    public func addMetric(metric: Metric) {
        var localMetrics = metrics
        localMetrics[metric.id] = metric
        metrics = localMetrics
    }

    public func removeMetric(id: UUID) {
        var localMetrics = metrics
        localMetrics[id] = nil
        metrics = localMetrics
    }

    @discardableResult
    public func removeAll() -> Self {
        metrics = [:]
        return self
    }
}
