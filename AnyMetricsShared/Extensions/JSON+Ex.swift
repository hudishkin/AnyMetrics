import Foundation
import SwiftyJSON

extension JSON: ValueParser {
    public func parseValue(by rules: String, formatter: MetricFormatter? = nil) -> String? {
        let listRules = Array((rules).split(separator: "."))
        var result = self
        for i in 0..<listRules.count {
            if listRules[i].first?.isNumber ?? false {
                guard let index = Int(listRules[i]) else {
                    continue
                }
                result = result[index]
            } else {
                result = result[String(listRules[i])]
            }
        }

        let stringValue = String(describing: result)
        if let formatter = formatter {
            return formatter.formatValue(stringValue)
        }
        return stringValue
    }

    public func rawData() -> String? {
        self.rawString(.utf8, options: .prettyPrinted)
    }
}
