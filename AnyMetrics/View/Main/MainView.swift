import SwiftUI
import SwiftyJSON
import AnyMetricsShared
import VVSI

struct MainView: View {

    enum SheetType: Identifiable {
        var id: String { "\(self)" }
        case addMetrics
        case info
        case editMetric(Metric)
    }

    @StateObject
    var viewState: ViewState<Interactor> = .init(Interactor())
    @State
    var sheetType: SheetType?
    @State
    var allowDismissed = true
    @State
    var showActionMenu = false
    @State
    var showOnboarding = !AppSettings.hasCompletedOnboarding
    @State
    private var pendingOnboardingCompletion: OnboardingView.Completion?
    @State
    var widgetInstructionsMetric: Metric?
    @State
    var exportMetric: Metric?
    @State
    var exportFileURL: URL?
    @State
    var shareMetric: Metric?
    @State
    var sharePayload: MetricSharePayload?
    @State
    var pendingWidgetInstructionsMetric: Metric?
    @State
    var isMetricOverlayPresented = false
    @State
    var errorMessage: String?
    @State
    var pendingErrorMessage: String?
    @State
    var showReviewPrompt = false
    @State
    var pendingFirstAddReview = false
    @State
    var reviewPromptScheduled = false
#if DEBUG
    @State
    var showDevMenu = false
#endif

    let columns = Constants.collumns

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Header
                HStack(spacing: 8) {
                    Button {
                        sheetType = .info
                    } label: {
                        Text(AnyMetricsStrings.appName)
                            .font(Constants.fontTitle)
                            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            .padding(Constants.titleInset)
                            .background(.ultraThinMaterial)
                            .cornerRadius(Constants.titleCorner)
                    }

#if DEBUG
                    Button {
                        showDevMenu = true
                    } label: {
                        Text("</>")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                            .padding(Constants.titleInset)
                            .background(.ultraThinMaterial)
                            .cornerRadius(Constants.titleCorner)
                    }
#endif
                }
                .padding(Constants.padding)
                .zIndex(Constants.zIndexTitle)

