import VVSI
import AnyMetricsShared
@preconcurrency import Combine
import Foundation

extension ImportMetricView {

    final class Interactor: ViewStateInteractorProtocol {

        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()

        private let metricStore: MetricStore
        private let parser: ImportMetricParser

        init(di: DI = .shared) {
            self.metricStore = di.metricStore
            self.parser = JsonMetricParser()
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: A,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .onAppear:
                break

            case .setJsonText(let text):
                Task { @MainActor in
                    await updater { $0.jsonText = text }
                    self.validate(text: text, updater: updater)
                }

            case .importMetric:
                Task { @MainActor in
                    guard let currentState = await state() else { return }
                    self.performImport(state: currentState)
                }
            }
        }

        // MARK: - Private

        private func validate(text: String, updater: @escaping StateUpdater<S>) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                Task { @MainActor in
                    await updater {
                        $0.validation = .idle
                        $0.duplicateIdFound = false
                    }
                }
                return
            }

            guard let data = trimmed.data(using: .utf8) else {
                Task { @MainActor in
                    await updater {
                        $0.validation = .invalid(AnyMetricsStrings.Import.Error.cannotRead)
                        $0.duplicateIdFound = false
                    }
                }
                return
            }

            // Пробуем как MetricItemImportData (обёртка с version/payload)
            if let importData = try? parser.parse(data: data),
               let metric = importData.payload {
                let isDuplicate = metricStore.metrics[metric.id] != nil
                Task { @MainActor in
                    await updater {
                        $0.validation = .valid(metric)
                        $0.duplicateIdFound = isDuplicate
                    }
                }
                return
            }

            // Пробуем как чистый Metric JSON
            do {
                let metric = try JSONDecoder().decode(Metric.self, from: data)
                let isDuplicate = metricStore.metrics[metric.id] != nil
                Task { @MainActor in
                    await updater {
                        $0.validation = .valid(metric)
                        $0.duplicateIdFound = isDuplicate
                    }
                }
            } catch {
                let message = mapDecodingError(error)
                Task { @MainActor in
                    await updater {
                        $0.validation = .invalid(message)
                        $0.duplicateIdFound = false
                    }
                }
            }
        }

        private func performImport(state: VState) {
            guard let metric = state.validation.metric else {
                notifications.send(.showError(AnyMetricsStrings.Import.Error.noValidMetric))
                return
            }

            let importedMetric = metric.duplicatingIfNeeded(in: metricStore.metrics)
            notifications.send(.imported(importedMetric))
        }

        private func mapDecodingError(_ error: Error) -> String {
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, _):
                    return AnyMetricsStrings.Import.Error.missingField(key.stringValue)
                case .typeMismatch(_, let context):
                    return AnyMetricsStrings.Import.Error.wrongType(
                        context.codingPath.map(\.stringValue).joined(separator: ".")
                    )
                case .valueNotFound(_, let context):
                    return AnyMetricsStrings.Import.Error.emptyValue(
                        context.codingPath.map(\.stringValue).joined(separator: ".")
                    )
                case .dataCorrupted(let context):
                    return AnyMetricsStrings.Import.Error.corruptedData(context.debugDescription)
                @unknown default:
                    return AnyMetricsStrings.Import.Error.decoding(error.localizedDescription)
                }
            }
            return AnyMetricsStrings.Import.Error.invalidJson(error.localizedDescription)
        }
    }

}
