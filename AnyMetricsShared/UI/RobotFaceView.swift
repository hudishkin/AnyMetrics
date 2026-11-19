import SwiftUI

public struct RobotFaceView: View {

    public enum Kind: Equatable {
        case glance
        case widget
        /// Squints and scans, as if working through something.
        case working
        /// Looks down at the bubble, back at the user, then nods.
        case awaiting
        /// Couldn't find it: drops into a sad face and stays there.
        case notFound
    }

    var size: CGFloat
    var kind: Kind
    var ink: Color
    /// When false, only the outline and eyes are drawn, so the face sits on the caller's background.
    var filled: Bool
    var animated: Bool
    /// When false, the clip plays once and holds the last frame.
    /// Clips with an intro play it once either way; looping repeats only the part after it.
    var loop: Bool

    public init(
        size: CGFloat,
        kind: Kind = .glance,
        ink: Color = .white,
        filled: Bool = true,
        animated: Bool = true,
        loop: Bool = true
    ) {
        self.size = size
        self.kind = kind
        self.ink = ink
        self.filled = filled
        self.animated = animated
        self.loop = loop
        _take = State(initialValue: Take(kind: kind, loops: loop, started: Date()))
    }

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private struct Take {
        var kind: Kind
        var loops: Bool
        var started: Date
    }

    @State private var take: Take
    /// The clip that was playing before the last switch; it keeps moving while the new one fades in.
    @State private var fading: Take?
    @State private var switchedAt = Date.distantPast

    private static let crossfade: TimeInterval = 0.45
    private static let breath: TimeInterval = 4.2

    public var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    face(pose(at: timeline.date, paused: reduceMotion))
                }
            } else {
                face(restPose)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            take = Take(kind: kind, loops: loop, started: Date())
            fading = nil
        }
        .onChange(of: kind) { _ in restart() }
        .onChange(of: loop) { _ in restart() }
    }

    private func restart() {
        guard take.kind != kind || take.loops != loop else { return }
        let now = Date()
        fading = take
        switchedAt = now
        take = Take(kind: kind, loops: loop, started: now)
    }

    private var restPose: FacePose {
        Self.pose(of: take, at: .distantPast, paused: true)
    }

    private func pose(at date: Date, paused: Bool) -> FacePose {
        var pose = Self.pose(of: take, at: date, paused: paused)
        guard !paused else { return pose }
        if let fading {
            let progress = min(max(date.timeIntervalSince(switchedAt) / Self.crossfade, 0), 1)
            if progress < 1 {
                let eased = 1 - pow(1 - progress, 3)
                pose = mix(Self.pose(of: fading, at: date, paused: false), pose, CGFloat(eased))
            }
        }
        if take.kind != .widget {
            let breath = CGFloat(sin(date.timeIntervalSinceReferenceDate * 2 * .pi / Self.breath))
            pose.scaleY *= 1 + 0.006 * breath
            pose.scaleX *= 1 - 0.003 * breath
        }
        return pose
    }

    private static func pose(of take: Take, at date: Date, paused: Bool) -> FacePose {
        switch take.kind {
        case .glance:
            Glance.pose(at: date, started: take.started, paused: paused, loops: take.loops)
        case .widget:
            WidgetTransform.pose(at: date, started: take.started, paused: paused, loops: take.loops)
        case .working:
            Working.pose(at: date, started: take.started, paused: paused, loops: take.loops)
        case .awaiting:
            Awaiting.pose(at: date, started: take.started, paused: paused, loops: take.loops)
        case .notFound:
            NotFound.pose(at: date, started: take.started, paused: paused, loops: take.loops)
        }
    }

    private func face(_ pose: FacePose) -> some View {
        let inset = FaceLayout.padding * size
        let borderSide = size - inset * 2
        let container = squircle(FaceLayout.corner * size)
        let border = squircle(FaceLayout.corner * borderSide)
        return ZStack {
            if filled {
                RobotMeshGradient(side: size)
                    .clipShape(container)
            }
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
        .rotationEffect(.degrees(Double(pose.tilt)))
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
    /// Degrees.
    var tilt: CGFloat = 0
    var left: FaceMark
    var right: FaceMark
}

private func mix(_ from: FacePose, _ to: FacePose, _ amount: CGFloat) -> FacePose {
    FacePose(
        headX: lerp(from.headX, to.headX, amount),
        headY: lerp(from.headY, to.headY, amount),
        scaleX: lerp(from.scaleX, to.scaleX, amount),
        scaleY: lerp(from.scaleY, to.scaleY, amount),
        tilt: lerp(from.tilt, to.tilt, amount),
        left: mix(from.left, to.left, amount),
        right: mix(from.right, to.right, amount)
    )
}

private func mix(_ from: FaceMark, _ to: FaceMark, _ amount: CGFloat) -> FaceMark {
    FaceMark(
        center: CGPoint(x: lerp(from.center.x, to.center.x, amount), y: lerp(from.center.y, to.center.y, amount)),
        size: CGSize(width: lerp(from.size.width, to.size.width, amount), height: lerp(from.size.height, to.size.height, amount)),
        corner: lerp(from.corner, to.corner, amount)
    )
}

private func sample(
    _ keys: [(Double, CGFloat)],
    _ frame: Double,
    ease: (Double) -> Double = { $0 * $0 * (3 - 2 * $0) }
) -> CGFloat {
    guard let first = keys.first else { return 0 }
    if frame <= first.0 { return first.1 }
    for index in keys.indices.dropFirst() {
        let previous = keys[index - 1]
        let next = keys[index]
        if frame <= next.0 {
            let span = next.0 - previous.0
            let t = span > 0 ? (frame - previous.0) / span : 1
            return previous.1 + (next.1 - previous.1) * ease(t)
        }
    }
    return keys[keys.count - 1].1
}

/// Heavy start, a little past the pose, then a settle. Holds are unchanged: equal keys have no delta.
private func inertia(_ t: Double) -> Double {
    let clamped = min(max(t, 0), 1)
    var guess = clamped
    for _ in 0..<6 {
        let x = bezier(guess, 0.22, 0.18)
        let slope = bezierSlope(guess, 0.22, 0.18)
        let error = x - clamped
        if abs(error) < 0.0001 || abs(slope) < 0.000001 { break }
        guess = min(max(guess - error / slope, 0), 1)
    }
    return bezier(guess, 0, 1.08)
}

private func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let c = 1 - t
    return 3 * c * c * t * a + 3 * c * t * t * b + t * t * t
}

