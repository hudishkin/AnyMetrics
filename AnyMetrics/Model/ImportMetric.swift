import Foundation
import AnyMetricsShared

struct MetricItemImportData {

    static let VERSION_JSON = "0.1"

    let version: String
    var author: String?
    var created: Date?
    var payload: Metric?

    private init() {
        self.version = Self.VERSION_JSON
    }

    private init(author: String, created: Date = Date(), payload: Metric) {
        self.version = Self.VERSION_JSON
        self.author = author
        self.created = created
        self.payload = payload
    }

    /// Заголовки, которые содержат чувствительные данные и должны быть удалены при экспорте
    private static let sensitiveHeaderPatterns: [String] = [
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
        "x-auth-token",
        "x-auth-key",
        "x-csrf-token",
        "x-csrftoken",
        "x-access-token",
        "x-apitoken",
        "x-password",
        "x-pswd",
        "auth-key",
        "auth-password",
        "access-token",
        "token",
        "secretkey",
        "api-key",
        "bearer",
    ]

    static func exportData(for metric: Metric) -> MetricItemImportData {
        var sanitized = metric

        // Очищаем result
        sanitized.result = ""
        sanitized.resultWithError = false

        // Фильтруем чувствительные заголовки
        if let request = sanitized.request {
            let filteredHeaders = request.headers.filter { key, _ in
                let lowered = key.lowercased()
                return !sensitiveHeaderPatterns.contains(where: { lowered == $0 || lowered.contains($0) })
            }
            sanitized.request = RequestData(
                headers: filteredHeaders,
                method: request.method,
                url: request.url,
                timeout: request.timeout
            )
        }

        var data = MetricItemImportData()
        data.author = metric.author
        data.created = Date()
        data.payload = sanitized
        return data
    }
}
