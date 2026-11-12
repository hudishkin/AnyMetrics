import XCTest
@testable import AnyMetrics

@MainActor
final class AuthSessionTests: XCTestCase {

    private var transport: ScriptedTransport!
    private var tokens: MemorySessionStore!
    private var servers: APIServerStore!
    private var defaultsName: String!
    private var session: AuthSession!

    override func setUp() async throws {
        let (store, _, name) = makeServerStore()
        defaultsName = name
        servers = store
        transport = ScriptedTransport()
        tokens = MemorySessionStore()
        let transport = transport!
        session = AuthSession(servers: store, tokens: tokens, transport: { request in
            try await transport.send(request)
        })
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: defaultsName)
        UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
    }

    func testRestoreWithoutATokenDoesNotCallTheServer() async {
        await session.restore()

        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertFalse(session.isSignedIn)
        XCTAssertTrue(session.isReady)
        XCTAssertNil(session.account)
    }

    func testRestoreReadsTheAccountForTheSelectedServer() async throws {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "stored", userID: apiUserID)
        transport.responses = [.success((200, apiJSON(apiAccountJSON)))]

        await session.restore()

        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.account?.balance, 2)
        XCTAssertEqual(session.account?.paid, true)
        XCTAssertNil(session.account?.user.email)
        XCTAssertEqual(session.userID, apiUserID)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer stored")
        XCTAssertEqual(transport.requests.first?.url?.host, "127.0.0.1")
    }

    func testRestoreClearsAnExpiredToken() async {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "expired", userID: apiUserID)
        transport.responses = [.success((401, apiJSON(#"{"error":{"code":"UNAUTHORIZED","message":"A session token is required."}}"#)))]

        await session.restore()

        XCTAssertFalse(session.isSignedIn)
        XCTAssertNil(tokens.sessions[APIServer.local.id])
    }

    func testRestoreKeepsTheTokenWhenTheServerIsUnreachable() async {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "stored", userID: apiUserID)
        transport.responses = [.failure(BuilderAPI.ClientError.transport(URLError(.cannotConnectToHost)))]

        await session.restore()

        XCTAssertTrue(session.isSignedIn)
        XCTAssertNil(session.account)
        XCTAssertEqual(session.userID, apiUserID)
        XCTAssertEqual(tokens.sessions[APIServer.local.id]?.token, "stored")
    }

    func testRejectedSignInKeepsThePreviousSession() async {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "previous", userID: apiUserID)
        transport.responses = [.success((401, apiJSON(#"{"error":{"code":"UNAUTHORIZED","message":"The sign-in token was rejected."}}"#)))]

        do {
            _ = try await session.signInWithGoogle(idToken: "bad")
            XCTFail("Expected the credential to be rejected")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertEqual(tokens.sessions[APIServer.local.id]?.token, "previous")
        XCTAssertNil(transport.requests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func testSignInReplacesTheStoredToken() async throws {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "previous", userID: apiUserID)
        transport.responses = [.success((200, apiJSON(apiSessionJSON)))]

        let account = try await session.signInWithGitHub(code: "code", redirectURI: "anymetrics://callback")

        XCTAssertEqual(account.user.name, "Ada")
        XCTAssertEqual(tokens.sessions[APIServer.local.id]?.token, "opaque-session-token")
        XCTAssertTrue(session.isSignedIn)
        let body = apiObject(transport.requests.first?.httpBody)
        XCTAssertEqual(body["code"] as? String, "code")
        XCTAssertEqual(body["redirectUri"] as? String, "anymetrics://callback")
    }

    func testLogoutDropsOnlyTheCurrentServerToken() async throws {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "local-token", userID: apiUserID)
        tokens.sessions["custom:http://10.0.0.2:3000"] = StoredSession(token: "other-token", userID: apiUserID)
        transport.responses = [.success((204, Data()))]

        try await session.logOut()

        XCTAssertNil(tokens.sessions[APIServer.local.id])
        XCTAssertEqual(tokens.sessions["custom:http://10.0.0.2:3000"]?.token, "other-token")
        XCTAssertFalse(session.isSignedIn)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer local-token")
    }

    func testAuthorizedCallClearsTheSessionOn401() async {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "stored", userID: apiUserID)
        transport.responses = [.success((401, apiJSON(#"{"error":{"code":"UNAUTHORIZED","message":"A session token is required."}}"#)))]

        do {
            _ = try await session.authorized { client in
                try await client.billing()
            }
            XCTFail("Expected the session to be rejected")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertFalse(session.isSignedIn)
        XCTAssertNil(tokens.sessions[APIServer.local.id])
    }

    func testSwitchingServersUsesThatServersSession() async throws {
        tokens.sessions[APIServer.local.id] = StoredSession(token: "local-token", userID: apiUserID)
        XCTAssertTrue(servers.selectCustom(urlString: "http://10.0.0.2:3000/"))

        await session.restore()

        XCTAssertFalse(session.isSignedIn)
        XCTAssertTrue(transport.requests.isEmpty)

        servers.selectBuiltIn(APIServer.local.id)
        transport.responses = [.success((200, apiJSON(apiAccountJSON)))]
        await session.restore()

        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "http://127.0.0.1:3000/v1/me")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer local-token")
        XCTAssertEqual(tokens.sessions["custom:http://10.0.0.2:3000"], nil)
    }
}

final class APIServerStoreTests: XCTestCase {

    private var defaultsName: String!

    override func tearDown() {
        UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
    }

    func testTheDefaultServerIsLocal() {
        let (store, _, name) = makeServerStore()
        defaultsName = name

        XCTAssertEqual(store.current, .local)
        XCTAssertEqual(store.current.baseURL.absoluteString, "http://127.0.0.1:3000")
        XCTAssertFalse(store.usesCustom)
    }

    func testCustomURLBecomesTheCurrentServerAndSurvivesReload() {
        let (store, defaults, name) = makeServerStore()
        defaultsName = name

        XCTAssertTrue(store.selectCustom(urlString: "  http://10.0.0.2:3000/ "))
        XCTAssertEqual(store.current.baseURL.absoluteString, "http://10.0.0.2:3000")
        XCTAssertTrue(store.usesCustom)
        XCTAssertEqual(store.customURLString, "http://10.0.0.2:3000")

        let reloaded = APIServerStore(defaults: defaults)
        XCTAssertEqual(reloaded.current, store.current)

        store.selectBuiltIn(APIServer.local.id)
        XCTAssertEqual(store.current, .local)
        XCTAssertEqual(store.customURLString, "http://10.0.0.2:3000")
    }

    func testInvalidCustomURLDoesNotReplaceTheSelection() {
        let (store, _, name) = makeServerStore()
        defaultsName = name

        XCTAssertFalse(store.selectCustom(urlString: "ftp://10.0.0.2"))
        XCTAssertFalse(store.selectCustom(urlString: "not a url"))
        XCTAssertEqual(store.current, .local)
    }

    func testUnknownStoredServerFallsBackToLocal() {
        let (store, defaults, name) = makeServerStore()
        defaultsName = name
        defaults.set(
            Data(#"{"selectedID":"production","customURL":null}"#.utf8),
            forKey: "api.server.selection"
        )

        XCTAssertEqual(APIServerStore(defaults: defaults).current, .local)
        XCTAssertEqual(store.current, .local)
    }
}
