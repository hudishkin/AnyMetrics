import SwiftUI

struct RobotFaceView: View {

    enum Kind {
        case glance
        case widget
    }

    var size: CGFloat
    var kind: Kind = .glance
    var ink: Color = .white

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            face(pose(at: timeline.date))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func pose(at date: Date) -> FacePose {
        switch kind {
        case .glance:
            Glance.pose(at: date, paused: reduceMotion)
        case .widget:
            WidgetTransform.pose(at: date, paused: reduceMotion)
        }
    }

    private func face(_ pose: FacePose) -> some View {
        let inset = FaceLayout.padding * size
        let borderSide = size - inset * 2
        let container = squircle(FaceLayout.corner * size)
        let border = squircle(FaceLayout.corner * borderSide)
        return ZStack {
            RobotMeshGradient(side: size)
                .clipShape(container)
            ZStack {
                mark(pose.left, side: borderSide)
                mark(pose.right, side: borderSide)
            }
            .frame(width: borderSide, height: borderSide)
            .clipShape(border)
            .overlay(border.strokeBorder(ink, lineWidth: FaceLayout.lineWidth * borderSide))
        }
        .frame(width: size, height: size)
        .scaleEffect(x: pose.scaleX, y: pose.scaleY)
        .offset(x: pose.headX * borderSide, y: pose.headY * borderSide)
    }

    private func mark(_ mark: FaceMark, side: CGFloat) -> some View {
        let width = mark.size.width * side
        let height = mark.size.height * side
        return squircle(min(width, height) * mark.corner)
            .fill(ink)
            .frame(width: width, height: height)
            .position(x: mark.center.x * side, y: mark.center.y * side)
    }
}

private func squircle(_ radius: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
}

private struct FaceMark {
    var center: CGPoint
    var size: CGSize
    var corner: CGFloat = 0.5
}

private struct FacePose {
    var headX: CGFloat = 0
    var headY: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var left: FaceMark
    var right: FaceMark
}

private func sample(_ keys: [(Double, CGFloat)], _ frame: Double) -> CGFloat {
    guard let first = keys.first else { return 0 }
    if frame <= first.0 { return first.1 }
    for index in keys.indices.dropFirst() {
        let previous = keys[index - 1]
        let next = keys[index]
        if frame <= next.0 {
            let span = next.0 - previous.0
            let t = span > 0 ? (frame - previous.0) / span : 1
            let eased = t * t * (3 - 2 * t)
            return previous.1 + (next.1 - previous.1) * eased
        }
    }
    return keys[keys.count - 1].1
}

private func lerp(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
    from + (to - from) * amount
}

private enum FaceLayout {
    static let reference: CGFloat = 201.38893
    static let outerReference: CGFloat = 231.15084
    static let padding: CGFloat = 14.88096 / outerReference
    static let corner: CGFloat = 0.20
    static let lineWidth: CGFloat = 9.920637 / reference
    static let eyeWidth: CGFloat = 33.046156 / reference
    static let eyeHeight: CGFloat = 74.130567 / reference
    static let leftEye = CGPoint(x: 0.27219, y: 0.31931)
    static let rightEye = CGPoint(x: 0.72667, y: 0.31931)
}

struct RobotGradientWash: View {

    enum Direction {
        case up
        case down
        case left
        case right
    }

    var direction: Direction = .down
    var softness: CGFloat = 0.65
    var opacity: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height)
            RobotMeshGradient(side: side)
                .frame(width: side, height: side)
                .frame(width: geo.size.width, height: geo.size.height, alignment: meshAlignment)
                .clipped()
        }
        .mask(fade)
        .opacity(min(max(opacity, 0), 1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var meshAlignment: Alignment {
        switch direction {
        case .down: .top
        case .up: .bottom
        case .left: .trailing
        case .right: .leading
        }
    }

    private var fade: LinearGradient {
        let softness = min(max(softness, 0), 1)
        let hold = 1 - softness
        return LinearGradient(
            stops: fadeStops(hold: hold, softness: softness),
            startPoint: opaquePoint,
            endPoint: clearPoint
        )
    }

    private var opaquePoint: UnitPoint {
        switch direction {
        case .down: .top
        case .up: .bottom
        case .left: UnitPoint(x: 1, y: 0.5)
        case .right: UnitPoint(x: 0, y: 0.5)
        }
    }

    private var clearPoint: UnitPoint {
        switch direction {
        case .down: .bottom
        case .up: .top
        case .left: UnitPoint(x: 0, y: 0.5)
        case .right: UnitPoint(x: 1, y: 0.5)
        }
    }

    private func fadeStops(hold: CGFloat, softness: CGFloat) -> [Gradient.Stop] {
        var stops = [Gradient.Stop(color: .black, location: 0)]
        guard softness > 0 else {
            stops.append(.init(color: .black, location: 1))
            return stops
        }
        if hold > 0 {
            stops.append(.init(color: .black, location: hold))
        }
        let steps = 4
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let eased = t * t * (3 - 2 * t)
            stops.append(.init(
                color: .black.opacity(1 - eased),
                location: hold + softness * t
            ))
        }
        return stops
    }
}

