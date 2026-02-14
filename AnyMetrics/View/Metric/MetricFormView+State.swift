import VVSI
import AnyMetricsShared
import Foundation

enum FormStep: Hashable {
    case requestStep, valueStep, displayStep
}

enum HTTPMethodType: String, Equatable, CaseIterable {
    case POST, GET, HEAD, DELETE, PUT
}

extension MetricFormView {

    struct VState: StateProtocol {

        enum RequestStatus {
            case none, loading, success, error
        }

        let id: UUID
        let isNew: Bool
        
        var canMakeRequest: Bool {
            requestUrl.isValidURL
        }
        var canSetupResponse: Bool = false
        var hasRequestError: Bool = false
        var hasParseRuleError: Bool = false
        var errorMessage: String = ""
        var requestStatus: RequestStatus = .none

        var title: String = ""
        var measure: String = ""
        var requestUrl: String = "http://jsonplaceholder.typicode.com/posts"
        var httpMethodType: HTTPMethodType = .GET
        var typeMetric: TypeMetric = .json
        var timeout: Double = DEFAULT_TIMEOUT
        var typeRule: ParseRules.RuleType = .none
        var parseConfigurationValue: String = ""
        var caseSensitive: Bool = false
        var paramEqualTo: String = ""
        var parseRules: String = ""
        var result: String = ""
        var httpHeaders: [String: String] = [:]
        var response: String = ""
        var formatType: MetricFormatterType = .none
        var maxLengthValue: Int = DEFAULT_LENGTH_VALUE
        var resultWithError: Bool = true
        var isEdited: Bool = false
        var canAddMetric: Bool {
            !measure.isEmpty
            && !title.isEmpty
            && requestUrl.isValidURL
            && timeout > 0
            && (typeMetric == .checkStatus || !parseRules.isEmpty)
        }
    }

    enum VAction: ActionProtocol {
        case makeRequest
        case updateValue(rule: String? = nil, length: Int? = nil)
        case setTitle(String)
        case setMeasure(String)
        case setRequestUrl(String)
        case setHTTPMethodType(HTTPMethodType)
        case setTypeMetric(TypeMetric)
        case setTimeout(Double)
        case setTypeRule(ParseRules.RuleType)
        case setParseConfigurationValue(String)
        case setCaseSensitive(Bool)
        case setParamEqualTo(String)
        case setParseRules(String)
        case setFormatType(MetricFormatterType)
        case setMaxLengthValue(Int)
        case addHeader(name: String, value: String)
        case removeHeader(name: String)
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}

extension Metric {

    init?(with state: MetricFormView.VState) {
        guard state.canAddMetric else { return nil }
        guard let url = URL(string: state.requestUrl) else { return nil }

        self.init(
            id: state.id,
            title: state.title,
            measure: state.measure,
            type: state.typeMetric,
            result: state.result,
            resultWithError: state.resultWithError,
            request: RequestData(
                headers: state.httpHeaders,
                method: state.httpMethodType.rawValue,
                url: url,
                timeout: state.timeout),
            formatter: .init(
                format: state.formatType,
                length: state.maxLengthValue),
            rules: .init(
                parseRules: state.parseRules,
                type: state.typeRule,
                value: state.parseConfigurationValue,
                caseSensitive: state.caseSensitive),
            created: Date(),
            updated: nil,
            author: nil,
            description: nil,
            website: nil
        )
    }

    static func empty(id: UUID = .init()) -> Metric {
        .init(id: id, title: "", measure: "", type: .checkStatus)
    }
}
