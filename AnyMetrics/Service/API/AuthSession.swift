import Foundation
import Security

struct StoredSession: Codable, Equatable {
    var token: String
    var userID: UUID
}

protocol SessionTokenStoring: AnyObject {
    func load(serverID: String) -> StoredSession?
    func save(_ session: StoredSession?, serverID: String) throws
}

/// Session token for one server id. The token is opaque and is not a JWT.
final class KeychainSessionStore: SessionTokenStoring {
    private let service = "app.anymetrics.api.session"

    func load(serverID: String) -> StoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession?, serverID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID
        ]
        let deleted = SecItemDelete(query as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
            throw KeychainError(status: deleted)
        }
        guard let session else { return }
        let data = try JSONEncoder().encode(session)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw KeychainError(status: added)
        }
    }

    struct KeychainError: Error {
        var status: OSStatus
    }
}

/// The signed-in Builder API account for the server that is selected now.
@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var account: BuilderAPI.Account?
    @Published private(set) var isSignedIn = false
    @Published private(set) var isReady = false

    private let servers: APIServerStore
    private let tokens: SessionTokenStoring
    private let transport: (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(
        servers: APIServerStore,
        tokens: SessionTokenStoring,
        transport: @escaping (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) {
        self.servers = servers
        self.tokens = tokens
        self.transport = transport
    }

    convenience init() {
        self.init(
            servers: .shared,
            tokens: KeychainSessionStore(),
            transport: APIClient.urlSession
        )
    }

    /// Keeps the shared account in step with a fresh `/v1/me` response.
    func remember(_ account: BuilderAPI.Account) {
        self.account = account
        isSignedIn = true
    }

    /// Reads `/v1/me` again. The balance changes on the server when a generation starts.
    func refreshAccount() async {
        guard let me = try? await authorized({ try await $0.me() }) else { return }
        remember(me)
    }

    /// Account id to pass as StoreKit `appAccountToken`. Falls back to the stored id when `/v1/me` has not returned.
    var userID: UUID? {
        account?.user.id ?? tokens.load(serverID: servers.current.id)?.userID
    }

    func restore() async {
        let server = servers.current
        account = nil
        guard let stored = tokens.load(serverID: server.id) else {
            isSignedIn = false
            isReady = true
            return
        }
        isSignedIn = true
        do {
            let me = try await makeClient().me()
            guard servers.current.id == server.id else {
                publishCurrent()
                return
            }
            account = me
            isSignedIn = true
            isReady = true
            try? tokens.save(StoredSession(token: stored.token, userID: me.user.id), serverID: server.id)
        } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
            guard servers.current.id == server.id else {
                publishCurrent()
                return
            }
            try? tokens.save(nil, serverID: server.id)
            account = nil
            isSignedIn = false
            isReady = true
        } catch {
            guard servers.current.id == server.id else {
                publishCurrent()
                return
            }
            isSignedIn = true
            isReady = true
        }
    }

    func signInWithApple(identityToken: String, nonce: String?, name: String?) async throws -> BuilderAPI.Account {
        let body = BuilderAPI.AppleSignIn(identityToken: identityToken, nonce: nonce, name: name)
        return try await openSession {
            try await $0.signInWithApple(body)
        }
    }

    func signInWithGoogle(idToken: String) async throws -> BuilderAPI.Account {
        try await openSession {
            try await $0.signInWithGoogle(BuilderAPI.GoogleSignIn(idToken: idToken))
        }
    }

    func signInWithGitHub(code: String, redirectURI: String?) async throws -> BuilderAPI.Account {
        let body = BuilderAPI.GitHubSignIn(code: code, redirectUri: redirectURI)
        return try await openSession {
            try await $0.signInWithGitHub(body)
        }
    }

    func logOut() async throws {
        let serverID = servers.current.id
        guard tokens.load(serverID: serverID) != nil else {
            publishCurrent()
            return
        }
        do {
            try await makeClient().logOut()
            try tokens.save(nil, serverID: serverID)
            publishCurrent()
        } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
            try? tokens.save(nil, serverID: serverID)
            publishCurrent()
            throw error
        }
    }

    /// Deletes the account on the current server and drops its session. Other servers keep theirs.
    func deleteAccount() async throws {
        let serverID = servers.current.id
        try await authorized { try await $0.deleteAccount() }
        try tokens.save(nil, serverID: serverID)
        publishCurrent()
    }

    /// Runs a signed-in call. A 401 clears only the session for the current server.
    func authorized<T>(_ work: (APIClient) async throws -> T) async throws -> T {
        let serverID = servers.current.id
        guard tokens.load(serverID: serverID) != nil else {
            account = nil
            isSignedIn = false
            isReady = true
            throw BuilderAPI.ClientError.missingSession
        }
        do {
            return try await work(makeClient())
        } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
            guard servers.current.id == serverID else { throw error }
            try? tokens.save(nil, serverID: serverID)
            account = nil
            isSignedIn = false
            isReady = true
            throw error
        }
    }

    private func openSession(
        _ signIn: (APIClient) async throws -> BuilderAPI.Session
    ) async throws -> BuilderAPI.Account {
        let serverID = servers.current.id
        do {
            let session = try await signIn(makeClient())
            try tokens.save(
                StoredSession(token: session.token, userID: session.user.id),
                serverID: serverID
            )
            guard servers.current.id == serverID else {
                publishCurrent()
                return session.account
            }
            account = session.account
            isSignedIn = true
            isReady = true
            return session.account
        } catch let error as BuilderAPI.ClientError where error.isUnauthorized {
            throw error
        }
    }

    private func makeClient() -> APIClient {
        let server = servers.current
        return APIClient(
            baseURL: server.baseURL,
            token: tokens.load(serverID: server.id)?.token,
            transport: transport
        )
    }

    private func publishCurrent() {
        let serverID = servers.current.id
        let stored = tokens.load(serverID: serverID)
        isSignedIn = stored != nil
        if account?.user.id != stored?.userID {
            account = nil
        }
        if !isSignedIn {
            account = nil
        }
        isReady = true
    }
}
