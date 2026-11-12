import Foundation
import AnyMetricsShared

enum PersonalCatalog {

    /// Dashboard metrics that are not gallery presets.
    /// Nothing is adopted once Personal already has entries.
    static func metricsToAdopt(
        dashboard: Metrics,
        personal: Metrics,
        galleryIDs: Set<UUID>
    ) -> [Metric] {
        guard personal.isEmpty else { return [] }
        return dashboard.values.filter { !galleryIDs.contains($0.id) }
    }
}
