import Foundation

public enum MetricDisplayHelpers {
    private static let justNowThreshold: TimeInterval = 10

    public static func valueString(
        for metric: Metric,
        goodLabel: String,
        badLabel: String,
        emptyLabel: String = "N/A",
        errorLabel: String = "Error"
    ) -> String {
        if metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none) {
            return metric.resultWithError ? badLabel : goodLabel
        }
        if metric.result.isEmpty {
            return metric.resultWithError ? errorLabel : emptyLabel
        }
        return metric.result
    }

    public static func relativeUpdatedString(
        for date: Date?,
        bundle: Bundle = Bundle(for: MetricStore.self)
    ) -> String? {
        guard let date else { return nil }
        let now = Date()
        let age = now.timeIntervalSince(date)
        if abs(age) < justNowThreshold {
            return NSLocalizedString("metric.updated.just-now", bundle: bundle, comment: "")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let pastDate = min(date, now)
        return formatter.localizedString(for: pastDate, relativeTo: now)
    }
}
