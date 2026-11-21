import SwiftUI

struct WidgetGuideDemoView: View {

    let step: Int
    let system: WidgetInstructionsView.System
    let metricTitle: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            scene(DemoClock(elapsed: max(0, timeline.date.timeIntervalSince(startDate)), paused: reduceMotion))
        }
        .onAppear { startDate = Date() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func scene(_ clock: DemoClock) -> some View {
        switch step {
        case 1:
            LongPressDemo(clock: clock)
        case 2:
            if system == .ios16 {
                PlusTapDemo(clock: clock)
            } else {
                EditMenuDemo(clock: clock)
            }
        case 3:
            SearchDemo(clock: clock)
        case 4:
            SizeDemo(clock: clock)
        default:
            SelectMetricDemo(clock: clock, metricTitle: metricTitle)
        }
    }
}

// MARK: - Timing

private struct DemoClock {
    let elapsed: TimeInterval
    let paused: Bool

    /// Local scene time; with Reduce Motion the scene freezes on its most telling frame.
    func time(cycle: TimeInterval, still: TimeInterval) -> TimeInterval {
        paused ? still : elapsed.truncatingRemainder(dividingBy: cycle)
    }

    func wobble(_ index: Int, amount: Double) -> Angle {
        guard !paused, amount > 0 else { return .zero }
        return .degrees(amount * 2.2 * sin(elapsed * 2 * .pi * 3.2 + Double(index) * 1.9))
    }
}

private func linear(_ t: Double, _ start: Double, _ duration: Double) -> Double {
    min(1, max(0, (t - start) / duration))
}

private func rise(_ t: Double, _ start: Double, _ duration: Double) -> Double {
    let x = linear(t, start, duration)
    return x * x * (3 - 2 * x)
}

private func pulse(_ t: Double, _ on: Double, _ off: Double, fade: Double = 0.15) -> Double {
    rise(t, on, fade) * (1 - rise(t, off, fade))
}

private func overshoot(_ x: Double) -> Double {
    let c = 1.70158
    let y = x - 1
    return 1 + (c + 1) * y * y * y + c * y * y
}

private func mix(_ a: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
}

// MARK: - Style

private enum DemoPalette {
    static let accent = Color.blue
    static let screen = Color(.systemBackground)
    static let bezel = Color(.systemGray4)
    static let tile = Color(.systemGray5)
    static let popover = Color(.secondarySystemGroupedBackground)
    static let separator = Color(.separator)
    static let text = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
}

private enum DemoLayout {
    /// Proportions of a 390pt iPhone home screen: 60pt icons, equal 30pt gaps and side margins.
    private static let referenceWidth: CGFloat = 390
    private static let referenceIcon: CGFloat = 60
    private static let referenceSpacing: CGFloat = 30
    private static let referenceRowSpacing: CGFloat = 18

    static let screen = CGSize(width: 136, height: 268)
    static let columns = 4
    static let screenCorner: CGFloat = 22
    static let bezelInset: CGFloat = 4
    static let iconCornerRatio: CGFloat = 0.2237

    private static var scale: CGFloat { screen.width / referenceWidth }

    static var icon: CGFloat { referenceIcon * scale }
    static var gap: CGFloat { referenceSpacing * scale }
    static var rowGap: CGFloat { referenceRowSpacing * scale }
    static var iconCorner: CGFloat { icon * iconCornerRatio }
    static var midX: CGFloat { screen.width / 2 }

    static var gridOrigin: CGPoint {
        CGPoint(x: gap, y: 58)
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

private extension View {
    func demoPopover(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DemoPalette.popover)
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(DemoPalette.separator, lineWidth: 0.5)
        )
    }

    func demoAppear(_ appear: Double, vanish: Double = 0, anchor: UnitPoint = .center) -> some View {
        scaleEffect((0.85 + 0.15 * overshoot(appear)) * (1 - 0.05 * vanish), anchor: anchor)
            .opacity(min(1, appear * 2) * (1 - vanish))
    }
}

// MARK: - Building blocks

private struct DemoStage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Color.clear
            .frame(width: DemoLayout.screen.width, height: DemoLayout.screen.height)
            .overlay { content() }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 40, height: 11)
                    .padding(.top, 7)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(DemoPalette.text.opacity(0.25))
                    .frame(width: 44, height: 4)
                    .padding(.bottom, 6)
            }
            .background(DemoPalette.screen)
            .clipShape(RoundedRectangle(cornerRadius: DemoLayout.screenCorner, style: .continuous))
            .padding(DemoLayout.bezelInset)
            .background(
                RoundedRectangle(cornerRadius: DemoLayout.screenCorner + DemoLayout.bezelInset, style: .continuous)
                    .fill(DemoPalette.bezel)
            )
    }
}

