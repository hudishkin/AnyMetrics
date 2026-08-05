import Foundation
import AnyMetricsShared

enum WidgetStyleImport {

    enum ParseError: Error {
        case invalidJSON
    }

    private struct AppearanceWrapper: Decodable {
        let widgetAppearance: WidgetAppearance
    }

    /// Accepts bare `WidgetAppearance`, `{ "widgetAppearance": ... }`, metric JSON, or metric import envelope.
    static func parse(data: Data) throws -> WidgetAppearance {
        let decoder = JSONDecoder()

        if let appearance = try? decoder.decode(WidgetAppearance.self, from: data) {
            return appearance
        }

        if let wrapper = try? decoder.decode(AppearanceWrapper.self, from: data) {
            return wrapper.widgetAppearance
        }

        if let metric = try? decoder.decode(Metric.self, from: data),
           let appearance = appearance(from: metric) {
            return appearance
        }

        if let envelope = try? JsonMetricParser().parse(data: data),
           let metric = envelope.payload,
           let appearance = appearance(from: metric) {
            return appearance
        }

        throw ParseError.invalidJSON
    }

    private static func appearance(from metric: Metric) -> WidgetAppearance? {
        if let appearance = metric.widgetAppearance {
            return appearance
        }
        if let design = metric.widgetDesign {
            return .preset(design)
        }
        return nil
    }
}
