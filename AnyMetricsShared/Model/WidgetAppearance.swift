import Foundation
import CoreGraphics

// MARK: - Root

/// Serializable widget look. One layout per size; colors adapt at runtime.
public struct WidgetAppearance: Hashable, Sendable, Codable {
    public static let currentVersion = 1

    public var version: Int
    /// `glassCircle` / `roundedCard` / `plain` / `custom`
    public var presetId: String?
    public var small: WidgetSizeAppearance
    public var medium: WidgetSizeAppearance

    public init(
        version: Int = WidgetAppearance.currentVersion,
        presetId: String? = nil,
        small: WidgetSizeAppearance,
        medium: WidgetSizeAppearance
    ) {
        self.version = version
        self.presetId = presetId
        self.small = small
        self.medium = medium
    }

    public func appearance(for size: WidgetSizeKey) -> WidgetSizeAppearance {
        switch size {
        case .small: return small
        case .medium: return medium
        }
    }

    public mutating func setAppearance(_ appearance: WidgetSizeAppearance, for size: WidgetSizeKey) {
        switch size {
        case .small: small = appearance
        case .medium: medium = appearance
        }
        presetId = WidgetAppearancePreset.custom.rawValue
    }

    /// Full-bleed result image; text overlays off until the user re-enables them.
    public mutating func applyImageResultPresentation() {
        small.applyImageResultPresentation()
        medium.applyImageResultPresentation()
        presetId = WidgetAppearancePreset.custom.rawValue
    }

    public var isCustom: Bool {
        presetId == WidgetAppearancePreset.custom.rawValue
    }
}

public enum WidgetSizeKey: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case small
    case medium

    public var id: String { rawValue }
}

public enum WidgetAppearancePreset: String, Codable, CaseIterable, Hashable, Sendable {
    case glassCircle
    case roundedCard
    case plain
    case custom
}

// MARK: - Per-size

public struct WidgetSizeAppearance: Hashable, Sendable, Codable {
    public var background: WidgetBackgroundSpec
    public var elements: [WidgetElementSpec]

    public init(background: WidgetBackgroundSpec, elements: [WidgetElementSpec]) {
        self.background = background
        self.elements = elements
    }

    public func element(kind: WidgetElementKind) -> WidgetElementSpec? {
        elements.first { $0.kind == kind }
    }

    public mutating func updateElement(kind: WidgetElementKind, _ update: (inout WidgetElementSpec) -> Void) {
        guard let index = elements.firstIndex(where: { $0.kind == kind }) else { return }
        update(&elements[index])
        presetMarkedCustom()
    }

    /// Result image fills the widget; title / measure / updated stay hidden until toggled on.
    public mutating func applyImageResultPresentation() {
        background.usesResultImageAsBackground = true
        background.imageContentMode = .fill
        background.imageScale = WidgetBackgroundSpec.defaultImageScale
        background.imageOffsetX = 0
        background.imageOffsetY = 0
        for kind: WidgetElementKind in [.title, .measure, .updated] {
            updateElement(kind: kind) { $0.isVisible = false }
        }
    }

    public mutating func clearImageResultPresentation() {
        background.usesResultImageAsBackground = false
        for kind in WidgetElementKind.allCases {
            updateElement(kind: kind) { $0.isVisible = true }
        }
    }

    private mutating func presetMarkedCustom() {
        // no-op at size level; root marks custom
    }
}

// MARK: - Background

public struct WidgetBackgroundSpec: Hashable, Sendable, Codable {
    public static let defaultImageScale: Double = 1.0
    public static let minImageScale: Double = 0.5
    public static let maxImageScale: Double = 3.0

    public var shape: WidgetSurfaceShape
    public var fill: WidgetBackgroundFill
    public var imageContentMode: WidgetImageContentMode
    /// App-only glass overlay (circle designs).
    public var usesGlassEffect: Bool
    /// When `true` and the metric has an image result, that result is drawn as the background
    /// instead of `fill`. Outside the editor, image results always fill the widget; this flag
    /// also gates text overlays (`isVisible`) and editor value-slot mode when `false`.
    public var usesResultImageAsBackground: Bool
    /// Extra zoom for background image (result or `fill == .image`).
    public var imageScale: Double
    /// Normalized pan (−1…1) of the background image relative to the canvas.
    public var imageOffsetX: Double
    public var imageOffsetY: Double

    public var resolvedImageScale: Double {
        min(max(imageScale, Self.minImageScale), Self.maxImageScale)
    }

