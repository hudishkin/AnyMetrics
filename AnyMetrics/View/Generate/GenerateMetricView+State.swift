import Foundation
import VVSI

extension GenerateMetricView {

    struct ExamplePrompt: Hashable, Identifiable, Sendable {
        let id: String
        let emoji: String
        let title: String
    }

    struct VState: StateProtocol {
        var draft: String = ""
        var examples: [ExamplePrompt] = []
    }

    enum VAction: ActionProtocol {
        case onAppear
        case setDraft(String)
        case selectExample(String)
        case send
    }

    enum VNotification: NotificationProtocol {
        case submitted(String)
    }
}
