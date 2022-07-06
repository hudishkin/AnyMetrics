//
//  Mocks.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation


enum Mocks {

    static let metricEmpty = Metric(id: UUID(), title: "Title", measure: "Measure", type: .json, result: "-", resultWithError: false)
    static let metricJsonWithError = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12222", resultWithError: true)
    static let metricJson = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12000")
    static let metricCheck = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: false)
    static let metricCheckWithError = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: true)
}
