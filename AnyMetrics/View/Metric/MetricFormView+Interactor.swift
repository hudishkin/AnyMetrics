import Foundation
import Combine
import SwiftyJSON
import SwiftSoup
import AnyMetricsShared
import VVSI

let DEFAULT_LENGTH_VALUE = 0

extension MetricFormView {
    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {
        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        var initialState: VState

        private var parserDocument: ValueParser?
        private var disposables = Set<AnyCancellable>()
        private var metric: Metric?

        init(metric: Metric? = nil) {
            self.metric = metric

            if let metric {
                var state = VState(id: metric.id, isNew: false)
                state.requestUrl = metric.request?.url.absoluteString ?? ""
                state.httpMethodType = .init(rawValue: metric.request?.method ?? "") ?? .GET
                state.typeMetric = metric.type
                state.title = metric.title
                state.measure = metric.measure
                state.maxLengthValue = metric.formatter?.length ?? DEFAULT_LENGTH_VALUE
                state.httpHeaders = metric.request?.headers ?? [:]
                state.parseRules = metric.rules?.parseRules ?? ""
                state.typeRule = metric.rules?.type ?? .none
                state.formatType = metric.formatter?.format ?? .none
                state.parseConfigurationValue = metric.rules?.value ?? ""
                state.canSetupResponse = true
                state.resultWithError = metric.resultWithError
                state.isEdited = true
                self.initialState = state
            } else {
                let state = VState(id: UUID(), isNew: true)
                self.initialState = state
            }
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .makeRequest:
                makeRequest(state: state, updater: updater)
            case .updateValue(let rule, let length):
                Task { @MainActor in
                    await updateValue(state: state, updater: updater, rule: rule, length: length)
                }
            case .setTitle(let value):
                Task { @MainActor in
                    await updater {
                        $0.title = value

                    }
                }
            case .setMeasure(let value):
                Task { @MainActor in
                    await updater {
                        $0.measure = value

                    }
                }
            case .setRequestUrl(let value):
                Task { @MainActor in
                    await updater {
                        $0.requestUrl = value

                    }
                }
            case .setHTTPMethodType(let value):
                Task { @MainActor in
                    await updater { $0.httpMethodType = value }
                }
            case .setTypeMetric(let value):
                Task { @MainActor in
                    await updater {
                        $0.typeMetric = value

                    }
                }
            case .setTimeout(let value):
                Task { @MainActor in
                    await updater {
                        $0.timeout = value

                    }
                }
            case .setTypeRule(let value):
                Task { @MainActor in
                    await updater {
                        $0.typeRule = value

                    }
                    await self.updateValue(state: state, updater: updater)
                }
            case .setParseConfigurationValue(let value):
                Task { @MainActor in
                    await updater { $0.parseConfigurationValue = value }
                    await self.updateValue(state: state, updater: updater)
                }
            case .setCaseSensitive(let value):
                Task { @MainActor in
                    await updater { $0.caseSensitive = value }
                    await self.updateValue(state: state, updater: updater)
                }
            case .setParamEqualTo(let value):
                Task { @MainActor in
                    await updater { $0.paramEqualTo = value }
                }
            case .setParseRules(let value):
                Task { @MainActor in
                    await updater {
                        $0.parseRules = value

                    }
                    await self.updateValue(state: state, updater: updater, rule: value)
                }
            case .setFormatType(let value):
                Task { @MainActor in
                    await updater { $0.formatType = value }
                    await self.updateValue(state: state, updater: updater)
                }
            case .setMaxLengthValue(let value):
                Task { @MainActor in
                    await updater { $0.maxLengthValue = value }
                    await self.updateValue(state: state, updater: updater, length: value)
                }
            case .addHeader(let name, let value):
                Task { @MainActor in
                    await updater { $0.httpHeaders[name] = value }
                }
            case .removeHeader(let name):
                Task { @MainActor in
                    await updater { $0.httpHeaders[name] = nil }
                }
            }
        }

        func metric(from state: VState) -> Metric? {
            guard state.canAddMetric else { return nil }
            guard let url = URL(string: state.requestUrl) else { return nil }

            return Metric(
                id: metric?.id ?? UUID(),
                title: state.title,
                measure: state.measure,
                type: state.typeMetric,
                result: state.result,
                resultWithError: state.resultWithError,
                request: RequestData(
                    headers: state.httpHeaders,
                    method: state.httpMethodType.rawValue,
                    url: url,
                    timeout: state.timeout),
                formatter: .init(
                    format: state.formatType,
                    length: state.maxLengthValue),
                rules: .init(
                    parseRules: state.parseRules,
                    type: state.typeRule,
                    value: state.parseConfigurationValue,
                    caseSensitive: state.caseSensitive),
                created: Date(),
                updated: nil,
                author: nil,
                description: nil,
                website: nil)
        }

        private func makeRequest(
            state: @escaping CurrentState<S>,
            updater: @escaping StateUpdater<S>
        ) {
            Task { @MainActor in
                guard let currentState = await state(),
                      let url = URL(string: currentState.requestUrl) else { return }

                await updater { $0.requestStatus = .loading }

                Fetcher.fetch(
                    for: url,
                    method: currentState.httpMethodType.rawValue,
                    headers: currentState.httpHeaders,
                    timeout: currentState.timeout
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
                        await self?.updateValue(state: state, updater: updater)
                    }
                })
                .store(in: &self.disposables)
            }
        }

        @MainActor
        private func updateValue(
            state: @escaping CurrentState<S>,
            updater: @escaping StateUpdater<S>,
            rule: String? = nil,
            length: Int? = nil
        ) async {
            guard let currentState = await state() else { return }

            let rules = rule ?? currentState.parseRules
            let formatter = MetricValueFormatter(
                format: currentState.formatType,
                length: length ?? currentState.maxLengthValue
            )

            await updater {
                if let value = self.parserDocument?.parseValue(by: rules, formatter: formatter) {
                    if currentState.typeRule != .none {
                        let parseRule = ParseRules(
                            parseRules: rules,
                            type: currentState.typeRule,
                            value: currentState.parseConfigurationValue,
                            caseSensitive: currentState.caseSensitive
                        )
                        switch parseRule.parse(value) {
                        case .status(let status):
                            $0.resultWithError = !status
                            $0.result = String(describing: status)
                        case .value(let parsedValue):
                            $0.result = parsedValue
                        }
                        $0.hasParseRuleError = false
                    } else {
                        $0.result = value
                        $0.hasParseRuleError = false
                    }
                } else {
                    $0.hasParseRuleError = true
                }
            }
        }
    }
}

extension TypeMetric {
    var localizedString: String {
        NSLocalizedString("addmetric.field.type-metric-\(self.rawValue.lowercased())", comment: "")
    }
}

extension MetricFormatterType {
    var localizedName: String { NSLocalizedString("addmetric.field.value-type-\(self.rawValue.lowercased())", comment: "") }
}

extension ParseRules.RuleType {
    var localizedName: String { NSLocalizedString("addmetric.field.rule-type-\(self.rawValue.lowercased())", comment: "") }
}
