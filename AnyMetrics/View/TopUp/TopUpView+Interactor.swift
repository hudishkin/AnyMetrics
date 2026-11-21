import Combine
import Foundation
import VVSI

extension TopUpView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {

        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        let initialState: VState

        private let store: CreditProductLoading
        private var generation = 0

        init(balance: Int, paid: Bool, store: CreditProductLoading = StoreKitCreditStore()) {
            self.store = store
            initialState = VState(balance: balance, paid: paid)
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .load:
                Task { await self.load(state: state, updater: updater) }
            case .select(let id):
                Task { await updater { $0.selectedID = id } }
            case .purchase:
                Task { await self.purchase(state: state, updater: updater) }
            }
        }

        @MainActor
        private func load(
            state: @escaping CurrentState<S>,
            updater: @escaping StateUpdater<S>
        ) async {
            let token = nextGeneration()
            await updater {
                $0.isLoading = true
                $0.loadFailed = false
            }
            if isPreview {
                guard isCurrent(token) else { return }
                let offers = Self.previewOffers
                await updater {
                    $0.offers = offers
                    $0.selectedID = offers.first { $0.isBest }?.id
                    $0.isLoading = false
                }
                return
            }
            do {
                let offers = try await store.load()
                guard isCurrent(token) else { return }
                let kept = await state()?.selectedID
                let recovered = await store.recover()
                guard isCurrent(token) else { return }
                if let recovered {
                    remember(recovered)
                }
                await updater {
                    $0.offers = offers
                    if let kept, offers.contains(where: { $0.id == kept }) {
                        $0.selectedID = kept
                    } else {
                        $0.selectedID = offers.first { $0.isBest }?.id
                    }
                    if let recovered {
                        $0.balance = recovered.balance
                        $0.paid = true
                    }
                    $0.isLoading = false
                    $0.loadFailed = false
                }
            } catch {
                guard isCurrent(token) else { return }
                await updater {
                    $0.isLoading = false
                    $0.loadFailed = true
                }
                notifications.send(.error(ErrorMessageFormatter.message(for: error)))
            }
        }

        @MainActor
        private func purchase(
            state: @escaping CurrentState<S>,
            updater: @escaping StateUpdater<S>
        ) async {
            guard !isPreview else { return }
            guard let current = await state(), let productID = current.selectedID, !current.isPurchasing else { return }
            let token = nextGeneration()
            await updater { $0.isPurchasing = true }
            do {
                let result = try await store.purchase(productID: productID)
                guard isCurrent(token) else { return }
                remember(result)
                await updater {
                    $0.balance = result.balance
                    $0.paid = true
                    $0.isPurchasing = false
                }
                ImpactHelper.success()
                notifications.send(.purchased)
            } catch CreditPurchaseError.cancelled {
                guard isCurrent(token) else { return }
                await updater { $0.isPurchasing = false }
            } catch CreditPurchaseError.pending {
                guard isCurrent(token) else { return }
                await updater { $0.isPurchasing = false }
                notifications.send(.error(AnyMetricsStrings.TopUp.pending))
            } catch CreditPurchaseError.unavailable {
                guard isCurrent(token) else { return }
                await updater { $0.isPurchasing = false }
                notifications.send(.error(AnyMetricsStrings.TopUp.unavailable))
            } catch {
                guard isCurrent(token) else { return }
                await updater { $0.isPurchasing = false }
                notifications.send(.error(ErrorMessageFormatter.message(for: error)))
            }
        }

        @MainActor
        private func remember(_ result: BuilderAPI.AppleTransactionResult) {
            guard var account = AuthSession.shared.account else { return }
            account.balance = result.balance
            account.paid = true
            AuthSession.shared.remember(account)
        }

        private func nextGeneration() -> Int {
            generation += 1
            return generation
        }

        private func isCurrent(_ token: Int) -> Bool {
            token == generation
        }

        private static let previewOffers = CreditOffer.listed([
            CreditOffer.Record(
                id: "app.anymetrics.credits.5",
                displayName: "Credits 5",
                displayPrice: "$4.99",
                price: Decimal(string: "4.99") ?? 4.99,
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            ),
            CreditOffer.Record(
                id: "app.anymetrics.credits.15",
                displayName: "Credits 15",
                displayPrice: "$9.99",
                price: Decimal(string: "9.99") ?? 9.99,
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            ),
            CreditOffer.Record(
                id: "app.anymetrics.credits.40",
                displayName: "Credits 40",
                displayPrice: "$19.99",
                price: Decimal(string: "19.99") ?? 19.99,
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            )
        ])
    }
}