                // MARK: - Content
                ScrollView {
                    Spacer(minLength: Constants.topPadding)
                    LazyVGrid(columns: columns, spacing: Constants.spacing) {
                        ForEach(viewState.state.metrics.values.sorted(by: { $0.created > $1.created })) { metric in
                            MetricView(
                                metric: metric,
                                refreshMetric: { uuid in
                                    viewState.trigger(.refreshMetric(uuid))
                                },
                                deletehMetric: { uuid in
                                    viewState.trigger(.removeMetric(uuid))
                                },
                                editMetric: { metric in
                                    sheetType = .editMetric(metric)
                                },
                                shareMetric: { metric in
                                    shareMetric = metric
                                },
                                exportMetric: { metric in
                                    exportMetric = metric
                                },
                                onOverlayChange: { presented in
                                    let wasPresented = isMetricOverlayPresented
                                    isMetricOverlayPresented = presented
                                    if wasPresented && !presented {
                                        scheduleReviewPromptIfNeeded()
                                    }
                                }
                            )
                            .frame(width: Constants.size, height: Constants.size)
                        }
                    }

                    Spacer(minLength: Constants.bottomPadding)
                }
            }

            // MARK: - Add Button
            Button {
                ImpactHelper.impactButton()
                sheetType = .addMetrics

            } label: {
                AnyMetricsAsset.Assets.plus.swiftUIImage
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                    .padding(Constants.addButtonPadding)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(Constants.addButtonCorner)
            .frame(width: Constants.addButtonSize, height: Constants.addButtonSize)
            .padding()
        }
        .sheet(item: $sheetType, onDismiss: {
            allowDismissed = true
            DispatchQueue.main.async {
                presentQueuedSurfaces()
            }
        }) { type in
            switch type {
            case .addMetrics:
                GalleryView(allowDismissed: $allowDismissed)
                    .interactiveDismiss(canDismissSheet: $allowDismissed)
                    .environmentObject(viewState)
            case .info:
                InfoView()
            case .editMetric(let metric):
                NavigationView {
                    MetricFormView(
                        allowDismissed: $allowDismissed,
                        metric: metric,
                        action: { updatedMetric in
                            viewState.trigger(.addMetricAndRefresh(updatedMetric))
                            sheetType = nil
                        }
                    )
                    .navigationTitle(AnyMetricsStrings.Metric.Actions.edit)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button(AnyMetricsStrings.Common.close) {
                            sheetType = nil
                        }
                    }
                }
                .interactiveDismiss(canDismissSheet: .constant(false))
                .environmentObject(viewState)
            }
        }
        .sheet(item: $widgetInstructionsMetric, onDismiss: {
            presentQueuedSurfaces()
        }) { metric in
            WidgetInstructionsView(metricTitle: metric.title) {
                widgetInstructionsMetric = nil
            }
        }
        .sheet(item: $exportMetric, onDismiss: {
            presentExportShareSheetIfNeeded()
        }) { metric in
            MetricExportOptionsView(metric: metric) { fileURL in
                exportFileURL = fileURL
                exportMetric = nil
            }
        }
        .sheet(item: $shareMetric, onDismiss: {
            presentMetricShareSheetIfNeeded()
        }) { metric in
            MetricShareOptionsView(metric: metric) { payload in
                sharePayload = payload
                shareMetric = nil
            }
        }
        .alert(AnyMetricsStrings.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 {
                errorMessage = nil
                presentQueuedSurfaces()
            } }
        )) {
            Button(AnyMetricsStrings.Common.ok, role: .cancel) {
                errorMessage = nil
                presentQueuedSurfaces()
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            AnyMetricsStrings.Review.title,
            isPresented: $showReviewPrompt
        ) {
            Button(AnyMetricsStrings.Review.rate) {
                ReviewHandler.markCompleted()
                ReviewHandler.requestReview()
            }
            Button(AnyMetricsStrings.Review.dontAsk) {
                ReviewHandler.markDeclined()
            }
            Button(AnyMetricsStrings.Review.later, role: .cancel) {
                ReviewHandler.markLater()
            }
        } message: {
            Text(AnyMetricsStrings.Review.message)
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            if case .addWidget(let metric) = pendingOnboardingCompletion {
                pendingOnboardingCompletion = nil
                viewState.trigger(.addOnboardingWidget(metric))
                return
            }
            pendingOnboardingCompletion = nil
            presentQueuedSurfaces()
        }) {
            OnboardingView { completion in
                pendingOnboardingCompletion = completion
                AppSettings.hasCompletedOnboarding = true
                showOnboarding = false
            }
            .environmentObject(viewState)
        }
#if DEBUG
        .sheet(isPresented: $showDevMenu, onDismiss: {
            presentQueuedSurfaces()
        }) {
            DevMenuView(
                onShowOnboarding: {
                    showOnboarding = true
                },
                onShowReviewPrompt: {
                    showReviewPrompt = true
                }
            )
        }
