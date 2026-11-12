import SwiftUI

struct SpeechBubble: View {

    enum Side {
        case top
        case bottom
        case left
        case right
    }

    var text: String
    var side: Side = .top
    var tilt: Angle = .zero

    private let maxWidth: CGFloat = 320
    private let cornerRadius: CGFloat = 18
    private let tailWidth: CGFloat = 18
    private let tailHeight: CGFloat = 8

    var body: some View {
        bubble
            .rotationEffect(tilt)
            .padding(.horizontal, 16)
    }

    private var bubble: some View {
        label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
            .padding(textInsets)
            .background(SpeechBubbleChrome(shape: shape))
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: text)
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: side)
    }

    @ViewBuilder
    private var label: some View {
        if #available(iOS 17.0, *) {
            Text(text)
                .lineSpacing(-1)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: text)
        } else {
            Text(text)
                .lineSpacing(-1)
        }
    }

    private var shape: SpeechBubbleShape {
        SpeechBubbleShape(
            cornerRadius: cornerRadius,
            tailWidth: tailWidth,
            tailHeight: tailHeight,
            side: side
        )
    }

    private var textInsets: EdgeInsets {
        let vertical: CGFloat = 4
        let horizontal: CGFloat = 12
        switch side {
        case .top:
            return EdgeInsets(top: tailHeight + vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
        case .bottom:
            return EdgeInsets(top: vertical, leading: horizontal, bottom: tailHeight + vertical, trailing: horizontal)
        case .left:
            return EdgeInsets(top: vertical, leading: tailHeight + horizontal, bottom: vertical, trailing: horizontal)
        case .right:
            return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: tailHeight + horizontal)
        }
    }
}

private struct SpeechBubbleChrome: View {
    var shape: SpeechBubbleShape

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        ZStack {
            shape
                .fill(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14))
                .blur(radius: 6)
                .offset(y: 3)
            fill
        }
    }

    @ViewBuilder
    private var fill: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5))
                }
                .overlay {
                    shape.stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.75), lineWidth: 0.75)
                }
        }
    }
}

private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var side: SpeechBubble.Side

    func path(in rect: CGRect) -> Path {
        let tail = min(tailHeight, min(rect.width, rect.height) / 3)
        let body = bodyRect(in: rect, tail: tail)
        let radius = min(cornerRadius, body.width / 2, body.height / 2)
        let halfX = min(tailWidth / 2, max(0, body.width / 2 - radius))
        let halfY = min(tailWidth / 2, max(0, body.height / 2 - radius))

        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        addTopEdge(to: &path, body: body, rect: rect, radius: radius, half: halfX)
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        addRightEdge(to: &path, body: body, rect: rect, radius: radius, half: halfY)
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        addBottomEdge(to: &path, body: body, rect: rect, radius: radius, half: halfX)
        path.addArc(
            center: CGPoint(x: body.minX + radius, y: body.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        addLeftEdge(to: &path, body: body, rect: rect, radius: radius, half: halfY)
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

    private func bodyRect(in rect: CGRect, tail: CGFloat) -> CGRect {
        switch side {
        case .top:
            return CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
        case .bottom:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        case .left:
            return CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        case .right:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
        }
    }

    private func addTopEdge(to path: inout Path, body: CGRect, rect: CGRect, radius: CGFloat, half: CGFloat) {
        if side == .top {
            path.addLine(to: CGPoint(x: body.midX - half, y: body.minY))
            path.addLine(to: CGPoint(x: body.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: body.midX + half, y: body.minY))
        }
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
    }

    private func addRightEdge(to path: inout Path, body: CGRect, rect: CGRect, radius: CGFloat, half: CGFloat) {
        if side == .right {
            path.addLine(to: CGPoint(x: body.maxX, y: body.midY - half))
            path.addLine(to: CGPoint(x: rect.maxX, y: body.midY))
            path.addLine(to: CGPoint(x: body.maxX, y: body.midY + half))
        }
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
    }

    private func addBottomEdge(to path: inout Path, body: CGRect, rect: CGRect, radius: CGFloat, half: CGFloat) {
        if side == .bottom {
            path.addLine(to: CGPoint(x: body.midX + half, y: body.maxY))
            path.addLine(to: CGPoint(x: body.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: body.midX - half, y: body.maxY))
        }
        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
    }

    private func addLeftEdge(to path: inout Path, body: CGRect, rect: CGRect, radius: CGFloat, half: CGFloat) {
        if side == .left {
            path.addLine(to: CGPoint(x: body.minX, y: body.midY + half))
            path.addLine(to: CGPoint(x: rect.minX, y: body.midY))
            path.addLine(to: CGPoint(x: body.minX, y: body.midY - half))
        }
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
    }
}
