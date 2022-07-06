//
//  Metric.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation



struct MetricStyle: Hashable {
    var symbol: String
    var hexColor: String?
    var imageURL: URL?
}

enum MetricFormatterType: String, Codable, CaseIterable {
    case none, currency
}

struct MetricValueFormatter: Hashable {
    static let `default` = MetricValueFormatter()

    var format: MetricFormatterType = .none
    var length: Int?
    var fraction: Int?
}

enum ParseResult {
    case value(String)
    case status(Bool)
}

struct ParseRules: Hashable {

    enum RuleType: String, Codable, CaseIterable {
        case none, equal, contains
    }

    static let `default` = ParseRules()

    var parseRules: String?
    var type: RuleType = .none
    var value: String?
    var caseSensitive = false
}

struct RequestData: Hashable {
    var headers: [String: String]
    var method: String
    var url: URL
    var timeout: Double?
}

enum TypeMetric: String, Codable, CaseIterable {
    case json,
         checkStatus,
         web
}

struct Metric: Hashable {
    let id: UUID
    var title: String
    var measure: String
    var type: TypeMetric

    /// Store value after parse and format
    var result: String = ""

    /// Indicate if request finished with error
    var resultWithError: Bool = false

    var request: RequestData?
    var formatter: MetricValueFormatter?
    var rules: ParseRules?

    var created: Date = Date()
    var updated: Date?

    var author: String?
    var description: String?
    var website: URL?

    var hasResult: Bool {
        return !result.isEmpty
    }
}

extension Metric: Identifiable { }