private struct RobotMeshGradient: View {
    var side: CGFloat

    private let cream = Color(red: 1.0, green: 0.90, blue: 0.74)
    private let yellow = Color(red: 0.98, green: 0.82, blue: 0.32)
    private let green = Color(red: 0.78, green: 0.86, blue: 0.52)
    private let orange = Color(red: 1.0, green: 0.52, blue: 0.24)
    private let blue = Color(red: 0.55, green: 0.84, blue: 0.94)

    var body: some View {
        ZStack {
            cream
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: yellow, location: 0.0),
                    .init(color: green.opacity(0.95), location: 0.42),
                    .init(color: cream.opacity(0), location: 0.92)
                ]),
                center: UnitPoint(x: 0.62, y: -0.18),
                startRadius: side * 0.02,
                endRadius: side * 0.62
            )
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: yellow, location: 0.0),
                    .init(color: yellow.opacity(0.55), location: 0.45),
                    .init(color: .clear, location: 1.0)
                ]),
                center: UnitPoint(x: 0.86, y: 0.02),
                startRadius: 0,
                endRadius: side * 0.34
            )
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: orange, location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.64, blue: 0.38).opacity(0.9), location: 0.38),
                    .init(color: .clear, location: 0.92)
                ]),
                center: UnitPoint(x: 1.05, y: 0.50),
                startRadius: 0,
                endRadius: side * 0.58
            )
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: blue, location: 0.0),
                    .init(color: Color(red: 0.68, green: 0.86, blue: 0.90).opacity(0.8), location: 0.42),
                    .init(color: .clear, location: 1.0)
                ]),
                center: UnitPoint(x: 0.0, y: 1.04),
                startRadius: 0,
                endRadius: side * 0.52
            )
        }
    }
}

/// 7.4s cycle at 60 fps: look left, right, up, blink, then a small nod.
private enum Glance {
    static let duration: TimeInterval = 444.0 / 60.0

    static let eyeX: [(Double, CGFloat)] = [
        (0, 0), (19, 0), (45, -11), (70, -11), (103, 11), (130, 11),
        (161, 0), (185, 0), (212, 4), (254, 4), (274, 0), (444, 0)
    ]
    static let eyeY: [(Double, CGFloat)] = [
        (0, 0), (130, 0), (160, -10), (185, -10), (212, -1), (254, -1),
        (274, 0), (301, 0), (309, -1.49), (321, 3), (339, 0), (444, 0)
    ]
    static let headX: [(Double, CGFloat)] = [
        (0, 0), (19, 0), (45, -2), (70, -2), (103, 2), (130, 2),
        (161, 0), (185, 0), (212, 1), (254, 1), (274, 0), (444, 0)
    ]
    static let headY: [(Double, CGFloat)] = [
        (0, 0), (130, 0), (160, -2), (185, -2), (212, 0),
        (301, 0), (309, -1.49), (321, 6), (339, -0.79), (351, 0), (444, 0)
    ]
    static let scaleX: [(Double, CGFloat)] = [
        (0, 1), (301, 1), (321, 1.008), (351, 1), (444, 1)
    ]
    static let scaleY: [(Double, CGFloat)] = [
        (0, 1), (301, 1), (321, 0.965), (351, 1), (444, 1)
    ]
    static let eyeScaleX: [(Double, CGFloat)] = [
        (0, 1), (254, 1), (272, 1.06), (287, 1), (444, 1)
    ]
    static let eyeScaleY: [(Double, CGFloat)] = [
        (0, 1), (207, 1), (225, 0.68), (254, 0.68), (272, 1.12), (287, 1), (444, 1)
    ]

