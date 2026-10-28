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
    var onShared: (MetricSharePayload, Bool) -> Void
    var onCancel: (() -> Void)?

    @State
    private var qrImage: UIImage?
    @State
    private var shareKind: MetricShareKind = .image
    @State
    private var includeRequest = true
    @State
    private var isSharing = false
    @State
    private var showShareInfo = false
    @State
    private var errorMessage: String?
    @State
    private var didCopyLink = false
    @State
    private var contentHeight: CGFloat = 0
    @State
    private var footerHeight: CGFloat = 0
    @Environment(\.dismiss)
    private var dismiss

    private var lockedHeight: CGFloat {
        contentHeight + footerHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                    header
                    preview
                    kindPicker
                    modeDetails
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, Constants.topPadding)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ShareContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollIndicators(.hidden)

            shareButton
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, Constants.bottomPadding)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ShareFooterHeightKey.self, value: proxy.size.height)
                    }
                )
                .background(Color(uiColor: .systemBackground))
        }
        .background(Color(uiColor: .systemBackground))
        .frame(height: lockedHeight > 0 ? min(lockedHeight, Self.sheetCap) : nil)
        .onPreferenceChange(ShareContentHeightKey.self) { height in
            guard height > 0 else { return }
            contentHeight = max(contentHeight, height)
        }
        .onPreferenceChange(ShareFooterHeightKey.self) { height in
            guard height > 0 else { return }
            footerHeight = height
        }
        .animation(nil, value: shareKind)
        .modifier(ShareFittedSheetModifier(height: lockedHeight > 0 ? lockedHeight : 560))
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
                    .accessibilityLabel(infoText)
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
            Text(infoText)
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
            .compositingGroup()
            .transaction { $0.animation = nil }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var modeDetails: some View {
        if shareKind == .file {
            VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                requestToggle
                Divider()
                MetricRequestNotice(includesRequest: includeRequest, showsBackground: false)
            }
        } else {
            Text(AnyMetricsStrings.Metric.Share.imageOnlySubtitle)
                .font(Constants.fontSecondary)
                .foregroundColor(Constants.secondaryColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var infoText: String {
        switch shareKind {
        case .file:
            return AnyMetricsStrings.Metric.Share.subtitle
        case .image:
            return AnyMetricsStrings.Metric.Share.imageOnlySubtitle
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            Text(AnyMetricsStrings.Metric.Share.kind)
                .font(Constants.fontRow)
                .foregroundColor(Constants.textColor)

            Picker(AnyMetricsStrings.Metric.Share.kind, selection: $shareKind) {
                Text(AnyMetricsStrings.Metric.Share.kindImage).tag(MetricShareKind.image)
                Text(AnyMetricsStrings.Metric.Share.kindFile).tag(MetricShareKind.file)
            }
            .pickerStyle(.segmented)
            .disabled(isSharing)
            .accessibilityIdentifier("metricShare.kind")
        }
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

    private var shareButton: some View {
        VStack(spacing: 0) {
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
                AnalyticsEvents.appLinkCopied()
                didCopyLink = true
            } label: {
                Text(didCopyLink ? AnyMetricsStrings.Metric.Share.copied : AnyMetricsStrings.Metric.Share.copyLink)
                    .font(Constants.fontSecondary)
                    .foregroundColor(Constants.secondaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .disabled(isSharing)
            .accessibilityIdentifier("metricShare.copyLink")
        }
    }

    private func share() {
        guard !isSharing else { return }
        isSharing = true
        let metricToShare = metric
        let kind = shareKind
        let options = MetricExportOptions(
            includeRequest: kind == .file && includeRequest,
            includeWidgetStyle: true
        )

        Task { @MainActor in
            do {
                let payload = try MetricShareComposer.writePayload(
                    metric: metricToShare,
                    options: options,
                    kind: kind
                )
                isSharing = false
                onShared(payload, includeRequest)
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

private struct ShareContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShareFooterHeightKey: PreferenceKey {
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
        let capped = min(height, MetricShareOptionsView.sheetCap)
        let fitted = content
            .presentationDetents([.height(capped)])
            .presentationDragIndicator(.visible)
        if #available(iOS 16.4, *) {
            fitted.presentationBackground(Color(uiColor: .systemBackground))
        } else {
            fitted
        }
    }
}

private extension MetricShareOptionsView {
    static var sheetCap: CGFloat { UIScreen.main.bounds.height * 0.92 }
}

#if DEBUG
#Preview {
    MetricShareOptionsView(metric: Mocks.metricJson, onShared: { _, _ in })
        .preferredColorScheme(.dark)
}
#endif
