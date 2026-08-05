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
            Self.installStarterMetricIfNeeded(store: metricStore)
            initialState = .init(metrics: metricStore.metrics)
        }

        private static func installStarterMetricIfNeeded(store: MetricStore) {
            guard !AppSettings.hasInstalledStarterMetric else { return }

            if store.metrics.isEmpty {
                store.addMetric(metric: StarterMetric.make())
            }

            AppSettings.hasInstalledStarterMetric = true
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
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
                    if isNew, !AppSettings.hideWidgetInstructions {
                        self.notifications.send(.showWidgetInstructions(metric))
                    }
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
                    if isNew, !AppSettings.hideWidgetInstructions {
                        self.notifications.send(.showWidgetInstructions(metric))
                    }
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

                    updateMetric(metric: metric) {[weak self] metric in
                        guard let self else { return }

                        self.metricStore.addMetric(metric: metric)

                        Task {
                            await updater {
                                $0.metrics = self.metricStore.metrics
                            }
                        }
                    }
                }
            }
        }

        private func refreshStoredMetric(id: UUID, updater: @escaping StateUpdater<S>) {
            guard let metric = metricStore.metrics[id] else { return }

            updateMetric(metric: metric) { [weak self] refreshed in
                guard let self else { return }

                self.metricStore.addMetric(metric: refreshed)

                Task { @MainActor in
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
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
                    case .error, .none:
                        m.resultWithError = true
                    }
                    updatedMetrics[m.id] = m
                    group.leave()
                }
            }
            group.notify(queue: .main) {

                callback(updatedMetrics)
            }
        }

        private func updateMetric(metric: Metric, callback: @escaping (Metric) -> Void) {
            var metric = metric
            Fetcher.fetch(for: metric) { result in
                switch result {
                case .result(let value):
                    metric.apply(parseResult: value)
                case .error, .none:
                    metric.resultWithError = true
                }

                DispatchQueue.main.async {
                    callback(metric)
                }
            }
        }
    }

}