    static func pose(at date: Date, paused: Bool) -> FacePose {
        let frame = paused ? 0 : date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: duration) / duration * 444
        let shiftX = sample(eyeX, frame) / FaceLayout.reference
        let shiftY = sample(eyeY, frame) / FaceLayout.reference
        let markSize = CGSize(
            width: FaceLayout.eyeWidth * sample(eyeScaleX, frame),
            height: FaceLayout.eyeHeight * sample(eyeScaleY, frame)
        )
        return FacePose(
            headX: sample(headX, frame) / FaceLayout.reference,
            headY: sample(headY, frame) / FaceLayout.reference,
            scaleX: sample(scaleX, frame),
            scaleY: sample(scaleY, frame),
            left: FaceMark(
                center: CGPoint(x: FaceLayout.leftEye.x + shiftX, y: FaceLayout.leftEye.y + shiftY),
                size: markSize
            ),
            right: FaceMark(
                center: CGPoint(x: FaceLayout.rightEye.x + shiftX, y: FaceLayout.rightEye.y + shiftY),
                size: markSize
            )
        )
    }
}

private enum WidgetTransform {
    static let duration: TimeInterval = 384.0 / 60.0
    private static let box: CGFloat = 30

    static let lookX: [(Double, CGFloat)] = [
        (0, 0), (15, 0), (25.8, -2), (43.2, -2), (56.4, 2), (73.8, 2),
        (85.8, -1.6), (99, -1.6), (112.8, 0), (384, 0)
    ]
    static let morph: [(Double, CGFloat)] = [
        (0, 0), (133, 0), (153, 1), (293, 1), (313, 0), (384, 0)
    ]
    static let jumpY: [(Double, CGFloat)] = [
        (0, 0), (123, 0), (130.2, 1), (145.8, -9), (151.8, -9),
        (169.2, 0), (174, 0.6), (182.4, 0),
        (283.2, 0), (290.4, 1), (306, -9), (312, -9),
        (329.4, 0), (334.2, 0.6), (342.6, 0), (384, 0)
    ]
    static let scaleX: [(Double, CGFloat)] = [
        (0, 1), (123, 1), (130.2, 1.035), (141, 0.98), (151.8, 1),
        (169.2, 1.055), (182.4, 1),
        (283.2, 1), (290.4, 1.035), (301.2, 0.98), (312, 1),
        (329.4, 1.055), (342.6, 1), (384, 1)
    ]
    static let scaleY: [(Double, CGFloat)] = [
        (0, 1), (123, 1), (130.2, 0.94), (141, 1.035), (151.8, 1),
        (169.2, 0.92), (182.4, 1),
        (283.2, 1), (290.4, 0.94), (301.2, 1.035), (312, 1),
        (329.4, 0.92), (342.6, 1), (384, 1)
    ]

    private static let inset: CGFloat = 3.5
    private static let valueSize = CGSize(width: 12, height: 9)
    private static let captionSize = CGSize(width: valueSize.width, height: 3.2)
    private static let valueCenter = CGPoint(
        x: inset + valueSize.width / 2,
        y: inset + valueSize.height / 2
    )
    private static let captionCenter = CGPoint(
        x: inset + captionSize.width / 2,
        y: box - inset - captionSize.height / 2
    )

    static func pose(at date: Date, paused: Bool) -> FacePose {
        let frame = paused ? 0 : date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: duration) / duration * 384
        let look = sample(lookX, frame) / box
        let turned = sample(morph, frame)
        return FacePose(
            headY: sample(jumpY, frame) / box,
            scaleX: sample(scaleX, frame),
            scaleY: sample(scaleY, frame),
            left: shape(
                from: (CGPoint(x: 9.5, y: 10.5), CGSize(width: 3, height: 7), 0.5),
                to: (valueCenter, valueSize, 0.22),
                amount: turned,
                look: look
            ),
            right: shape(
                from: (CGPoint(x: 20.5, y: 10.5), CGSize(width: 3, height: 7), 0.5),
                to: (captionCenter, captionSize, 0.5),
                amount: turned,
                look: look
            )
        )
    }

    private static func shape(
        from: (CGPoint, CGSize, CGFloat),
        to: (CGPoint, CGSize, CGFloat),
        amount: CGFloat,
        look: CGFloat
    ) -> FaceMark {
        FaceMark(
            center: CGPoint(
                x: lerp(from.0.x, to.0.x, amount) / box + look,
                y: lerp(from.0.y, to.0.y, amount) / box
            ),
            size: CGSize(
                width: lerp(from.1.width, to.1.width, amount) / box,
                height: lerp(from.1.height, to.1.height, amount) / box
            ),
            corner: lerp(from.2, to.2, amount)
        )
    }
}

#Preview("Sizes") {
    HStack(alignment: .center, spacing: 24) {
        RobotFaceView(size: 44, kind: .glance)
        RobotFaceView(size: 88, kind: .glance)
        RobotFaceView(size: 160, kind: .widget, ink: .white)
    }
    .padding(32)
    .background(Color.black)
}
