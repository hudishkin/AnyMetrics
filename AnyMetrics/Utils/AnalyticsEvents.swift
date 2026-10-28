import FirebaseAnalytics
import Foundation
import SwiftUI
import AnyMetricsShared

enum AnalyticsEvents {

    enum Source {
        static let gallery = "gallery"
        static let custom = "custom"
        static let imported = "import"
        static let onboarding = "onboarding"
    }

    enum FormStep {
        static let request = "request"
        static let value = "value"
        static let display = "display"
    }

    enum GalleryEntry {
        static let main = "main"
        static let onboarding = "onboarding"
    }

    enum ReviewSource {
        static let prompt = "prompt"
        static let about = "about"
    }

    static func onboardingShown() {
        log("onboarding_shown")
    }

    static func onboardingSkipped() {
        log("onboarding_skipped")
    }

    static func galleryOpened(entry: String) {
        log("gallery_opened", parameters: ["entry": entry])
    }

    static func metricAdded(
        source: String,
        type: TypeMetric,
        resultKind: MetricResultKind,
        galleryId: String? = nil,
        galleryGroup: String? = nil
    ) {
        var parameters: [String: Any] = [
            "source": source,
            "type": type.rawValue,
            "result_kind": resultKind.rawValue
        ]
        if let galleryId {
            parameters["gallery_id"] = clipped(galleryId)
        }
        if let galleryGroup, !galleryGroup.isEmpty {
            parameters["gallery_group"] = clipped(galleryGroup)
        }
        log("metric_added", parameters: parameters)
    }

    static func metricFormStarted() {
        log("metric_form_started")
    }

    static func metricFormStep(_ step: String) {
        log("metric_form_step", parameters: ["step": step])
    }

    static func metricFormSaved() {
        log("metric_form_saved")
    }

    static func metricFormAbandoned(step: String) {
        log("metric_form_abandoned", parameters: ["step": step])
    }

    static func metricRequestTested(success: Bool, error: Error? = nil) {
        var parameters: [String: Any] = ["success": flag(success)]
        if let error {
            parameters["error_kind"] = errorKind(for: error)
        }
        log("metric_request_tested", parameters: parameters)
    }

    static func widgetGuideShown() {
        log("widget_guide_shown")
    }

    static func widgetGuideDismissed(dontShowAgain: Bool) {
        log("widget_guide_dismissed", parameters: ["dont_show_again": flag(dontShowAgain)])
    }

    static func appLinkCopied() {
        log("app_link_copied")
    }

    static func metricShared(includeRequest: Bool, includesFile: Bool, activity: String?) {
        var parameters: [String: Any] = [
            "include_request": flag(includeRequest),
            "includes_file": flag(includesFile)
        ]
        if let activity, !activity.isEmpty {
            parameters["activity"] = clipped(activity)
        }
        log("metric_shared", parameters: parameters)
    }

    static func metricShareCancelled() {
        log("metric_share_cancelled")
    }

    static func metricEdited(type: TypeMetric, resultKind: MetricResultKind) {
        log("metric_edited", parameters: [
            "type": type.rawValue,
            "result_kind": resultKind.rawValue
        ])
    }

    static func metricDeleted(isStarter: Bool) {
        log("metric_deleted", parameters: ["is_starter": flag(isStarter)])
    }

    static func metricRefreshed(success: Bool, error: Error? = nil) {
        var parameters: [String: Any] = ["success": flag(success)]
        if let error {
            parameters["error_kind"] = errorKind(for: error)
        }
        log("metric_refreshed", parameters: parameters)
    }

    static func libraryRefreshed(librarySize: Int, failedCount: Int) {
        log("library_refreshed", parameters: [
            "library_size": librarySize,
            "failed_count": failedCount
        ])
    }

    static func syncLibrary(_ metrics: Metrics) {
        guard !isPreview else { return }
        let customCount = metrics.values.filter { !StarterMetric.isStarter($0.id) }.count
        Analytics.setUserProperty(String(metrics.count), forName: "metrics_count")
        Analytics.setUserProperty(String(customCount), forName: "custom_metrics_count")
        Analytics.setUserProperty(flag(AppSettings.hasCompletedOnboarding), forName: "onboarding_done")
    }

    static func reviewShown(trigger: ReviewHandler.Trigger, librarySize: Int) {
        log("review_shown", parameters: [
            "trigger": trigger.analyticsValue,
            "library_size": librarySize
        ])
    }

    static func reviewLater() {
        log("review_later")
    }

    static func reviewCompleted(source: String) {
        log("review_completed", parameters: ["source": source])
    }

    static func reviewDeclined() {
        log("review_declined")
    }

    private static func log(_ name: String, parameters: [String: Any]? = nil) {
        guard !isPreview else { return }
        Analytics.logEvent(name, parameters: parameters)
    }

    private static func flag(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private static func clipped(_ value: String) -> String {
        String(value.prefix(100))
    }

    private static func errorKind(for error: Error) -> String {
        if let fetcherError = error as? FetcherError {
            switch fetcherError {
            case .httpError:
                return "http"
            case .invalidData, .parseFailed:
                return "parse"
            }
        }
        if error is URLError {
            return "network"
        }
        return "unknown"
    }
}

/// Tracks one pass through the new-metric form. Edit flows use `inactive`.
final class MetricFormSession {
    static let inactive = MetricFormSession(tracksFunnel: false)

    private let tracksFunnel: Bool
    private var started = false
    private var finished = false
    private var reached: Set<String> = []
    private var furthest = AnalyticsEvents.FormStep.request

    init(tracksFunnel: Bool) {
        self.tracksFunnel = tracksFunnel
    }

    func begin() {
        guard tracksFunnel else { return }
        started = true
        finished = false
        furthest = AnalyticsEvents.FormStep.request
        reached = [AnalyticsEvents.FormStep.request]
        AnalyticsEvents.metricFormStarted()
        AnalyticsEvents.metricFormStep(AnalyticsEvents.FormStep.request)
    }

    func advance(to step: String) {
        guard tracksFunnel, started, !finished else { return }
        if rank(of: step) > rank(of: furthest) {
            furthest = step
        }
        guard reached.insert(step).inserted else { return }
        AnalyticsEvents.metricFormStep(step)
    }

    func markSaved() {
        guard tracksFunnel, started, !finished else { return }
        finished = true
        AnalyticsEvents.metricFormSaved()
    }

    func abandonIfNeeded() {
        guard tracksFunnel, started, !finished else { return }
        finished = true
        AnalyticsEvents.metricFormAbandoned(step: furthest)
    }

    private func rank(of step: String) -> Int {
        switch step {
        case AnalyticsEvents.FormStep.value:
            return 1
        case AnalyticsEvents.FormStep.display:
            return 2
        default:
            return 0
        }
    }
}

private struct MetricFormSessionKey: EnvironmentKey {
    static let defaultValue = MetricFormSession.inactive
}

extension EnvironmentValues {
    var metricFormSession: MetricFormSession {
        get { self[MetricFormSessionKey.self] }
        set { self[MetricFormSessionKey.self] = newValue }
    }
}
