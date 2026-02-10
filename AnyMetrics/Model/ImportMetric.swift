//
//  ImportMetric.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 15.06.2022.
//

import Foundation
import AnyMetricsShared


struct MetricItemImportData {

    static let VERSION_JSON = "0.1"

    let version: String
    var author: String?
    var created: Date?
    var payload: Metric?

    private init() {
        self.version = Self.VERSION_JSON
    }

    private init(author: String, created: Date = Date(), payload: Metric) {
        self.version = Self.VERSION_JSON
        self.author = author
        self.created = created
        self.payload = payload
    }
}
