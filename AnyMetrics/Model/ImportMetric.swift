import Foundation
import AnyMetricsShared

struct MetricExportOptions: Equatable, Sendable {
    var includeRequest: Bool
    var includeWidgetStyle: Bool

    static let `default` = MetricExportOptions(includeRequest: true, includeWidgetStyle: true)

    var canExport: Bool {
        includeRequest || includeWidgetStyle
    }
}

struct MetricExportIncludes: Codable, Equatable {
    var request: Bool
    var widgetStyle: Bool
}

struct MetricItemImportData {

    static let VERSION_JSON = "0.2"
    static let supportedVersions: Set<String> = ["0.1", "0.2"]

    let version: String
    var author: String?
    var created: Date?
    var includes: MetricExportIncludes?
    var payload: Metric?

    private init() {
        self.version = Self.VERSION_JSON
    }

    private init(author: String, created: Date = Date(), payload: Metric) {
        self.version = Self.VERSION_JSON
        self.author = author
        self.created = created
        self.payload = payload
    }

    static func exportData(for metric: Metric, options: MetricExportOptions = .default) throws -> MetricItemImportData {
        var sanitized = metric

        sanitized.result = ""
        sanitized.resultImagePath = nil
        sanitized.resultWithError = false

        if !options.includeRequest {
            sanitized.request = nil
        }

        if options.includeWidgetStyle {
            let appearance = sanitized.widgetAppearance ?? .preset(sanitized.widgetDesign ?? .default)
            sanitized.widgetAppearance = try appearance.preparingForExport()
        } else {
            sanitized.widgetAppearance = nil
            sanitized.widgetDesign = nil
        }

        var data = MetricItemImportData()
        data.author = metric.author
        data.created = Date()
        data.includes = MetricExportIncludes(
            request: options.includeRequest,
            widgetStyle: options.includeWidgetStyle
        )
        data.payload = sanitized
        return data
    }
}
