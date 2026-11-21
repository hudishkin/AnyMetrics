import SwiftUI

/// The user's lines, pinned to the bottom. The newest sits in front, older ones recede up the lane.
struct GenerateMessageLane: View {
    struct Line: Identifiable {
        let index: Int
        let text: String
        var id: Int { index }
    }

    var lines: [Line]
    /// Scrolls the newest line into front when it changes.
    var scrollKey: [String]
    var speech: Animation

    var body: some View {
        GeometryReader { lane in
            let frontInset = CGFloat(28)
            ScrollViewReader { scroller in
                ScrollView(showsIndicators: false) {
                    BottomPinLayout(minHeight: lane.size.height, spacing: -22, bottomInset: frontInset) {
                        ForEach(lines) { line in
                            userBubble(line, maxWidth: GenerateMetricView.Constants.textWidth(in: lane.size.width))
                                .scrollDepth(viewportHeight: lane.size.height, frontInset: frontInset)
                                .zIndex(Double(line.index))
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(speech, value: lines.count)
                }
                .coordinateSpace(name: ScrollDepth.space)
                .onAppear {
                    scrollToFront(scroller)
                }
                .onChange(of: scrollKey) { _ in
                    withAnimation(speech) {
                        scrollToFront(scroller)
                    }
                }
            }
        }
    }

    private func scrollToFront(_ scroller: ScrollViewProxy) {
        guard let last = lines.last else { return }
        scroller.scrollTo(last.id, anchor: .bottom)
    }

    private func userBubble(_ line: Line, maxWidth: CGFloat) -> some View {
        SpeechBubble(
            side: .bottomCenter,
            role: .user,
            tilt: .zero,
            maxWidth: maxWidth
        ) {
            Text(line.text)
                .font(GenerateMetricView.Constants.bubbleFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .multilineTextAlignment(.leading)
        }
        .rotationEffect(.degrees(1), anchor: .bottom)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("generate.sent.\(line.index)")
    }
}

/// One bubble for every robot line. It squeezes toward the tail while the old text clears, then springs to the new size.
struct RobotLineBubble: View {
    var text: String
    var textHidden: Bool
    var squeezed: Bool
    var maxWidth: CGFloat

    var body: some View {
        SpeechBubble(
            side: .topCenter,
            role: .robot,
            tilt: .zero,
            maxWidth: maxWidth
        ) {
            Text(text)
                .font(GenerateMetricView.Constants.bubbleFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .blur(radius: textHidden ? 5 : 0)
                .opacity(textHidden ? 0 : 1)
        }
        .scaleEffect(squeezed ? 0.95 : 1, anchor: .top)
    }
}

/// Pins a short message stack to the bottom of the lane. A `Spacer` inside `ScrollView` collapses, which left the bubbles in the far zone.
private struct BottomPinLayout: Layout {
    var minHeight: CGFloat
    var spacing: CGFloat
    var bottomInset: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let content = contentHeight(width: width, subviews: subviews)
        return CGSize(width: width, height: max(minHeight, content + bottomInset))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.maxY - bottomInset
        for subview in subviews.reversed() {
            let size = subview.sizeThatFits(proposal)
            y -= size.height
            subview.place(at: CGPoint(x: bounds.midX, y: y), anchor: .top, proposal: proposal)
            y -= spacing
        }
    }

    private func contentHeight(width: CGFloat, subviews: Subviews) -> CGFloat {
        let proposal = ProposedViewSize(width: width, height: nil)
        let heights = subviews.map { $0.sizeThatFits(proposal).height }
        return heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
    }
}
