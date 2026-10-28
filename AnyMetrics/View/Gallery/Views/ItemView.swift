import SwiftUI
import AnyMetricsShared

extension GalleryView {

    struct ItemView: View {
        var metric: Metric
        var addMetric: (Metric) -> Void
        var removeMetric: (UUID) -> Void
        var alreadyAdded: Bool

        var body: some View {
            let description = metric.description.flatMap { $0.isEmpty ? nil : $0 }

            return ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: Constants.itemContentSpacing) {
                    Text(metric.title)
                        .font(Constants.itemTitleFont)
                    Text(metric.measure)
                        .font(Constants.itemDefaultBoldFont)
                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)

                    if let description {
                        Text(description)
                            .font(Constants.itemDefaultFont)
                            .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                            .padding(.top, Constants.bodyTopInset)
                    }

                    if let website = metric.website {
                        Link(website.absoluteString, destination: website)
                            .font(Constants.itemDefaultFont)
                            .padding(.top, description == nil ? Constants.bodyTopInset : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Constants.itemContentPadding)
                .padding(.trailing, Constants.itemAccessoryTrailing)
                .modifier(GalleryItemCardBackground())
                if alreadyAdded {
                    Button {
                        removeMetric(metric.id)

                    } label: {
                        AnyMetricsAsset.Assets.minus.swiftUIImage
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: Constants.itemButtonSize, height: Constants.itemButtonSize, alignment: .center)
                            .background(Circle().fill(AnyMetricsAsset.Assets.red.swiftUIColor))

                    }
                    .offset(Constants.itemButtonOffset)
                } else {

                    Button {
                        addMetric(metric)
                    } label: {
                        AnyMetricsAsset.Assets.plus.swiftUIImage
                            .renderingMode(.template)
                            .frame(width: Constants.itemButtonSize, height: Constants.itemButtonSize, alignment: .center)
                            .overlay {
                                Circle()
                                    .stroke(AnyMetricsAsset.Assets.baseText.swiftUIColor, lineWidth: Constants.itemButtonLine)
                            }
                    }
                    .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                    .offset(Constants.itemButtonOffset)

                }

            }
        }
    }

}

/// На iOS 26 карточка — отдельное стекло. На старых версиях остаётся прежний цвет.
private struct GalleryItemCardBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: GalleryView.Constants.itemCorner, style: .continuous)
            )
        } else {
            content
                .background(AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor)
                .cornerRadius(GalleryView.Constants.itemCorner)
        }
    }
}