#endif
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .showWidgetInstructions(let metric):
                presentWidgetInstructions(metric)
            case .askReview:
                pendingFirstAddReview = true
                scheduleReviewPromptIfNeeded()
            case .error(let message):
                presentError(message)
            }
        }
        .onAppear {
            viewState.trigger(.onAppear)
            scheduleReviewPromptIfNeeded()
        }

    }

    private var canPresentReviewPrompt: Bool {
        var isReady = sheetType == nil
            && widgetInstructionsMetric == nil
            && pendingWidgetInstructionsMetric == nil
            && exportMetric == nil
            && shareMetric == nil
            && exportFileURL == nil
            && sharePayload == nil
            && !isMetricOverlayPresented
            && !showOnboarding
            && !showReviewPrompt
            && errorMessage == nil
#if DEBUG
        isReady = isReady && !showDevMenu
#endif
        return isReady
    }

    private var canPresentError: Bool {
        var isReady = sheetType == nil
            && widgetInstructionsMetric == nil
            && exportMetric == nil
            && shareMetric == nil
            && sharePayload == nil
            && exportFileURL == nil
            && !isMetricOverlayPresented
            && !showOnboarding
            && !showReviewPrompt
            && errorMessage == nil
#if DEBUG
        isReady = isReady && !showDevMenu
#endif
        return isReady
    }

    private var canPresentWidgetInstructions: Bool {
        sheetType == nil
            && exportMetric == nil
            && shareMetric == nil
            && sharePayload == nil
            && exportFileURL == nil
            && widgetInstructionsMetric == nil
            && !isMetricOverlayPresented
            && !showOnboarding
            && !showReviewPrompt
            && errorMessage == nil
    }

    private func presentWidgetInstructions(_ metric: Metric) {
        if canPresentWidgetInstructions {
            widgetInstructionsMetric = metric
        } else {
            pendingWidgetInstructionsMetric = metric
        }
    }

    private func presentQueuedSurfaces() {
        presentPendingWidgetInstructionsIfNeeded()
        if widgetInstructionsMetric == nil {
            presentPendingErrorIfNeeded()
        }
        scheduleReviewPromptIfNeeded()
    }

    private func presentPendingWidgetInstructionsIfNeeded() {
        guard widgetInstructionsMetric == nil, let metric = pendingWidgetInstructionsMetric else { return }
        guard canPresentWidgetInstructions else { return }
        pendingWidgetInstructionsMetric = nil
        widgetInstructionsMetric = metric
    }

    private func scheduleReviewPromptIfNeeded() {
        guard canPresentReviewPrompt, !reviewPromptScheduled else { return }

        guard reviewPromptTrigger(preferFirstAdd: pendingFirstAddReview) != nil else {
            pendingFirstAddReview = false
            return
        }

        reviewPromptScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            reviewPromptScheduled = false
            guard canPresentReviewPrompt else { return }
            guard let trigger = reviewPromptTrigger(preferFirstAdd: pendingFirstAddReview) else {
                pendingFirstAddReview = false
                return
            }
            pendingFirstAddReview = false
            ReviewHandler.recordPromptShown()
            AnalyticsEvents.reviewShown(trigger: trigger)
            showReviewPrompt = true
        }
    }

    private func reviewPromptTrigger(preferFirstAdd: Bool) -> ReviewHandler.Trigger? {
        let metrics = viewState.state.metrics
        if preferFirstAdd, ReviewHandler.shouldPrompt(.firstUserAdd, metrics: metrics) {
            return .firstUserAdd
        }
        if ReviewHandler.shouldPrompt(.existingUserLaunch, metrics: metrics) {
            return .existingUserLaunch
        }
        if ReviewHandler.shouldPrompt(.periodic, metrics: metrics) {
            return .periodic
        }
        return nil
    }

    private func presentError(_ message: String) {
        if canPresentError {
            errorMessage = message
        } else {
            pendingErrorMessage = message
        }
    }

    private func presentPendingErrorIfNeeded() {
        guard let message = pendingErrorMessage else { return }
        pendingErrorMessage = nil
        presentError(message)
    }

    private func presentExportShareSheetIfNeeded() {
        guard let fileURL = exportFileURL else {
            presentQueuedSurfaces()
            return
        }
        MetricSharePresenter.present(fileURL: fileURL) { result in
            cleanupExportFile()
            if case .failed = result {
                presentError(AnyMetricsStrings.Metric.Export.failed)
            }
            presentQueuedSurfaces()
        }
    }

    private func presentMetricShareSheetIfNeeded() {
        guard let payload = sharePayload else {
            presentQueuedSurfaces()
            return
        }
        MetricSharePresenter.present(items: payload.activityItems) { result in
            cleanupShareFiles()
            switch result {
            case .dismissed(completed: true):
                AnalyticsEvents.metricShared(mode: "image_and_metric")
            case .failed:
                presentError(AnyMetricsStrings.Metric.Share.failed)
            case .dismissed(completed: false):
                break
            }
            presentQueuedSurfaces()
        }
    }

    private func cleanupExportFile() {
        if let url = exportFileURL {
            try? FileManager.default.removeItem(at: url)
            exportFileURL = nil
        }
    }

    private func cleanupShareFiles() {
        if let payload = sharePayload {
            for url in payload.fileURLs {
                try? FileManager.default.removeItem(at: url)
            }
            sharePayload = nil
        }
    }
}

#Preview {
    MainView()
}
