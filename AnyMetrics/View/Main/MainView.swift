import SwiftUI
import SwiftyJSON
import AnyMetricsShared
import VVSI

struct MainView: View {

    enum SheetType: Identifiable {
        var id: String { "\(self)" }
        case addMetrics
        case info
        case profile
        case editRequest(Metric)
        case editTheme(Metric)
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
    var widgetGuideDontShowAgain = false
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
    var refreshSucceededThisLaunch = false
    @State
    var offerSecondMetric = false
    @State
    var reviewPromptScheduled = false
    @State
    private var startupMetricIDs: Set<UUID>?

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // MARK: - Content
                GeometryReader { proxy in
                    if viewState.state.metrics.isEmpty {
                        DashboardEmptyStateView()
                    } else {
                        metricsGrid(containerSize: proxy.size)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: Constants.spacing) {
                dashboardHeader
            }

            // MARK: - Add Button
            addMetricButton
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
                InfoView(
                    onShowOnboarding: {
                        showOnboarding = true
                    },
                    onShowReviewPrompt: {
                        showReviewPrompt = true
                    }
                )
            case .profile:
                ProfileView()
                    .environmentObject(viewState)
            case .editRequest(let metric):
                metricEditor(
                    metric: metric,
                    entry: .request,
                    title: AnyMetricsStrings.Metric.Actions.editRequest
                )
            case .editTheme(let metric):
                metricEditor(
                    metric: metric,
                    entry: .theme,
                    title: AnyMetricsStrings.Metric.Actions.editTheme
                )
            }
        }
        .sheet(item: $widgetInstructionsMetric, onDismiss: {
            AnalyticsEvents.widgetGuideDismissed(dontShowAgain: widgetGuideDontShowAgain)
            widgetGuideDontShowAgain = false
            let offerGallery = offerSecondMetric
            offerSecondMetric = false
            if offerGallery {
                DispatchQueue.main.async {
                    sheetType = .addMetrics
                }
            }
            presentQueuedSurfaces()
        }) { metric in
            WidgetInstructionsView(metricTitle: metric.title) { dontShowAgain in
                widgetGuideDontShowAgain = dontShowAgain
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
            MetricShareOptionsView(metric: metric) { payload, _ in
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
                ReviewHandler.markCompleted(source: AnalyticsEvents.ReviewSource.prompt)
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
                AnalyticsEvents.syncLibrary(viewState.state.metrics)
                showOnboarding = false
            }
            .environmentObject(viewState)
        }
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .showWidgetInstructions(let metric, let offerSecond):
                offerSecondMetric = offerSecond
                presentWidgetInstructions(metric)
            case .askReview:
                ReviewHandler.deferPromptUntilNextLaunch()
            case .reviewAfterSuccessfulRefresh:
                refreshSucceededThisLaunch = true
                scheduleReviewPromptIfNeeded()
            case .error(let message):
                presentError(message)
            }
        }
        .onAppear {
            captureStartupMetricsIfNeeded()
            viewState.trigger(.onAppear)
            scheduleReviewPromptIfNeeded()
        }

    }

    private func metricsGrid(containerSize: CGSize) -> some View {
        let columnCount = Constants.columnCount(for: containerSize)
        let cardSide = Constants.cardSide(for: containerSize.width, columns: columnCount)

        return ScrollView {
            LazyVGrid(columns: Constants.gridItems(count: columnCount), spacing: Constants.spacing) {
                ForEach(viewState.state.metrics.values.sorted(by: { $0.created > $1.created })) { metric in
                    MetricView(
                        metric: metric,
                        appearsImmediately: appearsImmediately(metric.id),
                        keepsInPersonalCatalog: viewState.state.personalMetrics[metric.id] != nil,
                        refreshMetric: { uuid in
                            viewState.trigger(.refreshMetric(uuid))
                        },
                        deletehMetric: { uuid in
                            viewState.trigger(.removeMetric(uuid))
                        },
                        editRequest: { metric in
                            sheetType = .editRequest(metric)
                        },
                        editTheme: { metric in
                            sheetType = .editTheme(metric)
                        },
                        duplicateMetric: { metric in
                            viewState.trigger(.duplicateMetric(metric))
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
                    .frame(width: cardSide, height: cardSide)
                }
            }
            .padding(.horizontal, Constants.gridHorizontalPadding)

            Spacer(minLength: Constants.bottomPadding)
        }
    }

    private var dashboardHeader: some View {
        ZStack {
            Text(AnyMetricsStrings.dashboard)
                .font(Constants.fontTitle)
                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                aboutButton
                Spacer(minLength: 0)
                profileButton
            }
        }
        .padding(.horizontal, Constants.padding)
        .padding(.top, Constants.padding)
    }

    private var addMetricButton: some View {
        Button {
            ImpactHelper.impactButton()
            sheetType = .addMetrics
        } label: {
            Image(systemName: "plus")
                .font(.system(size: Constants.addButtonSize - Constants.addButtonPadding * 2, weight: .thin))
                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                .frame(width: Constants.addButtonSize, height: Constants.addButtonSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(AddMetricButtonChrome())
        .padding()
    }

    private var aboutButton: some View {
        headerCircleButton(systemName: "info", accessibilityLabel: AnyMetricsStrings.appName) {
            sheetType = .info
        }
    }

    private var profileButton: some View {
        headerCircleButton(systemName: "person", accessibilityLabel: AnyMetricsStrings.Profile.title) {
            sheetType = .profile
        }
    }

    private func headerCircleButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                .frame(width: Constants.headerButtonSide, height: Constants.headerButtonSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(HeaderButtonChrome())
        .accessibilityLabel(accessibilityLabel)
    }

    private var canPresentReviewPrompt: Bool {
        sheetType == nil
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
    }

    private var canPresentError: Bool {
        sheetType == nil
            && widgetInstructionsMetric == nil
            && exportMetric == nil
            && shareMetric == nil
            && sharePayload == nil
            && exportFileURL == nil
            && !isMetricOverlayPresented
            && !showOnboarding
            && !showReviewPrompt
            && errorMessage == nil
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

    private func appearsImmediately(_ id: UUID) -> Bool {
        guard let startupMetricIDs else { return false }
        return !startupMetricIDs.contains(id)
    }

    private func captureStartupMetricsIfNeeded() {
        guard startupMetricIDs == nil else { return }
        startupMetricIDs = Set(viewState.state.metrics.keys)
    }

    private func metricEditor(metric: Metric, entry: MetricFormEntry, title: String) -> some View {
        NavigationView {
            MetricFormView(
                allowDismissed: $allowDismissed,
                metric: metric,
                entry: entry,
                action: { updatedMetric in
                    viewState.trigger(.addPersonalMetricAndRefresh(updatedMetric))
                    sheetType = nil
                }
            )
            .navigationTitle(title)
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

    private func presentWidgetInstructions(_ metric: Metric) {
        if canPresentWidgetInstructions {
            showWidgetGuide(metric)
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
        showWidgetGuide(metric)
    }

    private func showWidgetGuide(_ metric: Metric) {
        AnalyticsEvents.widgetGuideShown()
        widgetInstructionsMetric = metric
    }

    private func scheduleReviewPromptIfNeeded() {
        guard canPresentReviewPrompt, !reviewPromptScheduled else { return }

        guard reviewPromptTrigger() != nil else { return }

        reviewPromptScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            reviewPromptScheduled = false
            guard canPresentReviewPrompt else { return }
            guard let trigger = reviewPromptTrigger() else { return }
            ReviewHandler.recordPromptShown()
            AnalyticsEvents.reviewShown(
                trigger: trigger,
                librarySize: viewState.state.metrics.count
            )
            showReviewPrompt = true
        }
    }

    private func reviewPromptTrigger() -> ReviewHandler.Trigger? {
        guard refreshSucceededThisLaunch else { return nil }
        let metrics = viewState.state.metrics
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
        let includesRequest = payload.includesRequest
        let includesFile = payload.includesFile
        MetricSharePresenter.present(items: payload.activityItems) { result in
            cleanupShareFiles()
            switch result {
            case .dismissed(completed: true, let activity):
                AnalyticsEvents.metricShared(
                    includeRequest: includesRequest,
                    includesFile: includesFile,
                    activity: activity
                )
            case .failed:
                presentError(AnyMetricsStrings.Metric.Share.failed)
            case .dismissed(completed: false, _):
                AnalyticsEvents.metricShareCancelled()
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

private struct HeaderButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

private struct AddMetricButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial)
                .cornerRadius(MainView.Constants.addButtonCorner)
        }
    }
}

#Preview {
    MainView()
}
