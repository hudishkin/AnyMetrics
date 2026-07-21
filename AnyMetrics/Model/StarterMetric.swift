import Foundation
import AnyMetricsShared

enum StarterMetric {
    static let id = UUID(uuidString: "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")!

    static func make() -> Metric {
        Metric(
            id: id,
            title: AnyMetricsStrings.StarterMetric.title,
            measure: AnyMetricsStrings.StarterMetric.measure,
            type: .json,
            request: RequestData(
                headers: [
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "AnyMetrics"
                ],
                method: "GET",
                url: URL(string: "https://api.github.com/repos/hudishkin/AnyMetrics")!
            ),
            rules: ParseRules(parseRules: "stargazers_count"),
            website: AppConfig.Urls.appRepository,
            interval: 3600,
            widgetDesign: .glassCircle
        )
    }
}
