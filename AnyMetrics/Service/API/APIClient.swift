import Foundation

/// HTTP client for one Builder API base URL.
///
/// A 401 on a signed-in call means the stored session is no longer valid.
/// A 401 on Apple, Google, or GitHub sign-in rejects only that credential and
/// must not clear a session that is already stored.
struct APIClient {
    var baseURL: URL
    var token: String?
    var transport: (URLRequest) async throws -> (Data, HTTPURLResponse)

    func health() async throws -> BuilderAPI.Health {
        try await decode(method: "GET", path: "/health", authenticated: false, success: [200])
    }

    func signInProviders() async throws -> BuilderAPI.AuthProviders {
        try await decode(method: "GET", path: "/v1/auth/providers", authenticated: false, success: [200])
    }

    func signInWithApple(_ body: BuilderAPI.AppleSignIn) async throws -> BuilderAPI.Session {
        try await submit(method: "POST", path: "/v1/auth/apple", body: body, authenticated: false, success: [200])
    }

    func signInWithGoogle(_ body: BuilderAPI.GoogleSignIn) async throws -> BuilderAPI.Session {
        try await submit(method: "POST", path: "/v1/auth/google", body: body, authenticated: false, success: [200])
    }

    func signInWithGitHub(_ body: BuilderAPI.GitHubSignIn) async throws -> BuilderAPI.Session {
        try await submit(method: "POST", path: "/v1/auth/github", body: body, authenticated: false, success: [200])
    }

    func logOut() async throws {
        try await sendEmpty(method: "POST", path: "/v1/auth/logout", authenticated: true, success: [204])
    }

    func me() async throws -> BuilderAPI.Account {
        try await decode(method: "GET", path: "/v1/me", authenticated: true, success: [200])
    }

    func billing() async throws -> BuilderAPI.Billing {
        try await decode(method: "GET", path: "/v1/billing", authenticated: true, success: [200])
    }

    func verifyAppleTransaction(_ body: BuilderAPI.AppleTransaction) async throws -> BuilderAPI.AppleTransactionResult {
        try await submit(
            method: "POST",
            path: "/v1/billing/apple/transactions",
            body: body,
            authenticated: true,
            success: [200]
        )
    }

    func generate(
        _ body: BuilderAPI.GenerateRequest,
        idempotencyKey: String? = nil
    ) async throws -> BuilderAPI.AcceptedJob {
        var headers: [String: String] = [:]
        if let idempotencyKey, !idempotencyKey.isEmpty {
            headers["Idempotency-Key"] = idempotencyKey
        }
        return try await submit(
            method: "POST",
            path: "/v1/metrics/generate",
            body: body,
            headers: headers,
            authenticated: true,
            success: [202]
        )
    }

    func validate(_ body: BuilderAPI.ValidateRequest) async throws -> BuilderAPI.ValidateResponse {
        try await submit(method: "POST", path: "/v1/metrics/validate", body: body, authenticated: false, success: [200])
    }

    func jobs() async throws -> BuilderAPI.JobList {
        try await decode(method: "GET", path: "/v1/jobs", authenticated: true, success: [200])
    }

    func job(_ id: UUID) async throws -> BuilderAPI.Job {
        try await decode(method: "GET", path: "/v1/jobs/\(id.uuidString.lowercased())", authenticated: true, success: [200])
    }

    func answer(job id: UUID, text: String) async throws -> BuilderAPI.AcceptedJob {
        try await submit(
            method: "POST",
            path: "/v1/jobs/\(id.uuidString.lowercased())/answer",
            body: BuilderAPI.AnswerRequest(text: text),
            authenticated: true,
            success: [202]
        )
    }

    func cancel(job id: UUID) async throws -> BuilderAPI.CancelledJob {
        try await decode(
            method: "POST",
            path: "/v1/jobs/\(id.uuidString.lowercased())/cancel",
            authenticated: true,
            success: [200]
        )
    }

    /// Yields each poll. Stops on `needs_input`, `completed`, `failed`, or `cancelled`.
    func watchJob(
        _ id: UUID,
        intervalNanoseconds: UInt64 = 1_000_000_000
    ) -> AsyncThrowingStream<BuilderAPI.Job, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        let job = try await self.job(id)
                        continuation.yield(job)
                        if !job.status.isPolling {
                            continuation.finish()
                            return
                        }
                        try await Task.sleep(nanoseconds: intervalNanoseconds)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BuilderAPI.ClientError.invalidResponse
            }
            return (data, http)
        } catch let error as BuilderAPI.ClientError {
            throw error
        } catch let error as URLError {
            throw BuilderAPI.ClientError.transport(error)
        } catch {
            throw BuilderAPI.ClientError.transport(URLError(.unknown))
        }
    }
}

extension APIClient {
    fileprivate static let encoder = JSONEncoder()

    fileprivate static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parseDate(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: value)
        }
        return decoder
    }()

    private func submit<Response: Decodable, Body: Encodable>(
        method: String,
        path: String,
        body: Body,
        headers: [String: String] = [:],
        authenticated: Bool,
        success: Set<Int>
    ) async throws -> Response {
        try await decode(
            method: method,
            path: path,
            body: try Self.encode(body),
            headers: headers,
            authenticated: authenticated,
            success: success
        )
    }

    private func decode<Response: Decodable>(
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String] = [:],
        authenticated: Bool,
        success: Set<Int>
    ) async throws -> Response {
        let (data, response) = try await perform(
            method: method,
            path: path,
            body: body,
            headers: headers,
            authenticated: authenticated
        )
        guard success.contains(response.statusCode) else {
            throw BuilderAPI.ClientError.status(response.statusCode, Self.failure(from: data))
        }
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw BuilderAPI.ClientError.invalidResponse
        }
    }

    private func sendEmpty(
        method: String,
        path: String,
        authenticated: Bool,
        success: Set<Int>
    ) async throws {
        let (data, response) = try await perform(
            method: method,
            path: path,
            body: nil,
            headers: [:],
            authenticated: authenticated
        )
        guard success.contains(response.statusCode) else {
            throw BuilderAPI.ClientError.status(response.statusCode, Self.failure(from: data))
        }
    }

    private func perform(
        method: String,
        path: String,
        body: Data?,
        headers: [String: String],
        authenticated: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw BuilderAPI.ClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if authenticated {
            guard let token, !token.isEmpty else {
                throw BuilderAPI.ClientError.missingSession
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await transport(request)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: strippingNulls(json))
    }

    private static func strippingNulls(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var copy: [String: Any] = [:]
            for (key, item) in dictionary where !(item is NSNull) {
                copy[key] = strippingNulls(item)
            }
            return copy
        }
        if let array = value as? [Any] {
            return array.map { strippingNulls($0) }
        }
        return value
    }

    private static func failure(from data: Data) -> BuilderAPI.Failure? {
        guard !data.isEmpty else { return nil }
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            return envelope.error
        }
        if let fastify = try? decoder.decode(FastifyError.self, from: data) {
            return BuilderAPI.Failure(code: nil, message: fastify.message, balance: nil, required: nil)
        }
        return nil
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private struct ErrorEnvelope: Decodable {
        var error: BuilderAPI.Failure
    }

    private struct FastifyError: Decodable {
        var statusCode: Int
        var message: String
    }
}