private struct DemoHomeIcons: View {
    let clock: DemoClock
    var rows: Range<Int>
    var jiggle: Double = 0

    var body: some View {
        ForEach(rows.lowerBound * DemoLayout.columns ..< rows.upperBound * DemoLayout.columns, id: \.self) { index in
            RoundedRectangle(cornerRadius: DemoLayout.iconCorner, style: .continuous)
                .fill(DemoPalette.tile)
                .frame(width: DemoLayout.icon, height: DemoLayout.icon)
                .rotationEffect(clock.wobble(index, amount: jiggle))
                .position(DemoLayout.iconCenter(index: index))
        }
    }
}

/// Finger marker: the only accent element besides the final "Add Widget" button.
private struct DemoTouch: View {
    var visible: Double
    var pressed: Double
    var hold: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: hold)
                .stroke(DemoPalette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 32, height: 32)
                .opacity(hold > 0 ? 1 : 0)
            Circle()
                .fill(DemoPalette.accent.opacity(0.22 + 0.33 * pressed))
                .overlay(Circle().strokeBorder(DemoPalette.accent, lineWidth: 2))
                .frame(width: 22, height: 22)
                .scaleEffect(1 - 0.2 * pressed)
        }
        .scaleEffect(0.7 + 0.3 * visible)
        .opacity(visible)
    }
}

private struct DemoWidgetFace: View {
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(DemoPalette.tile)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().frame(width: min(26, width - 14), height: 3)
                    Capsule().frame(width: min(16, width - 14), height: 7)
                }
                .foregroundColor(DemoPalette.secondaryText.opacity(0.5))
                .padding(7)
            }
    }
}

// MARK: - Step 1: long press on the wallpaper

private struct LongPressDemo: View {
    let clock: DemoClock

    var body: some View {
        let t = clock.time(cycle: 3.0, still: 1.1)
        DemoStage {
            DemoHomeIcons(clock: clock, rows: 0..<3, jiggle: pulse(t, 1.05, 2.6, fade: 0.2))
            DemoTouch(
                visible: pulse(t, 0.1, 1.2, fade: 0.2),
                pressed: pulse(t, 0.3, 1.15, fade: 0.1),
                hold: linear(t, 0.4, 0.7)
            )
            .position(x: DemoLayout.midX, y: 190)
        }
    }
}

// MARK: - Step 2 (iOS 16–17): "+" in the top-left corner

private struct PlusTapDemo: View {
    let clock: DemoClock

    private let plusCenter = CGPoint(x: 22, y: 40)

    var body: some View {
        let t = clock.time(cycle: 3.2, still: 0.7)
        let pressed = pulse(t, 0.55, 0.8, fade: 0.1)
        let sheet = rise(t, 0.8, 0.35) * (1 - rise(t, 2.75, 0.3))
        DemoStage {
            Group {
                DemoHomeIcons(clock: clock, rows: 0..<3, jiggle: 1)
                plusButton(pressed: pressed)
                    .position(plusCenter)
            }
            .opacity(1 - 0.5 * sheet)
            DemoTouch(visible: pulse(t, 0.1, 0.95, fade: 0.2), pressed: pressed)
                .position(mix(CGPoint(x: plusCenter.x + 18, y: plusCenter.y + 26), plusCenter, rise(t, 0.1, 0.4)))
            gallerySheet
                .offset(y: (1 - sheet) * 170)
        }
    }

    private func plusButton(pressed: Double) -> some View {
        Image(systemName: "plus")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(DemoPalette.text)
            .frame(width: 20, height: 20)
            .background(Circle().fill(DemoPalette.tile))
            .scaleEffect(1 - 0.12 * pressed)
    }

    private var gallerySheet: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(DemoPalette.secondaryText.opacity(0.4))
                .frame(width: 24, height: 3)
            Capsule()
                .fill(DemoPalette.tile)
                .frame(height: 18)
            HStack(spacing: 8) {
                DemoWidgetFace(width: 50, height: 50)
                DemoWidgetFace(width: 50, height: 50)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: DemoLayout.screen.width, height: 160)
        .demoPopover(cornerRadius: 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: 20)
    }
}

// MARK: - Step 2 (iOS 18+): Edit → Add Widget

private struct EditMenuDemo: View {
    let clock: DemoClock

