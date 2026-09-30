import SwiftUI
import AnyMetricsShared
import VVSI

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

    enum Completion {
        case skipped
        case addWidget(Metric)
    }

    struct Page: Identifiable {
        let id: Int
        let image: Image?
        let title: String
        let subtitle: String
    }

    let onComplete: (Completion) -> Void

    @EnvironmentObject
    private var mainState: ViewState<MainView.Interactor>
    @State private var currentPage = 0
    @State private var selectedMetric = StarterMetric.make()
    @State private var isLoadingPreview = false
    @State private var previewFailed = false
    @State private var hasCompleted = false
    @State private var showGallery = false
    @State private var previewTask: Task<Void, Never>?

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
                image: AnyMetricsAsset.Assets.step4.swiftUIImage,
                title: AnyMetricsStrings.Onboarding.Page3.title,
                subtitle: AnyMetricsStrings.Onboarding.Page3.subtitle
            ),
            Page(
                id: 3,
                image: nil,
                title: AnyMetricsStrings.Onboarding.Page4.title,
                subtitle: AnyMetricsStrings.Onboarding.Page4.subtitle
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
                    completeOnboarding(.skipped)
                }
                .accessibilityIdentifier("onboarding.skip")
                .disabled(hasCompleted)
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

            VStack(spacing: 12) {
                Button(action: advance) {
                    Text(isLastPage ? AnyMetricsStrings.Onboarding.addWidget : AnyMetricsStrings.Onboarding.next)
                        .font(Constants.fontButton)
                        .foregroundColor(Constants.textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .background(Constants.buttonBackground)
                .cornerRadius(Constants.buttonCorner)
                .accessibilityIdentifier(isLastPage ? "onboarding.addWidget" : "onboarding.next")
                .disabled(hasCompleted)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showGallery) {
            GalleryView(allowDismissed: .constant(true), onPickMetric: { metric in
                selectMetric(metric)
            })
            .environmentObject(mainState)
        }
        .onAppear {
            loadPreview()
        }
        .onDisappear {
            previewTask?.cancel()
        }
    }

    private func pageView(_ page: Page) -> some View {
        GeometryReader { geometry in
            let previewSide = min(240, max(120, geometry.size.height * 0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.iconTextSpacing) {
                    Spacer(minLength: 0)

                    Group {
                        if let image = page.image {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            widgetPreview(side: previewSide)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: page.image == nil ? previewSide + 76 : min(Constants.imageHeight, geometry.size.height * 0.55))

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

                        if page.image == nil {
                            Button {
                                showGallery = true
                            } label: {
                                Label(AnyMetricsStrings.Onboarding.chooseFromGallery, systemImage: "square.grid.2x2")
                                    .font(Constants.fontSkip)
                            }
                            .foregroundColor(Constants.secondaryColor)
                            .accessibilityIdentifier("onboarding.chooseFromGallery")
                            .disabled(hasCompleted)
                            .padding(.top, 4)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .leading)
                .padding(.horizontal, Constants.horizontalPadding)
            }
        }
    }

    private func widgetPreview(side: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                MetricContentView(metric: selectedMetric)
                    .opacity(isLoadingPreview && !selectedMetric.hasResult ? 0.35 : 1)

                if isLoadingPreview && !selectedMetric.hasResult {
                    ProgressView()
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
            .accessibilityLabel(selectedMetric.title)

            Text(selectedMetric.title)
                .font(.headline)
                .foregroundColor(Constants.textColor)
                .accessibilityIdentifier("onboarding.starter.title")

            if isLoadingPreview {
                ProgressView(AnyMetricsStrings.Onboarding.previewLoading)
                    .font(.footnote)
            } else if previewFailed {
                Button {
                    loadPreview()
                } label: {
                    Label(AnyMetricsStrings.Onboarding.previewRetry, systemImage: "arrow.clockwise")
                        .font(.footnote)
                }
                .foregroundColor(Constants.secondaryColor)
            } else {
                Text(selectedMetric.measure)
                    .font(.footnote)
                    .foregroundColor(Constants.secondaryColor)
            }
        }
    }

    private func selectMetric(_ metric: Metric) {
        selectedMetric = metric
        previewFailed = false
        loadPreview()
    }

    private func loadPreview() {
        previewTask?.cancel()
        let metric = selectedMetric
        isLoadingPreview = true
        previewFailed = false
        previewTask = Task { @MainActor in
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<FetcherResult, Never>) in
                Fetcher.fetch(for: metric) { result in
                    continuation.resume(returning: result)
                }
            }
            guard !Task.isCancelled, selectedMetric.id == metric.id else { return }
            isLoadingPreview = false
            switch result {
            case .result(let parseResult):
                selectedMetric.apply(parseResult: parseResult)
            case .error, .none:
                previewFailed = true
            }
        }
    }

    private func advance() {
        ImpactHelper.impactButton()
        if isLastPage {
            completeOnboarding(.addWidget(selectedMetric))
        } else {
            withAnimation {
                currentPage += 1
            }
        }
    }

    private func completeOnboarding(_ completion: Completion) {
        guard !hasCompleted else { return }
        hasCompleted = true
        ImpactHelper.success()
        AnalyticsEvents.onboardingCompleted()
        onComplete(completion)
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: { _ in })
        .environmentObject(ViewState(MainView.Interactor()))
        .preferredColorScheme(.dark)
}
#endif
