//
//  Mocks.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation


enum Mocks {

    private static let mockTitle = "Your metric"
    private static let mockMeasure = "Measure"
    // Use in edit form and widget

    static func getMockMetric(
        title: String = mockTitle,
        measure: String = mockMeasure,
        type: TypeMetric = .json,
        typeRule: ParseRules? = nil,
        result: String = "-",
        resultWithError: Bool = false) -> Metric {
            Metric(
                id: UUID(),
                title: title.isEmpty ? mockTitle : title,
                measure: measure.isEmpty ? mockMeasure : measure,
                type: type,
                result: result,
                resultWithError: resultWithError,
                rules: typeRule)
    }

    static let metricEmpty = Self.getMockMetric()
    //
    static let metricJsonWithError = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12222", resultWithError: true)
    static let metricJson = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12000")
    static let metricCheck = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: false)
    static let metricCheckWithError = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: true)
}
