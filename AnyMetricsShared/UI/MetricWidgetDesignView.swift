#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftUI

public struct MetricWidgetPalette {
    public var textColor: Color
    public var textErrorColor: Color
    public var textSuccessColor: Color
    public var secondaryText: Color
    public var statusGoodLabel: String
    public var statusBadLabel: String
    public var emptyLabel: String
    public var errorLabel: String

    public init(
        textColor: Color,
        textErrorColor: Color,
        textSuccessColor: Color = Color(red: 0.16, green: 0.52, blue: 0.30),
        secondaryText: Color,
        statusGoodLabel: String = "Good",
        statusBadLabel: String = "Bad",
        emptyLabel: String = "N/A",
        errorLabel: String = "Error"
    ) {
        self.textColor = textColor
        self.textErrorColor = textErrorColor
        self.textSuccessColor = textSuccessColor
        self.secondaryText = secondaryText
        self.statusGoodLabel = statusGoodLabel
        self.statusBadLabel = statusBadLabel
        self.emptyLabel = emptyLabel
        self.errorLabel = errorLabel
    }

    public static let preview = MetricWidgetPalette(
        textColor: .black,
        textErrorColor: .red,
        textSuccessColor: Color(red: 0.16, green: 0.52, blue: 0.30),
        secondaryText: .secondary
    )

    public static func widget(bundle: Bundle = Bundle(for: MetricStore.self)) -> MetricWidgetPalette {
        MetricWidgetPalette(
            textColor: Color("metricText", bundle: bundle),
            textErrorColor: Color("red", bundle: bundle),
            secondaryText: Color("secondaryText", bundle: bundle),
            statusGoodLabel: NSLocalizedString("metric.value.good", bundle: bundle, comment: ""),
            statusBadLabel: NSLocalizedString("metric.value.bad", bundle: bundle, comment: ""),
            emptyLabel: NSLocalizedString("metric.value.empty", bundle: bundle, comment: ""),
            errorLabel: NSLocalizedString("metric.value.error", bundle: bundle, comment: "")
        )
    }
}

fileprivate enum DesignConstants {
    static func fontValue(size: CGFloat, monospaced: Bool) -> Font {
        Font.system(
            size: size,
            weight: size < 22 ? .medium : .semibold,
            design: monospaced ? .monospaced : .rounded)
    }

    static let fontTitle: Font = {
        Font.system(size: Bundle.isInWidget() ? 15 : 16, weight: .semibold, design: .default)
    }()

    static let fontParam: Font = {
        Font.system(size: Bundle.isInWidget() ? 11 : 12, weight: .medium, design: .default)
    }()

    static let paramsInset: EdgeInsets = {
        Bundle.isInWidget()
            ? EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
            : EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }()

    static let valueFrameHeight: CGFloat = Bundle.isInWidget() ? 28 : 42
    static let labelOffset: CGFloat = Bundle.isInWidget() ? 40 : 52
    static let cardLabelOffset: CGFloat = Bundle.isInWidget() ? 32 : 46
    static let valuePaddingInset = EdgeInsets(top: 0, leading: 8, bottom: 2, trailing: 8)
    static let titlePaddingInset: EdgeInsets = {
        Bundle.isInWidget()
            ? EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
            : EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }()
    static let plainContentPadding = EdgeInsets(
        top: Bundle.isInWidget() ? 14 : 18,
        leading: Bundle.isInWidget() ? 16 : 18,
        bottom: Bundle.isInWidget() ? 12 : 14,
        trailing: Bundle.isInWidget() ? 16 : 18
    )
    static let plainMeasureFont: Font = .system(
        size: Bundle.isInWidget() ? 12 : 13,
        weight: .medium,
        design: .default
    )
    static let updatedFont: Font = .system(
        size: Bundle.isInWidget() ? 10 : 11,
        weight: .medium,
        design: .default
    )
    static let captionStackSpacing: CGFloat = 2
    static let plainFooterTopPadding: CGFloat = 6
    static let paramLines = 2
    static let ringLineWidth: CGFloat = Bundle.isInWidget() ? 6 : 8
    static let widgetCardInset: CGFloat = 2

    static var widgetCardCornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 20
        }
        return 16
    }

    static var appCardCornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 36
        }
        return 24
    }

    static let plainShadowRadius: CGFloat = 12
    static let plainShadowY: CGFloat = 4

    static func appShadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.55)
            : Color.black.opacity(0.1)
    }

    static let defaultCircleGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.961, green: 0.835, blue: 0.808),
            Color(red: 0.98, green: 0.89, blue: 0.714),
            Color(red: 0.911, green: 0.992, blue: 0.847),
            Color(red: 0.886, green: 0.949, blue: 0.973)
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    static let goodCircleGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.873, green: 0.962, blue: 0.802),
            Color(red: 0.709, green: 0.871, blue: 0.577)
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    static let badCircleGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1, green: 0.908, blue: 0.887),
            Color(red: 0.917, green: 0.716, blue: 0.672)
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    /// Darker red for contrast on light pastel fills.
    static let onPastelErrorColor = Color(red: 0.78, green: 0.16, blue: 0.16)
}

