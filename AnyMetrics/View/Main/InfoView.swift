//
//  InfoView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 26.06.2022.
//

import SwiftUI
import MessageUI
import AnyMetricsShared

fileprivate enum Constants {
    static let imageSize: CGFloat = 96
    static let iconCorner: CGFloat = 22
    static let cardCorner: CGFloat = 18
    static let buttonCorner: CGFloat = 30
    static let horizontalPadding: CGFloat = 24
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
    static let fontTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let fontBody = Font.system(size: 16, weight: .regular, design: .default)
    static let fontTrust = Font.system(size: 15, weight: .regular, design: .default)
    static let fontRow = Font.system(size: 17, weight: .medium, design: .default)
    static let fontVersion = Font.system(size: 13, weight: .regular, design: .default)
}

struct InfoView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var showEmail = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    intro
                    links
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, 32)
                .padding(.bottom, 16)
            }

            Text(AnyMetricsStrings.Info.version(Bundle.appVersion()))
                .font(Constants.fontVersion)
                .foregroundColor(Constants.secondaryColor)
                .padding(.bottom, 8)

            Button {
                ImpactHelper.impactButton()
                dismiss()
            } label: {
                Text(AnyMetricsStrings.Common.close)
                    .foregroundColor(Constants.textColor)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Constants.cardBackground)
            .cornerRadius(Constants.buttonCorner)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showEmail) {
            MailView(result: $mailResult) { compose in
                compose.setToRecipients([AppConfig.emailForReport])
                compose.setSubject(AnyMetricsStrings.Info.mailSubject)
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            AnyMetricsAsset.Assets.appIconInfo.swiftUIImage
                .resizable()
                .frame(width: Constants.imageSize, height: Constants.imageSize)
                .clipShape(
                    RoundedRectangle(cornerRadius: Constants.iconCorner, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(AnyMetricsStrings.appName)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)

                Text(AnyMetricsStrings.Info.summary)
                    .font(Constants.fontBody)
                    .foregroundColor(Constants.textColor)

                Text(AnyMetricsStrings.Info.trust)
                    .font(Constants.fontTrust)
                    .foregroundColor(Constants.secondaryColor)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }

    private var links: some View {
        VStack(spacing: 0) {
            InfoLinkRow(systemImage: "star", title: AnyMetricsStrings.Info.rate, action: rateApp)
            rowDivider
            InfoLinkRow(systemImage: "envelope", title: AnyMetricsStrings.Info.contact, action: contactDeveloper)
            rowDivider
            InfoLinkRow(systemImage: "hand.raised", title: AnyMetricsStrings.Info.privacy) {
                open(AppConfig.Urls.privacyPolicy)
            }
            rowDivider
            InfoLinkRow(systemImage: "chevron.left.forwardslash.chevron.right", title: AnyMetricsStrings.Info.source) {
                open(AppConfig.Urls.appRepository)
            }
            rowDivider
            InfoLinkRow(systemImage: "plus.rectangle.on.folder", title: AnyMetricsStrings.Info.gallery) {
                open(AppConfig.Urls.galleryRepository)
            }
        }
        .background(Constants.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 54)
    }

    private func rateApp() {
        ImpactHelper.impactButton()
        ReviewHandler.markCompleted(source: AnalyticsEvents.ReviewSource.about)
        UIApplication.shared.open(AppConfig.Urls.appStoreReview)
    }

    private func contactDeveloper() {
        ImpactHelper.impactButton()
        if MFMailComposeViewController.canSendMail() {
            showEmail = true
            return
        }
        let subject = AnyMetricsStrings.Info.mailSubject
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(AppConfig.emailForReport)?subject=\(subject)") {
            UIApplication.shared.open(url)
        }
    }

    private func open(_ url: URL) {
        ImpactHelper.impactButton()
        UIApplication.shared.open(url)
    }
}

private struct InfoLinkRow: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24)
                Text(title)
                    .font(Constants.fontRow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Constants.secondaryColor)
            }
            .foregroundColor(Constants.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#if DEBUG
struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InfoView()
                .preferredColorScheme(.dark)
            InfoView()
                .preferredColorScheme(.light)
        }
    }
}
#endif
