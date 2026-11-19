import Foundation
import AnyMetricsShared

enum GeneratedMetricAdapter {

    static func metric(from job: BuilderAPI.Job) -> Metric? {
        guard job.status == .completed, let result = job.result else { return nil }
        guard let url = URL(string: result.metric.request.url) else { return nil }
        let generated = result.metric
        let validation = result.validation
        let displayed = displayedValue(validation)
        return Metric(
            id: UUID(uuidString: generated.id) ?? UUID(),
            title: generated.title,
            measure: generated.measure,
            type: TypeMetric(rawValue: generated.type.rawValue) ?? .json,
            resultKind: MetricResultKind(rawValue: generated.resultKind.rawValue) ?? .content,
            result: displayed.result,
            resultWithError: displayed.failed,
            request: RequestData(
                headers: generated.request.headers,
                method: generated.request.method.rawValue,
                url: url
            ),
            formatter: MetricValueFormatter(
                format: generated.formatter.format == .currency ? .currency : .none,
                length: generated.formatter.length,
                fraction: generated.formatter.fraction
            ),
            rules: ParseRules(
                parseRules: generated.rules.parseRules,
                type: ParseRules.RuleType(rawValue: generated.rules.type.rawValue) ?? .none,
                value: generated.rules.value,
                caseSensitive: generated.rules.caseSensitive
            ),
            created: job.createdAt,
            updated: validation.validatedAt,
            author: generated.author ?? result.source.name,
            description: generated.description,
            website: (generated.website ?? result.source.website).flatMap(URL.init(string:)),
            interval: generated.interval
        )
    }

    private static func displayedValue(_ validation: BuilderAPI.Validation) -> (result: String, failed: Bool) {
        if validation.valueKind == .status {
            return ("", validation.status == false)
        }
        let sample = validation.sampleValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sample.isEmpty {
            return (sample, false)
        }
        return (validation.rawValue ?? "", false)
    }
}
