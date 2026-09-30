import XCTest
import AnyMetricsShared
@testable import AnyMetrics

final class StarterMetricTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: MetricStore!

    override func setUpWithError() throws {
        suiteName = "AnyMetrics.StarterMetricTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = MetricStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testStarterMatchesGalleryQuoteOfTheDay() {
        let metric = StarterMetric.make()

        XCTAssertEqual(metric.id, UUID(uuidString: "B9E3E57C-A3AA-46D9-8537-0E5C22C07E3A"))
        XCTAssertEqual(metric.type, .json)
        XCTAssertEqual(metric.resultKind, .content)
        XCTAssertEqual(metric.rules?.parseRules, "0.q")
        XCTAssertEqual(metric.request?.url.absoluteString, "https://zenquotes.io/api/today")
    }

    func testOpeningAppDoesNotInstallMetricBeforeOnboardingChoice() {
        let interactor = MainView.Interactor(di: DI(metricStore: store))

        XCTAssertTrue(store.metrics.isEmpty)
        XCTAssertTrue(interactor.initialState.metrics.isEmpty)
    }

    func testRepeatingOnboardingPreservesEditedPreset() throws {
        var edited = StarterMetric.installIfNeeded(in: store)
        edited.title = "My quote"
        edited.interval = 7200
        store.addMetric(metric: edited)

        var incoming = StarterMetric.make()
        incoming.apply(parseResult: .value("Hello"))
        let existing = StarterMetric.installIfNeeded(incoming, in: store)
        let saved = try XCTUnwrap(store.metrics[StarterMetric.id])

        XCTAssertEqual(store.metrics.count, 1)
        XCTAssertEqual(existing.title, "My quote")
        XCTAssertEqual(saved.interval, 7200)
        XCTAssertFalse(saved.refreshFailed)
    }

    func testAddingQuotePreservesLegacyAndUserMetrics() {
        let legacy = Metric(id: StarterMetric.legacyID, title: "GitHub stars", measure: "Stars", type: .json)
        let user = Metric(id: UUID(), title: "My service", measure: "Status", type: .checkStatus)
        store.metrics = [legacy.id: legacy, user.id: user]

        StarterMetric.installIfNeeded(in: store)

        XCTAssertEqual(store.metrics.count, 3)
        XCTAssertEqual(store.metrics[legacy.id]?.title, legacy.title)
        XCTAssertEqual(store.metrics[user.id]?.title, user.title)
        XCTAssertEqual(store.metrics[StarterMetric.id]?.resultKind, .content)
        XCTAssertTrue(ReviewHandler.hasUserAddedMetrics(store.metrics))
    }

    func testStarterPresetsDoNotCountAsUserMetricsForReviewPrompts() {
        let legacy = Metric(id: StarterMetric.legacyID, title: "GitHub stars", measure: "Stars", type: .json)
        let picture = Metric(id: StarterMetric.pictureOfTheDayID, title: "Picture of the Day", measure: "Bing", type: .web)
        store.addMetric(metric: legacy)
        store.addMetric(metric: picture)
        StarterMetric.installIfNeeded(in: store)

        XCTAssertFalse(ReviewHandler.hasUserAddedMetrics(store.metrics))
    }
}
