//
//  Document+Ex.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 21.06.2022.
//

import SwiftSoup

extension Document: ValueParser {
    
    func parseValue(by rules: String, formatter: MetricFormatter? = nil) -> String? {
        let stringValue: String? = try? self.select(rules).last()?.text(trimAndNormaliseWhitespace: true)
        if let formatter = formatter, let value = stringValue {
            return formatter.formatValue(value)
        }
        return stringValue
    }
}
