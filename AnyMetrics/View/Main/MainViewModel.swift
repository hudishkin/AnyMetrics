//
//  MainViewModel.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import WidgetKit
import Combine

final class MainViewModel: MetricStore, ObservableObject {

    enum ActiveSheet {
        case addMetrics, info
    }

    public var activeSheet: ActiveSheet?
    private var tokens = Set<AnyCancellable>()

    func updateMetrics() {
        var updatedMetrics = [UUID: Metric]()
        let group = DispatchGroup()
        for (_, metric) in metrics {
            group.enter()
            var m = metric
            Fetcher.fetch(for: m) { result in
                switch result {
                case .result(let value):
                    switch value {
                    case .value(let valueString):
                        m.value = valueString
                    case .check(let success):
                        m.value = ""
                        m.hasError = !success
                    }
                case .error, .none:
                    m.hasError = true
                }
                m.updated = Date()
                updatedMetrics[m.id] = m
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.metrics = updatedMetrics
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func updateMetric(id: UUID) {
        guard var metric = metrics[id] else { return }
        Fetcher.fetch(for: metric) { result in
            switch result {
            case .result(let value):
                switch value {
                case .value(let valueString):
                    metric.value = valueString
                case .check(let success):
                    metric.value = ""
                    metric.hasError = !success
                }
            case .error, .none:
                metric.hasError = true
            }

            metric.updated = Date()
            DispatchQueue.main.async {
                self.addMetric(metric: metric)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

}

