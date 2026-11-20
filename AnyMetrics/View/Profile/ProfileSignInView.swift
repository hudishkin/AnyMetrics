import SwiftUI
import AnyMetricsShared

/// Sign-in methods the server offers, with legal links below.
struct ProfileSignInView: View {
    private typealias Constants = ProfileView.Constants

    var providers: [BuilderAPI.SignInProvider]
    var signingIn: BuilderAPI.SignInProvider?
    var onSignIn: (BuilderAPI.SignInProvider) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                Text(AnyMetricsStrings.Profile.selectMethod)
                    .font(Constants.fontBody)
                    .foregroundColor(Constants.secondaryColor)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    ForEach(providers, id: \.self) { provider in
                        signInButton(provider)
                    }
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            Spacer()
            legalLinks
                .padding(.bottom, 12)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Link(AnyMetricsStrings.TopUp.terms, destination: AppConfig.Urls.terms)
            Text("·")
            Link(AnyMetricsStrings.Info.privacy, destination: AppConfig.Urls.privacyPolicy)
        }
        .font(.system(size: 13))
        .foregroundColor(Constants.secondaryColor)
        .tint(Constants.secondaryColor)
    }

    private func signInButton(_ provider: BuilderAPI.SignInProvider) -> some View {
        let isBusy = signingIn != nil
        let showsLoader = signingIn == provider
        return Button {
            ImpactHelper.impactButton()
            onSignIn(provider)
        } label: {
            ZStack {
                Text(providerTitle(provider))
                    .font(Constants.fontRow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                HStack {
                    providerIcon(provider)
                        .frame(width: 24, height: 24)
                    Spacer(minLength: 0)
                    if showsLoader {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .foregroundColor(Constants.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isBusy)
        .opacity(isBusy && !showsLoader ? 0.45 : 1)
        .accessibilityLabel(providerTitle(provider))
    }

    private func providerTitle(_ provider: BuilderAPI.SignInProvider) -> String {
        switch provider {
        case .apple:
            return AnyMetricsStrings.Profile.signInApple
        case .google:
            return AnyMetricsStrings.Profile.signInGoogle
        case .github:
            return AnyMetricsStrings.Profile.signInGithub
        }
    }

    @ViewBuilder
    private func providerIcon(_ provider: BuilderAPI.SignInProvider) -> some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .semibold))
        case .google:
            Text("G")
                .font(.system(size: 18, weight: .semibold))
        case .github:
            AnyMetricsAsset.Assets.gitHub.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}