public struct MetricWidgetDesignView: View {

    public let metric: Metric
    public let palette: MetricWidgetPalette
    public let useGlassEffect: Bool
    public let updatedAt: Date?

    public init(
        metric: Metric,
        palette: MetricWidgetPalette,
        useGlassEffect: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.metric = metric
        self.palette = palette
        self.useGlassEffect = useGlassEffect
        self.updatedAt = updatedAt ?? metric.updated
    }

    private var design: WidgetDesign {
        metric.widgetDesign ?? .default
    }

    private var effectiveGlassEffect: Bool {
        useGlassEffect && !Bundle.isInWidget()
    }

    private var updatedLabel: String? {
        MetricDisplayHelpers.relativeUpdatedString(for: updatedAt)
    }

    public var body: some View {
        designContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(WidgetSurfaceModifier())
    }

    @ViewBuilder
    private var designContent: some View {
        switch design {
        case .glassCircle:
            glassCircleLayout
        case .roundedCard:
            roundedCardLayout
        case .plain:
            plainLayout
        }
    }

    private var glassCircleLayout: some View {
        ZStack(alignment: .center) {
            backgroundCircle(useGlass: effectiveGlassEffect)
            titleText
                .offset(y: -DesignConstants.labelOffset)
            valueText
            centeredBottomCaption
                .offset(y: DesignConstants.labelOffset)
        }
        .contentShape(Circle())
        .modifier(AppMetricShadowModifier())
    }

    private var roundedCardLayout: some View {
        ZStack {
            cardBackgroundFill
            cardTextContent
        }
        .modifier(CardClipModifier())
        .modifier(AppMetricShadowModifier())
    }

    private var cardTextContent: some View {
        ZStack {
            titleText
                .offset(y: -DesignConstants.cardLabelOffset)
            valueText
            centeredBottomCaption
                .offset(y: DesignConstants.cardLabelOffset)
        }
    }

