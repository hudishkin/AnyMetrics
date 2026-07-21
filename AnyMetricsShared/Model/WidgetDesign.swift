import Foundation

public enum WidgetDesign: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case glassCircle
    case roundedCard
    case plain

    public var id: String { rawValue }

    public static let `default`: WidgetDesign = .glassCircle

    public var usesMediumGradient: Bool {
        self != .plain
    }

    public static func migrated(fromLegacyRawValue rawValue: String) -> WidgetDesign? {
        switch rawValue {
        case WidgetDesign.glassCircle.rawValue,
             WidgetDesign.roundedCard.rawValue,
             WidgetDesign.plain.rawValue:
            return WidgetDesign(rawValue: rawValue)
        case "minimal", "ring":
            return .plain
        default:
            return nil
        }
    }
}
