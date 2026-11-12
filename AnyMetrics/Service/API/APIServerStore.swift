import Foundation

/// A Builder API origin. The documented list currently contains only local.
struct APIServer: Equatable, Identifiable {
    let id: String
    let baseURL: URL

    static let local = APIServer(
        id: "local",
        baseURL: URL(string: "http://127.0.0.1:3000")!
    )

    static let builtIn: [APIServer] = [local]

    static func custom(baseURL: URL) -> APIServer {
        APIServer(id: "custom:\(baseURL.absoluteString)", baseURL: baseURL)
    }
}

/// Remembers which origin the client calls. Each origin keeps its own session.
final class APIServerStore {
    static let shared = APIServerStore()

    private static let selectionKey = "api.server.selection"
    private static let customKey = "custom"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var usesCustom: Bool {
        savedRecord?.selectedID == Self.customKey && currentCustomURL != nil
    }

    var customURLString: String {
        savedRecord?.customURL ?? ""
    }

    var current: APIServer {
        guard let record = savedRecord else { return .local }
        if record.selectedID == Self.customKey, let url = currentCustomURL {
            return .custom(baseURL: url)
        }
        return APIServer.builtIn.first { $0.id == record.selectedID } ?? .local
    }

    func selectBuiltIn(_ id: String) {
        guard APIServer.builtIn.contains(where: { $0.id == id }) else { return }
        var record = savedRecord ?? Record(selectedID: id, customURL: nil)
        record.selectedID = id
        save(record)
    }

    @discardableResult
    func selectCustom(urlString: String) -> Bool {
        guard let url = Self.normalized(urlString) else { return false }
        save(Record(selectedID: Self.customKey, customURL: url.absoluteString))
        return true
    }

    private var currentCustomURL: URL? {
        guard let raw = savedRecord?.customURL else { return nil }
        return Self.normalized(raw)
    }

    private var savedRecord: Record? {
        guard let data = defaults.data(forKey: Self.selectionKey) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func save(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.selectionKey)
    }

    private static func normalized(_ raw: String) -> URL? {
        guard let url = raw.requestURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        if components.path == "/" {
            components.path = ""
        }
        return components.url
    }

    private struct Record: Codable {
        var selectedID: String
        var customURL: String?
    }
}
