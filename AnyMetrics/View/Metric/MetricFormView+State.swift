import VVSI
import AnyMetricsShared
import Foundation

enum FormStep: Hashable {
    case requestStep, valueStep, displayStep
}

enum HTTPMethodType: String, Equatable, CaseIterable {
    case POST, GET, HEAD, DELETE, PUT

    var hasBody: Bool {
        switch self {
        case .POST, .PUT, .DELETE:
            return true
        case .GET, .HEAD:
            return false
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case bySystem = 0
    case minutes15 = 900
    case minutes30 = 1800
    case hour1 = 3600
    case hours3 = 10800
    case hours6 = 21600
    case hours12 = 43200

    var id: Int { rawValue }

    var interval: Int? {
        self == .bySystem ? nil : rawValue
    }

    var localizedString: String {
        switch self {
        case .bySystem:  return AnyMetricsStrings.Addmetric.Field.refreshIntervalBySystem
        case .minutes15: return AnyMetricsStrings.Addmetric.Field.refreshInterval15min
        case .minutes30: return AnyMetricsStrings.Addmetric.Field.refreshInterval30min
        case .hour1:     return AnyMetricsStrings.Addmetric.Field.refreshInterval1h
        case .hours3:    return AnyMetricsStrings.Addmetric.Field.refreshInterval3h
        case .hours6:    return AnyMetricsStrings.Addmetric.Field.refreshInterval6h
        case .hours12:   return AnyMetricsStrings.Addmetric.Field.refreshInterval12h
        }
    }

    init(from seconds: Int?) {
        guard let seconds else { self = .bySystem; return }
        self = RefreshInterval(rawValue: seconds) ?? .bySystem
    }
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
        var parseErrorMessage: String = ""
        var widgetDesign: WidgetDesign = .default
        var widgetAppearance: WidgetAppearance = .preset(.default)
        /// Last edited/imported custom look; kept when browsing presets so it can be reselected.
        var savedCustomAppearance: WidgetAppearance?
        var created: Date = Date()
        var author: String?
        var description: String?
        var website: URL?
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
        case setWidgetDesign(WidgetDesign)
        case setWidgetAppearance(WidgetAppearance)
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}

extension Metric {

    static func canSave(from formState: MetricFormView.VState, requestState: RequestFormView.VState) -> Bool {
        guard requestState.requestUrl.requestURL != nil else {
            return false
        }
        let title = formState.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return false
        }
        if requestState.resultKind == .image {
            return true
        }
        return requestState.typeMetric == .checkStatus || !formState.parseRules.isEmpty
    }

    /// Suggested title from the request URL host (e.g. `api.example.com`).
    static func defaultTitle(from requestUrl: String) -> String? {
        guard var host = requestUrl.requestURL?.host else { return nil }
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return nil }
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    init?(formState: MetricFormView.VState, requestState: RequestFormView.VState) {
        guard Self.canSave(from: formState, requestState: requestState),
              let url = requestState.requestUrl.requestURL
        else { return nil }

        let title = formState.title.trimmingCharacters(in: .whitespacesAndNewlines)

        var imagePath: String?
        if requestState.resultKind == .image, let data = requestState.responseImageData {
            imagePath = try? MetricResultImageStore.shared.save(data: data, metricId: formState.id)
        }

        var appearance = formState.widgetAppearance
        // Default image metrics to result-as-background, but never override a custom
        // design (e.g. photo/URL fill or "use as background" turned off in the editor).
        if requestState.resultKind == .image,
           !appearance.isCustom,
           !appearance.small.background.usesResultImageAsBackground,
           !appearance.medium.background.usesResultImageAsBackground {
            appearance.applyImageResultPresentation()
        }

        self.init(
            id: formState.id,
            title: title,
            measure: formState.measure,
            type: requestState.typeMetric,
            resultKind: requestState.resultKind,
            result: requestState.resultKind == .image ? "" : formState.result,
            resultImagePath: imagePath,
            resultWithError: requestState.resultKind == .image
                ? imagePath == nil
                : formState.resultWithError,
            request: RequestData(
                headers: requestState.httpHeaders,
                method: requestState.httpMethodType.rawValue,
                url: url,
                timeout: requestState.timeout,
                requestBody: requestState.httpMethodType.hasBody && !requestState.requestBody.isEmpty
                    ? requestState.requestBody
                    : nil),
            formatter: .init(
                format: formState.formatType,
                length: formState.maxLengthValue),
            rules: .init(
                parseRules: formState.parseRules,
                type: formState.typeRule,
                value: formState.parseConfigurationValue,
                caseSensitive: formState.caseSensitive),
            created: formState.created,
            updated: formState.isNew ? nil : Date(),
            author: formState.author,
            description: formState.description,
            website: formState.website,
            interval: requestState.refreshInterval.interval,
            widgetDesign: appearance.matchingWidgetDesign ?? formState.widgetDesign,
            widgetAppearance: appearance
        )
    }

    static func empty(id: UUID = .init()) -> Metric {
        .init(id: id, title: "", measure: "", type: .checkStatus)
    }
}
