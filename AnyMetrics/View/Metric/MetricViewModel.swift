//
//  MetricViewModel.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//


import SwiftUI
import Combine
import SwiftyJSON
import SwiftSoup
import AnyMetricsShared

let DEFAULT_LENGTH_VALUE = 0

enum HTTPMethodType: String, Equatable, CaseIterable {
    case POST, GET, HEAD, DELETE, PUT
}



enum FormStep: Hashable {
    case requestStep, valueStep, displayStep

//    static let checkStatusSteps: [FormStep] = [.requestStep, .displayStep]
//    static let parseResponseSteps: [FormStep] = [.requestStep, .valueStep, .displayStep]
}

final class MetricViewModel: ObservableObject {

    // MARK: - Types

    enum RequestStatus {
        case none, loading, success, error
    }

    // MARK: - Published Properties

    var selectedStepIndex: Int = 0
    @Published var selectedStep: FormStep = .requestStep

    @Published private(set) var canMakeRequest: Bool = false
    @Published private(set) var canSetupResponse: Bool = false
    @Published private(set) var hasRequestError: Bool = false
    @Published private(set) var hasParseRuleError: Bool = false
    @Published private(set) var errorMessage: String = ""

//    @Published var loading: Bool = false
//    @Published var loadingRequest: Bool = false
    @Published var requestStatus: RequestStatus = .none
    

    @Published var title: String = ""
    @Published var measure: String = ""
    @Published var requestUrl: String = "http://jsonplaceholder.typicode.com/posts" {
        didSet {
            canMakeRequest = requestUrl.isValidURL
        }
    }
    @Published var httpMethodType: HTTPMethodType = .GET
    @Published var typeMetric: TypeMetric = .json
    @Published var timeout: Double = DEFAULT_TIMEOUT
    @Published var typeRule: ParseRules.RuleType = .none
    @Published var parseConfigurationValue: String = ""

    @Published var caseSensitive: Bool = false
    @Published var paramEqualTo: String = ""
    @Published var parseRules: String = ""
    @Published var result: String = ""
    @Published var httpHeaders: [String: String] = [:]
    @Published var response: String = ""
    @Published var formatType: MetricFormatterType = .none
    @Published var maxLengthValue: Int = DEFAULT_LENGTH_VALUE

    // MARK: - Private Properties

    private(set) var resultWithError: Bool = true
    private var parserDocument: ValueParser?
    private var disposables = Set<AnyCancellable>()
    private var metric: Metric?

    var isEdited: Bool {
        return metric != nil
    }

    // MARK: - Properties

    var parseValueByLength: String {
        if maxLengthValue == 0 {
            return result
        }
        return String(result.prefix(maxLengthValue))
    }

    var canAddMetric: Bool {
        if measure.isEmpty
            || title.isEmpty
            || !requestUrl.isValidURL
            || timeout <= 0
            || (typeMetric != .checkStatus && parseRules.isEmpty) {

            return false
        }
        return true
    }
//
//    var hasNextPage: Bool {
//        getNextIndex() != nil
//    }

    // MARK: - Init

    init() { }

    init(metric: Metric) {
        self.metric = metric
        requestUrl =  metric.request?.url.absoluteString ?? ""
        httpMethodType = .init(rawValue: metric.request?.method ?? "") ?? .GET
        typeMetric = metric.type
        title = metric.title
        measure = metric.measure
        maxLengthValue = metric.formatter?.length ?? DEFAULT_LENGTH_VALUE
        httpHeaders = metric.request?.headers ?? [:]
        parseRules = metric.rules?.parseRules ?? ""
        typeRule = metric.rules?.type ?? .none
        formatType = metric.formatter?.format ?? .none
        parseConfigurationValue = metric.rules?.value ?? ""
        canSetupResponse = true
        resultWithError = metric.resultWithError
        canMakeRequest = true

    }

    // MARK: - Public Methods

    func makeRequest() {
        guard let url = URL(string: self.requestUrl) else { return }
        self.requestStatus = .loading

        Fetcher.fetch(
            for: url,
            method: self.httpMethodType.rawValue,
            headers: self.httpHeaders,
            timeout: timeout)

        .map { data -> ValueParser? in
            if self.typeMetric == .json {
                let json = try? JSON(data: data)
                return (json)
            }
            if self.typeMetric == .web {
                let htmlDocument = try? SwiftSoup.parse(String(data: data, encoding: .utf8) ?? "")
                return (htmlDocument)
            }
            return (nil)
        }
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.requestStatus = .error
                    self.errorMessage = error.localizedDescription
                    self.hasRequestError = true
                    self.canSetupResponse = self.typeMetric == .checkStatus

                case .finished:
                    self.hasRequestError = false
                    self.canSetupResponse = true
                    self.requestStatus = .success
                }
            }, receiveValue: { parser in
                self.response = parser?.rawData() ?? ""
                self.parserDocument = parser
                self.updateValue()
            })
            .store(in: &disposables)
    }

    func updateValue(rule: String? = nil, length: Int? = nil) {
        let rules = rule ?? self.parseRules
        let formatter = MetricValueFormatter(
            format: self.formatType,
            length: length ?? maxLengthValue)
        if let value = parserDocument?.parseValue(by: rules, formatter: formatter) {
            if self.typeRule != .none {
                let rule = ParseRules(parseRules: rules, type: self.typeRule, value: self.parseConfigurationValue, caseSensitive: false)
                switch rule.parse(value) {
                case .status(let status):
                    self.resultWithError = !status
                    self.result = String(describing: status)
                case .value(let val):
                    self.result = val
                }
            } else {
                self.result = value
                self.hasParseRuleError = false
            }
        } else {
            self.hasParseRuleError = true
        }
    }

    func getMetric() -> Metric? {
        guard canAddMetric else { return nil }

        return Metric(
            id: metric?.id ?? UUID(),
            title: self.title,
            measure: self.measure,
            type: self.typeMetric,
            result: self.result,
            resultWithError: self.resultWithError,
            request: RequestData(
                headers: self.httpHeaders,
                method: self.httpMethodType.rawValue,
                url: URL(string: self.requestUrl)!,
                timeout: self.timeout),
            formatter: .init(
                format: self.formatType,
                length: self.maxLengthValue),
            rules: .init(
                parseRules: self.parseRules,
                type: self.typeRule,
                value: self.parseConfigurationValue,
                caseSensitive: self.caseSensitive),
            created: Date(),
            updated: nil,
            author: nil,
            description: nil,
            website: nil)
    }

    // MARK: - Private Methods

//    private func getNextIndex() -> Int? {
//        switch typeMetric {
//        case .json, .web:
//            guard
//                let index = FormStep.parseResponseSteps.firstIndex(of: selectedStep),
//                FormStep.checkStatusSteps.endIndex > index + 1 else { return nil }
//            return index + 1
//        case .checkStatus:
//            guard
//                let index = FormStep.checkStatusSteps.firstIndex(of: selectedStep),
//                    FormStep.checkStatusSteps.endIndex > index + 1 else { return  nil }
//            return index + 1
//        }
//    }
}

extension TypeMetric {
    var localizedString: String {
        NSLocalizedString("addmetric.field.type-metric-\(self.rawValue.lowercased())", comment: "")
    }
}

extension MetricFormatterType {
    var localizedName: String { NSLocalizedString("addmetric.field.value-type-\(self.rawValue.lowercased())", comment: "") }
}

extension ParseRules.RuleType {
    var localizedName: String { NSLocalizedString("addmetric.field.rule-type-\(self.rawValue.lowercased())", comment: "") }
}
