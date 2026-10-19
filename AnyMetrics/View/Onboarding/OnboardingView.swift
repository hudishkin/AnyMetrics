import SwiftUI
import AnyMetricsShared
import VVSI

fileprivate enum Constants {
    static let horizontalPadding: CGFloat = 24
    static let titleSubtitleSpacing: CGFloat = 10
    static let buttonCorner: CGFloat = 30
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

    let onComplete: (Completion) -> Void

    @EnvironmentObject
    private var mainState: ViewState<MainView.Interactor>
    @State private var selectedMetric = StarterMetric.make()
    @State private var selectedStyle = StarterMetric.QuoteStyle.dusk
    @State private var isLoadingPreview = false
    @State private var previewFailed = false
    @State private var hasCompleted = false
    @State private var showGallery = false
    @State private var didLogShown = false
    @State private var previewTask: Task<Void, Never>?

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

            VStack(spacing: 28) {
                VStack(spacing: Constants.titleSubtitleSpacing) {
                    Text(AnyMetricsStrings.Onboarding.Page4.title)
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(AnyMetricsStrings.Onboarding.Page4.subtitle)
                        .font(Constants.fontSubtitle)
                        .foregroundColor(Constants.secondaryColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                widgetPreview(side: 168)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 12)

            Spacer(minLength: 20)

            Button(action: addWidget) {
                Text(AnyMetricsStrings.Onboarding.addWidget)
                    .font(Constants.fontButton)
                    .foregroundColor(Constants.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Constants.buttonBackground)
            .cornerRadius(Constants.buttonCorner)
            .accessibilityIdentifier("onboarding.addWidget")
            .disabled(hasCompleted)
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
            logShown()
        }
        .onDisappear {
            previewTask?.cancel()
        }
    }

    private func widgetPreview(side: CGFloat) -> some View {
        VStack(spacing: 16) {
            ZStack {
                MetricContentView(metric: selectedMetric)
                    .opacity(isLoadingPreview && !selectedMetric.hasResult ? 0.35 : 1)

                if isLoadingPreview && !selectedMetric.hasResult {
                    ProgressView()
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .accessibilityLabel(selectedMetric.title)

            VStack(spacing: 4) {
                Text(selectedMetric.title)
                    .font(.headline)
                    .foregroundColor(Constants.textColor)
                    .multilineTextAlignment(.center)
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
                        .multilineTextAlignment(.center)
                }
            }

            if selectedMetric.id == StarterMetric.id {
                gradientPicker
            }

            Button {
                showGallery = true
            } label: {
                Text(AnyMetricsStrings.Onboarding.chooseFromGallery)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Constants.textColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Constants.buttonBackground)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("onboarding.chooseFromGallery")
            .disabled(hasCompleted)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var gradientPicker: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("onboarding.gradient.title", comment: ""))
                .font(.caption)
                .foregroundColor(Constants.secondaryColor)

            HStack(spacing: 12) {
                ForEach(StarterMetric.QuoteStyle.allCases) { style in
                    gradientSwatch(style)
                }
            }
        }
        .accessibilityIdentifier("onboarding.gradients")
    }

    private func gradientSwatch(_ style: StarterMetric.QuoteStyle) -> some View {
        let selected = selectedStyle == style
        return Button {
            applyStyle(style)
        } label: {
            Circle()
                .fill(style.swatch)
                .frame(width: 28, height: 28)
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(selected ? Constants.textColor : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.gradient.\(style.rawValue)")
        .accessibilityLabel(Text(NSLocalizedString(style.localizationKey, comment: "")))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func applyStyle(_ style: StarterMetric.QuoteStyle) {
        guard selectedStyle != style else { return }
        selectedStyle = style
        var metric = selectedMetric
        metric.widgetAppearance = StarterMetric.appearance(for: style)
        selectedMetric = metric
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

    private func addWidget() {
        ImpactHelper.impactButton()
        completeOnboarding(.addWidget(selectedMetric))
    }

    private func completeOnboarding(_ completion: Completion) {
        guard !hasCompleted else { return }
        hasCompleted = true
        ImpactHelper.success()
        onComplete(completion)
    }

    private func logShown() {
        guard !didLogShown else { return }
        didLogShown = true
        AnalyticsEvents.onboardingShown()
    }
}

private extension StarterMetric.QuoteStyle {
    var swatch: LinearGradient {
        LinearGradient(
            colors: colors.map { Color(quoteHex: $0) },
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
}

private extension Color {
    init(quoteHex: String) {
        var cleaned = quoteHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        let value = UInt64(cleaned, radix: 16) ?? 0
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

#if DEBUG
#Preview {
    OnboardingView(onComplete: { _ in })
        .environmentObject(ViewState(MainView.Interactor()))
        .preferredColorScheme(.dark)
}
#endif
