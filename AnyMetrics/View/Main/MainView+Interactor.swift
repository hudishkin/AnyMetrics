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
            
            initialState = .init(metrics: metricStore.metrics)
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .onAppear, .refreshAllMetrics, .syncMetrics:
                Task {
                    guard let state = await state() else { return }

                    updateMetrics(state: state) {[weak self] metrics in
                        self?.metricStore.metrics = metrics

                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            case .addMetric(let metric):
                Task { @MainActor in
                    metricStore.addMetric(metric: metric)
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                }

            case .removeMetric(let id):
                Task { @MainActor in
                    metricStore.removeMetric(id: id)
                    await updater {
                        $0.metrics = self.metricStore.metrics
                    }
                }
            case .refreshMetric(let id):
                Task { @MainActor in
                    guard let state = await state(), let metric = state.metrics[id] else { return }

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

        private func updateMetrics(state: VState, callback: @escaping (Metrics) -> Void) {
            var updatedMetrics = [UUID: Metric]()
            let group = DispatchGroup()
            for (_, metric) in state.metrics {
                group.enter()
                var m = metric
                Fetcher.fetch(for: m) { result in
                    switch result {
                    case .result(let value):
                        switch value {
                        case .value(let valueString):
                            m.result = valueString
                            m.resultWithError = false
                        case .status(let success):
                            m.result = ""
                            m.resultWithError = !success
                        }
                    case .error, .none:
                        m.resultWithError = true
                    }
                    m.updated = Date()
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
                    switch value {
                    case .value(let valueString):
                        metric.result = valueString
                        metric.resultWithError = false
                    case .status(let success):
                        metric.result = ""
                        metric.resultWithError = !success
                    }
                case .error, .none:
                    metric.resultWithError = true
                }

                metric.updated = Date()
                DispatchQueue.main.async {
                    callback(metric)
                }
            }
        }
    }

}

