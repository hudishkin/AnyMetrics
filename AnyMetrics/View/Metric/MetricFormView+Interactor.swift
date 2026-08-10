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

        let requestInteractor: RequestFormView.Interactor
        private var disposables = Set<AnyCancellable>()

        init(metric: Metric? = nil, requestInteractor: RequestFormView.Interactor) {
            self.requestInteractor = requestInteractor

            if let metric {
                var state = VState(id: metric.id, isNew: false)
                state.title = metric.title
                state.measure = metric.measure
                state.maxLengthValue = metric.formatter?.length ?? DEFAULT_LENGTH_VALUE
                state.parseRules = metric.rules?.parseRules ?? ""
                state.typeRule = metric.rules?.type ?? .none
                state.formatType = metric.formatter?.format ?? .none
                state.parseConfigurationValue = metric.rules?.value ?? ""
                state.caseSensitive = metric.rules?.caseSensitive ?? false
                state.result = metric.result
                state.resultWithError = metric.resultWithError
                state.isEdited = true
                state.widgetDesign = metric.widgetDesign ?? .default
                state.widgetAppearance = metric.widgetAppearance ?? .preset(metric.widgetDesign ?? .default)
                if state.widgetAppearance.isCustom || state.widgetAppearance.matchingWidgetDesign == nil {
                    var custom = state.widgetAppearance
                    custom.presetId = WidgetAppearancePreset.custom.rawValue
                    state.widgetAppearance = custom
                    state.savedCustomAppearance = custom
                }
                state.created = metric.created
                state.author = metric.author
                state.description = metric.description
                state.website = metric.website
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
            case .updateValue(let rule, let length):
                Task { @MainActor in
                    await updateValue(state: state, updater: updater, rule: rule, length: length)
                }
            case .setTitle(let value):
                Task { @MainActor in
                    await updater { $0.title = value }
                }
            case .setMeasure(let value):
                Task { @MainActor in
                    await updater { $0.measure = value }
                }
            case .setTypeRule(let value):
                Task { @MainActor in
                    await updater { $0.typeRule = value }
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
                    await updater { $0.parseRules = value }
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
            case .setWidgetDesign(let value):
                Task { @MainActor in
                    await updater {
                        $0.widgetDesign = value
                        $0.widgetAppearance = .preset(value)
                    }
                }
            case .setWidgetAppearance(let value):
                Task { @MainActor in
                    await updater {
                        $0.widgetAppearance = value
                        if value.isCustom || value.matchingWidgetDesign == nil {
                            var custom = value
                            custom.presetId = WidgetAppearancePreset.custom.rawValue
                            $0.widgetAppearance = custom
                            $0.savedCustomAppearance = custom
                        } else if let matched = value.matchingWidgetDesign {
                            $0.widgetDesign = matched
                        }
                    }
                }
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
                if let value = self.requestInteractor.parserDocument?.parseValue(by: rules, formatter: formatter) {
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
                        case .image:
                            break
                        }
                        $0.hasParseRuleError = false
                        $0.parseErrorMessage = ""
                    } else {
                        $0.result = value
                        $0.hasParseRuleError = false
                        $0.parseErrorMessage = ""
                    }
                } else {
                    $0.hasParseRuleError = true
                    $0.parseErrorMessage = ErrorMessageFormatter.parseRuleMessage(for: rules)
                }
            }
        }
    }
}

extension TypeMetric {
    var localizedString: String {
        switch self {
        case .json: return AnyMetricsStrings.Addmetric.Field.typeMetricJson
        case .web: return AnyMetricsStrings.Addmetric.Field.typeMetricWeb
        case .checkStatus: return AnyMetricsStrings.Addmetric.Field.typeMetricCheckstatus
        }
    }
}

extension MetricResultKind {
    var localizedString: String {
        switch self {
        case .content: return AnyMetricsStrings.Addmetric.Field.resultTypeContent
        case .image: return AnyMetricsStrings.Addmetric.Field.resultTypeImage
        }
    }
}

extension MetricFormatterType {
    var localizedName: String {
        switch self {
        case .none: return AnyMetricsStrings.Addmetric.Field.valueTypeNone
        case .currency: return AnyMetricsStrings.Addmetric.Field.valueTypeCurrency
        }
    }
}

extension ParseRules.RuleType {
    var localizedName: String {
        switch self {
        case .none: return AnyMetricsStrings.Addmetric.Field.ruleTypeNone
        case .equal: return AnyMetricsStrings.Addmetric.Field.ruleTypeEqual
        case .contains: return AnyMetricsStrings.Addmetric.Field.ruleTypeContains
        }
    }
}

extension WidgetDesign {
    var localizedName: String {
        switch self {
        case .glassCircle: return AnyMetricsStrings.Addmetric.Design.glassCircle
        case .roundedCard: return AnyMetricsStrings.Addmetric.Design.roundedCard
        case .plain: return AnyMetricsStrings.Addmetric.Design.plain
        }
    }
}
