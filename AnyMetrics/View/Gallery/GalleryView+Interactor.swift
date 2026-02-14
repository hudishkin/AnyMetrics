//
//  GalleryViewModel.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 21.06.2022.
//

import Foundation
import Combine
import AnyMetricsShared
import VVSI

extension GalleryView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {
        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        var initialState: VState = .init()

        private var allGallery: [GalleryItem] = []
        private var tokens = Set<AnyCancellable>()

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .onAppear:
                load(updater: updater)
            case .search(let text):
                search(text: text, updater: updater)
            }
        }

        private func load(updater: @escaping StateUpdater<S>) {
            Task { @MainActor in
                await updater { $0.showLoading = true }
            }

            GalleryService.load()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] result in
                    Task { @MainActor in
                        await updater { $0.showLoading = false }
                    }

                    if case .failure(let error) = result {
                        debugPrint(error.localizedDescription)
                        self?.notifications.send(.error(error.localizedDescription))
                    }
                } receiveValue: { [weak self] metrics in
                    self?.allGallery = metrics
                    Task { @MainActor in
                        await updater {
                            $0.galleryItems = metrics
                            $0.showSendRequestMetric = metrics.isEmpty
                        }
                    }
                }
                .store(in: &tokens)
        }

        private func search(text: String, updater: @escaping StateUpdater<S>) {
            guard !text.isEmpty else {
                Task { @MainActor in
                    await updater {
                        $0.showSendRequestMetric = false
                        $0.galleryItems = self.allGallery
                    }
                }
                return
            }

            let source = allGallery
            DispatchQueue.global(qos: .utility).async {
                var result: [GalleryItem] = []
                let searchText = text.lowercased()
                for value in source {
                    if value.name.lowercased().contains(searchText) || value.tags.lowercased().contains(searchText) {
                        result.append(value)
                    } else {
                        let metrics = value.metrics.filter { $0.title.lowercased().contains(searchText) }
                        if !metrics.isEmpty {
                            result.append(GalleryItem(name: value.name, tags: value.tags, metrics: metrics))
                        }
                    }
                }

                Task { @MainActor in
                    await updater {
                        $0.showSendRequestMetric = result.isEmpty
                        $0.galleryItems = result
                    }
                }
            }
        }
    }
}
