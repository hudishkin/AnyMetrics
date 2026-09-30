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
        static let bottomPadding: CGFloat = 36
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
        static let fontRow = Font.system(size: 17, weight: .medium, design: .default)
        static let fontSecondary = Font.system(size: 16, weight: .medium, design: .default)
        static let closeSize: CGFloat = 30
    }

    let metric: Metric
    var onShared: (MetricSharePayload) -> Void
    var onCancel: (() -> Void)?

    @State
    private var qrImage: UIImage?
    @State
    private var sheetHeight: CGFloat = 560
    @State
    private var includeRequest = true
    @State
    private var isSharing = false
    @State
    private var didCopyLink = false
    @State
    private var showShareInfo = false
    @State
    private var errorMessage: String?
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                header
                preview
                requestToggle
                Divider()
                MetricRequestNotice(includesRequest: includeRequest, showsBackground: false)
                Divider()
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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(AnyMetricsStrings.Metric.Share.title)
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textColor)

                    Button {
                        showShareInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Constants.secondaryColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AnyMetricsStrings.Metric.Share.subtitle)
                    .disabled(isSharing)
                }

                Text(metric.title)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button {
                onCancel?()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Constants.closeSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Constants.secondaryColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AnyMetricsStrings.Common.close)
            .disabled(isSharing)
        }
        .popover(isPresented: $showShareInfo) {
            Text(AnyMetricsStrings.Metric.Share.subtitle)
                .font(Constants.fontSecondary)
                .foregroundColor(Constants.textColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(width: 280)
                .modifier(ShareInfoPopoverAdaptation())
        }
    }

    private var preview: some View {
        MetricShareCardView(metric: metric, qrImage: qrImage)
            .environment(\.colorScheme, .light)
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

    private var requestToggle: some View {
        Toggle(isOn: $includeRequest) {
            Text(AnyMetricsStrings.Metric.Export.includeRequest)
                .font(Constants.fontRow)
                .foregroundColor(Constants.textColor)
        }
        .disabled(isSharing)
        .accessibilityIdentifier("metricShare.includeRequest")
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
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
            .disabled(isSharing)
            .accessibilityIdentifier("metricShare.copyLink")
        }
    }

    private func share() {
        guard !isSharing else { return }
        isSharing = true
        let metricToShare = metric
        let options = MetricExportOptions(
            includeRequest: includeRequest,
            includeWidgetStyle: true
        )

        Task { @MainActor in
            do {
                let payload = try MetricShareComposer.writePayload(metric: metricToShare, options: options)
                isSharing = false
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

private struct ShareInfoPopoverAdaptation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}

private struct ShareFittedSheetModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        let capped = min(height, UIScreen.main.bounds.height * 0.92)
        content
            .presentationDetents([.height(capped)])
            .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview {
    MetricShareOptionsView(metric: Mocks.metricJson, onShared: { _ in })
        .preferredColorScheme(.dark)
}
#endif
