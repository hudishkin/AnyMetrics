import Foundation

public extension WidgetAppearance {
    static func preset(_ design: WidgetDesign) -> WidgetAppearance {
        switch design {
        case .glassCircle:
            return glassCircle
        case .roundedCard:
            return roundedCard
        case .plain:
            return plain
        }
    }

    static func preset(_ preset: WidgetAppearancePreset) -> WidgetAppearance {
        switch preset {
        case .glassCircle: return glassCircle
        case .roundedCard: return roundedCard
        case .plain: return plain
        case .custom: return plain.markingCustom()
        }
    }

    var matchingWidgetDesign: WidgetDesign? {
        switch presetId {
        case WidgetAppearancePreset.glassCircle.rawValue: return .glassCircle
        case WidgetAppearancePreset.roundedCard.rawValue: return .roundedCard
        case WidgetAppearancePreset.plain.rawValue: return .plain
        default: return nil
        }
    }

    private func markingCustom() -> WidgetAppearance {
        var copy = self
        copy.presetId = WidgetAppearancePreset.custom.rawValue
        return copy
    }

    // MARK: Presets

    static let glassCircle = WidgetAppearance(
        presetId: WidgetAppearancePreset.glassCircle.rawValue,
        small: WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .circle,
                fill: .statusGradient,
                usesGlassEffect: true
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.06, y: 0.10, width: 0.88, height: 0.20),
                    alignment: .center,
                    color: .adaptive(.palettePrimary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.08, y: 0.36, width: 0.84, height: 0.24),
                    alignment: .center,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.10, y: 0.62, width: 0.80, height: 0.14),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.10, y: 0.76, width: 0.80, height: 0.12),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                )
            ]
        ),
        medium: mediumGlassLayout
    )

    static let roundedCard = WidgetAppearance(
        presetId: WidgetAppearancePreset.roundedCard.rawValue,
        small: WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .roundedRect,
                fill: .statusGradient,
                usesGlassEffect: false
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.06, y: 0.12, width: 0.88, height: 0.18),
                    alignment: .center,
                    color: .adaptive(.palettePrimary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.08, y: 0.36, width: 0.84, height: 0.24),
                    alignment: .center,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.10, y: 0.62, width: 0.80, height: 0.14),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.10, y: 0.76, width: 0.80, height: 0.12),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                )
            ]
        ),
        medium: mediumCardLayout
    )

    static let plain = WidgetAppearance(
        presetId: WidgetAppearancePreset.plain.rawValue,
        small: WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .rectangle,
                fill: .system,
                usesGlassEffect: false
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.08, y: 0.08, width: 0.84, height: 0.22),
                    alignment: .leading,
                    color: .adaptive(.primary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.08, y: 0.42, width: 0.84, height: 0.28),
                    alignment: .leading,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.08, y: 0.80, width: 0.42, height: 0.12),
                    alignment: .leading,
                    color: .adaptive(.secondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.50, y: 0.80, width: 0.42, height: 0.12),
                    alignment: .trailing,
                    color: .adaptive(.secondary)
                )
            ]
        ),
        medium: WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .rectangle,
                fill: .system,
                usesGlassEffect: false
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.05, y: 0.08, width: 0.90, height: 0.22),
                    alignment: .leading,
                    color: .adaptive(.primary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.05, y: 0.42, width: 0.90, height: 0.30),
                    alignment: .leading,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.05, y: 0.80, width: 0.45, height: 0.12),
                    alignment: .leading,
                    color: .adaptive(.secondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.50, y: 0.80, width: 0.45, height: 0.12),
                    alignment: .trailing,
                    color: .adaptive(.secondary)
                )
            ]
        )
    )

    /// Medium "Glass": centered stack on gradient (distinct from leading card).
    private static var mediumGlassLayout: WidgetSizeAppearance {
        WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .roundedRect,
                fill: .statusGradient,
                usesGlassEffect: true
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.08, y: 0.10, width: 0.84, height: 0.20),
                    alignment: .center,
                    color: .adaptive(.palettePrimary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.08, y: 0.36, width: 0.84, height: 0.32),
                    alignment: .center,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.10, y: 0.72, width: 0.80, height: 0.12),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.10, y: 0.84, width: 0.80, height: 0.10),
                    alignment: .center,
                    color: .adaptive(.onPastelSecondary)
                )
            ]
        )
    }

    /// Medium "Card": leading text on gradient.
    private static var mediumCardLayout: WidgetSizeAppearance {
        WidgetSizeAppearance(
            background: WidgetBackgroundSpec(
                shape: .roundedRect,
                fill: .statusGradient,
                usesGlassEffect: false
            ),
            elements: [
                .init(
                    kind: .title,
                    frame: NormalizedRect(x: 0.05, y: 0.08, width: 0.90, height: 0.22),
                    alignment: .leading,
                    color: .adaptive(.palettePrimary)
                ),
                .init(
                    kind: .value,
                    frame: NormalizedRect(x: 0.05, y: 0.42, width: 0.90, height: 0.30),
                    alignment: .leading,
                    color: .adaptive(.value)
                ),
                .init(
                    kind: .measure,
                    frame: NormalizedRect(x: 0.05, y: 0.80, width: 0.45, height: 0.12),
                    alignment: .leading,
                    color: .adaptive(.onPastelSecondary)
                ),
                .init(
                    kind: .updated,
                    frame: NormalizedRect(x: 0.50, y: 0.80, width: 0.45, height: 0.12),
                    alignment: .trailing,
                    color: .adaptive(.onPastelSecondary)
                )
            ]
        )
    }
}

public extension WidgetDesign {
    var appearancePresetId: String { rawValue }
}
