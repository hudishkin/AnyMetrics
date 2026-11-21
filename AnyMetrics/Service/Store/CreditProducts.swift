import Foundation
import os
import StoreKit

/// A credit pack the App Store can sell. Credits must match `APPLE_IAP_PRODUCTS` on the server.
struct CreditProduct: Equatable, Sendable {
    var id: String
    var credits: Int
}

struct CreditOffer: Equatable, Identifiable, Sendable {
    var id: String
    var credits: Int
    var displayName: String
    var displayPrice: String
    var price: Decimal
    var perCreditPrice: String
    /// How much cheaper one credit is than the pack with the highest per-credit price. Nil for that pack.
    var savingsPercent: Int?
    /// The highest-priced pack. The paywall opens with this one selected.
    var isBest: Bool

    struct Record: Equatable, Sendable {
        var id: String
        var displayName: String
        var displayPrice: String
        var price: Decimal
        var currencyCode: String
        /// The storefront's format, so the per-generation price reads like `displayPrice`.
        var locale: Locale = .current
    }

    /// Keeps packs this app sells. The highest-priced pack comes first.
    static func listed(_ records: [Record]) -> [CreditOffer] {
        let known: [(Record, Int)] = records.compactMap { record in
            guard let credits = CreditCatalog.credits(for: record.id), credits > 0 else { return nil }
            return (record, credits)
        }
        guard let best = known.max(by: { lhs, rhs in
            if lhs.0.price != rhs.0.price { return lhs.0.price < rhs.0.price }
            return lhs.1 < rhs.1
        }) else { return [] }

        let anchor = known.map { $0.0.price / Decimal($0.1) }.max() ?? 0
        return known.map { record, credits in
            let unit = record.price / Decimal(credits)
            return CreditOffer(
                id: record.id,
                credits: credits,
                displayName: record.displayName,
                displayPrice: record.displayPrice,
                price: record.price,
                perCreditPrice: CreditPriceFormat.string(unit, currencyCode: record.currencyCode, locale: record.locale),
                savingsPercent: savingsPercent(unit: unit, anchor: anchor),
                isBest: record.id == best.0.id
            )
        }
        .sorted { lhs, rhs in
            if lhs.isBest != rhs.isBest { return lhs.isBest }
            return lhs.credits > rhs.credits
        }
    }

    static func savingsPercent(unit: Decimal, anchor: Decimal) -> Int? {
        guard anchor > 0, unit < anchor else { return nil }
        let ratio = (anchor - unit) / anchor * 100
        let rounded = Int(NSDecimalNumber(decimal: ratio).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
    }
}

enum CreditPriceFormat {
    static func string(_ value: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? ""
    }
}

enum CreditCatalog {
    static let products: [CreditProduct] = [
        CreditProduct(id: "app.anymetrics.credits.5", credits: 5),
        CreditProduct(id: "app.anymetrics.credits.15", credits: 15),
        CreditProduct(id: "app.anymetrics.credits.40", credits: 40)
    ]

    static var identifiers: [String] {
        products.map(\.id)
    }

    static func credits(for productID: String) -> Int? {
        products.first { $0.id == productID }?.credits
    }
}

enum CreditPurchaseError: Error, Equatable {
    case cancelled
    case pending
    case unavailable
}

protocol CreditProductLoading: AnyObject {
    func load() async throws -> [CreditOffer]
    func purchase(productID: String) async throws -> BuilderAPI.AppleTransactionResult
    /// Sends a transaction that was charged but not finished, then finishes it.
    func recover() async -> BuilderAPI.AppleTransactionResult?
}

final class StoreKitCreditStore: CreditProductLoading {
    private static let log = Logger(subsystem: "app.anymetrics.AnyMetrics", category: "credits")

    private var products: [String: Product] = [:]

    func load() async throws -> [CreditOffer] {
        let loaded = try await Product.products(for: CreditCatalog.identifiers)
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        return CreditOffer.listed(loaded.map { product in
            CreditOffer.Record(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                price: product.price,
                currencyCode: product.priceFormatStyle.currencyCode,
                locale: product.priceFormatStyle.locale
            )
        })
    }

    func purchase(productID: String) async throws -> BuilderAPI.AppleTransactionResult {
        if products[productID] == nil {
            _ = try await load()
        }
        guard let product = products[productID] else {
            throw CreditPurchaseError.unavailable
        }
        guard let userID = await AuthSession.shared.userID else {
            throw BuilderAPI.ClientError.missingSession
        }
        let result = try await product.purchase(options: [.appAccountToken(userID)])
        switch result {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            let applied = try await AuthSession.shared.authorized { client in
                try await client.verifyAppleTransaction(
                    BuilderAPI.AppleTransaction(signedTransaction: verification.jwsRepresentation)
                )
            }
            await transaction.finish()
            return applied
        case .userCancelled:
            throw CreditPurchaseError.cancelled
        case .pending:
            throw CreditPurchaseError.pending
        @unknown default:
            throw CreditPurchaseError.unavailable
        }
    }

    func recover() async -> BuilderAPI.AppleTransactionResult? {
        var latest: BuilderAPI.AppleTransactionResult?
        for await result in Transaction.unfinished {
            do {
                let transaction = try Self.verified(result)
                let applied = try await AuthSession.shared.authorized { client in
                    try await client.verifyAppleTransaction(
                        BuilderAPI.AppleTransaction(signedTransaction: result.jwsRepresentation)
                    )
                }
                await transaction.finish()
                latest = applied
            } catch {
                Self.log.error("Unfinished transaction was not credited: \(error.localizedDescription, privacy: .public)")
            }
        }
        return latest
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