    private let editCenter = CGPoint(x: 36, y: 40)
    private let editSize = CGSize(width: 52, height: 18)
    private let itemCenter = CGPoint(x: 62, y: 68)
    private let itemSize = CGSize(width: 104, height: 24)

    var body: some View {
        let t = clock.time(cycle: 3.6, still: 1.45)
        let editPressed = pulse(t, 0.4, 0.6, fade: 0.1)
        let itemPressed = pulse(t, 1.35, 1.6, fade: 0.1)
        DemoStage {
            DemoHomeIcons(clock: clock, rows: 0..<3, jiggle: 1)
            editButton(pressed: editPressed)
                .position(editCenter)
            menu(pressed: itemPressed)
                .demoAppear(linear(t, 0.6, 0.3), vanish: rise(t, 3.1, 0.3), anchor: .topLeading)
                .position(itemCenter)
            DemoTouch(visible: pulse(t, 0.1, 1.75, fade: 0.2), pressed: max(editPressed, itemPressed))
                .position(mix(editCenter, itemCenter, rise(t, 0.85, 0.4)))
        }
    }

    private func editButton(pressed: Double) -> some View {
        Text(AnyMetricsStrings.WidgetGuide.Demo.edit)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(DemoPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .frame(width: editSize.width, height: editSize.height)
            .background(Capsule().fill(DemoPalette.tile))
            .scaleEffect(1 - 0.08 * pressed)
    }

    private func menu(pressed: Double) -> some View {
        Text(AnyMetricsStrings.WidgetGuide.Demo.addWidget)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(DemoPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .frame(width: itemSize.width, height: itemSize.height, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DemoPalette.tile.opacity(pressed))
            )
            .demoPopover(cornerRadius: 7)
    }
}

// MARK: - Step 3: search AnyMetrics in the gallery

private struct SearchDemo: View {
    let clock: DemoClock

    private let query = "AnyMetrics"
    private let resultCenter = CGPoint(x: DemoLayout.midX, y: 86)

    var body: some View {
        let t = clock.time(cycle: 3.4, still: 1.5)
        let count = Int((linear(t, 0.15, 0.8) * Double(query.count)).rounded(.down))
        let pressed = pulse(t, 1.4, 1.6, fade: 0.1)
        let reset = 1 - rise(t, 3.0, 0.3)
        DemoStage {
            Group {
                searchField(count: count)
                    .position(x: DemoLayout.midX, y: 46)
                resultRow(pressed: pressed)
                    .demoAppear(linear(t, 0.55, 0.3))
                    .position(resultCenter)
            }
            .opacity(reset)
            DemoTouch(visible: pulse(t, 1.1, 1.8, fade: 0.2), pressed: pressed)
                .position(x: resultCenter.x + 20, y: resultCenter.y)
        }
    }

    private func searchField(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DemoPalette.secondaryText)
            Text(String(query.prefix(count)))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DemoPalette.text)
                .lineLimit(1)
            Rectangle()
                .fill(DemoPalette.accent)
                .frame(width: 1, height: 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: DemoLayout.screen.width - 20, height: 22)
        .background(Capsule().fill(DemoPalette.tile))
    }

    private func resultRow(pressed: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DemoPalette.screen)
                .frame(width: 18, height: 18)
                .background(RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(DemoPalette.text))
            Text(query)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DemoPalette.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(width: DemoLayout.screen.width - 20, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DemoPalette.tile.opacity(0.35 + 0.65 * pressed))
        )
    }
}

// MARK: - Step 4: swipe to a size, tap Add Widget

private struct SizeDemo: View {
    let clock: DemoClock

    private let pageWidth: CGFloat = 92
    private let carouselY: CGFloat = 104
    private let buttonCenter = CGPoint(x: DemoLayout.midX, y: 204)
    private let sizes: [CGSize] = [
        CGSize(width: 42, height: 42),
        CGSize(width: 84, height: 42),
        CGSize(width: 84, height: 84)
    ]

