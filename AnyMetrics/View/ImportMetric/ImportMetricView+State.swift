import Foundation
import VVSI
import AnyMetricsShared

extension ImportMetricView {

    enum ValidationState: Equatable {
        case idle
        case valid(Metric)
        case invalid(String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }

        var metric: Metric? {
            if case .valid(let metric) = self { return metric }
            return nil
        }
    }

    struct VState: StateProtocol {
        var jsonText: String = ""
        var validation: ValidationState = .idle
        var duplicateIdFound: Bool = false
    }

    enum VAction: ActionProtocol {
        case onAppear
        case setJsonText(String)
        case importMetric
    }

    enum VNotification: NotificationProtocol {
        case showError(String)
        case imported
    }

}
