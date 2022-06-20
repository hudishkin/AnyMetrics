//
//  NewMetricViewModel.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 14.06.2022.
//


import SwiftUI
import Combine
import SwiftyJSON


let DEFAULT_LENGTH_VALUE = 7
let MAX_LENGTH_SYMBOL = 4



enum HTTPMethodType: String, Equatable, CaseIterable {
    case POST, GET, HEAD, DELETE, PUT
}

enum AddMetricType: String, Equatable, CaseIterable {
    case manual, fromJSON
}

class NewMetricViewModel: ObservableObject {

    @Published private(set) var showImportResult: Bool
    @Published private(set) var showRequestResult: Bool = false
    @Published private(set) var hasImportError: Bool = false
    @Published private(set) var hasRequestError: Bool = false
    @Published private(set) var hasParseRuleError: Bool = false
    @Published private(set) var errorMessage: String = ""

    @Published var type: AddMetricType = .manual
    @Published var loading: Bool = false
    @Published var loadingRequest: Bool = false
    @Published var jsonFileURL: String = "https://dl.dropbox.com/s/ovpdy4hx96lqc5u/testJson.json?dl=0"
    @Published var requestUrl: String = "https://api.coincap.io/v2/assets/tron"
    @Published var httpMethodType: HTTPMethodType = .GET
    @Published var typeMetric: TypeMetric = .json
    @Published var timeout: Double = DEFAULT_TIMEOUT

    @Published var title: String = ""
    @Published var paramName: String = ""
    @Published var parseRules: String = ""
    @Published var parseValue: String = ""

    @Published var symbol: String = "" {
        didSet {
            DispatchQueue.main.async {
                if self.symbol.count > MAX_LENGTH_SYMBOL && oldValue.count <= MAX_LENGTH_SYMBOL {
                    self.symbol = oldValue
                }
            }

        }
    }

    @Published var httpHeaders: [String: String] = [:]
    // @Published var canAddMetric: Bool = false
    @Published var responseJSON: String = ""

    @Published var author: String = ""
    @Published var description: String = ""
    @Published var website: String = ""
    @Published var formatType: MetricFormatterType = .none
    @Published var maxLengthValue: Int = DEFAULT_LENGTH_VALUE

    private var jsonObject: JSON?
    private var websiteURL: URL? {
        return URL(string: website)
    }

    var parseValueByLength: String {
        if maxLengthValue == 0 {
            return parseValue
        }
        return String(parseValue.prefix(maxLengthValue))
    }

    var jsonFileURLisValid: Bool {
        return jsonFileURL.isValidURL
    }

    var canAddMetric: Bool {
        if paramName.isEmpty || title.isEmpty || (parseValue.isEmpty && typeMetric == .json) || !requestUrl.isValidURL || timeout <= 0 || (!website.isEmpty && !website.isValidURL) {
            return false
        }
        return true
    }

    private var disposables = Set<AnyCancellable>()
    private var parser: ImportMetricParser

    init(showImportResult: Bool = false, parser: ImportMetricParser = JsonMetricParser()) {
        self.parser = parser
        self.showImportResult = showImportResult
    }

    func makeRequest() {
        self.loadingRequest = true

        var request = URLRequest(url: URL(string: self.requestUrl)!)
        for (k,v) in self.httpHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpMethod = self.httpMethodType.rawValue
        request.timeoutInterval = timeout
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.hasRequestError = true
                    self.showRequestResult = false
                case .finished:
                    break
                }
            }, receiveValue: { data, error in
                if self.typeMetric == .json {
                    self.jsonObject = try? JSON(data: data)
                    self.responseJSON = data.prettyJSONString ?? ""
                    self.showRequestResult = true
                }

                self.loadingRequest = false
            })
            .store(in: &disposables)
    }

    func updateValue(rule: String? = nil, length: Int? = nil) {
        let rules = rule ?? self.parseRules
        let formatter = MetricValueFormatter(
            format: self.formatType,
            length: length ?? maxLengthValue)

        if let value = jsonObject?.parseValue(by: rules, formatter: formatter) {
            self.parseValue = value
            self.hasParseRuleError = false
        }else {
            self.hasParseRuleError = true
        }
    }



    func getMetric() -> Metric? {
        if canAddMetric {
            return Metric(
                id: UUID(),
                title: title,
                paramName: self.paramName,
                lastValue: parseValueByLength,
                formatter: .default,
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

    func importJSON() {
        loading = true
        URLSession.shared.dataTaskPublisher(for: URL(string: self.jsonFileURL)!)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.hasImportError = true
                case .finished:
                    break
                }
            }, receiveValue: { data, error in
                if let data = try? self.parser.parse(data: data) {
                    self.errorMessage = ""
                    self.httpHeaders = data.payload?.request?.headers ?? [:]
                    self.timeout = data.payload?.request?.timeout ?? DEFAULT_TIMEOUT
                    self.requestUrl = data.payload?.request?.url.absoluteString ?? ""
                    self.formatType = data.payload?.formatter?.format ?? .none
                    if self.formatType == .none {
                        self.maxLengthValue = data.payload?.formatter?.length ?? DEFAULT_LENGTH_VALUE
                    }else {
                        self.maxLengthValue = 0
                    }

                    self.author = data.payload?.author ?? ""
                    self.title = data.payload?.title ?? ""
                    self.paramName = data.payload?.paramName ?? ""
                    self.description = data.payload?.description ?? ""
                    self.website = data.payload?.website?.absoluteString ?? ""
                    self.httpMethodType = .GET
                    if let _method = data.payload?.request?.method, let method = HTTPMethodType(rawValue: _method) {
                        self.httpMethodType = method
                    }
                    self.typeMetric = data.payload?.type ?? .json

                    self.hasImportError = false
//                    self.importData = data
                    self.showImportResult = true
                }else {
//                    self.importData = .empty
                    self.showImportResult = false
                }

                self.loading = false
            })
            .store(in: &disposables)
    }
}


extension TypeMetric {
    var localizedString: String {
        NSLocalizedString("addmetric.type-metric-\(self.rawValue.lowercased())", comment: "")
    }
}

extension AddMetricType {
    var localizedString: String { NSLocalizedString("addmetric.add-type-\(self.rawValue.lowercased())", comment: "") }
}
