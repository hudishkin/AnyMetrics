import VVSI
import AnyMetricsShared
import Foundation

extension RequestFormView {

    struct VState: StateProtocol {

        enum RequestStatus {
            case none, loading, success, error
        }

        var requestUrl: String = "http://jsonplaceholder.typicode.com/posts"
        var httpMethodType: HTTPMethodType = .GET
        var typeMetric: TypeMetric = .json
        var httpHeaders: [String: String] = [:]
        var requestBody: String = ""
        var timeout: Double = DEFAULT_TIMEOUT
        var refreshInterval: RefreshInterval = .bySystem
        var requestStatus: RequestStatus = .none
        var response: String = ""
        var errorMessage: String = ""
        var hasRequestError: Bool = false
        var canSetupResponse: Bool = false

        var canMakeRequest: Bool {
            requestUrl.isValidURL
        }
    }

    enum VAction: ActionProtocol {
        case setRequestUrl(String)
        case setHTTPMethodType(HTTPMethodType)
        case setTypeMetric(TypeMetric)
        case setRequestBody(String)
        case setRefreshInterval(RefreshInterval)
        case addHeader(name: String, value: String)
        case removeHeader(name: String)
        case editHeader(oldName: String, newName: String, newValue: String)
        case makeRequest
    }

    enum VNotification: NotificationProtocol {
        case requestCompleted
        case error(String)
    }
}
