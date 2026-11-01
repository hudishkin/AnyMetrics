import SwiftUI

/// Пустой дашборд: призрачные карточки метрик, подпись и стрелка к кнопке добавления.
struct DashboardEmptyStateView: View {

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            placeholderGrid(height: proxy.size.height)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    hint
                        .padding(.bottom, arrowClearance)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AnyMetricsStrings.Metric.placeholder)
    }

    private func placeholderGrid(height: CGFloat) -> some View {
        let columns = max(MainView.Constants.collumns.count, 1)
        let rowHeight = MainView.Constants.size + MainView.Constants.spacing
        let rows = max(2, Int(ceil(max(height - MainView.Constants.topPadding, 0) / max(rowHeight, 1))))

        return LazyVGrid(columns: MainView.Constants.collumns, spacing: MainView.Constants.spacing) {
            ForEach(0..<(columns * rows), id: \.self) { _ in
                RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                    .fill(cardFill)
                    .frame(width: MainView.Constants.size, height: MainView.Constants.size)
            }
        }
        .padding(.top, MainView.Constants.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask(verticalFade)
        .mask(horizontalFade)
        .accessibilityHidden(true)
    }

    private var hint: some View {
        VStack(spacing: Constants.hintSpacing) {
            Text(AnyMetricsStrings.Metric.placeholder)
                .font(Constants.font)
                .foregroundStyle(captionColor)
                .multilineTextAlignment(.center)
                .lineSpacing(Constants.lineSpacing)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, Constants.horizontalPadding)

            HintArrow(color: captionColor)
                .frame(width: Constants.arrowWidth, height: Constants.arrowHeight)
        }
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.038)
    }

    private var captionColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.58)
    }

    private var cardCorner: CGFloat {
        if #available(iOS 26.0, *) { return 36 }
        return 24
    }

    /// Стрелка заканчивается над круглой кнопкой «+».
    private var arrowClearance: CGFloat {
        MainView.Constants.addButtonSize + Constants.buttonOuterPadding + Constants.arrowGap
    }

    private var verticalFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.45), location: 0.16),
                .init(color: .black.opacity(0.7), location: 0.34),
                .init(color: .black.opacity(0.4), location: 0.58),
                .init(color: .black.opacity(0.12), location: 0.8),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var horizontalFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.55), location: 0.16),
                .init(color: .black, location: 0.38),
                .init(color: .black, location: 0.62),
                .init(color: .black.opacity(0.55), location: 0.84),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct HintArrow: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let tipY = size.height - 1
            let head = min(8, size.width / 2)
            var path = Path()
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: tipY))
            path.move(to: CGPoint(x: midX - head, y: tipY - head - 1))
            path.addLine(to: CGPoint(x: midX, y: tipY))
            path.addLine(to: CGPoint(x: midX + head, y: tipY - head - 1))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

private enum Constants {
    static let font = Font.system(size: 18, weight: .semibold, design: .default)
    static let lineSpacing: CGFloat = 3
    static let hintSpacing: CGFloat = 22
    static let horizontalPadding: CGFloat = 28
    static let arrowWidth: CGFloat = 24
    static let arrowHeight: CGFloat = 88
    static let buttonOuterPadding: CGFloat = 16
    static let arrowGap: CGFloat = 12
}

#Preview("Light") {
    DashboardEmptyStateView()
}

#Preview("Dark") {
    DashboardEmptyStateView()
        .preferredColorScheme(.dark)
}
