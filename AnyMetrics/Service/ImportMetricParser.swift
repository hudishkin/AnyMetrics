import Foundation

protocol ImportMetricParser {
    func parse(data: Data) throws -> MetricItemImportData
}

struct JsonMetricParser: ImportMetricParser {

    func parse(data: Data) throws -> MetricItemImportData {
        var lastError: Error?

        for decoder in Self.decoders {
            do {
                return try decoder.decode(MetricItemImportData.self, from: data)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? MetricItemImportDataError.invalidVersion
    }

    private static var decoders: [JSONDecoder] {
        let iso8601 = JSONDecoder()
        iso8601.dateDecodingStrategy = .iso8601

        let formatted = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatted.dateDecodingStrategy = .formatted(dateFormatter)

        let deferred = JSONDecoder()
        deferred.dateDecodingStrategy = .deferredToDate

        return [iso8601, formatted, deferred]
    }
}
