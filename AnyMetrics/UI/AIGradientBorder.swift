import SwiftUI

struct AIGradientBorder: View {
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme

    private static let cycle: TimeInterval = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let turn = reduceMotion
                ? 0.15
                : timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
            border(turn: turn)
        }
        .allowsHitTesting(false)
    }

    private func border(turn: Double) -> some View {
        let angle = turn * 360
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let gradient = AngularGradient(
            gradient: Self.gradient,
            center: .center,
            startAngle: .degrees(angle),
            endAngle: .degrees(angle + 360)
        )
        let glow = colorScheme == .dark ? 0.45 : 0.55

        return ZStack {
            shape
                .stroke(gradient, lineWidth: 8)
                .blur(radius: 8)
                .clipShape(shape)
                .opacity(glow)
            shape
                .strokeBorder(gradient, lineWidth: 0.5)
        }
    }

    private static let gradient = Gradient(stops: [
        .init(color: Color(red: 0.45, green: 0.76, blue: 0.72), location: 0.00),
        .init(color: Color(red: 0.74, green: 0.84, blue: 0.48), location: 0.16),
        .init(color: Color(red: 0.95, green: 0.84, blue: 0.32), location: 0.32),
        .init(color: Color(red: 0.93, green: 0.52, blue: 0.24), location: 0.46),
        .init(color: Color(red: 0.96, green: 0.74, blue: 0.48), location: 0.58),
        .init(color: Color(red: 0.90, green: 0.82, blue: 0.66), location: 0.72),
        .init(color: Color(red: 0.62, green: 0.78, blue: 0.88), location: 0.86),
        .init(color: Color(red: 0.45, green: 0.76, blue: 0.72), location: 1.00),
    ])
}
