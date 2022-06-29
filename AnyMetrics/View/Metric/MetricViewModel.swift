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

    @Published private(set) var canMakeRequest: Bool = false
    @Published private(set) var showRequestResult: Bool = false
    @Published private(set) var hasRequestError: Bool = false
    @Published private(set) var hasParseRuleError: Bool = false
    @Published private(set) var errorMessage: String = ""

    @Published var loading: Bool = false
    @Published var loadingRequest: Bool = false

    @Published var requestUrl: String = "" {
        didSet {
            canMakeRequest = URL(string: requestUrl) != nil
        }
    }
    @Published var httpMethodType: HTTPMethodType = .GET
    @Published var typeMetric: TypeMetric = .json
    @Published var timeout: Double = DEFAULT_TIMEOUT
    @Published var title: String = ""
    @Published var paramName: String = ""
    @Published var parseRules: String = ""
    @Published var parseValue: String = ""
    @Published var httpHeaders: [String: String] = [:]
    @Published var response: String = ""
    @Published var author: String = ""
    @Published var description: String = ""
    @Published var website: String = ""
    @Published var formatType: MetricFormatterType = .none
    @Published var maxLengthValue: Int = DEFAULT_LENGTH_VALUE

    // MARK: - Private Properties

    private var parserDocument: ValueParser?
    private var disposables = Set<AnyCancellable>()
    private var metric: Metric?
    
    private var websiteURL: URL? {
        return URL(string: website)
    }

    // MARK: - Properties

    var parseValueByLength: String {
        if maxLengthValue == 0 {
            return parseValue
        }
        return String(parseValue.prefix(maxLengthValue))
    }

    var canAddMetric: Bool {
        if paramName.isEmpty || title.isEmpty || (parseValue.isEmpty && typeMetric == .json) || !requestUrl.isValidURL || timeout <= 0 || (!website.isEmpty && !website.isValidURL) {
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
        paramName = metric.paramName
        description = metric.description ?? ""
        author = metric.author ?? ""
        maxLengthValue = metric.formatter?.length ?? DEFAULT_LENGTH_VALUE
        website = metric.website?.absoluteString ?? ""
        httpHeaders = metric.request?.headers ?? [:]
        parseRules = metric.parseRules ?? ""
        formatType = metric.formatter?.format ?? .none
        showRequestResult = true
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
                    self.showRequestResult = self.typeMetric == .checker

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
            self.parseValue = value
            self.hasParseRuleError = false
        } else {
            self.hasParseRuleError = true
        }
    }

    func getMetric() -> Metric? {
        if canAddMetric {
            return Metric(
                id: metric?.id ?? UUID(),
                title: title,
                paramName: self.paramName,
                value: parseValue,
                formatter: .init(format: formatType, length: maxLengthValue),
                indicateError: false,
                hasError: false,
                request: RequestData(
                    headers: self.httpHeaders,
                    method: self.httpMethodType.rawValue,
                    url: URL(string: self.requestUrl)!,
                    timeout: self.timeout),
                type: self.typeMetric,
                parseRules: self.parseRules,
                created: Date(),
                updated: nil,
                author: self.author,
                description: self.description,
                website: self.websiteURL)
        }
        return nil
    }
}


extension TypeMetric {
    var localizedString: String {
        NSLocalizedString("addmetric.type-metric-\(self.rawValue.lowercased())", comment: "")
    }
}

extension MetricFormatterType {
    var localizedName: String { NSLocalizedString("addmetric.format-type-\(self.rawValue.lowercased())", comment: "") }
}