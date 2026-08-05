import Foundation

public struct MetricStyle: Hashable, Sendable {
    public var symbol: String
    public var hexColor: String?
    public var imageURL: URL?

    public init(symbol: String, hexColor: String? = nil, imageURL: URL? = nil) {
        self.symbol = symbol
        self.hexColor = hexColor
        self.imageURL = imageURL
    }
}

public enum MetricFormatterType: String, Codable, CaseIterable, Sendable {
    case none, currency
}

public struct MetricValueFormatter: Hashable, Sendable {
    public static let `default` = MetricValueFormatter()

    public var format: MetricFormatterType = .none
    public var length: Int?
    public var fraction: Int?

    public init(format: MetricFormatterType = .none, length: Int? = nil, fraction: Int? = nil) {
        self.format = format
        self.length = length
        self.fraction = fraction
    }
}

public enum ParseResult: Sendable {
    case value(String)
    case status(Bool)
    case image(Data)
}

public enum MetricResultKind: String, Codable, CaseIterable, Sendable {
    case content, image
}

public struct ParseRules: Hashable, Sendable {
    public enum RuleType: String, Codable, CaseIterable, Sendable {
        case none, equal, contains
    }

    public static let `default` = ParseRules()

    public var parseRules: String?
    public var type: RuleType = .none
    public var value: String?
    public var caseSensitive = false

    public init(parseRules: String? = nil, type: RuleType = .none, value: String? = nil, caseSensitive: Bool = false) {
        self.parseRules = parseRules
        self.type = type
        self.value = value
        self.caseSensitive = caseSensitive
    }
}

public struct RequestData: Hashable, Sendable {
    public var headers: [String: String]
    public var method: String
    public var url: URL
    public var timeout: Double?
    public var requestBody: String?

    public init(headers: [String: String], method: String, url: URL, timeout: Double? = nil, requestBody: String? = nil) {
        self.headers = headers
        self.method = method
        self.url = url
        self.timeout = timeout
        self.requestBody = requestBody
    }
}

public enum TypeMetric: String, Codable, CaseIterable, Sendable {
    case json, checkStatus, web
}

public struct Metric: Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var measure: String
    public var type: TypeMetric

    /// How the HTTP response is interpreted: parsed text/status or raw image body.
    public var resultKind: MetricResultKind = .content

    /// Store value after parse and format
    public var result: String = ""

    /// Relative path in App Group for image result (`resultKind == .image`).
    public var resultImagePath: String?

    /// Indicate if request finished with error
    public var resultWithError: Bool = false

    public var request: RequestData?
    public var formatter: MetricValueFormatter?
    public var rules: ParseRules?

    public var created: Date = Date()
    public var updated: Date?

    public var author: String?
    public var description: String?
    public var website: URL?

    /// Widget refresh interval in seconds
    public var interval: Int?

    /// Widget visual layout preset (legacy + quick pick). Prefer `widgetAppearance` when set.
    public var widgetDesign: WidgetDesign?

    /// Full serializable widget look (per-size layout, background, visibility).
    public var widgetAppearance: WidgetAppearance?

    public var hasResult: Bool {
        switch resultKind {
        case .content:
            return !result.isEmpty
        case .image:
            return resultImagePath != nil
        }
    }

    /// Resolved appearance: custom spec or compiled preset from `widgetDesign`.
    public var resolvedAppearance: WidgetAppearance {
        if let widgetAppearance {
            return widgetAppearance
        }
        return .preset(widgetDesign ?? .default)
    }

    public init(
        id: UUID,
        title: String,
        measure: String,
        type: TypeMetric,
        resultKind: MetricResultKind = .content,
        result: String = "",
        resultImagePath: String? = nil,
        resultWithError: Bool = false,
        request: RequestData? = nil,
        formatter: MetricValueFormatter? = nil,
        rules: ParseRules? = nil,
        created: Date = Date(),
        updated: Date? = nil,
        author: String? = nil,
        description: String? = nil,
        website: URL? = nil,
        interval: Int? = nil,
        widgetDesign: WidgetDesign? = nil,
        widgetAppearance: WidgetAppearance? = nil
    ) {
        self.id = id
        self.title = title
        self.measure = measure
        self.type = type
        self.resultKind = resultKind
        self.result = result
        self.resultImagePath = resultImagePath
        self.resultWithError = resultWithError
        self.request = request
        self.formatter = formatter
        self.rules = rules
        self.created = created
        self.updated = updated
        self.author = author
        self.description = description
        self.website = website
        self.interval = interval
        self.widgetDesign = widgetDesign
        self.widgetAppearance = widgetAppearance
    }

    /// Applies a fetch/parse outcome to this metric (including image file persistence).
    public mutating func apply(parseResult: ParseResult) {
        switch parseResult {
        case .value(let valueString):
            result = valueString
            resultWithError = false
        case .status(let success):
            result = ""
            resultWithError = !success
        case .image(let data):
            do {
                let path = try MetricResultImageStore.shared.save(data: data, metricId: id)
                resultImagePath = path
                result = ""
                resultWithError = false
            } catch {
                resultWithError = true
            }
        }
        updated = Date()
    }

    /// Returns a copy with a new ID when a metric with the same ID already exists.
    public func duplicatingIfNeeded(in existingMetrics: Metrics) -> Metric {
        guard existingMetrics[id] != nil else { return self }
        var copy = Metric(
            id: UUID(),
            title: title,
            measure: measure,
            type: type,
            resultKind: resultKind,
            result: result,
            resultImagePath: nil,
            resultWithError: resultWithError,
            request: request,
            formatter: formatter,
            rules: rules,
            created: Date(),
            updated: nil,
            author: author,
            description: description,
            website: website,
            interval: interval,
            widgetDesign: widgetDesign,
            widgetAppearance: widgetAppearance
        )
        try? copy.persistWidgetBackgroundImages()
        if resultKind == .image, let path = resultImagePath,
           let data = MetricResultImageStore.shared.loadData(relativePath: path) {
            copy.resultImagePath = try? MetricResultImageStore.shared.save(data: data, metricId: copy.id)
        }
        return copy
    }

    /// Writes any inlined base64 widget backgrounds into the App Group container.
    /// Widgets cannot reliably host large base64 payloads from UserDefaults.
    public mutating func persistWidgetBackgroundImages(
        store: WidgetBackgroundStore = .shared
    ) throws {
        guard var appearance = widgetAppearance, appearance.containsBase64Images else { return }
        try appearance.materializeImportedImages(metricId: id, store: store)
        widgetAppearance = appearance
    }
}
