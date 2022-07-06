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

let DEFAULT_LENGTH_VALUE = 0

enum HTTPMethodType: String, Equatable, CaseIterable {
    case POST, GET, HEAD, DELETE, PUT
}

final class MetricViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var canMakeRequest: Bool = true
    @Published private(set) var showRequestResult: Bool = false
    @Published private(set) var hasRequestError: Bool = false
    @Published private(set) var hasParseRuleError: Bool = false
    @Published private(set) var errorMessage: String = ""

    @Published var loading: Bool = false
    @Published var loadingRequest: Bool = false

    @Published var title: String = ""
    @Published var measure: String = ""
    @Published var requestUrl: String = "" {
        didSet {
            canMakeRequest = URL(string: requestUrl) != nil
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

    private var resultWithError: Bool = true
    private var parserDocument: ValueParser?
    private var disposables = Set<AnyCancellable>()
    private var metric: Metric?


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
        showRequestResult = true
        resultWithError = metric.resultWithError

    }

    // MARK: - Public Methods

    func makeRequest() {
        guard let url = URL(string: self.requestUrl) else { return }
        self.loadingRequest = true

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
                    self.loadingRequest = false
                    self.errorMessage = error.localizedDescription
                    self.hasRequestError = true
                    self.showRequestResult = self.typeMetric == .checkStatus

                case .finished:
                    self.hasRequestError = false
                    self.showRequestResult = true
                }
            }, receiveValue: { parser in
                self.response = parser?.rawData() ?? ""
                self.parserDocument = parser
                self.loadingRequest = false
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
                    self.result = ""
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
