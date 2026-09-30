import FirebaseAnalytics
import Foundation
import AnyMetricsShared

enum AnalyticsEvents {

    static func onboardingCompleted() {
        log("onboarding_completed")
    }

    static func metricAdded(type: TypeMetric) {
        log("metric_added", parameters: ["type": type.rawValue])
    }

    static func metricShared(mode: String) {
        log("metric_shared", parameters: ["mode": mode])
    }

    static func reviewShown(trigger: ReviewHandler.Trigger) {
        log("review_shown", parameters: ["trigger": trigger.analyticsValue])
    }

    static func reviewLater() {
        log("review_later")
    }

    static func reviewCompleted() {
        log("review_completed")
    }

    static func reviewDeclined() {
        log("review_declined")
    }

    private static func log(_ name: String, parameters: [String: Any]? = nil) {
        guard !isPreview else { return }
        Analytics.logEvent(name, parameters: parameters)
    }
}
