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
        if metric.resultKind == .image {
            if let path = metric.resultImagePath {
                if MetricResultImageStore.shared.loadImage(relativePath: path) != nil {
                    return emptyLabel
                }
                // Path recorded but file missing/corrupt.
                return errorLabel
            }
            return (metric.refreshFailed || metric.resultWithError) ? errorLabel : emptyLabel
        }
        if metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none) {
            // Status Bad/Good from last successful evaluation — not from transport failures.
            return metric.resultWithError ? badLabel : goodLabel
        }
        if metric.result.isEmpty {
            return (metric.refreshFailed || metric.resultWithError) ? errorLabel : emptyLabel
        }
        return metric.result
    }

    /// Refresh failed while a previous value/status/image is still shown (tint `updated` red).
    public static func showsStaleUpdate(for metric: Metric) -> Bool {
        metric.refreshFailed
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
