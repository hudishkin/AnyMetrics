import SwiftUI
import AnyMetricsShared

struct MetricExportOptionsView: View {

    private enum Constants {
        static let contentSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 28
        static let rowSpacing: CGFloat = 18
        static let buttonCorner: CGFloat = 30
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 28
        static let bottomPadding: CGFloat = 24
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor

        static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let fontRow = Font.system(size: 17, weight: .medium, design: .default)
        static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
        static let fontFooter = Font.system(size: 14, weight: .regular, design: .default)
        static let fontClose = Font.system(size: 15, weight: .medium, design: .default)
    }

    let metric: Metric
    var onExported: (URL) -> Void
    var onCancel: (() -> Void)?

    @State
    private var includeRequest = true
    @State
    private var includeWidgetStyle = true
    @State
    private var sheetHeight: CGFloat = 420
    @State
    private var isExporting = false
    @State
    private var errorMessage: String?
    @Environment(\.dismiss)
    private var dismiss

    private var canExport: Bool {
        !isExporting && (includeRequest || includeWidgetStyle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                    Text(AnyMetricsStrings.Metric.Export.title)
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textColor)

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
                    Text(AnyMetricsStrings.Common.close)
                        .font(Constants.fontClose)
                        .foregroundColor(Constants.secondaryColor)
                }
                .disabled(isExporting)
            }

            VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                Toggle(isOn: $includeRequest) {
                    Text(AnyMetricsStrings.Metric.Export.includeRequest)
                        .font(Constants.fontRow)
                        .foregroundColor(Constants.textColor)
                }
                .disabled(isExporting)

                Toggle(isOn: $includeWidgetStyle) {
                    Text(AnyMetricsStrings.Metric.Export.includeWidgetStyle)
                        .font(Constants.fontRow)
                        .foregroundColor(Constants.textColor)
                }
                .disabled(isExporting)

                Text(AnyMetricsStrings.Metric.Export.footer)
                    .font(Constants.fontFooter)
                    .foregroundColor(Constants.secondaryColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetricRequestNotice(includesRequest: includeRequest)

            Button {
                ImpactHelper.impactButton()
                export()
            } label: {
                Group {
                    if isExporting {
                        ProgressView()
                    } else {
                        Text(AnyMetricsStrings.Metric.Actions.export)
                            .font(Constants.fontButton)
                            .foregroundColor(Constants.textColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Constants.buttonBackground)
            .cornerRadius(Constants.buttonCorner)
            .disabled(!canExport)
            .opacity(canExport ? 1.0 : 0.4)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .padding(.bottom, Constants.bottomPadding)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ExportSheetHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ExportSheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            sheetHeight = height
        }
        .modifier(ExportFittedSheetModifier(height: sheetHeight))
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

    private func export() {
        guard !isExporting else { return }
        let options = MetricExportOptions(
            includeRequest: includeRequest,
            includeWidgetStyle: includeWidgetStyle
        )
        guard options.canExport else { return }

        isExporting = true
        let metricToExport = metric

        Task {
            do {
                let fileURL = try await Task.detached(priority: .userInitiated) {
                    try MetricItemImportData.writeFile(for: metricToExport, options: options)
                }.value
                await MainActor.run {
                    isExporting = false
                    onExported(fileURL)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = Self.message(for: error)
                }
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
        return AnyMetricsStrings.Metric.Export.failed
    }
}

struct MetricRequestNotice: View {
    let includesRequest: Bool
    var showsBackground = true

    private var textColor: Color { AnyMetricsAsset.Assets.baseText.swiftUIColor }
    private var secondaryColor: Color { AnyMetricsAsset.Assets.secondaryText.swiftUIColor }
    private var warningColor: Color { AnyMetricsAsset.Assets.red.swiftUIColor }
    private var cardBackground: Color { AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor }

    var body: some View {
        ZStack(alignment: .topLeading) {
            row(
                icon: "exclamationmark.triangle.fill",
                tint: warningColor,
                text: AnyMetricsStrings.Metric.Export.requestWarning,
                isVisible: includesRequest
            )
            row(
                icon: "checkmark.circle.fill",
                tint: secondaryColor,
                text: AnyMetricsStrings.Metric.Export.requestSafe,
                isVisible: !includesRequest
            )
        }
        .padding(showsBackground ? 14 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showsBackground ? cardBackground : Color.clear)
        .cornerRadius(showsBackground ? 18 : 0)
        .animation(.easeInOut(duration: 0.2), value: includesRequest)
    }

    private func row(icon: String, tint: Color, text: String, isVisible: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(tint)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(isVisible ? 1 : 0)
        .accessibilityHidden(!isVisible)
    }
}

private struct ExportSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ExportFittedSheetModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview {
    MetricExportOptionsView(metric: Mocks.metricJson, onExported: { _ in })
        .preferredColorScheme(.dark)
}
#endif
