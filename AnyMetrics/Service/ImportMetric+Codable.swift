//
//  ImportMetric.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 15.06.2022.
//

import Foundation

enum MetricItemImportDataError: Error {
    case invalidVersion
}

extension MetricItemImportData: Codable {

    enum CodingKeys: String, CodingKey {
        case version, author, created, payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: CodingKeys.version)
        if Self.VERSION_JSON != version {
            throw MetricItemImportDataError.invalidVersion
        }
        author = try? container.decodeIfPresent(String.self, forKey: CodingKeys.author)
        created = try? container.decodeIfPresent(Date.self, forKey: CodingKeys.created)
        payload = try container.decode(Metric.self, forKey: CodingKeys.payload)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(created, forKey: .created)
        try container.encode(payload, forKey: .payload)
    }

}
