//
//  Mocks.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation


enum Mocks {
    static let metricJson = Metric(id: UUID(), title: "Your metric", paramName: "Price, USD", value: "12000", formatter: MetricValueFormatter(format: .currency, fraction: 2), type: .json)
    static let metricCheck = Metric(id: UUID(), title: "Your service", paramName: "", value: "", hasError: false, type: .checker)
    static let metricCheckWithError = Metric(id: UUID(), title: "Your service", paramName: "", value: "", hasError: true, type: .checker)
}
