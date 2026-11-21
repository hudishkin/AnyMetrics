import XCTest
@testable import AnyMetrics

final class CreditCatalogTests: XCTestCase {

    func testProductsMatchTheServerMap() {
        XCTAssertEqual(
            CreditCatalog.products,
            [
                CreditProduct(id: "app.anymetrics.credits.5", credits: 5),
                CreditProduct(id: "app.anymetrics.credits.15", credits: 15),
                CreditProduct(id: "app.anymetrics.credits.40", credits: 40)
            ]
        )
        XCTAssertEqual(CreditCatalog.identifiers, CreditCatalog.products.map(\.id))
    }

    func testListedOffersDropUnknownProductsAndLeadWithTheHighestPrice() {
        let offers = CreditOffer.listed([
            record("app.anymetrics.credits.40", name: "Forty", price: "19.99"),
            record("app.anymetrics.credits.other", name: "Other", price: "1.00"),
            record("app.anymetrics.credits.5", name: "Five", price: "4.99")
        ])

        XCTAssertEqual(offers.map(\.id), [
            "app.anymetrics.credits.40",
            "app.anymetrics.credits.5"
        ])
        XCTAssertEqual(offers.map(\.credits), [40, 5])
        XCTAssertEqual(offers.first?.displayName, "Forty")
        XCTAssertEqual(offers.first?.displayPrice, "$19.99")
        XCTAssertTrue(offers[0].isBest)
        XCTAssertFalse(offers[1].isBest)
    }

    func testBestPackShowsTheSavingAgainstTheSmallestPack() throws {
        let offers = CreditOffer.listed([
            record("app.anymetrics.credits.5", name: "Five", price: "4.99"),
            record("app.anymetrics.credits.15", name: "Fifteen", price: "9.99"),
            record("app.anymetrics.credits.40", name: "Forty", price: "19.99")
        ])

        let five = try XCTUnwrap(offers.first { $0.credits == 5 })
        let fifteen = try XCTUnwrap(offers.first { $0.credits == 15 })
        let forty = try XCTUnwrap(offers.first { $0.credits == 40 })

        XCTAssertEqual(offers.map(\.credits), [40, 15, 5])
        XCTAssertTrue(forty.isBest)
        XCTAssertEqual(forty.savingsPercent, 50)
        XCTAssertEqual(fifteen.savingsPercent, 33)
        XCTAssertNil(five.savingsPercent)
        XCTAssertEqual(forty.perCreditPrice, "$0.50")
        XCTAssertEqual(fifteen.perCreditPrice, "$0.67")
        XCTAssertEqual(five.perCreditPrice, "$1.00")
    }

    func testUnknownProductHasNoCreditAmount() {
        XCTAssertNil(CreditCatalog.credits(for: "app.anymetrics.credits.10"))
        XCTAssertEqual(CreditCatalog.credits(for: "app.anymetrics.credits.15"), 15)
    }

    private func record(_ id: String, name: String, price: String) -> CreditOffer.Record {
        CreditOffer.Record(
            id: id,
            displayName: name,
            displayPrice: "$\(price)",
            price: Decimal(string: price) ?? 0,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US")
        )
    }
}
