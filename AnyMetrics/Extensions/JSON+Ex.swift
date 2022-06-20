//
//  JSON+Ex.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation
import SwiftyJSON

extension JSON {
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
        if let formatter = formatter, let result = result.string {
            return formatter.formatValue(result)
        }
        if let value = result.string {
            return value
        }
        return nil
    }
}
