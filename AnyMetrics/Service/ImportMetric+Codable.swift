import Foundation
import AnyMetricsShared

enum MetricItemImportDataError: Error {
    case invalidVersion
}

extension MetricItemImportData: Codable {

    enum CodingKeys: String, CodingKey {
        case version, author, created, includes, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: CodingKeys.version)
        guard Self.supportedVersions.contains(version) else {
            throw MetricItemImportDataError.invalidVersion
        }
        author = try? container.decodeIfPresent(String.self, forKey: CodingKeys.author)
        created = try? container.decodeIfPresent(Date.self, forKey: CodingKeys.created)
        includes = try? container.decodeIfPresent(MetricExportIncludes.self, forKey: CodingKeys.includes)
        payload = try container.decode(Metric.self, forKey: CodingKeys.payload)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(created, forKey: .created)
        try container.encodeIfPresent(includes, forKey: .includes)
        try container.encode(payload, forKey: .payload)
    }

}
