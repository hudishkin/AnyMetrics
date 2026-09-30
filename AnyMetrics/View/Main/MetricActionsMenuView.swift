import SwiftUI

struct MetricActionsMenuView: View {

    private enum Constants {
        static let contentSpacing: CGFloat = 4
        static let sectionSpacing: CGFloat = 16
        static let rowSpacing: CGFloat = 8
        static let iconSize: CGFloat = 20
        static let iconWidth: CGFloat = 24
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
        static let rowHeight: CGFloat = 52
        static let closeSize: CGFloat = 30
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let deleteColor = AnyMetricsAsset.Assets.red.swiftUIColor
        static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let fontSubtitle = Font.system(size: 16, weight: .regular, design: .default)
        static let fontRow = Font.system(size: 17, weight: .regular, design: .default)
    }

    let metricTitle: String
    var onRefresh: () -> Void
    var onEdit: () -> Void
    var onExport: () -> Void
    var onShare: () -> Void
    var onDelete: () -> Void

    @State
    private var sheetHeight: CGFloat = 360
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            header

            VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                actionRow(
                    title: AnyMetricsStrings.Metric.Actions.updateValue,
                    icon: "arrow.clockwise",
                    action: onRefresh
                )
                actionRow(
                    title: AnyMetricsStrings.Metric.Actions.edit,
                    icon: "pencil",
                    action: onEdit
                )
                actionRow(
                    title: AnyMetricsStrings.Metric.Actions.export,
                    icon: "square.and.arrow.up.on.square",
                    action: onExport
                )
                actionRow(
                    title: AnyMetricsStrings.Metric.Actions.share,
                    icon: "square.and.arrow.up",
                    action: onShare
                )
            }

            Divider()
                .padding(.vertical, 8)

            actionRow(
                title: AnyMetricsStrings.Metric.Actions.delete,
                icon: "trash",
                color: Constants.deleteColor,
                action: onDelete
            )
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
        .padding(.bottom, Constants.bottomPadding)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ActionsSheetHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ActionsSheetHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            sheetHeight = height
        }
        .modifier(ActionsFittedSheetModifier(height: sheetHeight))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                Text(AnyMetricsStrings.Metric.Actions.menuTitle)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)

                Text(metricTitle)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button {
                ImpactHelper.impactLight()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Constants.closeSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Constants.secondaryColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AnyMetricsStrings.Common.close)
        }
    }

    private func actionRow(
        title: String,
        icon: String,
        color: Color = Constants.textColor,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            ImpactHelper.impactLight()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: Constants.iconSize, weight: .medium))
                    .frame(width: Constants.iconWidth, alignment: .center)
                Text(title)
                    .font(Constants.fontRow)
                Spacer(minLength: 0)
            }
            .foregroundColor(color)
            .frame(minHeight: Constants.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ActionsSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ActionsFittedSheetModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview {
    MetricActionsMenuView(
        metricTitle: "Bitcoin",
        onRefresh: {},
        onEdit: {},
        onExport: {},
        onShare: {},
        onDelete: {}
    )
    .preferredColorScheme(.dark)
}
#endif
