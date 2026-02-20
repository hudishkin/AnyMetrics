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

        let id: UUID
        let isNew: Bool

        var title: String = ""
        var measure: String = ""
        var typeRule: ParseRules.RuleType = .none
        var parseConfigurationValue: String = ""
        var caseSensitive: Bool = false
        var paramEqualTo: String = ""
        var parseRules: String = ""
        var result: String = ""
        var formatType: MetricFormatterType = .none
        var maxLengthValue: Int = DEFAULT_LENGTH_VALUE
        var resultWithError: Bool = true
        var isEdited: Bool = false
        var hasParseRuleError: Bool = false
    }

    enum VAction: ActionProtocol {
        case updateValue(rule: String? = nil, length: Int? = nil)
        case setTitle(String)
        case setMeasure(String)
        case setTypeRule(ParseRules.RuleType)
        case setParseConfigurationValue(String)
        case setCaseSensitive(Bool)
        case setParamEqualTo(String)
        case setParseRules(String)
        case setFormatType(MetricFormatterType)
        case setMaxLengthValue(Int)
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}

extension Metric {

    init?(formState: MetricFormView.VState, requestState: RequestFormView.VState) {
        guard !formState.measure.isEmpty,
              !formState.title.isEmpty,
              requestState.requestUrl.isValidURL,
              (requestState.typeMetric == .checkStatus || !formState.parseRules.isEmpty)
        else { return nil }
        guard let url = URL(string: requestState.requestUrl) else { return nil }

        self.init(
            id: formState.id,
            title: formState.title,
            measure: formState.measure,
            type: requestState.typeMetric,
            result: formState.result,
            resultWithError: formState.resultWithError,
            request: RequestData(
                headers: requestState.httpHeaders,
                method: requestState.httpMethodType.rawValue,
                url: url,
                timeout: requestState.timeout),
            formatter: .init(
                format: formState.formatType,
                length: formState.maxLengthValue),
            rules: .init(
                parseRules: formState.parseRules,
                type: formState.typeRule,
                value: formState.parseConfigurationValue,
                caseSensitive: formState.caseSensitive),
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