    private var plainLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.title)
                .font(DesignConstants.fontTitle)
                .foregroundColor(Color.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            plainValueText
            plainFooterRow
        }
        .padding(DesignConstants.plainContentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(PlainSurfaceModifier())
    }

    @ViewBuilder
    private var plainFooterRow: some View {
        let showUpdatedTime = updatedLabel != nil

        if !metric.measure.isEmpty || showUpdatedTime {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !metric.measure.isEmpty {
                    Text(metric.measure)
                        .font(DesignConstants.plainMeasureFont)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                if showUpdatedTime, let updatedLabel {
                    Text(updatedLabel)
                        .font(DesignConstants.updatedFont)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, DesignConstants.plainFooterTopPadding)
        }
    }

    /// Pastel fills stay light in every color scheme — secondary must stay dark for contrast.
    private var coloredSecondaryText: Color {
        Color(white: 0.32)
    }

    @ViewBuilder
    private var centeredBottomCaption: some View {
        let showUpdatedTime = updatedLabel != nil

        if !metric.measure.isEmpty || showUpdatedTime {
            VStack(spacing: DesignConstants.captionStackSpacing) {
                if !metric.measure.isEmpty {
                    Text(metric.measure)
                        .font(DesignConstants.fontParam)
                        .lineLimit(DesignConstants.paramLines)
                        .multilineTextAlignment(.center)
                        .foregroundColor(coloredSecondaryText)
                }

                if showUpdatedTime, let updatedLabel {
                    Text(updatedLabel)
                        .font(DesignConstants.updatedFont)
                        .foregroundColor(coloredSecondaryText.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)
            .padding(DesignConstants.paramsInset)
        }
    }

    private var plainValueText: some View {
        Text(displayValue)
            .font(plainValueFont())
            .foregroundColor(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBackgroundFill: some View {
        RoundedRectangle(
            cornerRadius: Bundle.isInWidget()
                ? DesignConstants.widgetCardCornerRadius
                : DesignConstants.appCardCornerRadius,
            style: .continuous
        )
        .fill(backgroundGradient())
        .padding(Bundle.isInWidget() ? DesignConstants.widgetCardInset : 0)
    }

    @ViewBuilder
    private func backgroundCircle(useGlass: Bool) -> some View {
        if useGlass, #available(iOS 16.0, *) {
            Circle()
                .fill(backgroundGradient())
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.45)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.7),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        } else {
            Circle()
                .fill(backgroundGradient())
        }
    }

    private var titleText: some View {
        Text(metric.title)
            .foregroundColor(palette.textColor)
            .font(DesignConstants.fontTitle)
            .lineLimit(DesignConstants.paramLines)
            .multilineTextAlignment(.center)
            .padding(DesignConstants.titlePaddingInset)
    }

    private var valueText: some View {
        Text(displayValue)
            .multilineTextAlignment(.center)
            .lineLimit(isStatusMetric ? 1 : DesignConstants.paramLines)
            .minimumScaleFactor(0.5)
            .frame(height: DesignConstants.valueFrameHeight, alignment: .center)
            .font(dynamicFont())
            .foregroundColor(valueColor)
            .padding(DesignConstants.valuePaddingInset)
    }

    private var isStatusMetric: Bool {
        metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
    }

    private var displayValue: String {
        MetricDisplayHelpers.valueString(
            for: metric,
            goodLabel: statusGoodLabel,
            badLabel: statusBadLabel,
            emptyLabel: palette.emptyLabel,
            errorLabel: palette.errorLabel
        )
    }

    private var valueColor: Color {
        if isStatusMetric {
            return metric.resultWithError ? errorTextColor : palette.textSuccessColor
        }
        if showsValueError {
            return errorTextColor
        }
        return design == .plain ? Color.primary : palette.textColor
    }

    /// Error styling only when there is no retained value to show.
    private var showsValueError: Bool {
        metric.resultWithError && metric.result.isEmpty
    }

    /// Pastel surfaces need a darker red than the theme accent.
    private var errorTextColor: Color {
        design == .plain ? palette.textErrorColor : DesignConstants.onPastelErrorColor
    }

    private var statusBadLabel: String { palette.statusBadLabel }
    private var statusGoodLabel: String { palette.statusGoodLabel }

    private func backgroundGradient() -> LinearGradient {
        if !isStatusMetric {
            if showsValueError {
                return DesignConstants.badCircleGradient
            }
            return DesignConstants.defaultCircleGradient
        }
        if metric.resultWithError {
            return DesignConstants.badCircleGradient
        }
        return DesignConstants.goodCircleGradient
    }

    private func dynamicFont() -> Font {
        let value = displayValue
        let isWidget = Bundle.isInWidget()
        let size: CGFloat
        switch value.count {
        case ..<4:
            size = isWidget ? 26 : 40
        case ..<6:
            size = isWidget ? 22 : 34
        case ..<10:
            size = isWidget ? 18 : 28
        case ..<15:
            size = isWidget ? 15 : 22
        default:
            size = isWidget ? 13 : 17
        }
        return DesignConstants.fontValue(size: size, monospaced: !isStatusMetric)
    }

    private func plainValueFont() -> Font {
        let value = displayValue
        let isWidget = Bundle.isInWidget()
        let size: CGFloat
        switch value.count {
        case ..<4:
            size = isWidget ? 34 : 40
        case ..<6:
            size = isWidget ? 28 : 34
        case ..<10:
            size = isWidget ? 24 : 30
        case ..<15:
            size = isWidget ? 20 : 24
        default:
            size = isWidget ? 16 : 20
        }
        return DesignConstants.fontValue(size: size, monospaced: !isStatusMetric)
    }
}

private struct PlainSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if Bundle.isInWidget() {
            content
        } else {
            content
                .background {
                    RoundedRectangle(
                        cornerRadius: DesignConstants.appCardCornerRadius,
                        style: .continuous
                    )
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: DesignConstants.appCardCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(borderColor, lineWidth: 1)
                    }
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignConstants.appCardCornerRadius,
                        style: .continuous
                    )
                )
                .shadow(
                    color: DesignConstants.appShadowColor(for: colorScheme),
                    radius: DesignConstants.plainShadowRadius,
                    x: 0,
                    y: DesignConstants.plainShadowY
                )
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.06)
    }
}

private struct AppMetricShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if Bundle.isInWidget() {
            content
        } else {
            content.shadow(
                color: DesignConstants.appShadowColor(for: colorScheme),
                radius: DesignConstants.plainShadowRadius,
                x: 0,
                y: DesignConstants.plainShadowY
            )
        }
    }
}

private struct CardClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if Bundle.isInWidget() {
            content.clipShape(
                RoundedRectangle(
                    cornerRadius: DesignConstants.widgetCardCornerRadius,
                    style: .continuous
                )
            )
        } else {
            content
                .clipShape(CardClipShape())
                .contentShape(CardClipShape())
        }
    }
}

private struct WidgetSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        guard Bundle.isInWidget() else {
            return AnyView(content)
        }

        if #available(iOS 17.0, *) {
            return AnyView(
                content.modifier(WidgetSurfaceModifierIOS17())
            )
        }

        return AnyView(
            content.background(Color("WidgetBackground"))
        )
    }
}

@available(iOS 17.0, *)
private struct WidgetSurfaceModifierIOS17: ViewModifier {
    func body(content: Content) -> some View {
        content.containerBackground(Color("WidgetBackground"), for: .widget)
    }
}

private struct CardClipShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: DesignConstants.appCardCornerRadius,
            style: .continuous
        ).path(in: rect)
    }
}

#if DEBUG
struct MetricWidgetDesignView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MetricWidgetDesignView(metric: Mocks.metricJson, palette: .preview, useGlassEffect: true)
                .frame(width: 200, height: 200)
                .previewDisplayName("Glass Circle")

            MetricWidgetDesignView(
                metric: {
                    var metric = Mocks.metricJson
                    metric.widgetDesign = .plain
                    return metric
                }(),
                palette: .preview
            )
            .frame(width: 200, height: 200)
            .previewDisplayName("Plain")
        }
    }
}
#endif
