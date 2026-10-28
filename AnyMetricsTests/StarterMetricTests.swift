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

    func testStarterMatchesGalleryPeopleInSpace() {
        let metric = StarterMetric.make()

        XCTAssertEqual(metric.id, UUID(uuidString: "A3B4C5D6-E7F8-4A9B-0C1D-2E3F4A5B6C7D"))
        XCTAssertEqual(metric.type, .json)
        XCTAssertEqual(metric.resultKind, .content)
        XCTAssertEqual(metric.rules?.parseRules, "number")
        XCTAssertEqual(metric.formatter?.format, .currency)
        XCTAssertEqual(metric.formatter?.fraction, 0)
        XCTAssertEqual(metric.request?.url.absoluteString, "http://api.open-notify.org/astros.json")
    }

    func testStarterWidgetUsesSpaceGradient() throws {
        let metric = StarterMetric.make()
        let small = metric.resolvedAppearance.small
        let mediumValue = try XCTUnwrap(metric.resolvedAppearance.medium.elements.first { $0.kind == .value })
        XCTAssertGreaterThanOrEqual(mediumValue.frame.height, 0.52)
        let elements = Dictionary(uniqueKeysWithValues: small.elements.map { ($0.kind, $0) })
        let title = try XCTUnwrap(elements[.title]).frame
        let value = try XCTUnwrap(elements[.value])
        let measure = try XCTUnwrap(elements[.measure]).frame
        let updated = try XCTUnwrap(elements[.updated]).frame

        XCTAssertGreaterThanOrEqual(value.frame.height, 0.50)
        XCTAssertLessThanOrEqual(title.y + title.height, value.frame.y + 0.001)
        XCTAssertLessThanOrEqual(value.frame.y + value.frame.height, measure.y + 0.001)
        XCTAssertLessThanOrEqual(measure.y + measure.height, updated.y + 0.001)

        guard case .gradient(let spec) = small.background.fill else {
            return XCTFail("Starter widget should use a custom gradient")
        }
        XCTAssertEqual(spec.colors, StarterMetric.QuoteStyle.space.colors.map { .hex($0) })
        XCTAssertEqual(spec.mesh, .cosmos)
        XCTAssertEqual(value.color, .hex("#FFFFFF"))
        XCTAssertEqual(StarterMetric.QuoteStyle.allCases.count, 13)
        XCTAssertEqual(
            StarterMetric.appearance(for: .haze).small.elements.first { $0.kind == .value }?.color,
            .hex("#1C1917")
        )
        guard case .gradient(let wave) = StarterMetric.appearance(for: .wave).small.background.fill else {
            return XCTFail("Wave style should be a gradient")
        }
        XCTAssertEqual(wave.mesh, .wave)
        XCTAssertTrue(StarterMetric.QuoteStyle.allCases.contains(.mono))
        guard case .gradient(let mono) = StarterMetric.appearance(for: .mono).small.background.fill else {
            return XCTFail("Monochrome style should be a gradient")
        }
        XCTAssertEqual(mono.colors, StarterMetric.QuoteStyle.mono.colors.map { .hex($0) })
    }

    func testCollectionMetricGetsStableGradient() {
        let id = UUID(uuidString: "B132BE3D-79E0-40BB-BF61-006E8EAB84C4")!
        let metric = Metric(id: id, title: "Fact of the Day", measure: "", type: .json)

        let prepared = StarterMetric.applyingCollectionGradient(to: metric)
        guard case .gradient = prepared.resolvedAppearance.small.background.fill,
              case .gradient = prepared.resolvedAppearance.medium.background.fill else {
            return XCTFail("Gallery metric should use a designed gradient")
        }
        XCTAssertEqual(prepared.widgetDesign, .roundedCard)
        XCTAssertNotEqual(StarterMetric.collectionStyle(for: id), .mono)
        XCTAssertEqual(
            prepared.widgetAppearance,
            StarterMetric.applyingCollectionGradient(to: metric).widgetAppearance
        )
    }

    func testCollectionMetricKeepsAuthoredAppearance() {
        var metric = Metric(id: UUID(), title: "Styled", measure: "", type: .json)
        metric.widgetAppearance = StarterMetric.appearance(for: .mono)

        let prepared = StarterMetric.applyingCollectionGradient(to: metric)
        XCTAssertEqual(prepared.widgetAppearance, metric.widgetAppearance)
    }

    func testPeopleInSpaceFromGalleryUsesSpaceGradient() {
        var metric = StarterMetric.make()
        metric.widgetAppearance = nil
        metric.widgetDesign = nil

        let prepared = StarterMetric.applyingCollectionGradient(to: metric)
        guard case .gradient(let spec) = prepared.resolvedAppearance.small.background.fill else {
            return XCTFail("People in Space should use the space gradient")
        }
        XCTAssertEqual(spec.mesh, .cosmos)
        XCTAssertEqual(spec.colors, StarterMetric.QuoteStyle.space.colors.map { .hex($0) })
    }

    func testQuoteWidgetFitsFourLinesOnBothSizes() throws {
        let metric = StarterMetric.make()
        let small = metric.resolvedAppearance.small
        let mediumValue = try XCTUnwrap(metric.resolvedAppearance.medium.elements.first { $0.kind == .value })
        XCTAssertGreaterThanOrEqual(mediumValue.frame.height, 0.52)
        let elements = Dictionary(uniqueKeysWithValues: small.elements.map { ($0.kind, $0) })
        let title = try XCTUnwrap(elements[.title]).frame
        let value = try XCTUnwrap(elements[.value])
        let measure = try XCTUnwrap(elements[.measure]).frame
        let updated = try XCTUnwrap(elements[.updated]).frame

        XCTAssertGreaterThanOrEqual(value.frame.height, 0.50)
        XCTAssertLessThanOrEqual(title.y + title.height, value.frame.y + 0.001)
        XCTAssertLessThanOrEqual(value.frame.y + value.frame.height, measure.y + 0.001)
        XCTAssertLessThanOrEqual(measure.y + measure.height, updated.y + 0.001)

        guard case .gradient(let spec) = small.background.fill else {
            return XCTFail("Quote widget should use a custom gradient")
        }
        XCTAssertEqual(spec.colors.count, 3)
        XCTAssertEqual(value.color, .hex("#FFFFFF"))
        XCTAssertEqual(StarterMetric.QuoteStyle.allCases.count, 13)
        XCTAssertTrue(StarterMetric.QuoteStyle.allCases.contains(.mono))
        guard case .gradient(let mono) = StarterMetric.appearance(for: .mono).small.background.fill else {
            return XCTFail("Monochrome style should be a gradient")
        }
        XCTAssertEqual(mono.colors, StarterMetric.QuoteStyle.mono.colors.map { .hex($0) })
    }

    func testOpeningAppDoesNotInstallMetricBeforeOnboardingChoice() {
        let interactor = MainView.Interactor(di: DI(metricStore: store))

        XCTAssertTrue(store.metrics.isEmpty)
        XCTAssertTrue(interactor.initialState.metrics.isEmpty)
    }

    func testExistingLibrarySkipsOnboardingWithoutAddingStarter() {
        let previous = AppSettings.hasCompletedOnboarding
        AppSettings.hasCompletedOnboarding = false
        defer { AppSettings.hasCompletedOnboarding = previous }

        let user = Metric(id: UUID(), title: "My service", measure: "Status", type: .checkStatus)
        store.addMetric(metric: user)

        _ = MainView.Interactor(di: DI(metricStore: store))

        XCTAssertTrue(AppSettings.hasCompletedOnboarding)
        XCTAssertEqual(store.metrics.count, 1)
        XCTAssertNil(store.metrics[StarterMetric.id])
    }

    func testEmptyLibraryKeepsOnboardingAvailable() {
        let previous = AppSettings.hasCompletedOnboarding
        AppSettings.hasCompletedOnboarding = false
        defer { AppSettings.hasCompletedOnboarding = previous }

        _ = MainView.Interactor(di: DI(metricStore: store))

        XCTAssertFalse(AppSettings.hasCompletedOnboarding)
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
        let quote = Metric(id: StarterMetric.quoteOfTheDayID, title: "Quote of the Day", measure: "ZenQuotes", type: .json)
        store.addMetric(metric: legacy)
        store.addMetric(metric: picture)
        store.addMetric(metric: quote)
        StarterMetric.installIfNeeded(in: store)

        XCTAssertFalse(ReviewHandler.hasUserAddedMetrics(store.metrics))
    }
}
