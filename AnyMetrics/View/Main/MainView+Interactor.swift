import SwiftUI
import WidgetKit
import Combine
import AnyMetricsShared
import VVSI

extension MainView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {

        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        var initialState: MainView.VState

        var metricStore: MetricStore
        var personalMetricStore: MetricStore
        private var migrationTokens = Set<AnyCancellable>()
        private var didMigratePersonalCatalog = false

        init(di: DI = .shared) {
            self.metricStore = di.metricStore
            self.personalMetricStore = di.personalMetricStore
            AppSettings.completeOnboardingForExistingLibrary(hasMetrics: !metricStore.metrics.isEmpty)
            ReviewHandler.recordAppLaunchIfNeeded()
            initialState = .init(
                metrics: metricStore.metrics,
                personalMetrics: personalMetricStore.metrics
            )
            AnalyticsEvents.syncLibrary(metricStore.metrics)
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .addOnboardingWidget(let metric):
                let isNew = metricStore.metrics[metric.id] == nil
                let metric = StarterMetric.installIfNeeded(metric, in: metricStore)
                if isNew {
                    AnalyticsEvents.metricAdded(
                        source: AnalyticsEvents.Source.onboarding,
                        type: metric.type,
                        resultKind: metric.resultKind,
                        galleryId: metric.id.uuidString
                    )
                }
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    // This is an explicit request, even if automatic guides were disabled.
                    AnalyticsEvents.syncLibrary(self.metricStore.metrics)
                    self.notifications.send(
                        .showWidgetInstructions(
                            metric,
                            offerSecondMetric: self.metricStore.metrics.count == 1
                        )
                    )
                    if !metric.hasResult {
                        self.refreshStoredMetric(id: metric.id, updater: updater)
                    }
                }
            case .onAppear:
                migratePersonalCatalogIfNeeded(updater: updater)
                fallthrough
            case .refreshAllMetrics, .syncMetrics:
                Task { @MainActor in
                    guard let state = await state() else { return }

                    updateMetrics(
                        state: state,
                        onEach: { [weak self] metric in
                            guard let self else { return }
                            self.metricStore.saveRefresh(metric)
                            Task { @MainActor in
                                await updater {
                                    $0.metrics = self.metricStore.metrics
                                }
                                // Each finished metric can leave the lock screen immediately.
                                // A sibling that is still in flight must not hold this one.
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        },
                        onComplete: { [weak self] updatedMetrics in
                            guard let self else { return }
                            let failed = updatedMetrics.values.filter(\.refreshFailed).count
                            if !updatedMetrics.isEmpty {
                                AnalyticsEvents.libraryRefreshed(
                                    librarySize: updatedMetrics.count,
                                    failedCount: failed
                                )
                                if failed == 0 {
                                    self.notifications.send(.reviewAfterSuccessfulRefresh)
                                }
                            }
                        }
                    )
                }
            case .addMetric(let metric):
                install(metric, refresh: false, rememberInPersonal: false, updater: updater)

            case .addMetricAndRefresh(let metric):
                install(metric, refresh: true, rememberInPersonal: false, updater: updater)

            case .addPersonalMetricAndRefresh(let metric):
                install(metric, refresh: true, rememberInPersonal: true, updater: updater)

            case .removeMetric(let id):
                if personalMetricStore.metrics[id] != nil {
                    if let current = metricStore.metrics[id] {
                        personalMetricStore.addMetric(metric: current)
                    }
                    metricStore.removeFromLibrary(id: id)
                } else {
                    let isStarter = StarterMetric.isStarter(id)
                    metricStore.removeMetric(id: id)
                    AnalyticsEvents.metricDeleted(isStarter: isStarter)
                }
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                publishLibraries(updater: updater)
            case .deletePersonalMetric(let id):
                let isStarter = StarterMetric.isStarter(id)
                personalMetricStore.removeFromLibrary(id: id)
                if metricStore.metrics[id] != nil {
                    metricStore.removeMetric(id: id)
                } else {
                    WidgetBackgroundStore.shared.deleteAll(for: id)
                    MetricResultImageStore.shared.deleteAll(for: id)
                }
                AnalyticsEvents.metricDeleted(isStarter: isStarter)
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                publishLibraries(updater: updater)
            case .migratePersonalCatalog:
                migratePersonalCatalogIfNeeded(updater: updater)
            case .duplicateMetric(let metric):
                let copy = metric.duplicated()
                personalMetricStore.addMetric(metric: copy)
                metricStore.addMetric(metric: copy)
                AnalyticsEvents.metricAdded(
                    source: AnalyticsEvents.Source.duplicate,
                    type: copy.type,
                    resultKind: copy.resultKind
                )
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                publishLibraries(updater: updater)
            case .refreshMetric(let id):
                Task { @MainActor in
                    guard let state = await state() else { return }
                    guard let metric = state.metrics[id] ?? metricStore.metrics[id] else { return }

                    updateMetric(metric: metric) {[weak self] metric, error in
                        guard let self else { return }

                        let saved = self.metricStore.saveRefresh(metric)

                        Task { @MainActor in
                            await updater {
                                $0.metrics = self.metricStore.metrics
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        AnalyticsEvents.metricRefreshed(success: error == nil, error: error)
                        if let error, saved.refreshFailed {
                            self.notifications.send(.error(Self.refreshErrorMessage(metric: saved, error: error)))
                        }
                    }
                }
            }
        }

        private func install(
            _ metric: Metric,
            refresh: Bool,
            rememberInPersonal: Bool,
            updater: @escaping StateUpdater<S>
        ) {
            let isNewToDashboard = metricStore.metrics[metric.id] == nil
            let isFirstSave = isNewToDashboard && personalMetricStore.metrics[metric.id] == nil
            if rememberInPersonal || personalMetricStore.metrics[metric.id] != nil {
                personalMetricStore.addMetric(metric: metric)
            }
            if !isNewToDashboard {
                AnalyticsEvents.metricEdited(type: metric.type, resultKind: metric.resultKind)
            }
            metricStore.addMetric(metric: metric)
            AnalyticsEvents.syncLibrary(metricStore.metrics)
            let metricID = metric.id
            Task { @MainActor in
                await updater {
                    $0.metrics = self.metricStore.metrics
                    $0.personalMetrics = self.personalMetricStore.metrics
                }
                WidgetCenter.shared.reloadAllTimelines()
                if refresh {
                    self.refreshStoredMetric(id: metricID, updater: updater)
                }
                self.notifyAfterSavingNewMetric(metric, isNew: isFirstSave)
            }
        }

        private func publishLibraries(updater: @escaping StateUpdater<S>) {
            Task { @MainActor in
                await updater {
                    $0.metrics = self.metricStore.metrics
                    $0.personalMetrics = self.personalMetricStore.metrics
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }

        /// Copies home-screen metrics that are not in the gallery into Personal
        /// when that catalog is still empty.
        private func migratePersonalCatalogIfNeeded(updater: @escaping StateUpdater<S>) {
            guard !didMigratePersonalCatalog else { return }
            guard personalMetricStore.metrics.isEmpty else {
                didMigratePersonalCatalog = true
                return
            }
            guard !metricStore.metrics.isEmpty else { return }

            didMigratePersonalCatalog = true
            GalleryService.load()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if case .failure = completion {
                        self?.didMigratePersonalCatalog = false
                    }
                } receiveValue: { [weak self] gallery in
                    guard let self else { return }
                    let galleryIDs = Set(gallery.flatMap { $0.metrics.map(\.id) })
                    let adopted = PersonalCatalog.metricsToAdopt(
                        dashboard: self.metricStore.metrics,
                        personal: self.personalMetricStore.metrics,
                        galleryIDs: galleryIDs
                    )
                    guard !adopted.isEmpty, self.personalMetricStore.metrics.isEmpty else { return }
                    var stored = self.personalMetricStore.metrics
                    for metric in adopted {
                        stored[metric.id] = metric
                    }
                    self.personalMetricStore.metrics = stored
                    Task { @MainActor in
                        await updater {
                            $0.personalMetrics = self.personalMetricStore.metrics
                        }
                    }
                }
                .store(in: &migrationTokens)
        }

        private func notifyAfterSavingNewMetric(_ metric: Metric, isNew: Bool) {
            guard isNew else { return }
            if !StarterMetric.isStarter(metric.id) {
                notifications.send(.askReview)
            }
            if !AppSettings.hideWidgetInstructions {
                notifications.send(
                    .showWidgetInstructions(
                        metric,
                        offerSecondMetric: metricStore.metrics.count == 1
                    )
                )
            }
        }

        private func refreshStoredMetric(id: UUID, updater: @escaping StateUpdater<S>) {
            guard let metric = metricStore.metrics[id] else { return }

            updateMetric(metric: metric) { [weak self] refreshed, error in
                guard let self else { return }

                let saved = self.metricStore.saveRefresh(refreshed)

                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if let error, saved.refreshFailed {
                    self.notifications.send(.error(Self.refreshErrorMessage(metric: saved, error: error)))
                }
            }
        }

        private func updateMetrics(
            state: VState,
            onEach: @escaping (Metric) -> Void,
            onComplete: @escaping (Metrics) -> Void
        ) {
            let metrics = Array(state.metrics.values)
            guard !metrics.isEmpty else {
                onComplete([:])
                return
            }

            var updatedMetrics = Metrics()
            let group = DispatchGroup()
            for metric in metrics {
                group.enter()
                fetchOne(metric) { updated in
                    updatedMetrics[updated.id] = updated
                    onEach(updated)
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                onComplete(updatedMetrics)
            }
        }

        private func fetchOne(_ metric: Metric, completion: @escaping (Metric) -> Void) {
            var copy = metric
            Fetcher.fetch(for: copy) { result in
                switch result {
                case .result(let value):
                    copy.apply(parseResult: value)
                case .error:
                    copy.markRefreshFailed()
                case .none:
                    break
                }
                DispatchQueue.main.async {
                    completion(copy)
                }
            }
        }

        private func updateMetric(metric: Metric, callback: @escaping (Metric, Error?) -> Void) {
            var metric = metric
            Fetcher.fetch(for: metric) { result in
                var error: Error?
                switch result {
                case .result(let value):
                    metric.apply(parseResult: value)
                case .error(let fetchError):
                    metric.markRefreshFailed()
                    error = fetchError
                case .none:
                    break
                }

                DispatchQueue.main.async {
                    callback(metric, error)
                }
            }
        }

        private static func refreshErrorMessage(metric: Metric, error: Error) -> String {
            AnyMetricsStrings.Error.metricRefresh(metric.title, ErrorMessageFormatter.message(for: error))
        }
    }

}
