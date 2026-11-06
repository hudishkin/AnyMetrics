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

        init(di: DI = .shared) {
            self.metricStore = di.metricStore
            AppSettings.completeOnboardingForExistingLibrary(hasMetrics: !metricStore.metrics.isEmpty)
            ReviewHandler.recordAppLaunchIfNeeded()
            initialState = .init(metrics: metricStore.metrics)
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
            case .onAppear, .refreshAllMetrics, .syncMetrics:
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
                let isNew = metricStore.metrics[metric.id] == nil
                metricStore.addMetric(metric: metric)
                if !isNew {
                    AnalyticsEvents.metricEdited(type: metric.type, resultKind: metric.resultKind)
                }
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    self.notifyAfterSavingNewMetric(metric, isNew: isNew)
                }

            case .addMetricAndRefresh(let metric):
                let isNew = metricStore.metrics[metric.id] == nil
                metricStore.addMetric(metric: metric)
                if !isNew {
                    AnalyticsEvents.metricEdited(type: metric.type, resultKind: metric.resultKind)
                }
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                let metricID = metric.id
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    self.refreshStoredMetric(id: metricID, updater: updater)
                    self.notifyAfterSavingNewMetric(metric, isNew: isNew)
                }

            case .removeMetric(let id):
                let isStarter = StarterMetric.isStarter(id)
                metricStore.removeMetric(id: id)
                AnalyticsEvents.metricDeleted(isStarter: isStarter)
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case .duplicateMetric(let metric):
                let copy = metric.duplicated()
                metricStore.addMetric(metric: copy)
                AnalyticsEvents.metricAdded(
                    source: AnalyticsEvents.Source.duplicate,
                    type: copy.type,
                    resultKind: copy.resultKind
                )
                AnalyticsEvents.syncLibrary(metricStore.metrics)
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
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
