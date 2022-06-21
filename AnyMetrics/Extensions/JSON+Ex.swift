//
//  JSON+Ex.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation
import SwiftyJSON

extension JSON: ValueParser {
    func parseValue(by rules: String, formatter: MetricFormatter? = nil) -> String? {
        let listRules = Array((rules).split(separator: "."))
        var result = self
        for i in 0..<listRules.count {
            if listRules[i].first?.isNumber ?? false {
                result = result[Int(listRules[i])!]
            }else {
                result = result[String(listRules[i])]
            }
        }

        var stringValue: String?
        if let value = result.double {
            stringValue = String(describing: value)
        } else if let value = result.int {
            stringValue = String(describing: value)
        } else if let value = result.bool {
            stringValue = String(describing: value)
        } else  if let value = result.string {
            stringValue = value
        } else if let formatter = formatter, let value = stringValue {
            return formatter.formatValue(value)
        }
        return stringValue
    }
}
