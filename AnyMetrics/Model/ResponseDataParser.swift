//
//  ResponseDataParser.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 02.07.2022.
//

import Foundation
import SwiftSoup
import SwiftyJSON

protocol ValueParser {
    func parseValue(by rules: String, formatter: MetricFormatter?) -> String?
    func rawData() -> String?
}

extension ParseRules {
    func parse(_ value: String) -> ParseResult {
        switch self.type {
        case .none:
            return .value(value)
        case .equal:
            guard let eqString = self.value else { return .status(false) }
            if self.value == value ||
                (!self.caseSensitive && (eqString.lowercased() == value.lowercased())){
                return .status(true)
            }
        case .contains:
            guard let containsString = self.value, !containsString.isEmpty else { return .status(false) }
            if (self.caseSensitive && value.localizedStandardContains(containsString)) || value.lowercased().contains(containsString.lowercased()) {
                return .status(true)
            }
        }
        return .status(false)
    }
}

final class MetricResponseParser {

    enum ParserError: Error {
        case parseError
    }

    let type: TypeMetric
    let formatter: MetricValueFormatter
    let rules: ParseRules

    init(type: TypeMetric, formatter: MetricValueFormatter, rules: ParseRules) {
        self.type = type
        self.formatter = formatter
        self.rules = rules
    }

    func parse(_ data: Data?) throws -> ParseResult {

        switch type {
        case .checkStatus:
            return .status(true)
        case .json:
            guard let value = valueFromJSON(data, rules: rules.parseRules, formatter: formatter) else {
                throw ParserError.parseError
            }
            return rules.parse(value)
        case .web:
            guard let value = valueFromHTML(data, rules: rules.parseRules ?? "", formatter: formatter) else {
                throw ParserError.parseError
            }
            return rules.parse(value)
        }
    }

    private func valueFromJSON(
        _ data: Data?,
        rules: String?,
        formatter: MetricFormatter?) -> String? {

        guard let data = data else { return "" }
        if let json = try? JSON(data: data), let rules = rules {
            return json.parseValue(by: rules, formatter: formatter)
        }
        return String(data: data, encoding: .utf8)!
    }

    private func valueFromHTML(
        _ data: Data?,
        rules: String,
        formatter: MetricFormatter?)
    -> String? {

        guard
            let data = data,
            let html = String(data: data, encoding: .utf8),
            let document = try? SwiftSoup.parse(html)
        else { return nil }
        return document.parseValue(by: rules, formatter: formatter)

    }
}
