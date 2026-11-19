import SwiftUI

extension View {
    /// Depth follows the row's distance above the front line, so new rows push old ones back and scrolling brings them forward.
    /// The scroll view needs `.coordinateSpace(name: ScrollDepth.space)`.
    func scrollDepth(viewportHeight: CGFloat, frontInset: CGFloat = 0) -> some View {
        modifier(ScrollDepth(viewportHeight: viewportHeight, frontInset: frontInset))
    }
}

struct ScrollDepth: ViewModifier {
    static let space = "scrollDepth"

    var viewportHeight: CGFloat
    var frontInset: CGFloat

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else if #available(iOS 17.0, *) {
            content.visualEffect { effect, proxy in
                let step = DepthStep(distance: distance(maxY: proxy.frame(in: .named(Self.space)).maxY))
                return effect
                    .scaleEffect(step.scale, anchor: .bottom)
                    .offset(y: step.drop)
                    .rotation3DEffect(.degrees(step.tilt), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
                    .blur(radius: step.blur)
                    .opacity(step.opacity)
            }
        } else {
            content.modifier(LegacyScrollDepth(depth: self))
        }
    }

    fileprivate func distance(maxY: CGFloat) -> CGFloat {
        viewportHeight - frontInset - maxY
    }
}

/// Perspective with a vanishing point `reach` above the front line. Spacing shrinks at the same rate as scale, so rows keep their overlap.
private struct DepthStep {
    static let reach: CGFloat = 170

    let scale: CGFloat
    let drop: CGFloat
    let blur: CGFloat
    let opacity: Double
    let tilt: Double

    init(distance: CGFloat) {
        let distance = max(distance, 0)
        let scale = exp(-distance / Self.reach)
        self.scale = scale
        drop = distance - Self.reach * (1 - scale)
        blur = min(distance / Self.reach * 5, 8)
        opacity = Double(0.2 + 0.8 * scale)
        tilt = Double(1 - scale) * 28
    }
}

/// iOS 16 has no `visualEffect`, so the position takes a trip through state.
private struct LegacyScrollDepth: ViewModifier {
    var depth: ScrollDepth

    @State
    private var distance: CGFloat = 0

    func body(content: Content) -> some View {
        let step = DepthStep(distance: distance)
        content
            .scaleEffect(step.scale, anchor: .bottom)
            .offset(y: step.drop)
            .rotation3DEffect(.degrees(step.tilt), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
            .blur(radius: step.blur)
            .opacity(step.opacity)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: DepthMaxY.self, value: geo.frame(in: .named(ScrollDepth.space)).maxY)
                }
            }
            .onPreferenceChange(DepthMaxY.self) { maxY in
                let next = depth.distance(maxY: maxY)
                guard abs(next - distance) > 0.5 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    distance = next
                }
            }
    }
}

private struct DepthMaxY: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
