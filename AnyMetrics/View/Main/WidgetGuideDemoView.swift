import SwiftUI

struct WidgetGuideDemoView: View {

    let step: Int
    let system: WidgetInstructionsView.System
    let metricTitle: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            scene(DemoPhase.make(at: timeline.date, paused: reduceMotion))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func scene(_ phase: Double) -> some View {
        switch step {
        case 1:
            LongPressDemo(phase: phase)
        case 2:
            if system == .ios16 {
                PlusTapDemo(phase: phase)
            } else {
                EditMenuDemo(phase: phase)
            }
        case 3:
            SearchDemo(phase: phase)
        case 4:
            SizeDemo(phase: phase, swipes: system == .ios18)
        default:
            SelectMetricDemo(phase: phase, metricTitle: metricTitle)
        }
    }
}

private enum DemoPhase {
    static let cycle: TimeInterval = 3.8

    static func make(at date: Date, paused: Bool) -> Double {
        if paused { return 0.62 }
        let time = date.timeIntervalSinceReferenceDate
        return time.truncatingRemainder(dividingBy: cycle) / cycle
    }
}

private func demoSpan(_ phase: Double, _ start: Double, _ end: Double) -> Double {
    let raw = min(1, max(0, (phase - start) / (end - start)))
    return raw * raw * (3 - 2 * raw)
}

private enum DemoLayout {
    /// Proportions of a 390pt iPhone home screen: 60pt icons, equal 30pt gaps and side margins.
    private static let referenceWidth: CGFloat = 390
    private static let referenceIcon: CGFloat = 60
    private static let referenceSpacing: CGFloat = 30
    private static let referenceRowSpacing: CGFloat = 18
    private static let referenceDockInset: CGFloat = 10
    private static let referenceDockVerticalPadding: CGFloat = 15
    private static let referenceDockCorner: CGFloat = 36

    static let screen = CGSize(width: 136, height: 268)
    static let columns = 4
    static let rows = 6
    static let screenCorner: CGFloat = 22
    static let bezelInset: CGFloat = 4
    static let iconCornerRatio: CGFloat = 0.2237

    private static var scale: CGFloat { screen.width / referenceWidth }

    static var icon: CGFloat { referenceIcon * scale }
    static var gap: CGFloat { referenceSpacing * scale }
    static var rowGap: CGFloat { referenceRowSpacing * scale }
    static var iconCorner: CGFloat { icon * iconCornerRatio }
    static var dockInset: CGFloat { referenceDockInset * scale }
    static var dockHeight: CGFloat { icon + referenceDockVerticalPadding * scale * 2 }
    static var dockCorner: CGFloat { referenceDockCorner * scale }
    static let dockBottom: CGFloat = 14

    static var iconCount: Int { columns * rows }

    static var gridOrigin: CGPoint {
        CGPoint(x: gap, y: 50)
    }

    static func iconCenter(index: Int) -> CGPoint {
        let row = index / columns
        let column = index % columns
        return CGPoint(
            x: gridOrigin.x + CGFloat(column) * (icon + gap) + icon / 2,
            y: gridOrigin.y + CGFloat(row) * (icon + rowGap) + icon / 2
        )
    }
}

private struct DemoStage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Color.clear
            .frame(width: DemoLayout.screen.width, height: DemoLayout.screen.height)
            .overlay { content() }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: 42, height: 12)
                    .padding(.top, 7)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.28))
                    .frame(width: 44, height: 4)
                    .padding(.bottom, 6)
            }
            .background(Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: DemoLayout.screenCorner, style: .continuous))
            .padding(DemoLayout.bezelInset)
            .background(
                RoundedRectangle(cornerRadius: DemoLayout.screenCorner + DemoLayout.bezelInset, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DemoLayout.screenCorner + DemoLayout.bezelInset, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct DemoAppIcon: View {
    let index: Int
    var jiggle: Double
    var phase: Double

    var body: some View {
        RoundedRectangle(cornerRadius: DemoLayout.iconCorner, style: .continuous)
            .fill(Color.primary.opacity(0.14 + Double(index % 4) * 0.05))
            .frame(width: DemoLayout.icon, height: DemoLayout.icon)
            .rotationEffect(.degrees(jiggle * sin(phase * 28 + Double(index) * 1.3) * 5))
    }
}

private struct DemoIconGrid: View {
    var phase: Double
    var jiggle: Double
    var hidden: Int = -1

    var body: some View {
        ForEach(0..<DemoLayout.iconCount, id: \.self) { index in
            if index != hidden {
                DemoAppIcon(index: index, jiggle: jiggle, phase: phase)
                    .position(DemoLayout.iconCenter(index: index))
            }
        }
    }
}

private struct DemoDock: View {
    var jiggle: Double = 0
    var phase: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DemoLayout.dockCorner, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .padding(.horizontal, DemoLayout.dockInset)
            HStack(spacing: DemoLayout.gap) {
                ForEach(0..<DemoLayout.columns, id: \.self) { index in
                    DemoAppIcon(index: index + 8, jiggle: jiggle, phase: phase)
                }
            }
        }
        .frame(height: DemoLayout.dockHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, DemoLayout.dockBottom)
    }
}

