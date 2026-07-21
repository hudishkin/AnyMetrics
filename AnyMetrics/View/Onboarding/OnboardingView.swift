import SwiftUI

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 24
    static let titleSubtitleSpacing: CGFloat = 10
    static let iconTextSpacing: CGFloat = 28
    static let buttonCorner: CGFloat = 30
    static let imageHeight: CGFloat = 320
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let buttonBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor

    static let fontTitle = Font.system(size: 32, weight: .bold, design: .default)
    static let fontSubtitle = Font.system(size: 17, weight: .regular, design: .default)
    static let fontButton = Font.system(size: 17, weight: .semibold, design: .default)
    static let fontSkip = Font.system(size: 15, weight: .medium, design: .default)
}

struct OnboardingView: View {

    struct Page: Identifiable {
        let id: Int
        let image: Image
        let title: String
        let subtitle: String
    }

    let onComplete: () -> Void

    @State private var currentPage = 0

    private var pages: [Page] {
        [
            Page(
                id: 0,
                image: AnyMetricsAsset.Assets.step1.swiftUIImage,
                title: AnyMetricsStrings.Onboarding.Page1.title,
                subtitle: AnyMetricsStrings.Onboarding.Page1.subtitle
            ),
            Page(
                id: 1,
                image: AnyMetricsAsset.Assets.step2.swiftUIImage,
                title: AnyMetricsStrings.Onboarding.Page2.title,
                subtitle: AnyMetricsStrings.Onboarding.Page2.subtitle
            ),
            Page(
                id: 2,
                image: AnyMetricsAsset.Assets.step3.swiftUIImage,
                title: AnyMetricsStrings.Onboarding.Page3.title,
                subtitle: AnyMetricsStrings.Onboarding.Page3.subtitle
            )
        ]
    }

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(AnyMetricsStrings.Onboarding.skip) {
                    completeOnboarding()
                }
                .font(Constants.fontSkip)
                .foregroundColor(Constants.secondaryColor)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)

            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    pageView(page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: advance) {
                Text(isLastPage ? AnyMetricsStrings.Onboarding.getStarted : AnyMetricsStrings.Onboarding.next)
                    .font(Constants.fontButton)
                    .foregroundColor(Constants.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Constants.buttonBackground)
            .cornerRadius(Constants.buttonCorner)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            page.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: Constants.imageHeight)
                .padding(.bottom, Constants.iconTextSpacing)

            VStack(alignment: .leading, spacing: Constants.titleSubtitleSpacing) {
                Text(page.title)
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private func advance() {
        ImpactHelper.impactButton()
        if isLastPage {
            completeOnboarding()
        } else {
            withAnimation {
                currentPage += 1
            }
        }
    }

    private func completeOnboarding() {
        ImpactHelper.success()
        onComplete()
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
#endif
