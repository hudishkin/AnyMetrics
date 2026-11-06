import XCTest
import AnyMetricsShared
@testable import AnyMetrics

final class MetricBasisCatalogTests: XCTestCase {

    func testEmptyQueryKeepsBothSections() {
        let catalog = sampleCatalog()
        let listed = catalog.filtered(query: "  ")

        XCTAssertEqual(listed.own.map(\.title), ["Bitcoin", "Weather"])
        XCTAssertEqual(listed.gallery.map { $0.metric.title }, ["Stars"])
    }

    func testSearchMatchesTitleAndRequestURL() {
        let catalog = sampleCatalog()

        XCTAssertEqual(catalog.filtered(query: "bit").own.map(\.title), ["Bitcoin"])
        XCTAssertEqual(catalog.filtered(query: "weather.test").own.map(\.title), ["Weather"])
    }

    func testSearchMatchesGalleryGroup() {
        let catalog = sampleCatalog()
        let listed = catalog.filtered(query: "dev")

        XCTAssertTrue(listed.own.isEmpty)
        XCTAssertEqual(listed.gallery.map(\.group), ["Dev"])
        XCTAssertEqual(listed.gallery.map { $0.metric.title }, ["Stars"])
    }

    private func sampleCatalog() -> MetricBasisCatalog {
        MetricBasisCatalog(
            own: [
                metric(title: "Bitcoin", measure: "USD", url: "https://example.com/btc"),
                metric(title: "Weather", measure: "°C", url: "https://weather.test/now")
            ],
            gallery: [
                GalleryItem(
                    name: "Dev",
                    tags: "github",
                    metrics: [metric(title: "Stars", measure: "count", url: "https://api.github.com")]
                )
            ]
        )
    }

    private func metric(title: String, measure: String, url: String) -> Metric {
        Metric(
            id: UUID(),
            title: title,
            measure: measure,
            type: .json,
            request: RequestData(headers: [:], method: "GET", url: URL(string: url)!)
        )
    }
}
