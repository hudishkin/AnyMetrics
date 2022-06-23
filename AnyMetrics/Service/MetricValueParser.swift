//
//  MetricValueParser.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 21.06.2022.
//

import Foundation
import SwiftyJSON
import SwiftSoup

protocol ValueParser {
    func parseValue(by rules: String, formatter: MetricFormatter?) -> String?
    func rawData() -> String?
}

enum MetricValueParser {

    enum ValueParseResult {
        case value(String)
        case check(Bool)
    }

    static func parse(rules: String?, data: Data?, metricType: TypeMetric, formatter: MetricFormatter?) -> ValueParseResult {
        switch metricType {
        case .checker:
            return .check(true)
        case .json:
            return .value(parseJSON(data, rules: rules, formatter: formatter))
        case .web:
            return .value(parseHTML(data, rules: rules ?? "", formatter: formatter))
        }
    }

    static private func parseJSON(
        _ data: Data?,
        rules: String?,
        formatter: MetricFormatter?) -> String {

        guard let data = data else { return "" }
        if let json = try? JSON(data: data), let rules = rules {
            return json.parseValue(by: rules, formatter: formatter) ?? ""
        }
        return String(data: data, encoding: .utf8)!
    }

    static private func parseHTML(
        _ data: Data?,
        rules: String,
        formatter: MetricFormatter?)
    -> String {

        guard
            let data = data,
            let html = String(data: data, encoding: .utf8),
            let document = try? SwiftSoup.parse(html),
            let value = document.parseValue(by: rules, formatter: formatter)
        else { return "" }
        return value

    }
}
