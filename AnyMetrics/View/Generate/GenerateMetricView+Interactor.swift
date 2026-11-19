import Combine
import Foundation
import VVSI

extension GenerateMetricView {

    final class Interactor: ViewStateInteractorProtocol, InitialStateProtocol {
        typealias S = VState
        typealias A = VAction
        typealias N = VNotification

        let notifications: PassthroughSubject<N, Never> = .init()
        let initialState: VState
        /// Drops a keystroke that lands after Send or Try again.
        private var draftEpoch = 0

        init(jobID: UUID? = nil, prompt: String? = nil) {
            initialState = VState(
                jobID: jobID,
                userLines: prompt.map { [$0] } ?? [],
                examples: [
                    ExamplePrompt(id: "people-in-space", emoji: "👨‍🚀", title: AnyMetricsStrings.Generate.Example.peopleInSpace),
                    ExamplePrompt(id: "iss", emoji: "🛰️", title: AnyMetricsStrings.Generate.Example.iss),
                    ExamplePrompt(id: "bitcoin", emoji: "🪙", title: AnyMetricsStrings.Generate.Example.bitcoin),
                    ExamplePrompt(id: "dollar", emoji: "💵", title: AnyMetricsStrings.Generate.Example.dollar),
                    ExamplePrompt(id: "apple", emoji: "🍎", title: AnyMetricsStrings.Generate.Example.apple),
                    ExamplePrompt(id: "spacex", emoji: "🚀", title: AnyMetricsStrings.Generate.Example.spacex),
                    ExamplePrompt(id: "fear-greed", emoji: "😱", title: AnyMetricsStrings.Generate.Example.fearGreed),
                    ExamplePrompt(id: "moon", emoji: "🌙", title: AnyMetricsStrings.Generate.Example.moon),
                    ExamplePrompt(id: "weather", emoji: "🌤️", title: AnyMetricsStrings.Generate.Example.weather),
                    ExamplePrompt(id: "gold", emoji: "🥇", title: AnyMetricsStrings.Generate.Example.gold)
                ]
            )
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .onAppear:
                Task { @MainActor in
                    guard !isPreview else { return }
                    await GenerationJobService.shared.resume()
                    guard let current = await state() else { return }
                    guard let jobID = current.jobID,
                          let record = GenerationJobService.shared.record(jobID: jobID) else { return }
                    await updater {
                        if $0.userLines.isEmpty {
                            $0.userLines = [record.prompt]
                        }
                    }
                }
            case .setDraft(let text):
                let epoch = draftEpoch
                Task { @MainActor in
                    guard epoch == self.draftEpoch else { return }
                    await updater {
                        guard epoch == self.draftEpoch else { return }
                        $0.draft = text
                        $0.generationError = nil
                    }
                }
            case .selectExample(let id):
                let epoch = draftEpoch
                Task { @MainActor in
                    guard epoch == self.draftEpoch else { return }
                    guard let current = await state() else { return }
                    guard let example = current.examples.first(where: { $0.id == id }) else { return }
                    await updater {
                        guard epoch == self.draftEpoch else { return }
                        $0.draft = example.title
                    }
                }
            case .send(let raw):
                draftEpoch += 1
                Task { @MainActor in
                    guard let current = await state() else { return }
                    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    guard text.count <= GenerationJobService.maximumPromptLength else {
                        await updater { $0.generationError = AnyMetricsStrings.Generate.promptTooLong }
                        return
                    }
                    if let jobID = current.jobID,
                       GenerationJobService.shared.record(jobID: jobID)?.status == .needsInput {
                        await updater {
                            $0.draft = ""
                            $0.userLines.append(text)
                            $0.isAnswering = true
                            $0.generationError = nil
                        }
                        self.notifications.send(.submitted(text))
                        do {
                            _ = try await GenerationJobService.shared.answer(jobID: jobID, text: text)
                            await updater { $0.isAnswering = false }
                        } catch {
                            await updater {
                                $0.isAnswering = false
                                $0.generationError = Self.message(for: error)
                                $0.draft = text
                            }
                        }
                        return
                    }
                    await updater {
                        $0.draft = ""
                        $0.userLines = [text]
                        $0.generationError = nil
                    }
                    self.notifications.send(.submitted(text))
                    let locale = Locale.preferredLanguages.first ?? "ru-RU"
                    #if DEBUG
                    let simulation = DevSettings.simulateGeneration
                    #else
                    let simulation = false
                    #endif
                    do {
                        let record = try await GenerationJobService.shared.start(
                            prompt: text,
                            locale: locale,
                            simulation: simulation,
                            idempotencyKey: current.idempotencyKey
                        )
                        guard let jobID = record.jobId else { return }
                        await updater { $0.jobID = jobID }
                    } catch {
                        let kept = GenerationJobService.shared.jobs.contains {
                            $0.idempotencyKey == current.idempotencyKey && $0.jobId == nil
                        }
                        let message = Self.message(for: error)
                        await updater {
                            $0.generationError = message
                            if !kept {
                                $0.userLines = []
                                $0.draft = text
                            }
                        }
                    }
                }
            case .reset:
                draftEpoch += 1
                Task { @MainActor in
                    await updater {
                        $0.draft = ""
                        $0.jobID = nil
                        $0.userLines = []
                        $0.isAnswering = false
                        $0.generationError = nil
                        $0.idempotencyKey = UUID().uuidString.lowercased()
                    }
                }
            }
        }

        private static func message(for error: Error) -> String {
            if case GenerationJobError.promptTooLong = error {
                return AnyMetricsStrings.Generate.promptTooLong
            }
            if let client = error as? BuilderAPI.ClientError {
                if let text = client.failure?.message, !text.isEmpty {
                    return text
                }
                switch client {
                case .missingSession:
                    return AnyMetricsStrings.Error.unknown("A session token is required.")
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
    }
}
