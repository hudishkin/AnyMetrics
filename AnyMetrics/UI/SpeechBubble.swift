import SwiftUI

enum SpeechBubbleSide: Equatable {
    case top
    case topCenter
    case bottomLeading
    case bottomTrailing
    case bottomCenter
    case left
    case right

    var tailOnTop: Bool {
        self == .top || self == .topCenter
    }

    var tailOnBottom: Bool {
        self == .bottomLeading || self == .bottomTrailing || self == .bottomCenter
    }
}

enum SpeechBubbleRole: Equatable {
    case robot
    case user
}

struct SpeechBubbleStyle: Equatable {
    var fill: [Color]
    var stroke: Color
    var shadow: Color
    var shadowRadius: CGFloat
    var shadowY: CGFloat

    static func style(role: SpeechBubbleRole, scheme: ColorScheme) -> SpeechBubbleStyle {
        let dark = scheme == .dark
        switch role {
        case .robot:
            return dark ? robotDark : robotLight
        case .user:
            return dark ? userDark : userLight
        }
    }

    private static let robotLight = SpeechBubbleStyle(
        fill: [Color.white, Color(red: 0.93, green: 0.94, blue: 0.96)],
        stroke: Color.black.opacity(0.10),
        shadow: Color.black.opacity(0.10),
        shadowRadius: 8,
        shadowY: 3
    )
    /// Opaque, so the screen gradient and the bubbles behind do not show through.
    private static let robotDark = SpeechBubbleStyle(
        fill: [Color(white: 0.22), Color(white: 0.17)],
        stroke: Color.white.opacity(0.14),
        shadow: Color.black.opacity(0.32),
        shadowRadius: 8,
        shadowY: 3
    )
    private static let userLight = SpeechBubbleStyle(
        fill: [Color.white, Color(red: 0.96, green: 0.97, blue: 0.98)],
        stroke: Color.black.opacity(0.08),
        shadow: Color.black.opacity(0.16),
        shadowRadius: 14,
        shadowY: -10
    )
    private static let userDark = SpeechBubbleStyle(
        fill: [Color(white: 0.19), Color(white: 0.15)],
        stroke: Color.white.opacity(0.10),
        shadow: Color.black.opacity(0.4),
        shadowRadius: 14,
        shadowY: -10
    )
}

struct SpeechBubble<Content: View>: View {

    var side: SpeechBubbleSide
    var role: SpeechBubbleRole
    var tilt: Angle
    var maxWidth: CGFloat
    var content: Content

    private let cornerRadius: CGFloat = 24
    private let tailWidth: CGFloat = 42
    private let tailHeight: CGFloat = 11
    /// Insets of the content inside the bubble body. The tail sits outside this box.
    private let contentPadding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)

    init(
        side: SpeechBubbleSide = .top,
        role: SpeechBubbleRole = .robot,
        tilt: Angle = .zero,
        maxWidth: CGFloat = 320,
        @ViewBuilder content: () -> Content
    ) {
        self.side = side
        self.role = role
        self.tilt = tilt
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        SpeechBubbleLayout(maxWidth: maxWidth) {
            content
        }
        .padding(contentPadding)
        .padding(tailInsets)
        .background(SpeechBubbleChrome(shape: shape, role: role))
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: side)
        .rotationEffect(tilt)
        .padding(.horizontal, 16)
    }

    private var shape: SpeechBubbleShape {
        SpeechBubbleShape(
            cornerRadius: cornerRadius,
            tailWidth: tailWidth,
            tailHeight: tailReach,
            side: side
        )
    }

    /// How far the tail sticks out. Side tails are longer so a short bubble still reads as a tail, not a sliver.
    private var tailReach: CGFloat {
        side == .left || side == .right ? 14 : tailHeight
    }

    /// Extra space the tail occupies outside the padded body, so the tip never eats the content inset.
    private var tailInsets: EdgeInsets {
        EdgeInsets(
            top: side.tailOnTop ? tailReach : 0,
            leading: side == .left ? tailReach : 0,
            bottom: side.tailOnBottom ? tailReach : 0,
            trailing: side == .right ? tailReach : 0
        )
    }
}

private struct SpeechBubbleLayout: Layout {
    var maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let limit = min(proposal.width ?? .infinity, maxWidth)
        let natural = subview.sizeThatFits(.unspecified)
        // A child capped with frame(maxWidth:) reports that cap as its ideal width and a single-line height.
        // Equality means the line was clamped, so the height has to be measured again at the real width.
        guard natural.width >= limit, limit.isFinite else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: limit, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let natural = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        subview.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: min(bounds.width, natural.width), height: natural.height)
        )
    }
}

