import XCTest
import AnyMetricsShared
@testable import AnyMetrics

final class MetricShareComposerTests: XCTestCase {

    func testFileNameKeepsAlphanumericsAndId() {
        let id = UUID(uuidString: "AABBCCDD-0000-0000-0000-000000000001")!
        let name = MetricShareComposer.fileName(title: "Bitcoin Price!", id: id)

        XCTAssertEqual(name, "share_bitcoin_price_aabbccdd.png")
    }

    func testFileNameFallbackWhenTitleIsSymbols() {
        let id = UUID(uuidString: "AABBCCDD-0000-0000-0000-000000000001")!
        let name = MetricShareComposer.fileName(title: "***", id: id)

        XCTAssertEqual(name, "share_metric_aabbccdd.png")
    }

    func testCaptionIncludesMetricTitle() {
        let caption = MetricShareComposer.caption(title: "Bitcoin")

        XCTAssertTrue(caption.contains("Bitcoin"))
        XCTAssertFalse(caption.isEmpty)
    }

    func testQRCodeImageIsGenerated() {
        let image = MetricShareComposer.qrImage(url: MetricShareComposer.appStoreURL, size: 120)

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width ?? 0, 120, accuracy: 2)
        XCTAssertEqual(image?.size.height ?? 0, 120, accuracy: 2)
    }

    func testQRCodeRejectsEmptySize() {
        XCTAssertNil(MetricShareComposer.qrImage(from: "https://example.com", size: 0))
    }

    func testAppStoreURLIsHTTPS() {
        XCTAssertEqual(MetricShareComposer.appStoreURL.scheme, "https")
        XCTAssertTrue(MetricShareComposer.appStoreURL.absoluteString.contains("1609900961"))
    }

    func testExportFileCanBeImported() throws {
        var metric = Mocks.metricJson
        metric.author = "tester"
        let fileURL = try MetricItemImportData.writeFile(for: metric, options: .default)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let data = try Data(contentsOf: fileURL)
        let imported = try JsonMetricParser().parse(data: data)

        XCTAssertEqual(imported.payload?.title, metric.title)
        XCTAssertEqual(imported.includes?.request, true)
        XCTAssertEqual(imported.includes?.widgetStyle, true)
        XCTAssertTrue(fileURL.lastPathComponent.hasSuffix(".json"))
    }

    func testExportOmitsRequestWhenDisabled() throws {
        let metric = Metric(
            id: UUID(),
            title: "Bitcoin",
            measure: "USD",
            type: .json,
            request: RequestData(
                headers: ["Authorization": "secret"],
                method: "GET",
                url: URL(string: "https://example.com/price")!
            )
        )
        let fileURL = try MetricItemImportData.writeFile(
            for: metric,
            options: MetricExportOptions(includeRequest: false, includeWidgetStyle: true)
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let data = try Data(contentsOf: fileURL)
        let imported = try JsonMetricParser().parse(data: data)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertNil(imported.payload?.request)
        XCTAssertEqual(imported.includes?.request, false)
        XCTAssertEqual(imported.includes?.widgetStyle, true)
        XCTAssertFalse(json.contains("secret"))
    }

    func testSharePayloadDoesNotExposeRawAppStoreURL() {
        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("share.png")
        let json = FileManager.default.temporaryDirectory.appendingPathComponent("metric.json")
        let payload = MetricSharePayload(
            image: UIImage(),
            imageURL: imageURL,
            metricURL: json,
            caption: "Hello"
        )

        XCTAssertEqual(payload.fileURLs, [imageURL, json])
        XCTAssertEqual(payload.activityItems.count, 3)
        XCTAssertFalse(payload.activityItems.contains { item in
            (item as? URL) == MetricShareComposer.appStoreURL
        })
        XCTAssertTrue(payload.activityItems.contains { $0 is MetricShareFileItem })
        XCTAssertTrue(payload.activityItems.contains { $0 is MetricShareImageItem })
    }

    func testMessengerShareOmitsLinkFromCaption() {
        let telegram = MetricShareTextItem.text(
            caption: "Hello",
            activityType: UIActivity.ActivityType("ph.telegra.Telegraph.Share")
        )
        let mail = MetricShareTextItem.text(caption: "Hello", activityType: .mail)

        XCTAssertEqual(telegram, "Hello")
        XCTAssertTrue(mail.contains(MetricShareComposer.appStoreURL.absoluteString))
    }

    func testTelegramIsTreatedAsFileFirstMessenger() {
        XCTAssertTrue(MetricShareActivity.prefersFilesOverLinks(UIActivity.ActivityType("ph.telegra.Telegraph.Share")))
        XCTAssertFalse(MetricShareActivity.prefersFilesOverLinks(.mail))
    }
}