private func bezierSlope(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let c = 1 - t
    return 3 * c * c * a + 6 * c * t * (b - a) + 3 * t * t * (1 - b)
}

private func lerp(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
    from + (to - from) * amount
}

/// Glance and the widget keep the shared clock while they loop, so a row of faces stays in sync.
/// A story clip, or any clip with `loops` off, plays from `started` so it begins on the first frame.
/// Frames before `loopFrom` are an intro: they play once, then only `loopFrom...frames` repeats.
private func playhead(
    at date: Date,
    started: Date,
    paused: Bool,
    frames: Double,
    loopFrom: Double = 0,
    loops: Bool,
    anchored: Bool
) -> Double {
    guard !paused else { return 0 }
    let origin = (anchored || !loops) ? started : Date(timeIntervalSinceReferenceDate: 0)
    let played = max(0, date.timeIntervalSince(origin)) * 60
    guard played > frames else { return played }
    guard loops else { return frames }
    return loopFrom + (played - frames).truncatingRemainder(dividingBy: frames - loopFrom)
}

private func gaze(
    _ frame: Double,
    eyeX: [(Double, CGFloat)],
    eyeY: [(Double, CGFloat)],
    headX: [(Double, CGFloat)],
    headY: [(Double, CGFloat)],
    scaleX: [(Double, CGFloat)],
    scaleY: [(Double, CGFloat)],
    eyeScaleX: [(Double, CGFloat)],
    eyeScaleY: [(Double, CGFloat)],
    tilt: [(Double, CGFloat)] = [(0, 0)],
    /// Positive opens the left eye wider than the right.
    eyeBias: [(Double, CGFloat)] = [(0, 0)],
    headDelay: Double = 0,
    travel: (Double) -> Double = { $0 * $0 * (3 - 2 * $0) }
) -> FacePose {
    let shiftX = sample(eyeX, frame, ease: travel) / FaceLayout.reference
    let shiftY = sample(eyeY, frame, ease: travel) / FaceLayout.reference
    let headFrame = max(0, frame - headDelay)
    let width = FaceLayout.eyeWidth * sample(eyeScaleX, frame)
    let height = FaceLayout.eyeHeight * sample(eyeScaleY, frame)
    let bias = sample(eyeBias, frame)
    return FacePose(
        headX: sample(headX, headFrame, ease: travel) / FaceLayout.reference,
        headY: sample(headY, headFrame, ease: travel) / FaceLayout.reference,
        scaleX: sample(scaleX, frame),
        scaleY: sample(scaleY, frame),
        tilt: sample(tilt, headFrame, ease: travel),
        left: FaceMark(
            center: CGPoint(x: FaceLayout.leftEye.x + shiftX, y: FaceLayout.leftEye.y + shiftY),
            size: CGSize(width: width, height: height * (1 + bias))
        ),
        right: FaceMark(
            center: CGPoint(x: FaceLayout.rightEye.x + shiftX, y: FaceLayout.rightEye.y + shiftY),
            size: CGSize(width: width, height: height * (1 - bias))
        )
    )
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

public struct RobotGradientWash: View {

    public enum Direction {
        case up
        case down
        case left
        case right
    }

    var direction: Direction
    var softness: CGFloat
    var opacity: CGFloat

    public init(direction: Direction = .down, softness: CGFloat = 0.65, opacity: CGFloat = 1) {
        self.direction = direction
        self.softness = softness
        self.opacity = opacity
    }

    public var body: some View {
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

    static func pose(at date: Date, started: Date, paused: Bool, loops: Bool) -> FacePose {
        gaze(
            playhead(at: date, started: started, paused: paused, frames: 444, loops: loops, anchored: false),
            eyeX: eyeX,
            eyeY: eyeY,
            headX: headX,
            headY: headY,
            scaleX: scaleX,
            scaleY: scaleY,
            eyeScaleX: eyeScaleX,
            eyeScaleY: eyeScaleY
        )
    }
}

private enum WidgetTransform {
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

    static func pose(at date: Date, started: Date, paused: Bool, loops: Bool) -> FacePose {
        let frame = playhead(at: date, started: started, paused: paused, frames: 384, loops: loops, anchored: false)
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

/// Squints in once (0.5s), then loops a 6.2s scan: uneven looks along a "line", a blink that hides a big
/// gaze shift, and a beat of concentration where one eye narrows and the head tilts.
private enum Working {
    static let frames: Double = 400
    static let loopFrom: Double = 30

    static let eyeX: [(Double, CGFloat)] = [
        (0, 0), (30, 0),
        (58, -14), (84, -15),
        (112, 15), (128, 16),
        (150, 9), (176, 8),
        (206, -6), (230, -7),
        (262, 12), (300, 13), (318, 12),
        (352, 0), (400, 0)
    ]
    static let eyeY: [(Double, CGFloat)] = [
        (0, 0), (30, 1),
        (58, -7), (84, -8),
        (112, 4), (128, 5),
        (150, 12), (176, 12),
        (206, 13), (230, 13),
        (262, -11), (300, -12), (318, -11),
        (352, 1), (400, 1)
    ]
    static let headX: [(Double, CGFloat)] = [
        (0, 0), (30, 0),
        (58, -3.5), (84, -3.8),
        (112, 3.8), (128, 4),
        (150, 2.4), (176, 2.2),
        (206, -1.6), (230, -1.8),
        (262, 3), (318, 3.2),
        (352, 0), (400, 0)
    ]
    static let headY: [(Double, CGFloat)] = [
        (0, 0), (20, 1.4), (30, 1.4),
        (58, -0.6), (84, -0.8),
        (112, 2.4), (128, 2.6),
        (150, 4.2), (176, 4.2),
        (206, 4.4), (230, 4.4),
        (262, -1.2), (318, -1.4),
        (352, 1.4), (400, 1.4)
    ]
    static let tilt: [(Double, CGFloat)] = [
        (0, 0), (262, 0), (284, 3), (318, 3), (352, 0), (400, 0)
    ]
    static let scaleX: [(Double, CGFloat)] = [
        (0, 1), (30, 1.012), (400, 1.012)
    ]
    static let scaleY: [(Double, CGFloat)] = [
        (0, 1), (30, 0.984), (400, 0.984)
    ]
    static let eyeScaleX: [(Double, CGFloat)] = [
        (0, 1), (8, 1), (30, 1.1), (400, 1.1)
    ]
    static let eyeScaleY: [(Double, CGFloat)] = [
        (0, 1), (8, 1), (30, 0.42),
        (226, 0.42), (232, 0.08), (235, 0.08), (246, 0.42),
        (276, 0.34), (318, 0.34), (340, 0.42),
        (400, 0.42)
    ]
    static let eyeBias: [(Double, CGFloat)] = [
        (0, 0), (262, 0), (284, 0.14), (318, 0.14), (340, 0), (400, 0)
    ]

    static func pose(at date: Date, started: Date, paused: Bool, loops: Bool) -> FacePose {
        gaze(
            playhead(
                at: date, started: started, paused: paused,
                frames: frames, loopFrom: loopFrom, loops: loops, anchored: true
            ),
            eyeX: eyeX,
            eyeY: eyeY,
            headX: headX,
            headY: headY,
            scaleX: scaleX,
            scaleY: scaleY,
            eyeScaleX: eyeScaleX,
            eyeScaleY: eyeScaleY,
            tilt: tilt,
            eyeBias: eyeBias,
            headDelay: 8,
            travel: inertia
        )
    }
}

/// Intro (4.2s): reads the bubble line by line, looks up, nods, and cocks the head with one eye a bit wider.
/// Loop (5s): holds eye contact, blinks, glances back at the bubble, and gives a small encouraging nod.
private enum Awaiting {
    static let frames: Double = 550
    static let loopFrom: Double = 250

    static let eyeX: [(Double, CGFloat)] = [
        (0, 0), (44, 0),
        (60, -5), (72, -5),
        (92, 5), (112, 5),
        (148, 0), (250, 0),
        (290, 1), (340, 1),
        (362, 2), (384, 2),
        (410, 0), (550, 0)
    ]
    static let eyeY: [(Double, CGFloat)] = [
        (0, 0), (14, 0),
        (44, 24), (92, 25), (118, 25),
        (148, -1),
        (162, -5), (182, 4), (200, -3), (214, -1), (226, -2),
        (340, -2),
        (362, 18), (384, 18),
        (410, -2), (430, -2),
        (444, 1), (460, -2),
        (550, -2)
    ]
    static let headX: [(Double, CGFloat)] = [
        (0, 0), (44, 0),
        (60, -1), (72, -1),
        (92, 1), (112, 1),
        (148, 0), (550, 0)
    ]
    static let headY: [(Double, CGFloat)] = [
        (0, 0), (14, 0),
        (44, 8), (118, 8),
        (148, -1),
        (162, -2.5), (182, 9), (200, -1), (214, 2), (226, 0),
        (340, 0),
        (362, 4), (384, 4),
        (410, 0), (430, 0),
        (444, 3.5), (460, 0),
        (550, 0)
    ]
    static let tilt: [(Double, CGFloat)] = [
        (0, 0), (214, 0), (240, -4),
        (340, -4), (362, -1), (384, -1), (420, -4),
        (550, -4)
    ]
    static let scaleX: [(Double, CGFloat)] = [
        (0, 1), (162, 1), (182, 1.015), (204, 1), (550, 1)
    ]
    static let scaleY: [(Double, CGFloat)] = [
        (0, 1), (14, 1),
        (44, 0.965), (118, 0.965), (148, 1),
        (162, 1.012), (182, 0.95), (204, 1),
        (550, 1)
    ]
    static let eyeScaleX: [(Double, CGFloat)] = [
        (0, 1), (148, 1), (162, 1.03), (550, 1.03)
    ]
    static let eyeScaleY: [(Double, CGFloat)] = [
        (0, 1), (14, 1),
        (44, 0.86), (118, 0.86),
        (148, 1.06),
        (300, 1.06), (306, 0.1), (308, 0.1), (320, 1.06),
        (340, 1.06), (362, 0.9), (384, 0.9), (410, 1.06),
        (496, 1.06), (502, 0.1), (504, 0.1), (516, 1.06),
        (550, 1.06)
    ]
    static let eyeBias: [(Double, CGFloat)] = [
        (0, 0), (214, 0), (240, 0.07), (550, 0.07)
    ]

    static func pose(at date: Date, started: Date, paused: Bool, loops: Bool) -> FacePose {
        gaze(
            playhead(
                at: date, started: started, paused: paused,
                frames: frames, loopFrom: loopFrom, loops: loops, anchored: true
            ),
            eyeX: eyeX,
            eyeY: eyeY,
            headX: headX,
            headY: headY,
            scaleX: scaleX,
            scaleY: scaleY,
            eyeScaleX: eyeScaleX,
            eyeScaleY: eyeScaleY,
            tilt: tilt,
            eyeBias: eyeBias,
            headDelay: 6,
            travel: inertia
        )
    }
}

/// Intro (2.8s): breathes in, sinks on the exhale with heavy lids, then looks away and down with a slight tilt.
/// Loop (4s): stays in that mood with a slow blink and a small sigh.
private enum NotFound {
    static let frames: Double = 410
    static let loopFrom: Double = 170

    static let eyeX: [(Double, CGFloat)] = [
        (0, 0), (124, 0),
        (160, -7), (170, -7),
        (230, -8), (380, -7), (410, -7)
    ]
    static let eyeY: [(Double, CGFloat)] = [
        (0, 0), (10, 0),
        (36, -4),
        (100, 18), (124, 16),
        (160, 17), (170, 17),
        (230, 18), (380, 17), (410, 17)
    ]
    static let headX: [(Double, CGFloat)] = [
        (0, 0), (124, 0), (160, -1.6), (410, -1.6)
    ]
    static let headY: [(Double, CGFloat)] = [
        (0, 0), (10, 0),
        (36, -1.5),
        (100, 10), (124, 8.5),
        (160, 9), (300, 9),
        (316, 8), (346, 10), (370, 9),
        (410, 9)
    ]
    static let tilt: [(Double, CGFloat)] = [
        (0, 0), (124, 0), (160, 3), (410, 3)
    ]
    static let scaleX: [(Double, CGFloat)] = [
        (0, 1), (10, 1), (36, 0.995), (100, 1.02), (124, 1.012), (410, 1.012)
    ]
    static let scaleY: [(Double, CGFloat)] = [
        (0, 1), (10, 1),
        (36, 1.015),
        (100, 0.95), (124, 0.965),
        (300, 0.965), (316, 0.975), (346, 0.955), (370, 0.965),
        (410, 0.965)
    ]
    static let eyeScaleX: [(Double, CGFloat)] = [
        (0, 1), (36, 0.98), (100, 1.06), (410, 1.06)
    ]
    static let eyeScaleY: [(Double, CGFloat)] = [
        (0, 1), (10, 1),
        (36, 1.06),
        (100, 0.6), (124, 0.64),
        (250, 0.64), (262, 0.08), (268, 0.08), (288, 0.64),
        (410, 0.64)
    ]
    static let eyeBias: [(Double, CGFloat)] = [
        (0, 0), (124, 0), (160, -0.06), (410, -0.06)
    ]

    static func pose(at date: Date, started: Date, paused: Bool, loops: Bool) -> FacePose {
        gaze(
            playhead(
                at: date, started: started, paused: paused,
                frames: frames, loopFrom: loopFrom, loops: loops, anchored: true
            ),
            eyeX: eyeX,
            eyeY: eyeY,
            headX: headX,
            headY: headY,
            scaleX: scaleX,
            scaleY: scaleY,
            eyeScaleX: eyeScaleX,
            eyeScaleY: eyeScaleY,
            tilt: tilt,
            eyeBias: eyeBias,
            headDelay: 7,
            travel: inertia
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

#Preview("Working and awaiting") {
    VStack(alignment: .center, spacing: 24) {
        RobotFaceView(size: 160, kind: .working)
        RobotFaceView(size: 160, kind: .awaiting)
        RobotFaceView(size: 160, kind: .notFound)
        RobotFaceView(size: 160, kind: .notFound, loop: false)
    }
    .padding(32)
    .background(Color.black)
}
