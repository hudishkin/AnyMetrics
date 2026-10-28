import SwiftUI
import AnyMetricsShared

struct MetricShareCardView: View {

    private enum Constants {
        static let widgetSide = MetricShareComposer.widgetSide
        static let qrSide = MetricShareComposer.qrSide
        static let qrPad: CGFloat = 5
        static let footerSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 24
        static let bottomPadding: CGFloat = 26
        static let qrCorner: CGFloat = 8
        static let pillCorner: CGFloat = 22
        static let brandFont = Font.system(size: 17, weight: .semibold, design: .default)
        static let hintFont = Font.system(size: 12, weight: .medium, design: .default)
        static let textColor = Color(red: 0.12, green: 0.14, blue: 0.16)
        static let secondaryText = Color(red: 0.12, green: 0.14, blue: 0.16).opacity(0.58)
    }

    let metric: Metric
    let qrImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            widgetPreview
                .frame(width: Constants.widgetSide, height: Constants.widgetSide)
                .shadow(color: Color.black.opacity(0.16), radius: 22, y: 12)

            Spacer(minLength: 0)

            footer
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.bottom, Constants.bottomPadding)
        }
        .frame(width: MetricShareComposer.cardSize.width, height: MetricShareComposer.cardSize.height)
        .background(WidgetShareBackdrop(metric: metric))
        .clipped()
    }

    private var widgetPreview: some View {
        MetricWidgetDesignView(
            metric: metric,
            palette: .widget(),
            useGlassEffect: false,
            matchWidgetMetrics: false
        )
    }

    private var footer: some View {
        HStack(spacing: Constants.footerSpacing) {
            qrView
                .frame(
                    width: Constants.qrSide + Constants.qrPad * 2,
                    height: Constants.qrSide + Constants.qrPad * 2
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(AnyMetricsStrings.Metric.Share.cardBrand)
                    .font(Constants.brandFont)
                    .foregroundColor(Constants.textColor)
                Text(AnyMetricsStrings.Metric.Share.cardHint)
                    .font(Constants.hintFont)
                    .foregroundColor(Constants.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Constants.pillCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.pillCorner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var qrView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.qrCorner, style: .continuous)
                .fill(Color.white)
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(Constants.qrPad)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    MetricShareCardView(
        metric: Mocks.metricJson,
        qrImage: MetricShareComposer.qrImage(url: MetricShareComposer.appStoreURL, size: 104)
    )
    .preferredColorScheme(.light)
}
#endif
