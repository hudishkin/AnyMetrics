import Foundation
import SwiftyJSON

extension JSON: ValueParser {
    public func parseValue(by rules: String, formatter: MetricFormatter? = nil) -> String? {
        let listRules = Array(rules.split(separator: "."))
        let result = Self.resolveValue(listRules: listRules, startIndex: 0, current: self)

        if let formatter = formatter {
            return formatter.formatValue(result)
        }
        return result
    }

    public func rawData() -> String? {
        self.rawString(.utf8, options: .prettyPrinted)
    }

    // MARK: - Aggregate Operations

    private enum AggregateOperation: String {
        case sum = "*+"
        case avg = "*avg"
        case min = "*min"
        case max = "*max"
    }

    // MARK: - Element Selectors

    private enum ElementSelector: String {
        case first = "*first"
        case last = "*last"
        case count = "*count"
    }

    // MARK: - Filter

    private enum FilterOperator {
        case equal
        case notEqual
        case greaterThan
        case lessThan
        case greaterOrEqual
        case lessOrEqual
    }

    private struct ArrayFilter {
        let field: String
        let op: FilterOperator
        let value: String
    }

    // MARK: - Resolve

    private static func resolveValue(
        listRules: [Substring],
        startIndex: Int,
        current: JSON
    ) -> String {
        var result = current
        for i in startIndex..<listRules.count {
            let rule = String(listRules[i])

            if let operation = AggregateOperation(rawValue: rule) {
                return applyAggregate(
                    operation,
                    json: result,
                    listRules: listRules,
                    fromIndex: i + 1
                )
            }

            if let selector = ElementSelector(rawValue: rule) {
                return applySelector(
                    selector,
                    json: result,
                    listRules: listRules,
                    fromIndex: i + 1
                )
            }

            if let filter = parseFilter(rule) {
                result = applyFilter(filter, json: result)
                continue
            }

            if rule.first?.isNumber ?? false {
                guard let index = Int(rule) else { continue }
                result = result[index]
            } else {
                result = result[rule]
            }
        }
        return String(describing: result)
    }

    // MARK: - Aggregate

    private static func collectValues(
        json: JSON,
        listRules: [Substring],
        fromIndex: Int
    ) -> [Double] {
        guard let array = json.array else { return [] }
        return array.compactMap { element in
            let valueStr = resolveValue(
                listRules: listRules,
                startIndex: fromIndex,
                current: element
            )
            return Double(valueStr)
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
    }

    private static func applyAggregate(
        _ operation: AggregateOperation,
        json: JSON,
        listRules: [Substring],
        fromIndex: Int
    ) -> String {
        let values = collectValues(json: json, listRules: listRules, fromIndex: fromIndex)
        guard !values.isEmpty else { return "0" }

        switch operation {
        case .sum:
            return formatNumber(values.reduce(0, +))
        case .avg:
            return formatNumber(values.reduce(0, +) / Double(values.count))
        case .min:
            return formatNumber(values.min()!)
        case .max:
            return formatNumber(values.max()!)
        }
    }

    // MARK: - Element Selectors

    private static func applySelector(
        _ selector: ElementSelector,
        json: JSON,
        listRules: [Substring],
        fromIndex: Int
    ) -> String {
        guard let array = json.array, !array.isEmpty else {
            return String(describing: json)
        }

        switch selector {
        case .count:
            return String(array.count)
        case .first:
            return resolveValue(listRules: listRules, startIndex: fromIndex, current: array[0])
        case .last:
            return resolveValue(listRules: listRules, startIndex: fromIndex, current: array[array.count - 1])
        }
    }

    // MARK: - Filter

    private static func parseFilter(_ rule: String) -> ArrayFilter? {
        guard rule.hasPrefix("*["), rule.hasSuffix("]") else { return nil }
        let content = String(rule.dropFirst(2).dropLast(1))

        let operators: [(String, FilterOperator)] = [
            ("!=", .notEqual),
            (">=", .greaterOrEqual),
            ("<=", .lessOrEqual),
            (">", .greaterThan),
            ("<", .lessThan),
            ("=", .equal)
        ]

        for (symbol, op) in operators {
            if let range = content.range(of: symbol) {
                let field = String(content[content.startIndex..<range.lowerBound])
                let value = String(content[range.upperBound...])
                guard !field.isEmpty else { continue }
                return ArrayFilter(field: field, op: op, value: value)
            }
        }
        return nil
    }

    private static func applyFilter(_ filter: ArrayFilter, json: JSON) -> JSON {
        guard let array = json.array else { return json }
        let filtered = array.filter { element in
            let fieldValue = element[filter.field]
            switch filter.op {
            case .equal:
                return fieldValue.stringValue == filter.value
            case .notEqual:
                return fieldValue.stringValue != filter.value
            case .greaterThan:
                guard let lhs = fieldValue.double, let rhs = Double(filter.value) else { return false }
                return lhs > rhs
            case .lessThan:
                guard let lhs = fieldValue.double, let rhs = Double(filter.value) else { return false }
                return lhs < rhs
            case .greaterOrEqual:
                guard let lhs = fieldValue.double, let rhs = Double(filter.value) else { return false }
                return lhs >= rhs
            case .lessOrEqual:
                guard let lhs = fieldValue.double, let rhs = Double(filter.value) else { return false }
                return lhs <= rhs
            }
        }
        return JSON(filtered)
    }
}
