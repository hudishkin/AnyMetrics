#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftUI

public struct MetricWidgetPalette {
    public var textColor: Color
    public var textErrorColor: Color
    public var secondaryText: Color
    public var statusGoodLabel: String
    public var statusBadLabel: String

    public init(
        textColor: Color,
        textErrorColor: Color,
        secondaryText: Color,
        statusGoodLabel: String = "Good",
        statusBadLabel: String = "Bad"
    ) {
        self.textColor = textColor
        self.textErrorColor = textErrorColor
        self.secondaryText = secondaryText
        self.statusGoodLabel = statusGoodLabel
        self.statusBadLabel = statusBadLabel
    }

    public static let preview = MetricWidgetPalette(
        textColor: .black,
        textErrorColor: .red,
        secondaryText: .secondary
    )
}

fileprivate enum DesignConstants {
    static let fontValue: Font = {
        Font.system(
            size: Bundle.isInWidget() ? 28 : 34,
            weight: .heavy,
            design: .default)
    }()

    static func fontValue(size: CGFloat) -> Font {
        Font.system(
            size: size,
            weight: size < 25 ? .regular : .light,
            design: .default)
    }

    static let fontTitle: Font = {
        Font.system(size: Bundle.isInWidget() ? 16 : 18, weight: .bold, design: .default)
    }()

    static let fontParam: Font = {
        Font.system(size: Bundle.isInWidget() ? 11 : 13, weight: .regular, design: .default)
    }()

    static let paramsInset = EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
    static let valueFrameHeight: CGFloat = Bundle.isInWidget() ? 29 : 40
    static let labelOffset: CGFloat = Bundle.isInWidget() ? 48 : 54
    static let cardLabelOffset: CGFloat = Bundle.isInWidget() ? 36 : 48
    static let valuePaddingInset = EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)
    static let titlePaddingInset = EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
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
}

public struct MetricWidgetDesignView: View {

    public let metric: Metric
    public let palette: MetricWidgetPalette
    public let useGlassEffect: Bool

    public init(
        metric: Metric,
        palette: MetricWidgetPalette,
        useGlassEffect: Bool = false
    ) {
        self.metric = metric
        self.palette = palette
        self.useGlassEffect = useGlassEffect
    }

    private var design: WidgetDesign {
        metric.widgetDesign ?? .default
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
        case .minimal:
            minimalLayout
        case .ring:
            ringLayout
        case .plain:
            plainLayout
        }
    }

    private var glassCircleLayout: some View {
        ZStack(alignment: .center) {
            backgroundCircle(useGlass: useGlassEffect)
            titleText
                .offset(y: -DesignConstants.labelOffset)
            valueText
            measureText
                .offset(y: DesignConstants.labelOffset)
        }
        .contentShape(Circle())
    }

    private var roundedCardLayout: some View {
        ZStack {
            cardBackgroundFill
            cardTextContent
        }
        .modifier(CardClipModifier())
    }

    private var cardTextContent: some View {
        ZStack {
            titleText
                .offset(y: -DesignConstants.cardLabelOffset)
            valueText
            measureText
                .offset(y: DesignConstants.cardLabelOffset)
        }
    }

    private var plainLayout: some View {
        ZStack {
            titleText
                .offset(y: -DesignConstants.labelOffset)
            valueText
            measureText
                .offset(y: DesignConstants.labelOffset)
        }
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

    private var minimalLayout: some View {
        ZStack {
            Circle()
                .fill(backgroundGradient().opacity(0.35))
            VStack(spacing: 8) {
                titleText
                    .font(DesignConstants.fontParam.weight(.semibold))
                    .foregroundColor(palette.secondaryText)
                valueText
                    .font(dynamicFont().weight(.medium))
                measureText
                    .font(DesignConstants.fontParam)
                    .foregroundColor(palette.secondaryText)
            }
            .padding(.horizontal, 20)
        }
    }

    private var ringLayout: some View {
        ZStack {
            Circle()
                .stroke(
                    backgroundGradient(),
                    style: StrokeStyle(
                        lineWidth: DesignConstants.ringLineWidth,
                        lineCap: .round
                    )
                )
                .padding(10)
            VStack(spacing: 4) {
                titleText
                    .font(DesignConstants.fontParam.weight(.semibold))
                valueText
                    .font(dynamicFont().weight(.semibold))
                measureText
                    .font(DesignConstants.fontParam)
                    .foregroundColor(palette.secondaryText)
            }
            .padding(.horizontal, 24)
        }
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
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
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

    @ViewBuilder
    private var measureText: some View {
        if !metric.measure.isEmpty {
            Text(metric.measure)
                .font(DesignConstants.fontParam)
                .lineLimit(DesignConstants.paramLines)
                .multilineTextAlignment(.center)
                .foregroundColor(palette.textColor)
                .padding(DesignConstants.paramsInset)
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none) {
            Text(metric.resultWithError ? statusBadLabel : statusGoodLabel)
                .frame(height: DesignConstants.valueFrameHeight, alignment: .center)
                .font(DesignConstants.fontValue)
                .multilineTextAlignment(.center)
                .foregroundColor(palette.textColor)
                .padding(DesignConstants.valuePaddingInset)
        } else {
            Text(displayResult)
                .multilineTextAlignment(.center)
                .lineLimit(DesignConstants.paramLines)
                .frame(height: DesignConstants.valueFrameHeight, alignment: .center)
                .font(dynamicFont())
                .foregroundColor(metric.resultWithError ? palette.textErrorColor : palette.textColor)
                .padding(DesignConstants.valuePaddingInset)
        }
    }

    private var displayResult: String {
        metric.result.isEmpty ? "—" : metric.result
    }

    private var statusBadLabel: String { palette.statusBadLabel }
    private var statusGoodLabel: String { palette.statusGoodLabel }

    private func backgroundGradient() -> LinearGradient {
        if metric.type != .checkStatus && ((metric.rules?.type ?? ParseRules.RuleType.none) == .none) {
            return DesignConstants.defaultCircleGradient
        }
        if metric.resultWithError {
            return DesignConstants.badCircleGradient
        }
        return DesignConstants.goodCircleGradient
    }

    private func dynamicFont() -> Font {
        let value = displayResult
        if value.count < 4 {
            return DesignConstants.fontValue(size: 42)
        }
        if value.count < 6 {
            return DesignConstants.fontValue(size: 40)
        }
        if value.count < 10 {
            return DesignConstants.fontValue(size: Bundle.isInWidget() ? 30 : 34)
        }
        if value.count < 15 {
            return DesignConstants.fontValue(size: 24)
        }
        return DesignConstants.fontValue(size: 19)
    }
}

private struct CardClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if Bundle.isInWidget() {
            content
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
        MetricWidgetDesignView(metric: Mocks.metricJson, palette: .preview, useGlassEffect: true)
            .frame(width: 200, height: 200)
    }
}
#endif
