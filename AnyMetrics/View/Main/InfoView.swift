//
//  InfoView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 26.06.2022.
//

import SwiftUI
import AnyMetricsShared

fileprivate enum Constants {
    static let imageSize: CGFloat = 120
    static let arrowIconSize: CGFloat = 16
    static let spacing: CGFloat = 12
    static let spacing2: CGFloat = 24
    static let iconCorner: CGFloat = 30
    static let buttonCorner: CGFloat = 30
    static let imageArrow = Image(systemName: "arrow.right")
    static let imageStar = Image(systemName: "star")
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let titleColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let linkColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let fontTitle: Font = {
        Font.system(size: 34, weight: .bold, design: .default)
    }()

    static let fontBody: Font = {
        Font.system(size: 18, weight: .semibold, design: .default)
    }()
    static let fontSmall: Font = {
        Font.system(size: 14, weight: .semibold, design: .default)
    }()
    static let fontLink: Font = {
        Font.system(size: 22, weight: .semibold, design: .default)
    }()
}
struct InfoView: View {

    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.spacing) {
                    HStack(alignment: .center) {
                        AnyMetricsAsset.Assets.appIconInfo.swiftUIImage
                            .resizable()
                            .cornerRadius(Constants.iconCorner)
                            .frame(width: Constants.imageSize, height: Constants.imageSize, alignment: .center)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)

                    Spacer(minLength: Constants.spacing2)
                    Text(AnyMetricsStrings.Info.title)
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.titleColor)
                    Text(AnyMetricsStrings.Info.message)
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textColor)
                    Spacer(minLength: Constants.spacing2)
//                    Link(destination: AppConfig.Urls.appRepository) {
//                        HStack {
//                            Text(AnyMetricsStrings.Info.githubAppRepo)
//                                .font(Constants.fontLink)
//                                .foregroundColor(Constants.linkColor)
//                            Constants.imageArrow
//                                .resizable()
//                                .frame(width: Constants.arrowIconSize, height: Constants.arrowIconSize, alignment: .center)
//                                .foregroundColor(Constants.linkColor)
//                        }
//                    }
                    Link(destination: AppConfig.Urls.galleryRepository) {
                        HStack {
                            Text(AnyMetricsStrings.Info.githubGalleryRepo)
                                .font(Constants.fontLink)
                                .foregroundColor(Constants.linkColor)
                            Constants.imageArrow
                                .resizable()
                                .frame(width: Constants.arrowIconSize, height: Constants.arrowIconSize, alignment: .center)
                                .foregroundColor(Constants.linkColor)
                        }
                    }

                    Spacer(minLength: Constants.spacing2 + Constants.spacing2)

                    VStack(alignment: .leading) {
                        Button {
                            ReviewHandler.requestReview()
                        } label: {
                            Text(AnyMetricsStrings.Info.rate)
                                .font(Constants.fontLink)
                                .foregroundColor(Constants.linkColor)
                            Constants.imageStar
                                .resizable()
                                .frame(width: Constants.arrowIconSize, height: Constants.arrowIconSize, alignment: .center)
                                .foregroundColor(Constants.linkColor)
                        }



                        Text(AnyMetricsStrings.Info.version(Bundle.appVersion()))
                            .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                            .font(Constants.fontBody)

                    }


                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .leading)
                .padding()
            }

            Spacer()
            HStack {
                Button {
                    ImpactHelper.impactButton()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(AnyMetricsStrings.Common.close)
                            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        Spacer()
                    }
                    .padding()
                }
                .background(AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor)
                .cornerRadius(Constants.buttonCorner)
            }
            .padding()

        }
    }
}

#if DEBUG
struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
            .preferredColorScheme(.dark)
    }
}
#endif
