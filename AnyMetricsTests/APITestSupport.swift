import Foundation
import XCTest
@testable import AnyMetrics

final class ScriptedTransport {
    var requests: [URLRequest] = []
    var responses: [Result<(Int, Data), Error>] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let next = responses.removeFirst()
        let (status, data) = try next.get()
        guard let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        ) else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

func apiJSON(_ value: String) -> Data {
    Data(value.utf8)
}

func apiObject(_ data: Data?) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
}

let apiUserID = UUID(uuidString: "6f1e5c3a-1b7d-4e2a-9c0d-8a4b2f6e1d30")!
let apiJobID = UUID(uuidString: "80d9fc21-3e2d-41b6-93ec-0d5474cb0758")!

let apiSessionJSON = """
{"token":"opaque-session-token","user":{"id":"6f1e5c3a-1b7d-4e2a-9c0d-8a4b2f6e1d30","email":"ada@privaterelay.appleid.com","name":"Ada"},"balance":0,"paid":false}
"""

let apiAccountJSON = """
{"user":{"id":"6f1e5c3a-1b7d-4e2a-9c0d-8a4b2f6e1d30","email":null,"name":null},"balance":2,"paid":true}
"""

final class MemorySessionStore: SessionTokenStoring {
    var sessions: [String: StoredSession] = [:]

    func load(serverID: String) -> StoredSession? {
        sessions[serverID]
    }

    func save(_ session: StoredSession?, serverID: String) throws {
        sessions[serverID] = session
    }
}

func makeServerStore() -> (APIServerStore, UserDefaults, String) {
    let name = "APIServerStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (APIServerStore(defaults: defaults, production: nil), defaults, name)
}
