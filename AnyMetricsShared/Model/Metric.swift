import Foundation

public struct MetricStyle: Hashable {
    public var symbol: String
    public var hexColor: String?
    public var imageURL: URL?

    public init(symbol: String, hexColor: String? = nil, imageURL: URL? = nil) {
        self.symbol = symbol
        self.hexColor = hexColor
        self.imageURL = imageURL
    }
}

public enum MetricFormatterType: String, Codable, CaseIterable {
    case none, currency
}

public struct MetricValueFormatter: Hashable {
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

public enum ParseResult {
    case value(String)
    case status(Bool)
}

public struct ParseRules: Hashable {
    public enum RuleType: String, Codable, CaseIterable {
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

public struct RequestData: Hashable {
    public var headers: [String: String]
    public var method: String
    public var url: URL
    public var timeout: Double?

    public init(headers: [String: String], method: String, url: URL, timeout: Double? = nil) {
        self.headers = headers
        self.method = method
        self.url = url
        self.timeout = timeout
    }
}

public enum TypeMetric: String, Codable, CaseIterable {
    case json, checkStatus, web
}

public struct Metric: Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var measure: String
    public var type: TypeMetric

    /// Store value after parse and format
    public var result: String = ""

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

    public var hasResult: Bool {
        !result.isEmpty
    }

    public init(
        id: UUID,
        title: String,
        measure: String,
        type: TypeMetric,
        result: String = "",
        resultWithError: Bool = false,
        request: RequestData? = nil,
        formatter: MetricValueFormatter? = nil,
        rules: ParseRules? = nil,
        created: Date = Date(),
        updated: Date? = nil,
        author: String? = nil,
        description: String? = nil,
        website: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.measure = measure
        self.type = type
        self.result = result
        self.resultWithError = resultWithError
        self.request = request
        self.formatter = formatter
        self.rules = rules
        self.created = created
        self.updated = updated
        self.author = author
        self.description = description
        self.website = website
    }
}
