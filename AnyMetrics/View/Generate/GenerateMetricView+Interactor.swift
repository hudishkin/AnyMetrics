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

        init() {
            initialState = VState(examples: [
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
            ])
        }

        @MainActor
        func execute(
            _ state: @escaping CurrentState<S>,
            _ action: VAction,
            _ updater: @escaping StateUpdater<S>
        ) {
            switch action {
            case .onAppear:
                break
            case .setDraft(let text):
                Task { @MainActor in
                    await updater { $0.draft = text }
                }
            case .selectExample(let id):
                Task { @MainActor in
                    guard let current = await state() else { return }
                    guard let example = current.examples.first(where: { $0.id == id }) else { return }
                    await updater { $0.draft = example.title }
                }
            case .send:
                Task { @MainActor in
                    guard let current = await state() else { return }
                    let text = current.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    await updater { $0.draft = "" }
                    self.notifications.send(.submitted(text))
                }
            }
        }
    }
}