    public init(
        shape: WidgetSurfaceShape,
        fill: WidgetBackgroundFill,
        imageContentMode: WidgetImageContentMode = .fill,
        usesGlassEffect: Bool = false,
        usesResultImageAsBackground: Bool = false,
        imageScale: Double = WidgetBackgroundSpec.defaultImageScale,
        imageOffsetX: Double = 0,
        imageOffsetY: Double = 0
    ) {
        self.shape = shape
        self.fill = fill
        self.imageContentMode = imageContentMode
        self.usesGlassEffect = usesGlassEffect
        self.usesResultImageAsBackground = usesResultImageAsBackground
        self.imageScale = imageScale
        self.imageOffsetX = imageOffsetX
        self.imageOffsetY = imageOffsetY
    }

    enum CodingKeys: String, CodingKey {
        case shape, fill, imageContentMode, usesGlassEffect
        case usesResultImageAsBackground, imageScale, imageOffsetX, imageOffsetY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = try container.decode(WidgetSurfaceShape.self, forKey: .shape)
        fill = try container.decode(WidgetBackgroundFill.self, forKey: .fill)
        imageContentMode = try container.decodeIfPresent(WidgetImageContentMode.self, forKey: .imageContentMode) ?? .fill
        usesGlassEffect = try container.decodeIfPresent(Bool.self, forKey: .usesGlassEffect) ?? false
        usesResultImageAsBackground = try container.decodeIfPresent(Bool.self, forKey: .usesResultImageAsBackground) ?? false
        imageScale = try container.decodeIfPresent(Double.self, forKey: .imageScale) ?? Self.defaultImageScale
        imageOffsetX = try container.decodeIfPresent(Double.self, forKey: .imageOffsetX) ?? 0
        imageOffsetY = try container.decodeIfPresent(Double.self, forKey: .imageOffsetY) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shape, forKey: .shape)
        try container.encode(fill, forKey: .fill)
        try container.encode(imageContentMode, forKey: .imageContentMode)
        try container.encode(usesGlassEffect, forKey: .usesGlassEffect)
        try container.encode(usesResultImageAsBackground, forKey: .usesResultImageAsBackground)
        try container.encode(imageScale, forKey: .imageScale)
        try container.encode(imageOffsetX, forKey: .imageOffsetX)
        try container.encode(imageOffsetY, forKey: .imageOffsetY)
    }
}

public enum WidgetSurfaceShape: String, Codable, Hashable, Sendable {
    case circle
    case roundedRect
    case rectangle
}

public enum WidgetImageContentMode: String, Codable, Hashable, Sendable {
    case fill
    case fit
}

public enum WidgetBackgroundFill: Hashable, Sendable {
    case system
    case solid(WidgetColorSpec)
    case gradient(WidgetGradientSpec)
    /// Pastel/status-aware gradients matching legacy templates.
    case statusGradient
    case image(WidgetImageRef)
}

public struct WidgetGradientSpec: Hashable, Sendable, Codable {
    public var colors: [WidgetColorSpec]
    public var startX: Double
    public var startY: Double
    public var endX: Double
    public var endY: Double

    public init(
        colors: [WidgetColorSpec],
        startX: Double = 0,
        startY: Double = 0,
        endX: Double = 1,
        endY: Double = 1
    ) {
        self.colors = colors
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
    }
}

/// Runtime: `file` under App Group. Export/import may use `base64`.
public enum WidgetImageRef: Hashable, Sendable {
    case file(String)
    case url(String)
    case base64(String)
}

// MARK: - Elements

public enum WidgetElementKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case title
    case value
    case measure
    case updated

    public var id: String { rawValue }
}

public struct WidgetElementSpec: Hashable, Sendable, Identifiable, Codable {
    public static let defaultFontScale: Double = 1.0
    public static let minFontScale: Double = 0.5
    public static let maxFontScale: Double = 2.5
    public static let defaultImageScale: Double = 1.0
    public static let minImageScale: Double = 0.5
    public static let maxImageScale: Double = 3.0

    public var kind: WidgetElementKind
    public var isVisible: Bool
    /// Normalized frame in unit space (0...1), origin top-left.
    public var frame: NormalizedRect
    public var alignment: WidgetTextAlignment
    public var color: WidgetColorSpec
    /// Multiplier for base font size (`1` = default). Persisted in appearance JSON.
    public var fontScale: Double
    /// Zoom for result image drawn in the value slot (`1` = fit).
    public var imageScale: Double
    /// Normalized pan (−1…1) of the result image inside its slot.
    public var imageOffsetX: Double
    public var imageOffsetY: Double