private struct DemoPress: View {
    var amount: Double
    var holding: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.45 * holding), lineWidth: 1.5)
                .frame(width: 14 + 18 * holding, height: 14 + 18 * holding)
            Circle()
                .fill(Color.primary.opacity(0.28))
                .frame(width: 16, height: 16)
                .scaleEffect(1.2 - 0.24 * amount)
        }
        .opacity(amount)
    }
}

private struct DemoAddButton: View {
    var pressed: Double

    var body: some View {
        Text(AnyMetricsStrings.WidgetGuide.Demo.addWidget)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(Color.primary.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.primary.opacity(0.1 + pressed * 0.18)))
            .scaleEffect(1 - pressed * 0.06)
    }
}

private struct LongPressDemo: View {
    var phase: Double

    private var press: Double {
        demoSpan(phase, 0.08, 0.26) * (1 - demoSpan(phase, 0.84, 0.96))
    }

    private var hold: Double {
        demoSpan(phase, 0.26, 0.46) * (1 - demoSpan(phase, 0.78, 0.9))
    }

    private var jiggle: Double {
        demoSpan(phase, 0.44, 0.56) * (1 - demoSpan(phase, 0.82, 0.94))
    }

    var body: some View {
        let target = DemoLayout.iconCenter(index: 5)
        DemoStage {
            ZStack {
                DemoIconGrid(phase: phase, jiggle: jiggle, hidden: 5)
                DemoDock(jiggle: jiggle, phase: phase)
                DemoPress(amount: press, holding: hold)
                    .position(x: target.x, y: target.y + (1 - press) * 20)
            }
        }
    }
}

private struct PlusTapDemo: View {
    var phase: Double

    private var tap: Double {
        demoSpan(phase, 0.16, 0.3) * (1 - demoSpan(phase, 0.4, 0.5))
    }

    private var sheet: Double {
        demoSpan(phase, 0.4, 0.56) * (1 - demoSpan(phase, 0.84, 0.96))
    }

    var body: some View {
        DemoStage {
            ZStack {
                DemoIconGrid(phase: phase, jiggle: 0.7)
                DemoDock(jiggle: 0.7, phase: phase)
                plusButton
                    .position(x: 20, y: 26)
                gallerySheet
            }
        }
    }

    private var plusButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color.primary.opacity(0.8))
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.primary.opacity(0.1 + tap * 0.2)))
            .scaleEffect(1 - tap * 0.12)
    }

    private var gallerySheet: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.primary.opacity(0.25))
                .frame(width: 28, height: 3)
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 22, height: 22)
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: (1 - sheet) * 70)
        .opacity(sheet)
    }
}

private struct EditMenuDemo: View {
    var phase: Double

    private var tap: Double {
        demoSpan(phase, 0.12, 0.26) * (1 - demoSpan(phase, 0.34, 0.42))
    }

    private var menu: Double {
        demoSpan(phase, 0.32, 0.44) * (1 - demoSpan(phase, 0.86, 0.96))
    }

    private var highlight: Double {
        demoSpan(phase, 0.5, 0.64) * (1 - demoSpan(phase, 0.8, 0.9))
    }

    var body: some View {
        DemoStage {
            ZStack(alignment: .topLeading) {
                DemoIconGrid(phase: phase, jiggle: 0.45)
                DemoDock(jiggle: 0.45, phase: phase)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AnyMetricsStrings.WidgetGuide.Demo.edit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color.primary.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.14 + tap * 0.2)))
                        .scaleEffect(1 - tap * 0.08)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(AnyMetricsStrings.WidgetGuide.Demo.addWidget)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.16 + highlight * 0.2))
                            )
                    }
                    .frame(width: 92)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.28))
                            .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                    )
                    .opacity(menu)
                    .scaleEffect(menu > 0 ? 1 : 0.92, anchor: .topLeading)
                }
                .padding(.top, 18)
                .padding(.leading, 8)
            }
        }
    }
}

