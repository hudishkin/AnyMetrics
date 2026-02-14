import SwiftUI
import AnyMetricsShared

extension GalleryView {

    struct ItemView: View {
        var metric: Metric
        var addMetric: (Metric) -> Void
        var removeMetric: (UUID) -> Void
        @State var alreadyAdded: Bool

        var body: some View {
            ZStack(alignment: .topTrailing ) {
                VStack(alignment: .leading, spacing: Constants.itemContentSpacing) {
                    HStack {
                        VStack(alignment: .leading, spacing: Constants.itemContentSpacing) {
                            Text(metric.title)
                                .font(Constants.itemTitleFont)
                            Text(metric.measure)
                                .font(Constants.itemDefaultBoldFont)
                                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)

                        }
                        Spacer()
                    }

                    if let description = metric.description, !description.isEmpty {
                        Text(description)
                            .lineLimit(nil)

                            .font(Constants.itemDefaultFont)
                            .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                            .padding(Constants.descriptionInset)
                    }

                    if let website = metric.website {
                        Link(website.absoluteString, destination: website)
                            .font(Constants.itemDefaultFont)
                    }
                }
                .padding(Constants.itemContentPadding)
                .background(AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor)
                .cornerRadius(Constants.itemCorner)
                if alreadyAdded {
                    Button {
                        alreadyAdded = false
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
                        alreadyAdded = true
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
