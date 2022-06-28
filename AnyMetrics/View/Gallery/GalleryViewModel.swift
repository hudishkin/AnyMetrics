//
//  GalleryViewModel.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 21.06.2022.
//

import Foundation
import SwiftUI
import Combine

final class GalleryViewModel: ObservableObject {

    @Published var galleryItems: [GalleryItem] = []

    private var allGallery: [GalleryItem] = []
    private var tokens = Set<AnyCancellable>()

    init() { }

    func load() {
        GalleryService.load()
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .failure(let error):
                    debugPrint(error.localizedDescription)
                case .finished:
                    break
                }
            } receiveValue: { metrics in
                self.allGallery = metrics
                self.galleryItems = metrics
            }
            .store(in: &tokens)
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