private struct SpeechBubbleChrome: View {
    var shape: SpeechBubbleShape
    var role: SpeechBubbleRole

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        let style = SpeechBubbleStyle.style(role: role, scheme: colorScheme)
        let centeredOnTop = shape.side == .topCenter
        shape
            .fill(
                LinearGradient(colors: style.fill, startPoint: .top, endPoint: .bottom)
            )
            .overlay {
                shape.stroke(style.stroke, lineWidth: 0.75)
            }
            .shadow(
                color: style.shadow,
                radius: centeredOnTop ? 20 : style.shadowRadius,
                y: centeredOnTop ? 14 : style.shadowY
            )
    }
}

private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var side: SpeechBubbleSide

    func path(in rect: CGRect) -> Path {
        let tail = min(tailHeight, min(rect.width, rect.height) / 3)
        let body = bodyRect(in: rect, tail: tail)
        let radius = resolvedRadius(body: body)

        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        addEdge(
            to: &path,
            from: CGPoint(x: body.minX + radius, y: body.minY),
            to: CGPoint(x: body.maxX - radius, y: body.minY),
            outward: CGVector(dx: 0, dy: -1),
            hasTail: side.tailOnTop,
            tail: tail
        )
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        addEdge(
            to: &path,
            from: CGPoint(x: body.maxX, y: body.minY + radius),
            to: CGPoint(x: body.maxX, y: body.maxY - radius),
            outward: CGVector(dx: 1, dy: 0),
            hasTail: side == .right,
            tail: tail
        )
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        addEdge(
            to: &path,
            from: CGPoint(x: body.maxX - radius, y: body.maxY),
            to: CGPoint(x: body.minX + radius, y: body.maxY),
            outward: CGVector(dx: 0, dy: 1),
            hasTail: side.tailOnBottom,
            tail: tail
        )
        path.addArc(
            center: CGPoint(x: body.minX + radius, y: body.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        addEdge(
            to: &path,
            from: CGPoint(x: body.minX, y: body.maxY - radius),
            to: CGPoint(x: body.minX, y: body.minY + radius),
            outward: CGVector(dx: -1, dy: 0),
            hasTail: side == .left,
            tail: tail
        )
        path.addArc(
            center: CGPoint(x: body.minX + radius, y: body.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    private func addEdge(
        to path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        outward: CGVector,
        hasTail: Bool,
        tail: CGFloat
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard hasTail, length > 1 else {
            path.addLine(to: end)
            return
        }

        let tangent = CGVector(dx: dx / length, dy: dy / length)
        let width = min(preferredTailBase, length * 0.92)
        let half = width * 0.5
        let anchor = min(max(length * tailFraction, half), length - half)
        let mirrored = side == .bottomLeading
        let symmetric = side == .topCenter || side == .bottomCenter || side == .left || side == .right

        func point(_ distance: CGFloat, _ out: CGFloat) -> CGPoint {
            CGPoint(
                x: start.x + tangent.dx * distance + outward.dx * out,
                y: start.y + tangent.dy * distance + outward.dy * out
            )
        }

        let tailStart = point(anchor - width * 0.5, 0)
        let tailEnd = point(anchor + width * 0.5, 0)
        path.addLine(to: tailStart)
        if symmetric {
            path.addCurve(
                to: point(anchor - width * 0.08, tail * 0.7),
                control1: point(anchor - width * 0.22, 0),
                control2: point(anchor - width * 0.14, tail * 0.42)
            )
            path.addQuadCurve(
                to: point(anchor + width * 0.08, tail * 0.7),
                control: point(anchor, tail)
            )
            path.addCurve(
                to: tailEnd,
                control1: point(anchor + width * 0.14, tail * 0.42),
                control2: point(anchor + width * 0.22, 0)
            )
        } else if mirrored {
            path.addCurve(
                to: point(anchor + width * 0.06, tail * 0.68),
                control1: point(anchor - width * 0.22, 0),
                control2: point(anchor + width * 0.02, tail * 0.4)
            )
            path.addQuadCurve(
                to: point(anchor + width * 0.26, tail * 0.62),
                control: point(anchor + width * 0.18, tail)
            )
            path.addCurve(
                to: tailEnd,
                control1: point(anchor + width * 0.30, tail * 0.35),
                control2: point(anchor + width * 0.22, 0)
            )
        } else {
            path.addCurve(
                to: point(anchor - width * 0.26, tail * 0.62),
                control1: point(anchor - width * 0.22, 0),
                control2: point(anchor - width * 0.30, tail * 0.35)
            )
            path.addQuadCurve(
                to: point(anchor - width * 0.06, tail * 0.68),
                control: point(anchor - width * 0.18, tail)
            )
            path.addCurve(
                to: tailEnd,
                control1: point(anchor - width * 0.02, tail * 0.4),
                control2: point(anchor + width * 0.22, 0)
            )
        }
        path.addLine(to: end)
    }

    private var tailFraction: CGFloat {
        switch side {
        case .bottomTrailing:
            return 0.27
        case .topCenter, .bottomCenter, .left, .right:
            return 0.5
        default:
            return 0.73
        }
    }

    /// Widest the tail may be. Side edges are shorter, so their tail stays narrower than the top one.
    private var preferredTailBase: CGFloat {
        side == .left || side == .right ? 26 : tailWidth
    }

    /// Shrinks the corner when the tailed edge is short, so the tail keeps a real base instead of a hairline.
    private func resolvedRadius(body: CGRect) -> CGFloat {
        let limit = min(cornerRadius, body.width / 2, body.height / 2)
        let span = side == .left || side == .right ? body.height : body.width
        let base = min(preferredTailBase, span * 0.5)
        let fitted = (span - base) / 2
        return min(limit, max(fitted, 0))
    }

    private func bodyRect(in rect: CGRect, tail: CGFloat) -> CGRect {
        switch side {
        case .top, .topCenter:
            return CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
        case .bottomLeading, .bottomTrailing, .bottomCenter:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        case .left:
            return CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        case .right:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
        }
    }

}

private struct SpeechBubblePreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                sample("Short, tail top") {
                    SpeechBubble(side: .topCenter, role: .robot) {
                        bubbleText("Hi")
                    }
                }
                sample("Short, tail bottom") {
                    SpeechBubble(side: .bottomCenter, role: .user) {
                        bubbleText("Hi")
                    }
                }
                sample("Long") {
                    SpeechBubble(side: .topCenter, role: .robot, maxWidth: 280) {
                        bubbleText("I couldn't recognise that location. Please enter a city name, or a city and country, for the current weather.")
                    }
                }
                sample("User") {
                    SpeechBubble(side: .bottomCenter, role: .user, maxWidth: 280) {
                        bubbleText("What's the weather in San Francisco right now?", alignment: .leading)
                    }
                }
                sample("Loader") {
                    SpeechBubble(side: .topCenter, role: .robot) {
                        ProgressView()
                    }
                }
                sample("Loader and text") {
                    SpeechBubble(side: .topCenter, role: .robot) {
                        HStack(spacing: 10) {
                            ProgressView()
                            bubbleText("Looking that up")
                        }
                    }
                }
                sample("Tail left") {
                    SpeechBubble(side: .left, role: .robot) {
                        bubbleText("One line")
                    }
                }
                sample("Tail right") {
                    SpeechBubble(side: .right, role: .user) {
                        bubbleText("One line")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func sample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func bubbleText(_ text: String, alignment: TextAlignment = .center) -> some View {
        speechBubblePreviewText(text, alignment: alignment)
    }
}

private struct SpeechBubbleTiltPreview: View {
    private let long = "I couldn't recognise that location. Please enter a city name, or a city and country, for the current weather."

    var body: some View {
        ScrollView {
            VStack(spacing: 56) {
                sample("Top −3°, long") {
                    robot(long)
                        .rotationEffect(.degrees(-3), anchor: .top)
                }
                sample("Top −7°, long") {
                    robot(long)
                        .rotationEffect(.degrees(-7), anchor: .top)
                }
                sample("Top −3°, short") {
                    robot("Hi")
                        .rotationEffect(.degrees(-3), anchor: .top)
                }
                sample("Top −7°, loader") {
                    SpeechBubble(side: .topCenter, role: .robot) {
                        ProgressView()
                    }
                    .rotationEffect(.degrees(-7), anchor: .top)
                }
                sample("Bottom 1°, long") {
                    user("What's the weather in San Francisco right now?")
                        .rotationEffect(.degrees(1), anchor: .bottom)
                }
                sample("Bottom 2°, short") {
                    user("Hi")
                        .rotationEffect(.degrees(2), anchor: .bottom)
                }
                sample("Center −8°, long") {
                    SpeechBubble(side: .topCenter, role: .robot, tilt: .degrees(-8), maxWidth: 280) {
                        speechBubblePreviewText(long)
                    }
                }
                sample("Center 8°, short") {
                    SpeechBubble(side: .bottomCenter, role: .user, tilt: .degrees(8)) {
                        speechBubblePreviewText("Hi")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func robot(_ text: String) -> some View {
        SpeechBubble(side: .topCenter, role: .robot, maxWidth: 280) {
            speechBubblePreviewText(text)
        }
    }

    private func user(_ text: String) -> some View {
        SpeechBubble(side: .bottomCenter, role: .user, maxWidth: 280) {
            speechBubblePreviewText(text, alignment: .leading)
        }
    }

    private func sample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .padding(.vertical, 28)
        }
    }
}

private func speechBubblePreviewText(_ text: String, alignment: TextAlignment = .center) -> some View {
    Text(text)
        .font(.system(size: 16))
        .multilineTextAlignment(alignment)
        .lineSpacing(2)
}

#Preview("Light") {
    SpeechBubblePreview()
}

#Preview("Dark") {
    SpeechBubblePreview()
        .preferredColorScheme(.dark)
}

#Preview("Tilted") {
    SpeechBubbleTiltPreview()
}
