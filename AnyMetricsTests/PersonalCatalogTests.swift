import XCTest
import AnyMetricsShared
@testable import AnyMetrics

final class PersonalCatalogTests: XCTestCase {

    func testAdoptsDashboardMetricsThatAreNotInTheGallery() {
        let galleryID = UUID()
        let customID = UUID()
        let adopted = PersonalCatalog.metricsToAdopt(
            dashboard: [
                galleryID: metric(id: galleryID, title: "From gallery"),
                customID: metric(id: customID, title: "Mine")
            ],
            personal: [:],
            galleryIDs: [galleryID]
        )

        XCTAssertEqual(adopted.map(\.id), [customID])
    }

    func testSkipsAdoptionWhenPersonalAlreadyHasMetrics() {
        let customID = UUID()
        let adopted = PersonalCatalog.metricsToAdopt(
            dashboard: [customID: metric(id: customID, title: "Mine")],
            personal: [UUID(): metric(title: "Already saved")],
            galleryIDs: []
        )

        XCTAssertTrue(adopted.isEmpty)
    }

    func testSkipsAdoptionWhenDashboardHasOnlyGalleryMetrics() {
        let galleryID = UUID()
        let adopted = PersonalCatalog.metricsToAdopt(
            dashboard: [galleryID: metric(id: galleryID, title: "From gallery")],
            personal: [:],
            galleryIDs: [galleryID]
        )

        XCTAssertTrue(adopted.isEmpty)
    }

    private func metric(id: UUID = UUID(), title: String) -> Metric {
        Metric(id: id, title: title, measure: "n", type: .json)
    }
}
