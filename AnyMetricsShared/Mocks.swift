import Foundation

public enum Mocks {

    public static let mockTitle = "Your metric"
    public static let mockMeasure = "Measure"
    // Use in edit form and widget

    public static func getMockMetric(
        title: String = mockTitle,
        measure: String = mockMeasure,
        type: TypeMetric = .json,
        typeRule: ParseRules? = nil,
        result: String = "-",
        resultWithError: Bool = false) -> Metric {
            Metric(
                id: UUID(),
                title: title.isEmpty ? mockTitle : title,
                measure: measure.isEmpty ? mockMeasure : measure,
                type: type,
                result: result,
                resultWithError: resultWithError,
                rules: typeRule)
    }

    public static let metricEmpty = Self.getMockMetric()
    //
    public static let metricJsonWithError = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12222", resultWithError: true)
    public static let metricJson = Metric(id: UUID(), title: "Your metric", measure: "Peram name type test test", type: .json, result: "12000")
    public static let metricCheck = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: false)
    public static let metricCheckWithError = Metric(id: UUID(), title: "Your service", measure: "", type: .checkStatus, result: "", resultWithError: true)
}