private struct SearchDemo: View {
    var phase: Double

    private let query = "AnyMetrics"

    private var typed: Double {
        demoSpan(phase, 0.08, 0.5) * (1 - demoSpan(phase, 0.86, 0.97))
    }

    private var pick: Double {
        demoSpan(phase, 0.55, 0.68) * (1 - demoSpan(phase, 0.82, 0.92))
    }

    var body: some View {
        let count = Int((typed * Double(query.count)).rounded(.down))
        DemoStage {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9, weight: .semibold))
                    Text(String(query.prefix(count)))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(Color.primary.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(Color.primary.opacity(0.08)))

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 16, height: 16)
                    Text(query)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.primary.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06 + pick * 0.16))
                )
                .opacity(count > 2 ? 1 : 0.2)
                .scaleEffect(1 - pick * 0.04)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 30)
            .padding(.bottom, 16)
        }
    }
}

private struct SizeDemo: View {
    var phase: Double
    var swipes: Bool

    private var alive: Double {
        1 - demoSpan(phase, 0.86, 0.97)
    }

    private var pressed: Double {
        demoSpan(phase, 0.68, 0.78) * (1 - demoSpan(phase, 0.82, 0.9))
    }

    var body: some View {
        DemoStage {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Group {
                    if swipes {
                        swipingSizes
                    } else {
                        choosingSizes
                    }
                }
                .opacity(alive)
                DemoAddButton(pressed: pressed)
                    .opacity(alive)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var choosingSizes: some View {
        let progress = demoSpan(phase, 0.12, 0.55)
        let selected = min(2, Int(progress * 2.99))
        return HStack(spacing: 4) {
            widgetFace(width: 20, height: 20, selected: selected == 0)
            widgetFace(width: 34, height: 20, selected: selected == 1)
            widgetFace(width: 34, height: 30, selected: selected == 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var swipingSizes: some View {
        let shift = demoSpan(phase, 0.14, 0.62)
        return ZStack {
            HStack(spacing: 8) {
                widgetFace(width: 36, height: 36, selected: shift < 0.35)
                widgetFace(width: 72, height: 40, selected: shift >= 0.35 && shift < 0.7)
                widgetFace(width: 72, height: 56, selected: shift >= 0.7)
            }
            .offset(x: 28 - shift * 80)

            DemoPress(amount: shift > 0.04 && shift < 0.92 ? 0.85 : 0, holding: 0.15)
                .offset(x: -18 + shift * 36, y: 18)
        }
        .frame(height: 76)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func widgetFace(width: CGFloat, height: CGFloat, selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(selected ? 0.16 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(selected ? 0.55 : 0.12), lineWidth: selected ? 1.5 : 1)
            )
            .frame(width: width, height: height)
    }
}

private struct SelectMetricDemo: View {
    var phase: Double
    var metricTitle: String

    private var press: Double {
        demoSpan(phase, 0.06, 0.22) * (1 - demoSpan(phase, 0.36, 0.46))
    }

    private var menu: Double {
        demoSpan(phase, 0.3, 0.42) * (1 - demoSpan(phase, 0.56, 0.64))
    }

    private var list: Double {
        demoSpan(phase, 0.6, 0.72) * (1 - demoSpan(phase, 0.9, 0.98))
    }

    var body: some View {
        DemoStage {
            ZStack {
                widget
                    .opacity(1 - list)
                    .overlay {
                        DemoPress(amount: press, holding: press)
                            .offset(y: (1 - press) * 14)
                    }
                Text(AnyMetricsStrings.WidgetGuide.Demo.editWidget)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.28))
                            .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
                    )
                    .offset(y: 36)
                    .opacity(menu)
                metricList
                    .opacity(list)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var widget: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.1))
            .frame(width: 92, height: 48)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 34, height: 8)
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 56, height: 3)
                }
                .foregroundColor(Color.primary.opacity(0.35))
                .padding(10)
            }
    }

    private var metricList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AnyMetricsStrings.WidgetGuide.Demo.metricType)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color.primary.opacity(0.55))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(metricTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.28))
                .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
        )
    }
}

#if DEBUG
#Preview("Long press") {
    WidgetGuideDemoView(step: 1, system: .ios18, metricTitle: "Server Status")
        .padding()
}
#endif