    public var id: WidgetElementKind { kind }

    public var resolvedFontScale: Double {
        min(max(fontScale, Self.minFontScale), Self.maxFontScale)
    }

    public var resolvedImageScale: Double {
        min(max(imageScale, Self.minImageScale), Self.maxImageScale)
    }

    public init(
        kind: WidgetElementKind,
        isVisible: Bool = true,
        frame: NormalizedRect,
        alignment: WidgetTextAlignment = .center,
        color: WidgetColorSpec = .adaptive(.palettePrimary),
        fontScale: Double = WidgetElementSpec.defaultFontScale,
        imageScale: Double = WidgetElementSpec.defaultImageScale,
        imageOffsetX: Double = 0,
        imageOffsetY: Double = 0
    ) {
        self.kind = kind
        self.isVisible = isVisible
        self.frame = frame
        self.alignment = alignment
        self.color = color
        self.fontScale = fontScale
        self.imageScale = imageScale
        self.imageOffsetX = imageOffsetX
        self.imageOffsetY = imageOffsetY
    }

    enum CodingKeys: String, CodingKey {
        case kind, isVisible, frame, alignment, color, fontScale
        case imageScale, imageOffsetX, imageOffsetY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(WidgetElementKind.self, forKey: .kind)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        frame = try container.decode(NormalizedRect.self, forKey: .frame)
        alignment = try container.decodeIfPresent(WidgetTextAlignment.self, forKey: .alignment) ?? .center
        color = try container.decodeIfPresent(WidgetColorSpec.self, forKey: .color) ?? .adaptive(.palettePrimary)
        fontScale = try container.decodeIfPresent(Double.self, forKey: .fontScale) ?? Self.defaultFontScale
        imageScale = try container.decodeIfPresent(Double.self, forKey: .imageScale) ?? Self.defaultImageScale
        imageOffsetX = try container.decodeIfPresent(Double.self, forKey: .imageOffsetX) ?? 0
        imageOffsetY = try container.decodeIfPresent(Double.self, forKey: .imageOffsetY) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(frame, forKey: .frame)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(color, forKey: .color)
        try container.encode(fontScale, forKey: .fontScale)
        try container.encode(imageScale, forKey: .imageScale)
        try container.encode(imageOffsetX, forKey: .imageOffsetX)
        try container.encode(imageOffsetY, forKey: .imageOffsetY)
    }
}

public struct NormalizedRect: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public func clamped(in bounds: NormalizedRect = .unit) -> NormalizedRect {
        var copy = self
        copy.width = min(max(copy.width, 0.04), 1)
        copy.height = min(max(copy.height, 0.04), 1)
        copy.x = min(max(copy.x, 0), max(0, 1 - copy.width))
        copy.y = min(max(copy.y, 0), max(0, 1 - copy.height))
        _ = bounds
        return copy
    }

    /// Shrinks to a content pixel size while keeping the visual position for the given alignment.
    public func tightened(
        to pixelSize: CGSize,
        canvas: CGSize,
        alignment: WidgetTextAlignment
    ) -> NormalizedRect {
        let canvasW = max(canvas.width, 1)
        let canvasH = max(canvas.height, 1)
        let newWidth = min(max(Double(pixelSize.width / canvasW), 0.04), 1)
        let newHeight = min(max(Double(pixelSize.height / canvasH), 0.04), 1)

        var copy = self
        switch alignment {
        case .leading:
            break
        case .center:
            copy.x += (width - newWidth) / 2
        case .trailing:
            copy.x += width - newWidth
        }
        copy.y += (height - newHeight) / 2
        copy.width = newWidth
        copy.height = newHeight
        return copy
    }

    public static let unit = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

public enum WidgetTextAlignment: String, Codable, Hashable, Sendable {
    case leading
    case center
    case trailing
}

// MARK: - Colors (adaptive tokens + optional hex)

public enum WidgetColorSpec: Hashable, Sendable {
    case adaptive(WidgetAdaptiveColor)
    case hex(String)
    case adaptiveHex(light: String, dark: String)
}

public enum WidgetAdaptiveColor: String, Codable, Hashable, Sendable {
    case primary
    case secondary
    case palettePrimary
    case paletteSecondary
    /// Status/error-aware value color.
    case value
    /// Dark secondary for light pastel fills.
    case onPastelSecondary
}
