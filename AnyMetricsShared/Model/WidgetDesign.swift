import Foundation

public enum WidgetDesign: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case glassCircle
    case roundedCard
    case minimal
    case ring
    case plain

    public var id: String { rawValue }

    public static let `default`: WidgetDesign = .glassCircle
}
