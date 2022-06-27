//
//  Mocks.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation


enum Mocks {
    static let metricJsonWithError = Metric(id: UUID(), title: "Your metric", paramName: "Peram name type test test", value: "12222", formatter: MetricValueFormatter(format: .currency, fraction: 2), hasError: true, type: .json)
    static let metricJson = Metric(id: UUID(), title: "Your metric", paramName: "Peram name type test test", value: "12000", formatter: MetricValueFormatter(format: .currency, fraction: 2), type: .json)
    static let metricCheck = Metric(id: UUID(), title: "Your service", paramName: "", value: "", hasError: false, type: .checker)
    static let metricCheckWithError = Metric(id: UUID(), title: "Your service", paramName: "", value: "", hasError: true, type: .checker)
}
