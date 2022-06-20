//
//  Mocks.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation


enum Mocks {
    static let metricJson = Metric(id: UUID(), title: "Mock service", paramName: "Price, USD", lastValue: "12", type: .json)
    static let metricCheck = Metric(id: UUID(), title: "Mock service", paramName: "Price, USD", lastValue: "$12,00.00", hasError: false, type: .checker)
    static let metricCheckWithError = Metric(id: UUID(), title: "Mock service", paramName: "Price, USD", lastValue: "", hasError: true, type: .checker)
}
