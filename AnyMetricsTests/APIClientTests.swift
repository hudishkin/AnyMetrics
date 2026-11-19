import XCTest
@testable import AnyMetrics

final class APIClientTests: XCTestCase {

    private var transport: ScriptedTransport!
    private var client: APIClient!

    override func setUp() {
        let transport = ScriptedTransport()
        self.transport = transport
        client = APIClient(
            baseURL: APIServer.local.baseURL,
            token: "session-token",
            transport: { request in
                try await transport.send(request)
            }
        )
    }

    func testHealthUsesTheLocalOriginAndNoSession() async throws {
        client.token = "session-token"
        transport.responses = [.success((200, apiJSON(#"{"status":"ok"}"#)))]

        let health = try await client.health()

        XCTAssertEqual(health.status, .ok)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:3000/health")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request.httpBody)
    }

    func testSignInProvidersOmitsUnconfiguredProvidersAndNeedsNoSession() async throws {
        transport.responses = [.success((200, apiJSON(#"{"providers":["apple","google"]}"#)))]

        let providers = try await client.signInProviders()

        XCTAssertEqual(providers.providers, [.apple, .google])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/v1/auth/providers")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testAppleSignInOmitsEmptyFieldsAndDoesNotSendTheStoredToken() async throws {
        transport.responses = [.success((200, apiJSON(apiSessionJSON)))]

        let session = try await client.signInWithApple(
            BuilderAPI.AppleSignIn(identityToken: "apple-token", name: "Ada")
        )

        XCTAssertEqual(session.token, "opaque-session-token")
        XCTAssertEqual(session.user.id, apiUserID)
        XCTAssertEqual(session.user.email, "ada@privaterelay.appleid.com")
        XCTAssertEqual(session.balance, 0)
        XCTAssertFalse(session.paid)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/auth/apple")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = apiObject(request.httpBody)
        XCTAssertEqual(body["identityToken"] as? String, "apple-token")
        XCTAssertEqual(body["name"] as? String, "Ada")
        XCTAssertNil(body["nonce"])
    }

    func testGenerateSendsTheBearerTokenAndIdempotencyKey() async throws {
        let job = #"{"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"queued"}"#
        transport.responses = [.success((202, apiJSON(job)))]

        let accepted = try await client.generate(
            BuilderAPI.GenerateRequest(prompt: "Star count", locale: "ru-RU"),
            idempotencyKey: "one-search"
        )

        XCTAssertEqual(accepted.jobId, apiJobID)
        XCTAssertEqual(accepted.status, .queued)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "one-search")
        XCTAssertNil(request.url?.query)
        let body = apiObject(request.httpBody)
        XCTAssertEqual(body["prompt"] as? String, "Star count")
        XCTAssertEqual(body["locale"] as? String, "ru-RU")
        XCTAssertNil(body["sourceUrl"])
    }

    func testMissingSessionDoesNotHitTheNetwork() async {
        client.token = nil

        do {
            _ = try await client.me()
            XCTFail("Expected a missing session")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertEqual(error, .missingSession)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPaymentRequiredExposesBalanceAndCost() async {
        let body = """
        {"error":{"code":"PAYMENT_REQUIRED","message":"The account balance is too low.","balance":0,"required":1}}
        """
        transport.responses = [.success((402, apiJSON(body)))]

        do {
            _ = try await client.generate(BuilderAPI.GenerateRequest(prompt: "Stars"))
            XCTFail("Expected payment required")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertEqual(error.failure?.code, "PAYMENT_REQUIRED")
            XCTAssertEqual(error.failure?.balance, 0)
            XCTAssertEqual(error.failure?.required, 1)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testFastifyErrorHasNoApplicationCode() async {
        let body = #"{"statusCode":500,"error":"Internal Server Error","message":"queue failed"}"#
        transport.responses = [.success((500, apiJSON(body)))]

        do {
            _ = try await client.billing()
            XCTFail("Expected a server error")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertEqual(error.failure?.code, nil)
            XCTAssertEqual(error.failure?.message, "queue failed")
            if case .status(500, _) = error {} else {
                XCTFail("Expected HTTP 500")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testCompletedJobDecodesTheMetricAndValidationTime() async throws {
        transport.responses = [.success((200, apiJSON(completedJobJSON)))]

        let job = try await client.job(apiJobID)

        XCTAssertEqual(job.status, .completed)
        XCTAssertEqual(job.result?.metric.title, "AnyMetrics Stars")
        XCTAssertEqual(job.result?.metric.type, .json)
        XCTAssertEqual(job.result?.metric.request.headers, [:])
        XCTAssertEqual(job.result?.validation.sampleValue, "10")
        XCTAssertEqual(job.result?.source.kind, .publicAPI)
        XCTAssertEqual(job.result?.source.name, "GitHub")
        XCTAssertEqual(job.result?.source.website, "https://github.com")
        XCTAssertEqual(job.result?.metric.author, "GitHub")
        XCTAssertEqual(job.result?.metric.website, "https://github.com")
        XCTAssertNil(job.simulation)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(
            job.result?.validation.validatedAt,
            formatter.date(from: "2026-11-05T12:00:00.000Z")
        )
        XCTAssertEqual(
            transport.requests.first?.url?.absoluteString,
            "http://127.0.0.1:3000/v1/jobs/80d9fc21-3e2d-41b6-93ec-0d5474cb0758"
        )
    }

    func testNeedsInputAndAuthRequiredKeepTheirExtraFields() async throws {
        transport.responses = [
            .success((200, apiJSON(needsInputJSON))),
            .success((200, apiJSON(authRequiredJSON)))
        ]

        let question = try await client.job(apiJobID)
        XCTAssertEqual(question.status, .needsInput)
        XCTAssertEqual(question.question?.options, ["Stars", "Forks"])
        XCTAssertEqual(question.question?.allowsFreeText, true)

        let failed = try await client.job(apiJobID)
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.error?.code, "AUTH_REQUIRED")
        XCTAssertEqual(failed.requirement?.kind, .apiKey)
        XCTAssertEqual(failed.draft?.validated, false)
        XCTAssertEqual(failed.draft?.metric.rules.parseRules, "main.temp")
    }

    func testValidateDoesNotSendASession() async throws {
        let body = """
        {"validation":{"success":false,"message":"missed","validatedAt":"2026-11-05T12:00:00Z"}}
        """
        transport.responses = [.success((200, apiJSON(body)))]
        let metric = BuilderAPI.MetricInput(title: "Stars", measure: "Stars", type: .json)

        let response = try await client.validate(BuilderAPI.ValidateRequest(metric: metric))

        XCTAssertFalse(response.validation.success)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.url?.path, "/v1/metrics/validate")
    }

    func testJobsListsTheAccountNewestFirst() async throws {
        let body = """
        {"jobs":[
          {"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"completed","prompt":"Star count","createdAt":"2026-11-08T12:00:00.000Z"},
          {"jobId":"11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314","status":"failed","prompt":"погода в Москве","createdAt":"2026-11-08T11:00:00.000Z"}
        ]}
        """
        transport.responses = [.success((200, apiJSON(body)))]

        let list = try await client.jobs()

        XCTAssertEqual(list.jobs.map(\.status), [.completed, .failed])
        XCTAssertEqual(list.jobs.map(\.prompt), ["Star count", "погода в Москве"])
        XCTAssertEqual(list.jobs.first?.jobId, apiJobID)
        XCTAssertNil(list.jobs.first?.question)
        XCTAssertNil(list.jobs.first?.simulation)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/v1/jobs")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
    }

    func testSimulationGenerateSendsTestModeAndKeepsTheFlagOnTheJob() async throws {
        let queued = #"{"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"queued"}"#
        let waiting = """
        {"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"needs_input","simulation":true,"prompt":"погода","createdAt":"2026-11-08T12:00:00.000Z","question":{"text":"Какой показатель показать?","options":["Значение","Изменение"],"allowsFreeText":true}}
        """
        let list = """
        {"jobs":[{"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"needs_input","prompt":"погода","createdAt":"2026-11-08T12:00:00.000Z","simulation":true,"question":{"text":"Какой показатель показать?","options":["Значение","Изменение"],"allowsFreeText":true}}]}
        """
        transport.responses = [
            .success((202, apiJSON(queued))),
            .success((200, apiJSON(waiting))),
            .success((200, apiJSON(list)))
        ]

        let accepted = try await client.generate(
            BuilderAPI.GenerateRequest(prompt: "погода", locale: "ru-RU"),
            idempotencyKey: "sim",
            simulation: true
        )

        XCTAssertEqual(accepted.status, .queued)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/metrics/generate")
        XCTAssertEqual(request.url?.query, "test=1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "sim")

        let job = try await client.job(apiJobID)
        XCTAssertEqual(job.simulation, true)
        XCTAssertEqual(job.question?.options, ["Значение", "Изменение"])

        let summary = try await client.jobs().jobs.first
        XCTAssertEqual(summary?.simulation, true)
        XCTAssertEqual(summary?.question?.text, "Какой показатель показать?")
        XCTAssertEqual(summary?.question?.allowsFreeText, true)
    }
}

let completedJobJSON = """
{
  "jobId": "80d9fc21-3e2d-41b6-93ec-0d5474cb0758",
  "status": "completed",
  "prompt": "Star count",
  "createdAt": "2026-11-08T12:00:00.000Z",
  "result": {
    "metric": {
      "id": "b3c1c2e0-7c2a-4e0a-9a1a-6c1e0b7a1111",
      "title": "AnyMetrics Stars",
      "measure": "Stars",
      "type": "json",
      "resultKind": "content",
      "interval": 21600,
      "request": {
        "url": "https://api.github.com/repos/hudishkin/AnyMetrics",
        "method": "GET",
        "headers": {}
      },
      "formatter": { "format": "none" },
      "rules": { "type": "none", "parseRules": "stargazers_count", "caseSensitive": false },
      "author": "GitHub",
      "website": "https://github.com"
    },
    "validation": {
      "success": true,
      "valueKind": "content",
      "rawValue": "10",
      "sampleValue": "10",
      "statusCode": 200,
      "finalUrl": "https://api.github.com/repos/hudishkin/AnyMetrics",
      "validatedAt": "2026-11-05T12:00:00.000Z"
    },
    "source": {
      "kind": "public_api",
      "name": "GitHub",
      "url": "https://api.github.com/repos/hudishkin/AnyMetrics",
      "website": "https://github.com"
    }
  }
}
"""

let needsInputJSON = """
{
  "jobId": "80d9fc21-3e2d-41b6-93ec-0d5474cb0758",
  "status": "needs_input",
  "prompt": "Stars or forks of hudishkin/AnyMetrics",
  "createdAt": "2026-11-08T12:00:00.000Z",
  "question": { "text": "Stars or forks?", "options": ["Stars", "Forks"], "allowsFreeText": true }
}
"""

private let authRequiredJSON = """
{
  "jobId": "80d9fc21-3e2d-41b6-93ec-0d5474cb0758",
  "status": "failed",
  "prompt": "погода в Москве",
  "createdAt": "2026-11-08T12:00:00.000Z",
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "The source responds only with a key."
  },
  "requirement": {
    "kind": "api_key",
    "text": "Get a key from the provider.",
    "url": "https://openweathermap.org/api"
  },
  "draft": {
    "validated": false,
    "metric": {
      "id": "b3c1c2e0-7c2a-4e0a-9a1a-6c1e0b7a1111",
      "title": "Weather",
      "measure": "°C",
      "type": "json",
      "resultKind": "content",
      "interval": 21600,
      "request": {
        "url": "https://api.openweathermap.org/data/2.5/weather",
        "method": "GET",
        "headers": {}
      },
      "formatter": { "format": "none" },
      "rules": { "type": "none", "parseRules": "main.temp", "caseSensitive": false }
    }
  }
}
"""
