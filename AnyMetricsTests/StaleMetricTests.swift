import XCTest
import AnyMetricsShared

final class StaleMetricTests: XCTestCase {

    func testLockScreenUsesAsteriskInsteadOfTheWord() {
        var metric = sample(result: "12000", refreshFailed: true, updated: Date().addingTimeInterval(-3600))

        XCTAssertTrue(MetricDisplayHelpers.showsStaleValue(for: metric))
        XCTAssertEqual(
            MetricDisplayHelpers.lockScreenValue(metric.result, isStale: true),
            "12000*"
        )
        XCTAssertEqual(MetricDisplayHelpers.lockScreenValue("12000", isStale: false), "12000")
        XCTAssertEqual(MetricDisplayHelpers.lockScreenValue("", isStale: true), "*")

        metric.refreshFailed = false
        XCTAssertFalse(MetricDisplayHelpers.showsStaleValue(for: metric))
    }

    func testEmptyFailedRefreshIsAnErrorNotAStaleValue() {
        let metric = sample(result: "", refreshFailed: true, updated: Date().addingTimeInterval(-60))
        XCTAssertFalse(MetricDisplayHelpers.showsStaleValue(for: metric))
        XCTAssertTrue(MetricDisplayHelpers.showsStaleUpdate(for: metric))
    }

    func testStatusKeepsLastVerdictAndIsMarkedStale() {
        let metric = Metric(
            id: UUID(),
            title: "API",
            measure: "",
            type: .checkStatus,
            result: "",
            resultWithError: false,
            refreshFailed: true,
            updated: Date().addingTimeInterval(-120)
        )
        XCTAssertTrue(MetricDisplayHelpers.showsStaleValue(for: metric))
        XCTAssertEqual(
            MetricDisplayHelpers.valueString(for: metric, goodLabel: "Good", badLabel: "Bad"),
            "Good"
        )
    }

    func testFreshSuccessIsShownWithoutAnotherFetch() {
        let interval = 900
        let fresh = sample(
            result: "10",
            refreshFailed: false,
            updated: Date().addingTimeInterval(-30),
            interval: interval
        )
        XCTAssertTrue(fresh.isReadyForWidgetDisplay())

        let stillFresh = sample(
            result: "10",
            refreshFailed: false,
            updated: Date().addingTimeInterval(-240),
            interval: interval
        )
        XCTAssertTrue(stillFresh.isReadyForWidgetDisplay())

        let due = sample(
            result: "10",
            refreshFailed: false,
            updated: Date().addingTimeInterval(-TimeInterval(interval)),
            interval: interval
        )
        XCTAssertFalse(due.isReadyForWidgetDisplay())

        let failed = sample(
            result: "10",
            refreshFailed: true,
            updated: Date().addingTimeInterval(-5),
            interval: interval
        )
        XCTAssertFalse(failed.isReadyForWidgetDisplay())
    }

    func testSlowerFailureDoesNotReplaceANewerSuccess() {
        let id = UUID()
        let success = sample(
            id: id,
            result: "42",
            refreshFailed: false,
            updated: Date()
        )
        let failure = sample(
            id: id,
            result: "41",
            refreshFailed: true,
            updated: Date().addingTimeInterval(-20)
        )

        XCTAssertTrue(MetricStore.shouldKeepStored(success, insteadOf: failure))
        XCTAssertFalse(MetricStore.shouldKeepStored(failure, insteadOf: success))
    }

    func testSaveRefreshKeepsTheNewerValue() {
        let suiteName = "AnyMetrics.StaleMetricTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = MetricStore(defaults: defaults, key: "metrics")

        let id = UUID()
        let success = sample(id: id, result: "42", refreshFailed: false, updated: Date())
        store.addMetric(metric: success)

        let failure = sample(
            id: id,
            result: "41",
            refreshFailed: true,
            updated: success.updated!.addingTimeInterval(-20)
        )
        let saved = store.saveRefresh(failure)

        XCTAssertEqual(saved.result, "42")
        XCTAssertFalse(saved.refreshFailed)
        XCTAssertEqual(store.metrics[id]?.result, "42")
    }

    private func sample(
        id: UUID = UUID(),
        result: String,
        refreshFailed: Bool,
        updated: Date?,
        interval: Int? = 900
    ) -> Metric {
        Metric(
            id: id,
            title: "Load",
            measure: "ms",
            type: .json,
            result: result,
            refreshFailed: refreshFailed,
            updated: updated,
            interval: interval
        )
    }
}
