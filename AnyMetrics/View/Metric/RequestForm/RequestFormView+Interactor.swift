import Foundation
import Combine
import SwiftyJSON
import SwiftSoup
import AnyMetricsShared
import VVSI

extension RequestFormView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {
        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        var initialState: VState

        var parserDocument: ValueParser?
        private var disposables = Set<AnyCancellable>()

        init(metric: Metric? = nil) {
            if let metric {
                var state = VState()
                state.requestUrl = metric.request?.url.absoluteString ?? ""
                state.httpMethodType = .init(rawValue: metric.request?.method ?? "") ?? .GET
                state.typeMetric = metric.type
                state.httpHeaders = metric.request?.headers ?? [:]
                state.requestBody = metric.request?.requestBody ?? ""
                state.refreshInterval = RefreshInterval(from: metric.interval)
                state.canSetupResponse = true
                self.initialState = state
            } else {
                self.initialState = VState()
            }
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .setRequestUrl(let value):
                Task { @MainActor in
                    await updater { $0.requestUrl = value }
                }
            case .setHTTPMethodType(let value):
                Task { @MainActor in
                    await updater { $0.httpMethodType = value }
                }
            case .setTypeMetric(let value):
                Task { @MainActor in
                    await updater { $0.typeMetric = value }
                }
            case .setRequestBody(let value):
                Task { @MainActor in
                    await updater { $0.requestBody = value }
                }
            case .setRefreshInterval(let value):
                Task { @MainActor in
                    await updater { $0.refreshInterval = value }
                }
            case .addHeader(let name, let value):
                Task { @MainActor in
                    await updater { $0.httpHeaders[name] = value }
                }
            case .removeHeader(let name):
                Task { @MainActor in
                    await updater { $0.httpHeaders[name] = nil }
                }
            case .editHeader(let oldName, let newName, let newValue):
                Task { @MainActor in
                    await updater {
                        if oldName != newName {
                            $0.httpHeaders[oldName] = nil
                        }
                        $0.httpHeaders[newName] = newValue
                    }
                }
            case .makeRequest:
                makeRequest(state: state, updater: updater)
            }
        }

        private func makeRequest(
            state: @escaping CurrentState<S>,
            updater: @escaping StateUpdater<S>
        ) {
            Task { @MainActor in
                guard let currentState = await state(),
                      let url = URL(string: currentState.requestUrl) else { return }

                await updater { $0.requestStatus = .loading }

                let body = currentState.httpMethodType.hasBody ? currentState.requestBody : nil
                Fetcher.fetch(
                    for: url,
                    method: currentState.httpMethodType.rawValue,
                    headers: currentState.httpHeaders,
                    timeout: currentState.timeout,
                    requestBody: body
                )
                .map { data -> ValueParser? in
                    if currentState.typeMetric == .json {
                        return try? JSON(data: data)
                    }
                    if currentState.typeMetric == .web {
                        return try? SwiftSoup.parse(String(data: data, encoding: .utf8) ?? "")
                    }
                    return nil
                }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    Task { @MainActor in
                        switch completion {
                        case .failure(let error):
                            await updater {
                                $0.requestStatus = .error
                                $0.errorMessage = error.localizedDescription
                                $0.hasRequestError = true
                                $0.canSetupResponse = $0.typeMetric == .checkStatus
                            }
                            self?.notifications.send(.error(error.localizedDescription))
                        case .finished:
                            await updater {
                                $0.hasRequestError = false
                                $0.canSetupResponse = true
                                $0.requestStatus = .success
                            }
                        }
                    }
                }, receiveValue: { [weak self] parser in
                    self?.parserDocument = parser
                    Task { @MainActor in
                        await updater { $0.response = parser?.rawData() ?? "" }
                        self?.notifications.send(.requestCompleted)
                    }
                })
                .store(in: &self.disposables)
            }
        }
    }
}
