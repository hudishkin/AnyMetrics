//
//  GalleryService.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation
import Combine
import AnyMetricsShared

struct GalleryItem: Hashable, Codable {
    var name: String
    var tags: String
    var metrics: [Metric]
}

typealias MetricGallery = [GalleryItem]

enum GalleryService {

    static func load() -> AnyPublisher<MetricGallery, Error> {
        URLSession.shared.dataTaskPublisher(for: AppConfig.Urls.gallery)
            .tryMap {
                if let httpResponse = $0.response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 { throw FetcherError.error }
                }
                return $0.data
            }
            .decode(type: MetricGallery.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
