import Foundation
import AnyMetricsShared

enum ErrorMessageFormatter {
    static func message(for error: Error) -> String {
        if let fetcherError = error as? FetcherError {
            return message(for: fetcherError)
        }

        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        return AnyMetricsStrings.Error.unknown(error.localizedDescription)
    }

    static func message(for fetcherError: FetcherError) -> String {
        switch fetcherError {
        case .httpError(let statusCode):
            return AnyMetricsStrings.Error.httpStatus(statusCode)
        case .invalidData:
            return AnyMetricsStrings.Error.invalidResponse
        case .parseFailed:
            return AnyMetricsStrings.Error.parseFailedGeneric
        }
    }

    private static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .timedOut:
            return AnyMetricsStrings.Error.timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return AnyMetricsStrings.Error.noConnection
        case .badURL, .unsupportedURL:
            return AnyMetricsStrings.Error.invalidUrl
        case .cannotFindHost, .dnsLookupFailed:
            return AnyMetricsStrings.Error.hostNotFound
        case .secureConnectionFailed, .serverCertificateUntrusted, .clientCertificateRejected:
            return AnyMetricsStrings.Error.ssl
        default:
            return AnyMetricsStrings.Error.unknown(urlError.localizedDescription)
        }
    }

    static func parseRuleMessage(for rule: String) -> String {
        AnyMetricsStrings.Error.parseFailed(rule)
    }
}
