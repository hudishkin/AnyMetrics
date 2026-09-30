import SwiftUI
import AnyMetricsShared

struct MetricShareOptionsView: View {

    private enum Constants {
        static let contentSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 24
        static let buttonCorner: CGFloat = 30
        static let cardCorner: CGFloat = 18
        static let previewWidth: CGFloat = 220
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 28
        static let bottomPadding: CGFloat = 24
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
        static let fontClose = Font.system(size: 15, weight: .medium, design: .default)
        static let fontSecondary = Font.system(size: 16, weight: .medium, design: .default)
        static let fontWarning = Font.system(size: 14, weight: .regular, design: .default)
        static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let warningColor = AnyMetricsAsset.Assets.red.swiftUIColor
    }

    let metric: Metric
    var onShared: (MetricSharePayload) -> Void
    var onCancel: (() -> Void)?

    @State
    private var qrImage: UIImage?
    @State
    private var sheetHeight: CGFloat = 560
    @State
    private var isSharing = false
    @State
    private var didCopyLink = false
    @State
    private var errorMessage: String?
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                header
                preview
                requestWarning
                actions
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.topPadding)
            .padding(.bottom, Constants.bottomPadding)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ShareSheetHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
        }
        .frame(maxHeight: sheetHeight)
        .onPreferenceChange(ShareSheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            sheetHeight = height
        }
        .modifier(ShareFittedSheetModifier(height: sheetHeight))
        .task {
            if qrImage == nil {
                qrImage = MetricShareComposer.qrImage(
                    url: MetricShareComposer.appStoreURL,
                    size: MetricShareComposer.qrSide * 2
                )
            }
        }
        .alert(AnyMetricsStrings.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(AnyMetricsStrings.Common.ok, role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                Text(AnyMetricsStrings.Metric.Share.title)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)

                Text(metric.title)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .lineLimit(2)

                Text(AnyMetricsStrings.Metric.Share.subtitle)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                onCancel?()
                dismiss()
            } label: {
                Text(AnyMetricsStrings.Common.close)
                    .font(Constants.fontClose)
                    .foregroundColor(Constants.secondaryColor)
            }
            .disabled(isSharing)
        }
    }

    private var preview: some View {
        MetricShareCardView(metric: metric, qrImage: qrImage)
            .frame(width: MetricShareComposer.cardSize.width, height: MetricShareComposer.cardSize.height)
            .scaleEffect(Constants.previewWidth / MetricShareComposer.cardSize.width)
            .frame(
                width: Constants.previewWidth,
                height: Constants.previewWidth * MetricShareComposer.cardSize.height / MetricShareComposer.cardSize.width
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var requestWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Constants.warningColor)
                .padding(.top, 1)

            Text(AnyMetricsStrings.Metric.Export.requestWarning)
                .font(Constants.fontWarning)
                .foregroundColor(Constants.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.cardBackground)
        .cornerRadius(Constants.cardCorner)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                ImpactHelper.impactButton()
                share()
            } label: {
                Group {
                    if isSharing {
                        ProgressView()
                    } else {
                        Text(AnyMetricsStrings.Metric.Share.button)
                            .font(Constants.fontButton)
                            .foregroundColor(Constants.textColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Constants.buttonBackground)
            .cornerRadius(Constants.buttonCorner)
            .disabled(isSharing)
            .accessibilityIdentifier("metricShare.share")

            Button {
                UIPasteboard.general.string = MetricShareComposer.appStoreURL.absoluteString
                ImpactHelper.success()
                AnalyticsEvents.metricShared(mode: "link")
                didCopyLink = true
            } label: {
                Text(didCopyLink ? AnyMetricsStrings.Metric.Share.copied : AnyMetricsStrings.Metric.Share.copyLink)
                    .font(Constants.fontSecondary)
                    .foregroundColor(Constants.secondaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .disabled(isSharing)
            .accessibilityIdentifier("metricShare.copyLink")
        }
    }

    private func share() {
        guard !isSharing else { return }
        isSharing = true
        let metricToShare = metric

        Task { @MainActor in
            do {
                let payload = try MetricShareComposer.writePayload(metric: metricToShare)
                isSharing = false
                AnalyticsEvents.metricShared(mode: "image_and_metric")
                onShared(payload)
            } catch {
                isSharing = false
                errorMessage = Self.message(for: error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let storeError = error as? WidgetBackgroundStoreError {
            switch storeError {
            case .imageUnavailableForExport:
                return AnyMetricsStrings.Metric.Export.imageUnavailable
            case .containerUnavailable, .encodingFailed, .invalidBase64, .invalidURL, .downloadFailed:
                break
            }
        }
        return AnyMetricsStrings.Metric.Share.failed
    }
}

private struct ShareSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShareFittedSheetModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            let capped = min(height, UIScreen.main.bounds.height * 0.92)
            content
                .presentationDetents([.height(capped)])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    MetricShareOptionsView(metric: Mocks.metricJson, onShared: { _ in })
        .preferredColorScheme(.dark)
}
#endif
