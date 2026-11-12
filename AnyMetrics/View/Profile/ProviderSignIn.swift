import AuthenticationServices
import CryptoKit
import Foundation
import Security

enum ProviderSignInError: Error {
    case cancelled
    case notConfigured(BuilderAPI.SignInProvider)
    case failed(String)
}

enum ProviderSignIn {
    /// The provider sheet runs first. The API session opens only after it returns a credential.
    @MainActor
    static func signIn(_ provider: BuilderAPI.SignInProvider) async throws -> BuilderAPI.Account {
        switch provider {
        case .apple:
            let credential = try await AppleSignInSession().credential()
            return try await AuthSession.shared.signInWithApple(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                name: credential.name
            )
        case .google:
            let idToken = try await GoogleSignIn.request()
            return try await AuthSession.shared.signInWithGoogle(idToken: idToken)
        case .github:
            let credential = try await GitHubSignIn.request()
            return try await AuthSession.shared.signInWithGitHub(
                code: credential.code,
                redirectURI: credential.redirectURI
            )
        }
    }
}

private enum SignInClients {
    static var googleClientID: String? { value(for: "GoogleClientID") }
    static var gitHubClientID: String? { value(for: "GitHubClientID") }
    static let gitHubRedirectURI = "anymetrics://callback"
    static let gitHubCallbackScheme = "anymetrics"

    private static func value(for key: String) -> String? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
        return raw
    }
}

private enum SignInNonce {
    static func make(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct AppleSignInCredential {
    var identityToken: String
    var nonce: String
    var name: String?
}

@MainActor
private final class AppleSignInSession: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleSignInCredential, Error>?
    private var hashedNonce = ""
    private var controller: ASAuthorizationController?

    func credential() async throws -> AppleSignInCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let rawNonce = SignInNonce.make()
            // Apple puts the SHA-256 hash into the token. The API expects that same hash.
            hashedNonce = SignInNonce.sha256(rawNonce)
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = apple.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty
        else {
            finish(.failure(ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)))
            return
        }
        let name = apple.fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter().string(from: components)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return formatted.isEmpty ? nil : formatted
        }
        finish(.success(AppleSignInCredential(identityToken: token, nonce: hashedNonce, name: name)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorization = error as? ASAuthorizationError, authorization.code == .canceled {
            finish(.failure(ProviderSignInError.cancelled))
            return
        }
        finish(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        PresentationWindow.current
    }

    private func finish(_ result: Result<AppleSignInCredential, Error>) {
        controller = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

private struct GitHubSignInCredential {
    var code: String
    var redirectURI: String
}

private enum GitHubSignIn {
    static func request() async throws -> GitHubSignInCredential {
        guard let clientID = SignInClients.gitHubClientID else {
            throw ProviderSignInError.notConfigured(.github)
        }
        let state = SignInNonce.make(length: 24)
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: SignInClients.gitHubRedirectURI),
            URLQueryItem(name: "scope", value: "user:email"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidUrl)
        }
        let callback = try await WebLoginSession().start(url: url, scheme: SignInClients.gitHubCallbackScheme)
        return try credential(from: callback, state: state)
    }

    private static func credential(from callback: URL, state: String) throws -> GitHubSignInCredential {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.contains(where: { $0.name == "error" }) {
            throw ProviderSignInError.cancelled
        }
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)
        }
        return GitHubSignInCredential(code: code, redirectURI: SignInClients.gitHubRedirectURI)
    }
}

private enum GoogleSignIn {
    static func request() async throws -> String {
        guard let clientID = SignInClients.googleClientID,
              let redirect = redirectURI(clientID: clientID),
              let scheme = redirect.split(separator: ":").first.map(String.init)
        else {
            throw ProviderSignInError.notConfigured(.google)
        }
        let verifier = SignInNonce.make(length: 64)
        let state = SignInNonce.make(length: 24)
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge(verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "nonce", value: SignInNonce.make()),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        guard let url = components?.url else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidUrl)
        }
        let callback = try await WebLoginSession().start(url: url, scheme: scheme)
        let code = try authorizationCode(from: callback, state: state)
        return try await idToken(code: code, verifier: verifier, redirect: redirect, clientID: clientID)
    }

    /// An iOS client id redirects to its reversed form.
    private static func redirectURI(clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return nil }
        let prefix = clientID.dropLast(suffix.count)
        return "com.googleusercontent.apps.\(prefix):/oauth2callback"
    }

    private static func codeChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func authorizationCode(from callback: URL, state: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.contains(where: { $0.name == "error" }) {
            throw ProviderSignInError.cancelled
        }
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)
        }
        return code
    }

    private static func idToken(
        code: String,
        verifier: String,
        redirect: String,
        clientID: String
    ) async throws -> String {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidUrl)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]
        request.httpBody = Data((body.percentEncodedQuery ?? "").utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              !idToken.isEmpty
        else {
            throw ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)
        }
        return idToken
    }
}

@MainActor
private final class WebLoginSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: ASWebAuthenticationSession?

    func start(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callback, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        if let web = error as? ASWebAuthenticationSessionError, web.code == .canceledLogin {
                            self.finish(.failure(ProviderSignInError.cancelled))
                        } else {
                            self.finish(.failure(error))
                        }
                        return
                    }
                    guard let callback else {
                        self.finish(.failure(ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)))
                        return
                    }
                    self.finish(.success(callback))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                finish(.failure(ProviderSignInError.failed(AnyMetricsStrings.Error.invalidResponse)))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        PresentationWindow.current
    }

    private func finish(_ result: Result<URL, Error>) {
        session = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

private enum PresentationWindow {
    static var current: ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
