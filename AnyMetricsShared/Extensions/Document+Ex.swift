import SwiftSoup

extension Document: ValueParser {
    public func parseValue(by rules: String, formatter: MetricFormatter? = nil) -> String? {
        let stringValue: String? = try? self.select(rules).last()?.text(trimAndNormaliseWhitespace: true)
        if let formatter = formatter, let value = stringValue {
            return formatter.formatValue(value)
        }
        return stringValue
    }

    public func rawData() -> String? {
        try? self.outerHtml()
    }
}
