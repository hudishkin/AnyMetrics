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


struct RequestData: Hashable {
    var headers: [String: String]
    var method: String
    var url: URL
    var timeout: Double?
}

enum TypeMetric: String, Codable, CaseIterable {
    case json,
         checker
}

struct Metric: Hashable {
    let id: UUID
    var title: String
//    var style: MetricStyle?
    var paramName: String
    var lastValue: String = ""
    var formatter: MetricValueFormatter?
    var indicateError: Bool = false
    var hasError: Bool = false
    var request: RequestData?
    var type: TypeMetric
    var parseRules: String?

    var created: Date = Date()
    var updated: Date?

    var author: String?
    var description: String?
    var website: URL?

    var hasValue: Bool {
        return !lastValue.isEmpty
    }

    var formattedValue: String {
        formatter?.formatValue(self.lastValue) ?? lastValue
    }
}

extension Metric: Identifiable { }
