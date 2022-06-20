//
//  Formatter.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation

protocol MetricFormatter {
    func formatValue(_ value: String) -> String
}

extension MetricValueFormatter: MetricFormatter {
    func formatValue(_ value: String) -> String {

        switch self.format {
        case .currency:
            if let doubleValue = Double(value) {
                let formatter = NumberFormatter()
                formatter.locale = Locale.current
                formatter.currencySymbol = ""
                formatter.numberStyle = .currency
                if let fraction = fraction {
                    formatter.maximumFractionDigits = fraction
                }
                return formatter.string(from: NSNumber(value: doubleValue)) ?? value
            }
        case .none:
            if let length = length {
                return String(value.prefix(length))
            }
        }
        return value
    }
}