    var body: some View {
        let t = clock.time(cycle: 4.0, still: 1.9)
        let shift = rise(t, 0.5, 0.6) * (t < 3.7 ? 1 : 0)
        let dragging = pulse(t, 0.4, 1.1, fade: 0.1)
        let buttonPressed = pulse(t, 1.8, 2.0, fade: 0.1)
        let dragStart = CGPoint(x: DemoLayout.midX + 30, y: carouselY + 30)
        let dragEnd = CGPoint(x: DemoLayout.midX - 30, y: carouselY + 30)
        let touchPoint = mix(mix(dragStart, dragEnd, shift), buttonCenter, rise(t, 1.25, 0.4))
        DemoStage {
            Group {
                ForEach(sizes.indices, id: \.self) { index in
                    DemoWidgetFace(width: sizes[index].width, height: sizes[index].height)
                        .position(x: DemoLayout.midX + (CGFloat(index) - CGFloat(shift)) * pageWidth, y: carouselY)
                }
                pageDots(active: shift > 0.5 ? 1 : 0)
                    .position(x: DemoLayout.midX, y: 158)
                addButton(pressed: buttonPressed)
                    .position(buttonCenter)
            }
            .opacity(1 - pulse(t, 3.5, 3.85, fade: 0.15))
            DemoTouch(visible: pulse(t, 0.2, 2.2, fade: 0.2), pressed: max(dragging, buttonPressed))
                .position(touchPoint)
        }
    }

    private func pageDots(active: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(sizes.indices, id: \.self) { index in
                Circle()
                    .fill(DemoPalette.text.opacity(index == active ? 0.8 : 0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func addButton(pressed: Double) -> some View {
        Text(AnyMetricsStrings.WidgetGuide.Demo.addWidget)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .frame(width: DemoLayout.screen.width - 24, height: 26)
            .background(Capsule().fill(DemoPalette.accent.opacity(1 - 0.25 * pressed)))
            .scaleEffect(1 - 0.05 * pressed)
    }
}

// MARK: - Step 5: Edit Widget → Metric Type

private struct SelectMetricDemo: View {
    let clock: DemoClock
    var metricTitle: String

    private var widgetSize: CGSize {
        CGSize(width: DemoLayout.screen.width - DemoLayout.gap * 2, height: DemoLayout.icon * 2 + DemoLayout.rowGap)
    }

    private var widgetCenter: CGPoint {
        CGPoint(x: DemoLayout.midX, y: DemoLayout.gridOrigin.y + widgetSize.height / 2)
    }

    private var itemCenter: CGPoint {
        CGPoint(x: DemoLayout.midX, y: widgetCenter.y + widgetSize.height / 2 + 20)
    }

    var body: some View {
        let t = clock.time(cycle: 4.4, still: 2.4)
        let holdPressed = pulse(t, 0.3, 1.0, fade: 0.1)
        let itemPressed = pulse(t, 1.5, 1.7, fade: 0.1)
        let menuVanish = rise(t, 1.75, 0.2)
        let card = linear(t, 1.85, 0.3)
        let cardVanish = rise(t, 4.0, 0.3)
        let focus = pulse(t, 0.9, 4.0, fade: 0.2)
        DemoStage {
            DemoHomeIcons(clock: clock, rows: 2..<4)
                .opacity(1 - 0.6 * focus)
            DemoWidgetFace(width: widgetSize.width, height: widgetSize.height)
                .scaleEffect(1 + 0.04 * pulse(t, 0.9, 1.75, fade: 0.15))
                .opacity(1 - 0.6 * card * (1 - cardVanish))
                .position(widgetCenter)
            menuItem(pressed: itemPressed)
                .demoAppear(linear(t, 1.0, 0.3), vanish: menuVanish, anchor: .top)
                .position(itemCenter)
            editCard
                .demoAppear(card, vanish: cardVanish)
                .position(x: DemoLayout.midX, y: itemCenter.y)
            DemoTouch(
                visible: pulse(t, 0.1, 1.85, fade: 0.2),
                pressed: max(holdPressed, itemPressed),
                hold: linear(t, 0.35, 0.6) * (1 - rise(t, 1.0, 0.1))
            )
            .position(mix(widgetCenter, itemCenter, rise(t, 1.1, 0.35)))
        }
    }

    private func menuItem(pressed: Double) -> some View {
        Text(AnyMetricsStrings.WidgetGuide.Demo.editWidget)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(DemoPalette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .frame(width: 110, height: 24, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DemoPalette.tile.opacity(pressed))
            )
            .demoPopover(cornerRadius: 7)
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AnyMetricsStrings.WidgetGuide.Demo.metricType)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(DemoPalette.secondaryText)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(metricTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DemoPalette.accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(DemoPalette.accent)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(width: 116, alignment: .leading)
        .demoPopover(cornerRadius: 10)
    }
}

#if DEBUG
#Preview("All steps") {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(1...5, id: \.self) { step in
                WidgetGuideDemoView(step: step, system: .ios18, metricTitle: "Server Status")
            }
            WidgetGuideDemoView(step: 2, system: .ios16, metricTitle: "Server Status")
        }
        .padding()
    }
}
#endif
