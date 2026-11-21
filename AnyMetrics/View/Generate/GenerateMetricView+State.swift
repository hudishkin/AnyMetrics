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
        var jobID: UUID?
        var userLines: [String] = []
        var isAnswering: Bool = false
        var generationError: String?
        var examples: [ExamplePrompt] = []
        /// One search for this visit. A new screen, and Try again, each get a new key.
        var idempotencyKey: String = UUID().uuidString.lowercased()
    }

    enum VAction: ActionProtocol {
        case onAppear
        case setDraft(String)
        case selectExample(String)
        case send(String)
        case reset
    }

    enum VNotification: NotificationProtocol {
        case submitted(String)
        /// The server refused a new generation for lack of credits. Carries the prompt to send after a purchase.
        case paymentRequired(String)
    }
}
