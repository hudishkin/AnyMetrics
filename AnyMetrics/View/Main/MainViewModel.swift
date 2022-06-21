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

    @Published var galleryItems: [GalleryItem] = []

    private var allGallery: [GalleryItem] = []
    private var tokens = Set<AnyCancellable>()

    func updateMetrics() {
        var updatedMetrics = [String:Metric]()
        let group = DispatchGroup()
        for (_, metric) in metrics {
            group.enter()
            var m = metric
            Fetcher.fetch(for: m) { result in
                switch result {
                case .result(let value):
                    switch value {
                    case .value(let valueString):
                        m.lastValue = valueString
                    case .check(let success):
                        m.lastValue = ""
                        m.hasError = !success
                    }
                case .error, .none:
                    m.hasError = true
                }
                m.updated = Date()
                updatedMetrics[m.id.uuidString] = m
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.metrics = updatedMetrics
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func updateMetric(id: UUID) {
        guard var metric = metrics[id.uuidString] else { return }
        Fetcher.fetch(for: metric) { result in
            switch result {
            case .result(let value):
                switch value {
                case .value(let valueString):
                    metric.lastValue = valueString
                case .check(let success):
                    metric.lastValue = ""
                    metric.hasError = !success
                }
            case .error, .none:
                metric.hasError = true
            }

            metric.updated = Date()
            DispatchQueue.main.async {
                self.metrics[id.uuidString] = metric

            }
        }
    }


    func addMetric(metric: Metric) {
        metrics[metric.id.uuidString] = metric
        updateMetric(id: metric.id)
    }

    func addMetrics(metrics: [Metric]) {
        for m in metrics {
            self.metrics[m.id.uuidString] = m
        }
    }

    func removeMetric(id: UUID) {
        self.metrics[id.uuidString] = nil
    }

    func removeAll() -> Self {
        self.metrics = [:]
        return self
    }

    func load() {
        GalleryService.load()
            .receive(on: DispatchQueue.main)
            .sink { _ in  } receiveValue: { metrics in
                self.allGallery = metrics
                self.galleryItems = metrics
            }.store(in: &tokens)
    }

    func search(text: String) {
        guard !text.isEmpty else {
            self.galleryItems = allGallery
            return
        }

        DispatchQueue.global(qos: .utility).async {
            var result: [GalleryItem] = []
            let searchText = text.lowercased()
            for value in self.allGallery {
                if value.name.lowercased().contains(searchText) || value.tags.lowercased().contains(searchText) {
                    result.append(value)
                }else {
                    var metrics: [Metric] = []
                    for metric in value.metrics {
                        if metric.title.lowercased().contains(searchText) {
                            metrics.append(metric)
                        }
                    }
                    if !metrics.isEmpty {
                        result.append(GalleryItem(name: value.name, tags: value.tags, metrics: metrics))
                    }

                }
            }
            DispatchQueue.main.async {
                self.galleryItems = result
            }
        }


    }
}

