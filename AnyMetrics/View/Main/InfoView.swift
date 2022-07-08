//
//  InfoView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 26.06.2022.
//

import SwiftUI

fileprivate enum Constants {
    static let imageSize: CGFloat = 120
    static let arrowIconSize: CGFloat = 16
    static let spacing: CGFloat = 12
    static let spacing2: CGFloat = 24
    static let iconCorner: CGFloat = 30
    static let buttonCorner: CGFloat = 30
    static let imageArrow = Image(systemName: "arrow.right")
    static let imageStar = Image(systemName: "star")
    static let textColor = R.color.baseText.color
    static let titleColor = R.color.baseText.color
    static let linkColor = R.color.baseText.color
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
                        R.image.appIconInfo.image
                            .resizable()
                            .cornerRadius(Constants.iconCorner)
                            .frame(width: Constants.imageSize, height: Constants.imageSize, alignment: .center)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)

                    Spacer(minLength: Constants.spacing2)
                    Text(R.string.localizable.infoTitle())
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.titleColor)
                    Text(R.string.localizable.infoMessage())
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textColor)
                    Spacer(minLength: Constants.spacing2)
                    Link(destination: AppConfig.Urls.appRepository) {
                        HStack {
                            Text(R.string.localizable.infoGithubAppRepo())
                                .font(Constants.fontLink)
                                .foregroundColor(Constants.linkColor)
                            Constants.imageArrow
                                .resizable()
                                .frame(width: Constants.arrowIconSize, height: Constants.arrowIconSize, alignment: .center)
                                .foregroundColor(Constants.linkColor)
                        }
                    }
                    Link(destination: AppConfig.Urls.galleryRepository) {
                        HStack {
                            Text(R.string.localizable.infoGithubGalleryRepo())
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
                            Text(R.string.localizable.infoRate())
                                .font(Constants.fontLink)
                                .foregroundColor(Constants.linkColor)
                            Constants.imageStar
                                .resizable()
                                .frame(width: Constants.arrowIconSize, height: Constants.arrowIconSize, alignment: .center)
                                .foregroundColor(Constants.linkColor)
                        }



                        Text(R.string.localizable.infoVersion(Bundle.version()))
                            .foregroundColor(R.color.secondaryText.color)
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
                        Text(R.string.localizable.commonClose())
                            .foregroundColor(R.color.baseText.color)
                        Spacer()
                    }
                    .padding()
                }
                .background(R.color.galleryItemBackground.color)
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
