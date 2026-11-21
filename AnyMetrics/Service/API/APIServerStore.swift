import Foundation

/// A Builder API origin.
struct APIServer: Equatable, Identifiable {
    let id: String
    let baseURL: URL

    static let local = APIServer(
        id: "local",
        baseURL: URL(string: "http://127.0.0.1:3000")!
    )

    /// Comes from the `BuilderAPIURL` Info.plist key, filled by the `BUILDER_API_URL` build setting.
    static let production: APIServer? = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BuilderAPIURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, !raw.hasPrefix("$("), let url = URL(string: raw) else { return nil }
        return APIServer(id: "production", baseURL: url)
    }()

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
    private let production: APIServer?

    init(defaults: UserDefaults = .standard, production: APIServer? = .production) {
        self.defaults = defaults
        self.production = production
    }

    /// Release builds offer only one server, so a selection saved by a debug build cannot leak into them.
    var builtIn: [APIServer] {
        #if DEBUG
        return [production, .local].compactMap { $0 }
        #else
        return [fallback]
        #endif
    }

    private var fallback: APIServer {
        production ?? .local
    }

    var usesCustom: Bool {
        savedRecord?.selectedID == Self.customKey && currentCustomURL != nil
    }

    var customURLString: String {
        savedRecord?.customURL ?? ""
    }

    var current: APIServer {
        #if DEBUG
        guard let record = savedRecord else { return fallback }
        if record.selectedID == Self.customKey, let url = currentCustomURL {
            return .custom(baseURL: url)
        }
        return builtIn.first { $0.id == record.selectedID } ?? fallback
        #else
        return fallback
        #endif
    }

    func selectBuiltIn(_ id: String) {
        guard builtIn.contains(where: { $0.id == id }) else { return }
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
