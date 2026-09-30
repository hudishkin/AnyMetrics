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
            ReviewHandler.recordAppLaunchIfNeeded()
            initialState = .init(metrics: metricStore.metrics)
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .addOnboardingWidget(let metric):
                let metric = StarterMetric.installIfNeeded(metric, in: metricStore)
                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    // This is an explicit request, even if automatic guides were disabled.
                    self.notifications.send(.showWidgetInstructions(metric))
                    if !metric.hasResult {
                        self.refreshStoredMetric(id: metric.id, updater: updater)
                    }
                }
            case .onAppear, .refreshAllMetrics, .syncMetrics:
                Task { @MainActor in
                    guard let state = await state() else { return }

                    updateMetrics(state: state) { [weak self] updatedMetrics in
                        guard let self else { return }
                        Task { @MainActor in
                            var merged = self.metricStore.metrics
                            for (id, metric) in updatedMetrics {
                                merged[id] = metric
                            }
                            self.metricStore.metrics = merged
                            await updater {
                                $0.metrics = merged
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                }
            case .addMetric(let metric):
                let isNew = metricStore.metrics[metric.id] == nil
                metricStore.addMetric(metric: metric)
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
                metricStore.removeMetric(id: id)
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

                        self.metricStore.addMetric(metric: metric)

                        Task {
                            await updater {
                                $0.metrics = self.metricStore.metrics
                            }
                        }
                        if let error {
                            self.notifications.send(.error(Self.refreshErrorMessage(metric: metric, error: error)))
                        }
                    }
                }
            }
        }

        private func notifyAfterSavingNewMetric(_ metric: Metric, isNew: Bool) {
            guard isNew else { return }
            if !StarterMetric.isStarter(metric.id) {
                AnalyticsEvents.metricAdded(type: metric.type)
                notifications.send(.askReview)
            }
            if !AppSettings.hideWidgetInstructions {
                notifications.send(.showWidgetInstructions(metric))
            }
        }

        private func refreshStoredMetric(id: UUID, updater: @escaping StateUpdater<S>) {
            guard let metric = metricStore.metrics[id] else { return }

            updateMetric(metric: metric) { [weak self] refreshed, error in
                guard let self else { return }

                self.metricStore.addMetric(metric: refreshed)

                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if let error {
                    self.notifications.send(.error(Self.refreshErrorMessage(metric: refreshed, error: error)))
                }
            }
        }

        private func updateMetrics(state: VState, callback: @escaping (Metrics) -> Void) {
            var updatedMetrics = [UUID: Metric]()
            let group = DispatchGroup()
            for (_, metric) in state.metrics {
                group.enter()
                var m = metric
                Fetcher.fetch(for: m) { result in
                    switch result {
                    case .result(let value):
                        m.apply(parseResult: value)
                    case .error:
                        m.markRefreshFailed()
                    case .none:
                        break
                    }
                    updatedMetrics[m.id] = m
                    group.leave()
                }
            }
            group.notify(queue: .main) {

                callback(updatedMetrics)
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
