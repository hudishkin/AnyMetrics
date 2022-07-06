//
//  ImportMetricParser.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 15.06.2022.
//

import Foundation

// TODO: - Пока не используется

protocol ImportMetricParser {
    func parse(data: Data) throws -> MetricItemImportData
}

struct JsonMetricParser: ImportMetricParser {

    func parse(data: Data) throws -> MetricItemImportData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        let result = try decoder.decode(MetricItemImportData.self, from: data)
        return result
    }
}
