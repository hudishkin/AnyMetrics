import AuthenticationServices
import Combine
import Foundation
import VVSI

extension ProfileView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {

        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        var initialState: VState = .init()

        private var generation = 0

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .load:
                Task { await self.load(updater: updater) }
            case .logOut:
                Task { await self.logOut(updater: updater) }
            case .signIn(let provider):
                Task { await self.signIn(provider, updater: updater) }
            }
        }

        @MainActor
        private func load(updater: @escaping StateUpdater<S>) async {
            let token = nextGeneration()
            await updater {
                $0.isLoading = true
                $0.loadFailed = false
            }
            if !AuthSession.shared.isReady {
                await AuthSession.shared.restore()
            }
            guard isCurrent(token) else { return }

            if AuthSession.shared.isSignedIn {
                await loadAccount(token: token, updater: updater)
            } else {
                await loadProviders(token: token, updater: updater)
            }
        }

        @MainActor
        private func loadAccount(token: Int, updater: @escaping StateUpdater<S>) async {
            do {
                let account = try await AuthSession.shared.authorized { client in
                    try await client.me()
                }
                guard isCurrent(token) else { return }
                await updater {
                    $0.account = account
                    $0.isSignedIn = true
                    $0.providers = []
                    $0.isLoading = false
                    $0.loadFailed = false
                }
            } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
                guard isCurrent(token) else { return }
                await loadProviders(token: token, updater: updater)
            } catch {
                guard isCurrent(token) else { return }
                let cached = AuthSession.shared.account
                await updater {
                    $0.account = cached
                    $0.isSignedIn = true
                    $0.isLoading = false
                    $0.loadFailed = cached == nil
                }
                notifications.send(.error(message(for: error)))
            }
        }

        @MainActor
        private func loadProviders(token: Int, updater: @escaping StateUpdater<S>) async {
            do {
                let providers = try await fetchProviders()
                guard isCurrent(token) else { return }
                await updater {
                    $0.account = nil
                    $0.isSignedIn = false
                    $0.providers = providers
                    $0.isLoading = false
                    $0.loadFailed = false
                }
            } catch {
                guard isCurrent(token) else { return }
                await updater {
                    $0.account = nil
                    $0.isSignedIn = false
                    $0.providers = []
                    $0.isLoading = false
                    $0.loadFailed = true
                }
                notifications.send(.error(message(for: error)))
            }
        }

        @MainActor
        private func logOut(updater: @escaping StateUpdater<S>) async {
            let token = nextGeneration()
            await updater { $0.isSubmitting = true }
            do {
                try await AuthSession.shared.logOut()
                guard isCurrent(token) else { return }
                await showSignedOut(token: token, updater: updater)
            } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
                guard isCurrent(token) else { return }
                await showSignedOut(token: token, updater: updater)
            } catch {
                guard isCurrent(token) else { return }
                await updater { $0.isSubmitting = false }
                notifications.send(.error(message(for: error)))
            }
        }

        @MainActor
        private func signIn(
            _ provider: BuilderAPI.SignInProvider,
            updater: @escaping StateUpdater<S>
        ) async {
            let token = nextGeneration()
            await updater { $0.isSubmitting = true }
            do {
                let account = try await ProviderSignIn.signIn(provider)
                guard isCurrent(token) else { return }
                await updater {
                    $0.account = account
                    $0.isSignedIn = true
                    $0.providers = []
                    $0.isSubmitting = false
                    $0.isLoading = false
                    $0.loadFailed = false
                }
            } catch {
                guard isCurrent(token) else { return }
                await updater { $0.isSubmitting = false }
                if !isCancellation(error) {
                    notifications.send(.error(message(for: error)))
                }
            }
        }

        @MainActor
        private func showSignedOut(token: Int, updater: @escaping StateUpdater<S>) async {
            await updater {
                $0.account = nil
                $0.isSignedIn = false
                $0.isSubmitting = false
                $0.isLoading = true
            }
            await loadProviders(token: token, updater: updater)
        }

        private func fetchProviders() async throws -> [BuilderAPI.SignInProvider] {
            let server = APIServerStore.shared.current
            let client = APIClient(
                baseURL: server.baseURL,
                token: nil,
                transport: APIClient.urlSession
            )
            return try await client.signInProviders().providers
        }

        private func nextGeneration() -> Int {
            generation += 1
            return generation
        }

        private func isCurrent(_ token: Int) -> Bool {
            token == generation
        }

        private func isCancellation(_ error: Error) -> Bool {
            if error is CancellationError { return true }
            if let signIn = error as? ProviderSignInError, case .cancelled = signIn { return true }
            if let authorization = error as? ASAuthorizationError, authorization.code == .canceled { return true }
            if let web = error as? ASWebAuthenticationSessionError, web.code == .canceledLogin { return true }
            return false
        }

        private func message(for error: Error) -> String {
            if let signIn = error as? ProviderSignInError {
                switch signIn {
                case .cancelled:
                    return ""
                case .notConfigured(let provider):
                    return AnyMetricsStrings.Profile.providerNotConfigured(providerName(provider))
                case .failed(let text):
                    return text
                }
            }
            if let client = error as? BuilderAPI.ClientError {
                if let text = client.failure?.message, !text.isEmpty {
                    return text
                }
                switch client {
                case .missingSession:
                    return AnyMetricsStrings.Profile.loadFailed
                case .status(let code, _):
                    return AnyMetricsStrings.Error.httpStatus(code)
                case .transport(let urlError):
                    return ErrorMessageFormatter.message(for: urlError as Error)
                case .invalidResponse:
                    return AnyMetricsStrings.Error.invalidResponse
                }
            }
            return ErrorMessageFormatter.message(for: error)
        }

        private func providerName(_ provider: BuilderAPI.SignInProvider) -> String {
            switch provider {
            case .apple:
                return "Apple"
            case .google:
                return "Google"
            case .github:
                return "GitHub"
            }
        }
    }
}
