import SwiftUI
import UIKit

public struct WidgetAppearanceRenderer: View {
    public let metric: Metric
    public let appearance: WidgetSizeAppearance
    public let palette: MetricWidgetPalette
    public let sizeKey: WidgetSizeKey
    public let useGlassEffect: Bool
    /// When true, use Home Screen widget metrics (fonts, radius, surface) even inside the app.
    public let matchWidgetMetrics: Bool
    public let updatedAt: Date?
    public let isEditing: Bool
    public let selectedKind: WidgetElementKind?
    public var onSelect: ((WidgetElementKind) -> Void)?
    public var onDrag: ((WidgetElementKind, CGSize, CGSize) -> Void)?
    public var onDragEnd: ((WidgetElementKind) -> Void)?
    /// Pan background image (result-as-background or image fill). `translation` in points.
    public var onBackgroundDrag: ((CGSize, CGSize) -> Void)?
    public var onBackgroundDragEnd: (() -> Void)?
    public var onFittedSizes: (([WidgetElementKind: CGSize], CGSize) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var fittedSizes: [WidgetElementKind: CGSize] = [:]

    public init(
        metric: Metric,
        appearance: WidgetSizeAppearance,
        palette: MetricWidgetPalette,
        sizeKey: WidgetSizeKey,
        useGlassEffect: Bool = false,
        matchWidgetMetrics: Bool = false,
        updatedAt: Date? = nil,
        isEditing: Bool = false,
        selectedKind: WidgetElementKind? = nil,
        onSelect: ((WidgetElementKind) -> Void)? = nil,
        onDrag: ((WidgetElementKind, CGSize, CGSize) -> Void)? = nil,
        onDragEnd: ((WidgetElementKind) -> Void)? = nil,
        onBackgroundDrag: ((CGSize, CGSize) -> Void)? = nil,
        onBackgroundDragEnd: (() -> Void)? = nil,
        onFittedSizes: (([WidgetElementKind: CGSize], CGSize) -> Void)? = nil
    ) {
        self.metric = metric
        self.appearance = appearance
        self.palette = palette
        self.sizeKey = sizeKey
        self.useGlassEffect = useGlassEffect
        self.matchWidgetMetrics = matchWidgetMetrics
        self.updatedAt = updatedAt ?? metric.updated
        self.isEditing = isEditing
        self.selectedKind = selectedKind
        self.onSelect = onSelect
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
        self.onBackgroundDrag = onBackgroundDrag
        self.onBackgroundDragEnd = onBackgroundDragEnd
        self.onFittedSizes = onFittedSizes
    }

    private var usesWidgetChrome: Bool {
        matchWidgetMetrics || Bundle.isInWidget()
    }

    /// Result image as full-bleed background when the appearance flag is on.
    /// Otherwise `fill` is used (photo / URL / solid / gradient), and the result stays in the value slot.
    private var resultBackgroundImage: UIImage? {
        guard appearance.background.usesResultImageAsBackground,
              metric.resultKind == .image,
              let path = metric.resultImagePath
        else { return nil }
        return MetricResultImageStore.shared.loadImage(relativePath: path)
    }

    private var usesResultImageAsBackground: Bool {
        resultBackgroundImage != nil
    }

    private var allowsBackgroundPan: Bool {
        if usesResultImageAsBackground { return true }
        if case .image = appearance.background.fill { return true }
        return false
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                backgroundLayer(size: geo.size)

                ForEach(orderedElements) { element in
                    if shouldShow(element) {
                        elementView(element, canvas: geo.size)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .onPreferenceChange(ElementFittedSizeKey.self) { sizes in
                fittedSizes = sizes
                onFittedSizes?(sizes, geo.size)
            }
            .modifier(CanvasEditGestureModifier(
                isEditing: isEditing,
                elements: appearance.elements.filter(shouldShow),
                canvas: geo.size,
                fittedSizes: fittedSizes,
                selectedKind: selectedKind,
                allowsBackgroundPan: allowsBackgroundPan,
                panImageContentKinds: resultImagePanKinds,
                onSelect: { onSelect?($0) },
                onDrag: { kind, translation in
                    onDrag?(kind, translation, geo.size)
                },
                onDragEnd: { onDragEnd?($0) },
                onBackgroundDrag: { translation in
                    onBackgroundDrag?(translation, geo.size)
                },
                onBackgroundDragEnd: { onBackgroundDragEnd?() }
            ))
        }
        .modifier(AppearanceSurfaceModifier(
            shape: appearance.background.shape,
            useWidgetSurface: Bundle.isInWidget(),
            clearContainerBackground: needsClearWidgetBackground
        ))
    }

    /// Circle / glass / translucent solid need a clear container so Home Screen wallpaper shows through.
    private var needsClearWidgetBackground: Bool {
        guard Bundle.isInWidget() else { return false }
        if appearance.background.shape == .circle { return true }
        if appearance.background.usesGlassEffect { return true }
        if case .solid(let color) = appearance.background.fill {
            return colorSpecHasAlpha(color)
        }
        return false
    }

    private func colorSpecHasAlpha(_ spec: WidgetColorSpec) -> Bool {
        switch spec {
        case .hex(let hex):
            var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("#") { cleaned.removeFirst() }
            guard cleaned.count == 8, let value = UInt64(cleaned, radix: 16) else { return false }
            return ((value & 0xFF000000) >> 24) < 255
        case .adaptiveHex(let light, let dark):
            return colorSpecHasAlpha(.hex(light)) || colorSpecHasAlpha(.hex(dark))
        case .adaptive:
            return false
        }
    }

    /// Value slot with a result image: drag pans image content instead of moving the frame.
    private var resultImagePanKinds: Set<WidgetElementKind> {
        guard metric.resultKind == .image,
              !usesResultImageAsBackground,
              let path = metric.resultImagePath,
              MetricResultImageStore.shared.loadImage(relativePath: path) != nil
        else { return [] }
        return [.value]
    }

    /// Selected element on top so it receives taps/drags over overlaps.
    private var orderedElements: [WidgetElementSpec] {
        appearance.elements.sorted { lhs, rhs in
            let lSelected = lhs.kind == selectedKind
            let rSelected = rhs.kind == selectedKind
            if lSelected != rSelected { return !lSelected && rSelected }
            return false
        }
    }

    private func shouldShow(_ element: WidgetElementSpec) -> Bool {
        guard element.isVisible || isEditing else { return false }
        switch element.kind {
        case .title:
            return isEditing || !metric.title.isEmpty
        case .value:
            // Result image is drawn as the background instead of the value slot.
            if usesResultImageAsBackground { return false }
            return true
        case .measure:
            return isEditing || !metric.measure.isEmpty
        case .updated:
            return isEditing || MetricDisplayHelpers.relativeUpdatedString(for: updatedAt) != nil
        }
    }

    @ViewBuilder
    private func elementView(_ element: WidgetElementSpec, canvas: CGSize) -> some View {
        let rect = pixelRect(for: element.frame, in: canvas)
        let text = text(for: element.kind)
        let color = resolveColor(element.color, for: element.kind)
            .opacity(element.isVisible ? 1 : (isEditing ? 0.35 : 0))
        let isSelected = selectedKind == element.kind
        let editPad: CGFloat = isEditing ? 4 : 0
        let showsResultImage = element.kind == .value
            && metric.resultKind == .image
            && !usesResultImageAsBackground
        let slotW = max(rect.width - editPad * 2, 8)
        let slotH = max(rect.height - editPad * 2, 8)

        // Slot keeps layout position/alignment; label hugs content so it can be grabbed.
        Color.clear
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: frameAlignment(element.alignment)) {
                Group {
                    if showsResultImage,
                       let path = metric.resultImagePath,
                       let uiImage = MetricResultImageStore.shared.loadImage(relativePath: path) {
                        resultImageView(
                            uiImage,
                            slotWidth: slotW,
                            slotHeight: slotH,
                            scale: element.resolvedImageScale,
                            offsetX: element.imageOffsetX,
                            offsetY: element.imageOffsetY
                        )
                    } else {
                        Text(text)
                            .font(font(for: element, text: text))
                            .foregroundColor(color)
                            .lineLimit(lineLimit(for: element.kind))
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(textAlignment(element.alignment))
                            // Hug content, but never wider than the layout slot.
                            .frame(maxWidth: slotW, alignment: frameAlignment(element.alignment))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
                .padding(editPad)
                .background {
                    if isEditing {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.25),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ElementFittedSizeKey.self,
                            value: [element.kind: proxy.size]
                        )
                    }
                )
            }
            .offset(x: rect.minX, y: rect.minY)
            .zIndex(isSelected ? 10 : zIndex(for: element.kind))
            .allowsHitTesting(false)
    }

    private func resultImageView(
        _ uiImage: UIImage,
        slotWidth: CGFloat,
        slotHeight: CGFloat,
        scale: Double,
        offsetX: Double,
        offsetY: Double
    ) -> some View {
        let s = CGFloat(scale)
        let ox = CGFloat(offsetX) * slotWidth * 0.5
        let oy = CGFloat(offsetY) * slotHeight * 0.5
        return Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .scaleEffect(s)
            .offset(x: ox, y: oy)
            .frame(width: slotWidth, height: slotHeight)
            .clipped()
    }

    private func zIndex(for kind: WidgetElementKind) -> Double {
        switch kind {
        case .title: return 1
        case .value: return 2
        case .measure: return 3
        case .updated: return 4
        }
    }

    private func text(for kind: WidgetElementKind) -> String {
        switch kind {
        case .title:
            return metric.title.isEmpty ? "—" : metric.title
        case .value:
            return MetricDisplayHelpers.valueString(
                for: metric,
                goodLabel: palette.statusGoodLabel,
                badLabel: palette.statusBadLabel,
                emptyLabel: palette.emptyLabel,
                errorLabel: palette.errorLabel
            )
        case .measure:
            return metric.measure.isEmpty ? "—" : metric.measure
        case .updated:
            return MetricDisplayHelpers.relativeUpdatedString(for: updatedAt) ?? "—"
        }
    }

    private func font(for element: WidgetElementSpec, text: String) -> Font {
        let scale = CGFloat(element.resolvedFontScale)
        let inWidget = usesWidgetChrome
        switch element.kind {
        case .title:
            let base: CGFloat = inWidget ? (sizeKey == .medium ? 16 : 15) : (sizeKey == .medium ? 17 : 16)
            return .system(size: base * scale, weight: .semibold)
        case .measure:
            let base: CGFloat = inWidget ? 12 : 13
            return .system(size: base * scale, weight: .medium)
        case .updated:
            let base: CGFloat = inWidget ? 10 : 11
            return .system(size: base * scale, weight: .medium)
        case .value:
            return valueFont(for: text, scale: scale)
        }
    }

    private func valueFont(for text: String, scale: CGFloat) -> Font {
        let inWidget = usesWidgetChrome
        let isStatus = isStatusMetric
        let base: CGFloat
        if sizeKey == .medium {
            switch text.count {
            case ..<4: base = inWidget ? 44 : 48
            case ..<6: base = inWidget ? 38 : 42
            case ..<10: base = inWidget ? 32 : 36
            case ..<15: base = inWidget ? 26 : 30
            default: base = inWidget ? 20 : 24
            }
        } else {
            switch text.count {
            case ..<4: base = inWidget ? 26 : 40
            case ..<6: base = inWidget ? 22 : 34
            case ..<10: base = inWidget ? 18 : 28
            case ..<15: base = inWidget ? 15 : 22
            default: base = inWidget ? 13 : 17
            }
        }
        let size = base * scale
        return .system(size: size, weight: size < 22 ? .medium : .semibold, design: isStatus ? .rounded : .monospaced)
    }

    private func lineLimit(for kind: WidgetElementKind) -> Int {
        switch kind {
        case .title, .measure: return 2
        case .value: return isStatusMetric ? 1 : 2
        case .updated: return 1
        }
    }

    private var isStatusMetric: Bool {
        metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
    }

    private var showsValueError: Bool {
        // Empty content with failed refresh (not a status Bad).
        metric.refreshFailed && metric.result.isEmpty && metric.resultKind != .image && !isStatusMetric
    }

    private var showsStaleUpdate: Bool {
        MetricDisplayHelpers.showsStaleUpdate(for: metric)
    }

    private func resolveColor(_ spec: WidgetColorSpec, for kind: WidgetElementKind) -> Color {
        if kind == .updated && showsStaleUpdate {
            return palette.textErrorColor
        }
        switch spec {
        case .hex(let hex):
            return Color(hex: hex) ?? palette.textColor
        case .adaptiveHex(let light, let dark):
            let hex = colorScheme == .dark ? dark : light
            return Color(hex: hex) ?? palette.textColor
        case .adaptive(let token):
            return adaptiveColor(token, for: kind)
        }
    }

    private func adaptiveColor(_ token: WidgetAdaptiveColor, for kind: WidgetElementKind) -> Color {
        let onStatusGradient = appearance.background.fill == .statusGradient
        let onDarkGradient = onStatusGradient && colorScheme == .dark

        switch token {
        case .primary:
            return Color.primary
        case .secondary:
            return Color.secondary
        case .palettePrimary:
            if onDarkGradient { return Color.white.opacity(0.92) }
            return palette.textColor
        case .paletteSecondary:
            if onDarkGradient { return Color.white.opacity(0.6) }
            return palette.secondaryText
        case .onPastelSecondary:
            if onDarkGradient { return Color.white.opacity(0.6) }
            return Color(white: 0.32)
        case .value:
            if isStatusMetric {
                if metric.resultWithError {
                    return onStatusGradient && !onDarkGradient
                        ? Color(red: 0.78, green: 0.16, blue: 0.16)
                        : palette.textErrorColor
                }
                return palette.textSuccessColor
            }
            if showsValueError {
                return onStatusGradient && !onDarkGradient
                    ? Color(red: 0.78, green: 0.16, blue: 0.16)
                    : palette.textErrorColor
            }
            if onDarkGradient { return .white }
            if appearance.background.fill == .system { return Color.primary }
            return palette.textColor
        }
    }

    private func pixelRect(for frame: NormalizedRect, in canvas: CGSize) -> CGRect {
        CGRect(
            x: frame.x * canvas.width,
            y: frame.y * canvas.height,
            width: frame.width * canvas.width,
            height: frame.height * canvas.height
        )
    }

    private func textAlignment(_ alignment: WidgetTextAlignment) -> TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func frameAlignment(_ alignment: WidgetTextAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        let shape = appearance.background.shape
        let fill = fillView
        let clipped: AnyView = {
            switch shape {
            case .circle:
                return AnyView(fill.clipShape(Circle()))
            case .roundedRect:
                return AnyView(fill.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            case .rectangle:
                return AnyView(fill)
            }
        }()

        clipped
            .frame(width: size.width, height: size.height)
            .overlay {
                if effectiveGlass, #available(iOS 16.0, *), shape == .circle {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.45)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.7), .white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                }
            }
    }

    private var effectiveGlass: Bool {
        // Glass needs a clear container (see needsClearWidgetBackground).
        useGlassEffect && appearance.background.usesGlassEffect
    }

    private var cornerRadius: CGFloat {
        if usesWidgetChrome {
            if #available(iOS 26.0, *) { return 20 }
            return 16
        }
        if #available(iOS 26.0, *) { return 36 }
        return 24
    }

    @ViewBuilder
    private var fillView: some View {
        if let uiImage = resultBackgroundImage {
            transformedBackgroundImage(uiImage)
        } else {
            switch appearance.background.fill {
            case .system:
                if Bundle.isInWidget() {
                    Color("WidgetBackground")
                } else {
                    Color(uiColor: .secondarySystemGroupedBackground)
                }
            case .solid(let color):
                resolveColor(color, for: .title)
            case .gradient(let spec):
                LinearGradient(
                    colors: spec.colors.map { resolveColor($0, for: .title) },
                    startPoint: UnitPoint(x: spec.startX, y: spec.startY),
                    endPoint: UnitPoint(x: spec.endX, y: spec.endY)
                )
            case .statusGradient:
                statusGradient
            case .image(let ref):
                imageFill(ref)
            }
        }
    }

    private var statusGradient: LinearGradient {
        WidgetStatusGradients.gradient(
            for: metric,
            colorScheme: colorScheme,
            sizeKey: sizeKey
        )
    }

    @ViewBuilder
    private func imageFill(_ ref: WidgetImageRef) -> some View {
        if let uiImage = loadImage(ref) {
            transformedBackgroundImage(uiImage)
        } else {
            Color(uiColor: .secondarySystemFill)
        }
    }

    private func transformedBackgroundImage(_ uiImage: UIImage) -> some View {
        let mode: ContentMode = appearance.background.imageContentMode == .fit ? .fit : .fill
        let scale = CGFloat(appearance.background.resolvedImageScale)
        let ox = CGFloat(appearance.background.imageOffsetX)
        let oy = CGFloat(appearance.background.imageOffsetY)
        return GeometryReader { geo in
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: mode)
                .scaleEffect(scale)
                .offset(x: ox * geo.size.width * 0.5, y: oy * geo.size.height * 0.5)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }

    private func loadImage(_ ref: WidgetImageRef) -> UIImage? {
        switch ref {
        case .file(let path):
            return WidgetBackgroundStore.shared.loadImage(relativePath: path)
        case .base64(let string):
            guard let data = Data(base64Encoded: string, options: .ignoreUnknownCharacters) else { return nil }
            return UIImage(data: data)
        case .url:
            // URL backgrounds should be cached to file before render; show placeholder otherwise.
            return nil
        }
    }
}

private struct ElementFittedSizeKey: PreferenceKey {
    static var defaultValue: [WidgetElementKind: CGSize] = [:]

    static func reduce(value: inout [WidgetElementKind: CGSize], nextValue: () -> [WidgetElementKind: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Single canvas gesture with manual hit-testing so overlaps don't steal drags.
private struct CanvasEditGestureModifier: ViewModifier {
    let isEditing: Bool
    let elements: [WidgetElementSpec]
    let canvas: CGSize
    let fittedSizes: [WidgetElementKind: CGSize]
    let selectedKind: WidgetElementKind?
    let allowsBackgroundPan: Bool
    /// Element kinds whose drag pans image content (handled by parent via onDrag).
    let panImageContentKinds: Set<WidgetElementKind>
    let onSelect: (WidgetElementKind) -> Void
    let onDrag: (WidgetElementKind, CGSize) -> Void
    let onDragEnd: (WidgetElementKind) -> Void
    let onBackgroundDrag: (CGSize) -> Void
    let onBackgroundDragEnd: () -> Void

    @State private var activeKind: WidgetElementKind?
    @State private var draggingBackground = false

    func body(content: Content) -> some View {
        if isEditing {
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeKind == nil && !draggingBackground {
                            if let kind = hitTest(at: value.startLocation) {
                                activeKind = kind
                                onSelect(kind)
                            } else if allowsBackgroundPan {
                                draggingBackground = true
                            } else if let selectedKind {
                                activeKind = selectedKind
                                onSelect(selectedKind)
                            }
                        }
                        if draggingBackground {
                            onBackgroundDrag(value.translation)
                        } else if let activeKind {
                            onDrag(activeKind, value.translation)
                        }
                    }
                    .onEnded { _ in
                        if draggingBackground {
                            onBackgroundDragEnd()
                        } else if let activeKind {
                            onDragEnd(activeKind)
                        }
                        activeKind = nil
                        draggingBackground = false
                    }
            )
        } else {
            content
        }
    }

    /// Prefer selected if under finger; otherwise the smallest content box that contains the point.
    private func hitTest(at point: CGPoint) -> WidgetElementKind? {
        let hits: [(WidgetElementKind, CGFloat)] = elements.compactMap { element in
            let rect = contentRect(for: element).insetBy(dx: -6, dy: -6)
            guard rect.contains(point) else { return nil }
            return (element.kind, rect.width * rect.height)
        }
        if let selectedKind,
           hits.contains(where: { $0.0 == selectedKind }) {
            return selectedKind
        }
        return hits.min(by: { $0.1 < $1.1 })?.0
    }

    private func contentRect(for element: WidgetElementSpec) -> CGRect {
        let slot = CGRect(
            x: element.frame.x * canvas.width,
            y: element.frame.y * canvas.height,
            width: element.frame.width * canvas.width,
            height: element.frame.height * canvas.height
        )
        // Image slots use the full layout frame for hit-testing (content is clipped inside).
        if panImageContentKinds.contains(element.kind) {
            return slot
        }
        guard let fitted = fittedSizes[element.kind] else { return slot }

        let x: CGFloat
        switch element.alignment {
        case .leading: x = slot.minX
        case .center: x = slot.midX - fitted.width / 2
        case .trailing: x = slot.maxX - fitted.width
        }
        let y = slot.midY - fitted.height / 2
        return CGRect(x: x, y: y, width: fitted.width, height: fitted.height)
    }
}

// MARK: - Status gradients (legacy parity)

enum WidgetStatusGradients {
    static func gradient(for metric: Metric, colorScheme: ColorScheme, sizeKey: WidgetSizeKey) -> LinearGradient {
        let isDark = colorScheme == .dark
        let hasStatus = metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
        // Empty + failed refresh (not status Bad); stale refresh keeps previous gradient.
        let showsError = metric.refreshFailed && metric.result.isEmpty
            && metric.resultKind != .image && !hasStatus

        if sizeKey == .small {
            if hasStatus {
                if metric.resultWithError {
                    return isDark ? smallDarkBad : smallBad
                }
                return isDark ? smallDarkGood : smallGood
            }
            if showsError { return isDark ? smallDarkBad : smallBad }
            return isDark ? smallDarkDefault : smallDefault
        }

        if hasStatus {
            if metric.resultWithError {
                return isDark ? mediumDarkBad : mediumLightBad
            }
            return isDark ? mediumDarkGood : mediumLightGood
        }
        if showsError {
            return isDark ? mediumDarkBad : mediumLightBad
        }
        return isDark ? mediumDarkDefault : mediumLightDefault
    }

    private static let smallDefault = LinearGradient(
        colors: [
            Color(red: 0.961, green: 0.835, blue: 0.808),
            Color(red: 0.98, green: 0.89, blue: 0.714),
            Color(red: 0.911, green: 0.992, blue: 0.847),
            Color(red: 0.886, green: 0.949, blue: 0.973)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let smallDarkDefault = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.12, blue: 0.10),
            Color(red: 0.08, green: 0.22, blue: 0.14),
            Color(red: 0.28, green: 0.10, blue: 0.08)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let smallGood = LinearGradient(
        colors: [
            Color(red: 0.873, green: 0.962, blue: 0.802),
            Color(red: 0.709, green: 0.871, blue: 0.577)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let smallDarkGood = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.22, blue: 0.12),
            Color(red: 0.14, green: 0.28, blue: 0.16)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let smallBad = LinearGradient(
        colors: [
            Color(red: 1, green: 0.908, blue: 0.887),
            Color(red: 0.917, green: 0.716, blue: 0.672)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let smallDarkBad = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.12, blue: 0.10),
            Color(red: 0.32, green: 0.14, blue: 0.12)
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    private static let mediumLightDefault = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.95, blue: 0.75),
            Color(red: 0.88, green: 0.96, blue: 0.82),
            Color(red: 0.96, green: 0.84, blue: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let mediumDarkDefault = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.12, blue: 0.10),
            Color(red: 0.08, green: 0.22, blue: 0.14),
            Color(red: 0.28, green: 0.10, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let mediumLightGood = LinearGradient(
        colors: [
            Color(red: 0.87, green: 0.96, blue: 0.80),
            Color(red: 0.71, green: 0.87, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let mediumDarkGood = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.22, blue: 0.12),
            Color(red: 0.14, green: 0.28, blue: 0.16)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let mediumLightBad = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.91, blue: 0.89),
            Color(red: 0.92, green: 0.72, blue: 0.67)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let mediumDarkBad = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.12, blue: 0.10),
            Color(red: 0.32, green: 0.14, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct AppearanceSurfaceModifier: ViewModifier {
    let shape: WidgetSurfaceShape
    let useWidgetSurface: Bool
    let clearContainerBackground: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if useWidgetSurface {
            widgetSurface(content)
        } else {
            appSurface(content)
        }
    }

    @ViewBuilder
    private func widgetSurface(_ content: Content) -> some View {
        // iOS 17+: `containerBackground` must live on the Widget entry root
        // (`WidgetEntryView`); nesting it here is ignored and triggers
        // "Please adopt containerBackground API" on the Home Screen.
        if #available(iOS 17.0, *) {
            content
        } else if clearContainerBackground {
            content
        } else {
            content.background(Color("WidgetBackground"))
        }
    }

    @ViewBuilder
    private func appSurface(_ content: Content) -> some View {
        switch shape {
        case .circle:
            content.shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        case .roundedRect:
            content
                .clipShape(RoundedRectangle(cornerRadius: appCorner, style: .continuous))
                .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        case .rectangle:
            content
                .background {
                    RoundedRectangle(cornerRadius: appCorner, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: appCorner, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: appCorner, style: .continuous))
                .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        }
    }

    private var appCorner: CGFloat {
        if #available(iOS 26.0, *) { return 36 }
        return 24
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.1)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }
}

private extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16)
        else { return nil }

        let hasAlpha = cleaned.count == 8
        let a = hasAlpha ? Double((value & 0xFF000000) >> 24) / 255 : 1
        let r = Double((value & 0x00FF0000) >> 16) / 255
        let g = Double((value & 0x0000FF00) >> 8) / 255
        let b = Double(value & 0x000000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
