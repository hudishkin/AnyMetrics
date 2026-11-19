import XCTest
@testable import AnyMetrics

final class GenerationJobServiceTests: XCTestCase {

    private var transport: ScriptedTransport!
    private var defaultsName: String!
    private var defaults: UserDefaults!
    private var service: GenerationJobService!

    override func setUp() async throws {
        let transport = ScriptedTransport()
        self.transport = transport
        let name = "GenerationJobServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaultsName = name
        self.defaults = defaults
        let client = APIClient(
            baseURL: APIServer.local.baseURL,
            token: "session-token",
            transport: { request in
                try await transport.send(request)
            }
        )
        service = await MainActor.run {
            GenerationJobService(
                networking: client,
                defaults: defaults,
                serverID: { "local" },
                hasSession: { true },
                intervalNanoseconds: 1_000_000
            )
        }
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func testStartPollsUntilTheMetricIsReadyAndKeepsTheJob() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(queuedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]

        let started = try await service.start(prompt: "Star count", locale: "ru-RU")
        XCTAssertEqual(started.jobId, apiJobID)
        XCTAssertEqual(started.status, .queued)
        XCTAssertEqual(started.startedAt, started.createdAt)

        let generate = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(generate.httpMethod, "POST")
        XCTAssertEqual(generate.url?.path, "/v1/metrics/generate")
        XCTAssertEqual(generate.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
        let key = try XCTUnwrap(generate.value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertFalse(key.isEmpty)
        let body = apiObject(generate.httpBody)
        XCTAssertEqual(body["prompt"] as? String, "Star count")
        XCTAssertEqual(body["locale"] as? String, "ru-RU")

        await waitUntil { service.record(prompt: "Star count")?.status == .completed }
        let saved = await service.record(jobID: apiJobID)
        XCTAssertEqual(saved?.prompt, "Star count")
        XCTAssertEqual(saved?.startedAt, started.startedAt)
        XCTAssertEqual(saved?.createdAt, serverDate("2026-11-08T12:00:00.000Z"))
        XCTAssertEqual(saved?.job?.result?.metric.title, "AnyMetrics Stars")
        XCTAssertEqual(saved?.job?.result?.validation.sampleValue, "10")
        XCTAssertEqual(transport.requests.count, 3)

        let reloaded = await MainActor.run {
            GenerationJobService(
                networking: self.client(),
                defaults: self.defaults,
                serverID: { "local" },
                hasSession: { true },
                intervalNanoseconds: 1_000_000
            )
        }
        let requestsBeforeResume = transport.requests.count
        await reloaded.resume()
        let restored = await reloaded.record(prompt: "Star count")
        XCTAssertEqual(restored?.job?.result?.metric.title, "AnyMetrics Stars")
        XCTAssertEqual(restored?.status, .completed)
        XCTAssertEqual(transport.requests.count, requestsBeforeResume)
    }

    func testPollingStopsWhenTheJobNeedsInput() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(queuedJobJSON))),
            .success((200, apiJSON(needsInputJSON)))
        ]

        try await service.start(prompt: "Stars or forks", locale: "en-US")
        await waitUntil { service.record(prompt: "Stars or forks")?.status == .needsInput }

        XCTAssertEqual(transport.requests.count, 3)
        let question = await service.record(prompt: "Stars or forks")?.job?.question
        XCTAssertEqual(question?.text, "Stars or forks?")
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testAnswerContinuesTheSameJob() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(queuedJobJSON))),
            .success((200, apiJSON(needsInputJSON))),
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]

        try await service.start(prompt: "Stars or forks", locale: "en-US")
        await waitUntil { service.record(prompt: "Stars or forks")?.status == .needsInput }
        try await Task.sleep(nanoseconds: 50_000_000)

        let answered = try await service.answer(jobID: apiJobID, text: "stars")
        XCTAssertEqual(answered.jobId, apiJobID)
        XCTAssertEqual(answered.status, .queued)
        XCTAssertNil(answered.job?.question)

        let reply = try XCTUnwrap(transport.requests.first { $0.url?.path.hasSuffix("/answer") == true })
        XCTAssertEqual(reply.httpMethod, "POST")
        XCTAssertNil(reply.value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertEqual(apiObject(reply.httpBody)["text"] as? String, "stars")

        await waitUntil { service.record(jobID: apiJobID)?.status == .completed }
        let finished = await service.record(jobID: apiJobID)
        XCTAssertEqual(finished?.job?.result?.metric.title, "AnyMetrics Stars")
    }

    func testPaymentRequiredDropsTheSavedAttempt() async {
        let body = """
        {"error":{"code":"PAYMENT_REQUIRED","message":"The account balance is too low.","balance":0,"required":1}}
        """
        transport.responses = [.success((402, apiJSON(body)))]

        do {
            try await service.start(prompt: "Stars", locale: "ru-RU")
            XCTFail("Expected payment required")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertEqual(error.failure?.code, "PAYMENT_REQUIRED")
            XCTAssertEqual(error.failure?.required, 1)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        let jobs = await service.jobs
        XCTAssertTrue(jobs.isEmpty)
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testDroppedGenerateKeepsTheIdempotencyKeyAndTheNextStartRepeatsIt() async throws {
        transport.responses = [
            .failure(URLError(.networkConnectionLost)),
            .failure(URLError(.networkConnectionLost))
        ]

        do {
            try await service.start(prompt: "Star count", locale: "ru-RU")
            XCTFail("Expected the generate call to fail")
        } catch {
            XCTAssertTrue(error is URLError)
        }

        let kept = await service.record(prompt: "Star count")
        let key = try XCTUnwrap(kept?.idempotencyKey)
        XCTAssertNil(kept?.jobId)
        XCTAssertFalse(kept?.failure?.isEmpty ?? true)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }, [key, key])

        await service.resume()
        XCTAssertEqual(transport.requests.count, 2)
        let afterResume = await service.record(prompt: "Star count")
        XCTAssertEqual(afterResume?.idempotencyKey, key)
        XCTAssertNil(afterResume?.jobId)
        XCTAssertEqual(afterResume?.failure, kept?.failure)

        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]
        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }

        let generate = transport.requests[2]
        XCTAssertEqual(generate.value(forHTTPHeaderField: "Idempotency-Key"), key)
        let saved = await service.record(prompt: "Star count")
        XCTAssertEqual(saved?.jobId, apiJobID)
        XCTAssertEqual(saved?.job?.result?.metric.title, "AnyMetrics Stars")
    }

    func testBlankPromptDoesNotCallTheNetworkOrSaveAJob() async {
        do {
            try await service.start(prompt: " \n\t ", locale: "ru-RU")
            XCTFail("Expected an empty prompt to be rejected")
        } catch GenerationJobError.emptyPrompt {
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertTrue(transport.requests.isEmpty)
        let jobs = await service.jobs
        XCTAssertTrue(jobs.isEmpty)
    }

    func testPromptLongerThan2000DoesNotCallTheNetworkOrSaveAJob() async throws {
        let tooLong = String(repeating: "я", count: GenerationJobService.maximumPromptLength + 1)
        do {
            try await service.start(prompt: tooLong, locale: "ru-RU")
            XCTFail("Expected a long prompt to be rejected")
        } catch GenerationJobError.promptTooLong {
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertTrue(transport.requests.isEmpty)
        let jobs = await service.jobs
        XCTAssertTrue(jobs.isEmpty)

        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]
        let accepted = String(repeating: "a", count: GenerationJobService.maximumPromptLength)
        try await service.start(prompt: " \(accepted) ", locale: "ru-RU")
        await waitUntil { service.record(prompt: accepted)?.status == .completed }
        let body = apiObject(transport.requests.first?.httpBody)
        XCTAssertEqual((body["prompt"] as? String)?.count, GenerationJobService.maximumPromptLength)
    }

    func testPromptIsTrimmedBeforeItIsSentAndStored() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]

        try await service.start(prompt: "  Star count\n", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }

        let body = apiObject(transport.requests.first?.httpBody)
        XCTAssertEqual(body["prompt"] as? String, "Star count")
        let saved = await service.record(prompt: "Star count")
        XCTAssertEqual(saved?.prompt, "Star count")
    }

    func testSourceURLIsSentAndADifferentLocaleStartsASeparateSearch() async throws {
        let otherID = UUID(uuidString: "11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314")!
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON))),
            .success((202, apiJSON(acceptedJSON(otherID)))),
            .success((200, apiJSON(snapshotJSON(otherID, status: "completed"))))
        ]

        try await service.start(
            prompt: "Star count",
            locale: "ru-RU",
            sourceURL: "https://api.github.com/repos/hudishkin/AnyMetrics"
        )
        await waitUntil { service.jobs.contains { $0.jobId == apiJobID && $0.status == .completed } }

        let first = apiObject(transport.requests.first?.httpBody)
        XCTAssertEqual(first["sourceUrl"] as? String, "https://api.github.com/repos/hudishkin/AnyMetrics")

        try await service.start(prompt: "Star count", locale: "en-US")
        await waitUntil { service.jobs.contains { $0.jobId == otherID && $0.status == .completed } }

        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertNotEqual(
            posts[0].value(forHTTPHeaderField: "Idempotency-Key"),
            posts[1].value(forHTTPHeaderField: "Idempotency-Key")
        )
        let second = apiObject(posts[1].httpBody)
        XCTAssertEqual(second["locale"] as? String, "en-US")
        XCTAssertNil(second["sourceUrl"])
    }

    func testSimulationUsesTestModeAndARealSearchOfTheSamePromptStartsSeparately() async throws {
        let otherID = UUID(uuidString: "11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314")!
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(needsInputJSON))),
            .success((202, apiJSON(acceptedJSON(otherID)))),
            .success((200, apiJSON(snapshotJSON(otherID, status: "completed"))))
        ]

        try await service.start(prompt: "Star count", locale: "ru-RU", simulation: true)
        await waitUntil { service.record(prompt: "Star count")?.status == .needsInput }

        let simulationRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(simulationRequest.url?.path, "/v1/metrics/generate")
        XCTAssertEqual(simulationRequest.url?.query, "test=1")
        let simulated = await service.record(jobID: apiJobID)
        XCTAssertEqual(simulated?.simulation, true)

        try await service.start(prompt: "Star count", locale: "ru-RU", simulation: false)
        await waitUntil { service.jobs.contains { $0.jobId == otherID && $0.status == .completed } }

        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertNil(posts[1].url?.query)
        XCTAssertNotEqual(
            posts[0].value(forHTTPHeaderField: "Idempotency-Key"),
            posts[1].value(forHTTPHeaderField: "Idempotency-Key")
        )
        let real = await service.record(jobID: otherID)
        XCTAssertEqual(real?.simulation, false)
    }

    func testSamePromptAfterCompletionStartsANewSearch() async throws {
        let otherID = UUID(uuidString: "11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314")!
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON))),
            .success((202, apiJSON(acceptedJSON(otherID)))),
            .success((200, apiJSON(snapshotJSON(otherID, status: "completed"))))
        ]

        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.jobs.contains { $0.status == .completed } }
        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.jobs.filter { $0.status == .completed }.count == 2 }

        let keys = transport.requests
            .filter { $0.httpMethod == "POST" }
            .map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        XCTAssertEqual(keys.count, 2)
        XCTAssertNotEqual(keys[0], keys[1])
    }

    func testServerErrorRetriesTheSameKeyOnceAndASecondFailureKeepsIt() async throws {
        let failed = #"{"statusCode":500,"error":"Internal Server Error","message":"queue failed"}"#
        transport.responses = [
            .success((500, apiJSON(failed))),
            .success((500, apiJSON(failed)))
        ]

        do {
            try await service.start(prompt: "Star count", locale: "ru-RU")
            XCTFail("Expected the generate call to fail")
        } catch let error as BuilderAPI.ClientError {
            if case .status(500, _) = error {} else { XCTFail("Expected HTTP 500") }
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        let kept = await service.record(prompt: "Star count")
        let key = try XCTUnwrap(kept?.idempotencyKey)
        let active = await service.active
        XCTAssertNil(kept?.jobId)
        XCTAssertEqual(kept?.failure, "queue failed")
        XCTAssertNil(active)
        XCTAssertEqual(
            transport.requests.map { $0.value(forHTTPHeaderField: "Idempotency-Key") },
            [key, key]
        )
    }

    func testUnauthorizedAndConflictDropTheAttemptWithoutARetry() async {
        let unauthorized = #"{"error":{"code":"UNAUTHORIZED","message":"A session token is required."}}"#
        let conflict = #"{"error":{"code":"CONFLICT","message":"That key belongs to another account."}}"#
        transport.responses = [
            .success((401, apiJSON(unauthorized))),
            .success((409, apiJSON(conflict)))
        ]

        await assertStartRejected(prompt: "First", code: 401)
        await assertStartRejected(prompt: "Second", code: 409)
        let jobs = await service.jobs
        XCTAssertTrue(jobs.isEmpty)
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testBrokenAcceptedBodyRetriesTheSameKey() async throws {
        transport.responses = [
            .success((202, apiJSON("{}"))),
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(completedJobJSON)))
        ]

        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }

        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(
            posts[0].value(forHTTPHeaderField: "Idempotency-Key"),
            posts[1].value(forHTTPHeaderField: "Idempotency-Key")
        )
    }

    func testResumeContinuesAQueuedJobAndSkipsAFinishedOne() async throws {
        let store = GenerationJobStore(defaults: defaults)
        store.save([
            storedRecord(status: .queued),
            storedRecord(
                key: "done",
                id: UUID(uuidString: "11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314")!,
                status: .needsInput,
                prompt: "Already asked"
            )
        ], serverID: "local")
        transport.responses = [.success((200, apiJSON(completedJobJSON)))]

        await service.resume()
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.httpMethod, "GET")
        XCTAssertEqual(transport.requests.first?.url?.path, "/v1/jobs/\(apiJobID.uuidString.lowercased())")
        let paused = await service.jobs.first { $0.prompt == "Already asked" }
        XCTAssertEqual(paused?.status, .needsInput)
    }

    func testResumeWithoutASessionLoadsJobsAndDoesNotCallTheNetwork() async throws {
        GenerationJobStore(defaults: defaults).save([storedRecord(status: .queued)], serverID: "local")
        let signedOut = await makeService(hasSession: { false }) { request in
            try await self.transport.send(request)
        }

        await signedOut.resume()

        XCTAssertTrue(transport.requests.isEmpty)
        let jobs = await signedOut.jobs
        XCTAssertEqual(jobs.map(\.prompt), ["Star count"])
        XCTAssertEqual(jobs.first?.status, .queued)
    }

    func testPollSurvivesATransportErrorAndStopsOnNotFoundUnauthorizedOrCancelled() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .failure(URLError(.networkConnectionLost)),
            .success((200, apiJSON(completedJobJSON)))
        ]
        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }
        XCTAssertEqual(transport.requests.count, 3)
        let completed = await service.record(prompt: "Star count")
        XCTAssertNil(completed?.failure)

        let missing = #"{"error":{"code":"SOURCE_NOT_FOUND","message":"The job was not found."}}"#
        let unauthorized = #"{"error":{"code":"UNAUTHORIZED","message":"A session token is required."}}"#
        transport.responses = [
            .success((202, apiJSON(acceptedJSON(otherJobID)))),
            .success((404, apiJSON(missing)))
        ]
        try await service.start(prompt: "Missing", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Missing")?.status == .failed }
        let missingJob = await service.record(prompt: "Missing")
        XCTAssertEqual(missingJob?.failure, "The job was not found.")

        let beforeUnauthorized = transport.requests.count
        transport.responses = [
            .success((202, apiJSON(acceptedJSON(thirdJobID)))),
            .success((401, apiJSON(unauthorized)))
        ]
        try await service.start(prompt: "Signed out", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Signed out")?.status == .failed }
        let signedOut = await service.record(prompt: "Signed out")
        XCTAssertEqual(signedOut?.failure, "A session token is required.")

        transport.responses = [
            .success((202, apiJSON(acceptedJSON(fourthJobID)))),
            .success((200, apiJSON(snapshotJSON(fourthJobID, status: "cancelled"))))
        ]
        try await service.start(prompt: "Cancelled", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Cancelled")?.status == .cancelled }

        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(transport.requests.count, beforeUnauthorized + 4)
        let cancelled = await service.record(prompt: "Cancelled")
        XCTAssertNil(cancelled?.failure)
    }

    func testTerminalFailureFromTheServerStopsPollingAndKeepsTheMessage() async throws {
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((200, apiJSON(failedJobJSON)))
        ]

        try await service.start(prompt: "Weather", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Weather")?.status == .failed }

        let saved = await service.record(prompt: "Weather")
        XCTAssertEqual(saved?.failure, "The source responds only with a key.")
        XCTAssertEqual(saved?.job?.requirement?.kind, .apiKey)
        XCTAssertFalse(saved?.isPolling ?? true)
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testQueuedJobWithAStoredFailureStillResumesPolling() async throws {
        var record = storedRecord(status: .queued)
        record.failure = "try again"
        GenerationJobStore(defaults: defaults).save([record], serverID: "local")
        transport.responses = [.success((200, apiJSON(completedJobJSON)))]

        await service.resume()
        await waitUntil { service.record(jobID: apiJobID)?.status == .completed }

        XCTAssertEqual(transport.requests.count, 1)
        let saved = await service.record(jobID: apiJobID)
        XCTAssertNil(saved?.failure)
        XCTAssertEqual(saved?.startedAt, record.startedAt)
    }

    func testBadRequestAndConflictOnGetStopPolling() async throws {
        let bad = #"{"error":{"code":"BAD_REQUEST","message":"Bad job id."}}"#
        let conflict = #"{"error":{"code":"CONFLICT","message":"That key belongs to another account."}}"#
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((400, apiJSON(bad)))
        ]
        try await service.start(prompt: "Bad", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Bad")?.status == .failed }
        let badJob = await service.record(prompt: "Bad")
        XCTAssertEqual(badJob?.failure, "Bad job id.")

        transport.responses = [
            .success((202, apiJSON(acceptedJSON(otherJobID)))),
            .success((409, apiJSON(conflict)))
        ]
        try await service.start(prompt: "Conflict", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Conflict")?.status == .failed }
        let conflictJob = await service.record(prompt: "Conflict")
        XCTAssertEqual(conflictJob?.failure, "That key belongs to another account.")

        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(transport.requests.count, 4)
    }

    func testPollBackoffDoublesUntilTheCapAndResetsAfterARead() async throws {
        let log = SleepLog()
        let service = await makeService(sleep: { nanoseconds in
            log.add(nanoseconds)
        }) { request in
            try await self.transport.send(request)
        }
        let busy = #"{"statusCode":503,"error":"Service Unavailable","message":"busy"}"#
        transport.responses = [
            .success((202, apiJSON(acceptedJobJSON))),
            .success((503, apiJSON(busy))),
            .success((503, apiJSON(busy))),
            .success((200, apiJSON(queuedJobJSON))),
            .success((503, apiJSON(busy))),
            .success((503, apiJSON(busy))),
            .success((503, apiJSON(busy))),
            .success((503, apiJSON(busy))),
            .success((503, apiJSON(busy))),
            .success((200, apiJSON(completedJobJSON)))
        ]

        try await service.start(prompt: "Star count", locale: "ru-RU")
        await waitUntil { service.record(prompt: "Star count")?.status == .completed }

        let delays = log.delays
        XCTAssertEqual(
            delays,
            [
                1_000_000, 2_000_000, 1_000_000,
                1_000_000, 2_000_000, 4_000_000, 8_000_000, 15_000_000
            ]
        )
        let saved = await service.record(prompt: "Star count")
        XCTAssertEqual(saved?.status, .completed)
        XCTAssertNil(saved?.failure)
    }

    func testPromptLookupAndSortUseLocalStartTime() async {
        let olderStart = Date(timeIntervalSince1970: 100)
        let newerStart = Date(timeIntervalSince1970: 200)
        GenerationJobStore(defaults: defaults).save([
            storedRecord(
                key: "older-start",
                id: apiJobID,
                status: .completed,
                prompt: "Stars",
                startedAt: olderStart,
                createdAt: Date(timeIntervalSince1970: 9_000)
            ),
            storedRecord(
                key: "newer-start",
                id: otherJobID,
                status: .failed,
                prompt: "Stars",
                startedAt: newerStart,
                createdAt: Date(timeIntervalSince1970: 50)
            )
        ], serverID: "local")
        let signedOut = await makeService(hasSession: { false }) { request in
            try await self.transport.send(request)
        }

        await signedOut.resume()

        let picked = await signedOut.record(prompt: "Stars")
        XCTAssertEqual(picked?.idempotencyKey, "newer-start")
        let jobs = await signedOut.jobs
        XCTAssertEqual(jobs.map(\.idempotencyKey), ["newer-start", "older-start"])
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testSecondStartWhileTheFirstIsInFlightDoesNotSendAnotherSearch() async throws {
        let gate = RequestGate()
        let service = await makeService { request in
            try await gate.send(request)
        }
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }

        let second = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gate.requests.count, 1)

        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        let started = try await first.value
        let again = try await second.value
        XCTAssertEqual(started.jobId, apiJobID)
        XCTAssertEqual(again.jobId, apiJobID)
        XCTAssertEqual(started.idempotencyKey, again.idempotencyKey)
        await waitUntil { gate.requests.count == 2 }
        await MainActor.run { gate.respond(200, apiJSON(completedJobJSON)) }
        await waitUntil { service.record(prompt: "Stars")?.status == .completed }
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "POST" }.count, 1)
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "GET" }.count, 1)
    }

    func testSecondStartWhileTheFirstIsInFlightReceivesTheSameError() async throws {
        let gate = RequestGate()
        let service = await makeService { request in
            try await gate.send(request)
        }
        let body = """
        {"error":{"code":"PAYMENT_REQUIRED","message":"The account balance is too low.","balance":0,"required":1}}
        """
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }
        let second = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gate.requests.count, 1)

        await MainActor.run { gate.respond(402, apiJSON(body)) }
        await assertPaymentRequired(first)
        await assertPaymentRequired(second)
        let jobs = await service.jobs
        XCTAssertTrue(jobs.isEmpty)
        XCTAssertEqual(gate.requests.count, 1)
    }

    func testSamePromptWhilePollingDoesNotGenerateAgain() async throws {
        let gate = RequestGate()
        let service = await makeService { request in
            try await gate.send(request)
        }
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }
        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        _ = try await first.value
        await waitUntil { gate.requests.count == 2 }

        let again = try await service.start(prompt: "Stars", locale: "ru-RU")
        XCTAssertEqual(again.jobId, apiJobID)
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "POST" }.count, 1)
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "GET" }.count, 1)

        await MainActor.run { gate.respond(200, apiJSON(completedJobJSON)) }
        await waitUntil { service.record(prompt: "Stars")?.status == .completed }
        let saved = await service.record(prompt: "Stars")
        XCTAssertEqual(saved?.status, .completed)
        XCTAssertNil(saved?.failure)
    }

    func testScreenKeyStartsANewSearchEvenWhileTheSamePromptIsPolling() async throws {
        let gate = RequestGate()
        let service = await makeService { request in
            try await gate.send(request)
        }
        let firstKey = "screen-one"
        let secondKey = "screen-two"

        let first = Task {
            try await service.start(prompt: "Star count", locale: "ru-RU", idempotencyKey: firstKey)
        }
        await waitUntil { gate.requests.count == 1 }
        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        let started = try await first.value
        XCTAssertEqual(started.idempotencyKey, firstKey)
        await waitUntil { gate.requests.count == 2 }

        let again = try await service.start(prompt: "Star count", locale: "ru-RU", idempotencyKey: firstKey)
        XCTAssertEqual(again.idempotencyKey, firstKey)
        XCTAssertEqual(again.jobId, apiJobID)
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "POST" }.count, 1)

        let second = Task {
            try await service.start(prompt: "Star count", locale: "ru-RU", idempotencyKey: secondKey)
        }
        await waitUntil { gate.requests.filter { $0.httpMethod == "POST" }.count == 2 }
        let posts = gate.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }, [firstKey, secondKey])

        await MainActor.run { gate.respond(at: 1, 202, apiJSON(acceptedJSON(otherJobID))) }
        let created = try await second.value
        XCTAssertEqual(created.idempotencyKey, secondKey)
        XCTAssertEqual(created.jobId, otherJobID)
    }

    func testResumeWhilePollingDoesNotStartAnotherGet() async throws {
        let gate = RequestGate()
        let service = await makeService { request in
            try await gate.send(request)
        }
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }
        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        _ = try await first.value
        await waitUntil { gate.requests.count == 2 }

        await service.resume()
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(gate.requests.filter { $0.httpMethod == "GET" }.count, 1)

        await MainActor.run { gate.respond(200, apiJSON(completedJobJSON)) }
        await waitUntil { service.record(prompt: "Stars")?.status == .completed }
    }

    func testLateGetAfterServerSwitchDoesNotOverwriteTheFinishedJob() async throws {
        let box = ServerIDBox(id: "local")
        let gate = RequestGate()
        let service = await makeService(serverID: { box.id }) { request in
            try await gate.send(request)
        }
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }
        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        _ = try await first.value
        await waitUntil { gate.requests.count == 2 }

        await MainActor.run { box.id = "other" }
        await service.resume()
        await MainActor.run { box.id = "local" }
        await service.resume()
        await waitUntil { gate.requests.count == 3 }

        await MainActor.run {
            gate.respond(at: 1, 200, apiJSON(completedJobJSON))
        }
        await waitUntil { service.record(prompt: "Stars")?.status == .completed }
        await MainActor.run {
            gate.respond(
                at: 0,
                404,
                apiJSON(#"{"error":{"code":"SOURCE_NOT_FOUND","message":"The job was not found."}}"#)
            )
        }

        try await Task.sleep(nanoseconds: 40_000_000)
        let saved = await service.record(prompt: "Stars")
        XCTAssertEqual(saved?.status, .completed)
        XCTAssertEqual(saved?.job?.result?.metric.title, "AnyMetrics Stars")
        XCTAssertNil(saved?.failure)
        XCTAssertEqual(gate.requests.count, 3)
    }

    func testSwitchingServerDropsTheInFlightSnapshot() async throws {
        let box = ServerIDBox(id: "local")
        let gate = RequestGate()
        let service = await makeService(serverID: { box.id }) { request in
            try await gate.send(request)
        }
        let first = Task { try await service.start(prompt: "Stars", locale: "ru-RU") }
        await waitUntil { gate.requests.count == 1 }
        await MainActor.run { gate.respond(202, apiJSON(acceptedJobJSON)) }
        _ = try await first.value
        await waitUntil { gate.requests.count == 2 }

        await MainActor.run { box.id = "other" }
        await service.resume()
        let current = await service.jobs
        XCTAssertTrue(current.isEmpty)

        await MainActor.run { gate.respond(200, apiJSON(completedJobJSON)) }
        try await Task.sleep(nanoseconds: 40_000_000)

        let after = await service.jobs
        XCTAssertTrue(after.isEmpty)
        let store = GenerationJobStore(defaults: defaults)
        let local = store.load(serverID: "local")
        XCTAssertEqual(local.count, 1)
        XCTAssertEqual(local.first?.status, .queued)
        XCTAssertNil(local.first?.job)
        XCTAssertTrue(store.load(serverID: "other").isEmpty)
    }

    private func assertStartRejected(prompt: String, code: Int) async {
        do {
            try await service.start(prompt: prompt, locale: "ru-RU")
            XCTFail("Expected HTTP \(code)")
        } catch let error as BuilderAPI.ClientError {
            if case .status(let status, _) = error {
                XCTAssertEqual(status, code)
            } else {
                XCTFail("Expected HTTP \(code)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func assertPaymentRequired(_ task: Task<GenerationJobRecord, Error>) async {
        do {
            _ = try await task.value
            XCTFail("Expected payment required")
        } catch let error as BuilderAPI.ClientError {
            XCTAssertEqual(error.failure?.code, "PAYMENT_REQUIRED")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeService(
        serverID: @escaping @MainActor () -> String = { "local" },
        hasSession: @escaping @MainActor () -> Bool = { true },
        sleep: ((UInt64) async throws -> Void)? = nil,
        transport: @escaping (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async -> GenerationJobService {
        let defaults = self.defaults!
        let client = APIClient(
            baseURL: APIServer.local.baseURL,
            token: "session-token",
            transport: transport
        )
        return await MainActor.run {
            GenerationJobService(
                networking: client,
                defaults: defaults,
                serverID: serverID,
                hasSession: hasSession,
                intervalNanoseconds: 1_000_000,
                sleep: sleep
            )
        }
    }

    private func storedRecord(
        key: String = "saved-key",
        id: UUID = apiJobID,
        status: BuilderAPI.JobStatus,
        prompt: String = "Star count",
        startedAt: Date = Date(timeIntervalSince1970: 1_762_000_000),
        createdAt: Date = Date(timeIntervalSince1970: 1_762_000_000)
    ) -> GenerationJobRecord {
        GenerationJobRecord(
            idempotencyKey: key,
            prompt: prompt,
            locale: "ru-RU",
            sourceURL: nil,
            jobId: id,
            status: status,
            startedAt: startedAt,
            createdAt: createdAt,
            job: nil,
            failure: nil
        )
    }

    private func client() -> APIClient {
        let transport = self.transport!
        return APIClient(
            baseURL: APIServer.local.baseURL,
            token: "session-token",
            transport: { request in
                try await transport.send(request)
            }
        )
    }

    private func serverDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }

    private func waitUntil(_ predicate: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if await MainActor.run(body: predicate) {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for the job")
    }
}

private let acceptedJobJSON = #"{"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"queued"}"#

private let queuedJobJSON = """
{"jobId":"80d9fc21-3e2d-41b6-93ec-0d5474cb0758","status":"queued","prompt":"Star count","createdAt":"2026-11-08T12:00:00.000Z"}
"""

private let otherJobID = UUID(uuidString: "11a0b2c3-4d5e-4f60-a7b8-c9d0e1f20314")!
private let thirdJobID = UUID(uuidString: "22b1c3d4-5e6f-4071-b8c9-d0e1f2031425")!
private let fourthJobID = UUID(uuidString: "33c2d4e5-6f70-4182-c9d0-e1f203142536")!

private let failedJobJSON = """
{
  "jobId": "80d9fc21-3e2d-41b6-93ec-0d5474cb0758",
  "status": "failed",
  "prompt": "Weather",
  "createdAt": "2026-11-08T12:00:00.000Z",
  "error": {"code": "AUTH_REQUIRED", "message": "The source responds only with a key."},
  "requirement": {"kind": "api_key", "text": "Get a key from the provider.", "url": "https://openweathermap.org/api"}
}
"""

private func acceptedJSON(_ id: UUID, status: String = "queued") -> String {
    #"{"jobId":"\#(id.uuidString.lowercased())","status":"\#(status)"}"#
}

private func snapshotJSON(_ id: UUID, status: String) -> String {
    """
    {"jobId":"\(id.uuidString.lowercased())","status":"\(status)","prompt":"Star count","createdAt":"2026-11-08T12:00:00.000Z"}
    """
}

final class GenerationJobStoreTests: XCTestCase {
    private var defaultsName: String!
    private var defaults: UserDefaults!
    private var store: GenerationJobStore!

    override func setUp() {
        let name = "GenerationJobStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaultsName = name
        self.defaults = defaults
        store = GenerationJobStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    func testRoundTripKeepsTheAttemptAndDoesNotMixServers() throws {
        let record = GenerationJobRecord(
            idempotencyKey: "key-1",
            prompt: "Star count",
            locale: "ru-RU",
            sourceURL: "https://api.github.com/repos/hudishkin/AnyMetrics",
            jobId: apiJobID,
            status: .queued,
            startedAt: Date(timeIntervalSince1970: 1_762_000_000),
            createdAt: Date(timeIntervalSince1970: 1_762_531_200),
            job: nil,
            failure: "try again"
        )
        store.save([record], serverID: "local")
        store.save([], serverID: "other")

        let loaded = store.load(serverID: "local")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.idempotencyKey, "key-1")
        XCTAssertEqual(loaded.first?.sourceURL, record.sourceURL)
        XCTAssertEqual(loaded.first?.failure, "try again")
        XCTAssertEqual(loaded.first?.jobId, apiJobID)
        XCTAssertEqual(
            loaded.first?.createdAt.timeIntervalSince1970 ?? 0,
            record.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(
            loaded.first?.startedAt.timeIntervalSince1970 ?? 0,
            record.startedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertTrue(store.load(serverID: "other").isEmpty)
        XCTAssertTrue(store.load(serverID: "missing").isEmpty)
    }

    func testPlainISO8601DatesAndACorruptBlob() throws {
        let plain = """
        [{
          "idempotencyKey": "plain",
          "prompt": "Stars",
          "locale": "ru-RU",
          "status": "running",
          "createdAt": "2026-11-08T12:00:00Z"
        }]
        """
        defaults.set(Data(plain.utf8), forKey: "generation.jobs.local")

        let loaded = store.load(serverID: "local")
        let expected = ISO8601DateFormatter()
        expected.formatOptions = [.withInternetDateTime]
        XCTAssertEqual(loaded.first?.status, .running)
        XCTAssertEqual(loaded.first?.createdAt, expected.date(from: "2026-11-08T12:00:00Z"))
        XCTAssertEqual(loaded.first?.startedAt, loaded.first?.createdAt)
        XCTAssertEqual(loaded.first?.simulation, false)

        defaults.set(Data("not-json".utf8), forKey: "generation.jobs.local")
        XCTAssertTrue(store.load(serverID: "local").isEmpty)
        XCTAssertEqual(defaults.data(forKey: "generation.jobs.local.corrupt"), Data("not-json".utf8))

        defaults.set(Data("still-bad".utf8), forKey: "generation.jobs.local")
        XCTAssertTrue(store.load(serverID: "local").isEmpty)
        XCTAssertEqual(defaults.data(forKey: "generation.jobs.local.corrupt"), Data("not-json".utf8))

        store.save([
            GenerationJobRecord(
                idempotencyKey: "kept",
                prompt: "Stars",
                locale: "ru-RU",
                sourceURL: nil,
                jobId: nil,
                status: nil,
                startedAt: Date(timeIntervalSince1970: 10),
                createdAt: Date(timeIntervalSince1970: 10),
                job: nil,
                failure: nil
            )
        ], serverID: "local")
        XCTAssertEqual(store.load(serverID: "local").first?.idempotencyKey, "kept")
        XCTAssertEqual(defaults.data(forKey: "generation.jobs.local.corrupt"), Data("not-json".utf8))
    }

    func testLiveJobIsTheNewestSessionStillOpen() {
        let older = UUID()
        let waiting = UUID()
        let jobs = [
            jobRecord(id: older, status: .running, startedAt: 10),
            jobRecord(id: waiting, status: .needsInput, startedAt: 20),
            jobRecord(id: UUID(), status: .completed, startedAt: 30),
            jobRecord(id: nil, status: .queued, startedAt: 40),
            jobRecord(id: UUID(), status: .failed, startedAt: 50),
            jobRecord(id: UUID(), status: .cancelled, startedAt: 60)
        ]

        XCTAssertEqual(GenerationJobService.liveJob(in: jobs)?.jobId, waiting)
        XCTAssertNil(GenerationJobService.liveJob(in: []))
    }

    private func jobRecord(
        id: UUID?,
        status: BuilderAPI.JobStatus?,
        startedAt: TimeInterval
    ) -> GenerationJobRecord {
        let started = Date(timeIntervalSince1970: startedAt)
        return GenerationJobRecord(
            idempotencyKey: id?.uuidString ?? "missing-\(startedAt)",
            prompt: "Stars",
            locale: "ru-RU",
            sourceURL: nil,
            jobId: id,
            status: status,
            startedAt: started,
            createdAt: started,
            job: nil,
            failure: nil
        )
    }
}

private final class SleepLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UInt64] = []

    func add(_ value: UInt64) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    var delays: [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

final class RequestGate {
    private(set) var requests: [URLRequest] = []
    private var waiters: [CheckedContinuation<(Int, Data), Error>] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (status, body) = try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
        let url = request.url ?? URL(string: "http://127.0.0.1:3000")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }

    func respond(_ status: Int, _ data: Data) {
        waiters.removeFirst().resume(returning: (status, data))
    }

    func respond(at index: Int, _ status: Int, _ data: Data) {
        waiters.remove(at: index).resume(returning: (status, data))
    }
}

final class ServerIDBox {
    var id: String
    init(id: String) { self.id = id }
}

final class GeneratedMetricAdapterTests: XCTestCase {
    func testCompletedJobBecomesTheDashboardCard() throws {
        let job = try Self.decoder.decode(BuilderAPI.Job.self, from: Data(completedJobJSON.utf8))
        let metric = try XCTUnwrap(GeneratedMetricAdapter.metric(from: job))

        XCTAssertEqual(metric.id, UUID(uuidString: "b3c1c2e0-7c2a-4e0a-9a1a-6c1e0b7a1111"))
        XCTAssertEqual(metric.title, "AnyMetrics Stars")
        XCTAssertEqual(metric.measure, "Stars")
        XCTAssertEqual(metric.type, .json)
        XCTAssertEqual(metric.resultKind, .content)
        XCTAssertEqual(metric.result, "10")
        XCTAssertFalse(metric.resultWithError)
        XCTAssertEqual(metric.request?.method, "GET")
        XCTAssertEqual(metric.request?.url.absoluteString, "https://api.github.com/repos/hudishkin/AnyMetrics")
        XCTAssertEqual(metric.rules?.parseRules, "stargazers_count")
        XCTAssertEqual(metric.interval, 21600)
        XCTAssertEqual(metric.author, "GitHub")
        XCTAssertEqual(metric.website?.absoluteString, "https://github.com")
        XCTAssertEqual(metric.created, job.createdAt)
    }

    func testStatusResultUsesTheCheckAndAnUnfinishedJobIsNotACard() throws {
        let body = """
        {
          "jobId": "80d9fc21-3e2d-41b6-93ec-0d5474cb0758",
          "status": "completed",
          "prompt": "Site up",
          "createdAt": "2026-11-08T12:00:00Z",
          "result": {
            "metric": {
              "id": "not-a-uuid",
              "title": "Site",
              "measure": "",
              "type": "checkStatus",
              "resultKind": "content",
              "interval": 600,
              "request": {"url": "https://example.com", "method": "HEAD", "headers": {}},
              "formatter": {"format": "none"},
              "rules": {"type": "none", "caseSensitive": false}
            },
            "validation": {
              "success": true,
              "valueKind": "status",
              "status": false,
              "validatedAt": "2026-11-08T12:00:00Z"
            },
            "source": {"kind": "public_api", "url": "https://example.com"}
          }
        }
        """
        let job = try Self.decoder.decode(BuilderAPI.Job.self, from: Data(body.utf8))
        let metric = try XCTUnwrap(GeneratedMetricAdapter.metric(from: job))
        XCTAssertEqual(metric.type, .checkStatus)
        XCTAssertEqual(metric.request?.method, "HEAD")
        XCTAssertEqual(metric.result, "")
        XCTAssertTrue(metric.resultWithError)
        XCTAssertNotEqual(metric.id, UUID(uuidString: "not-a-uuid"))

        var queued = job
        queued.status = .queued
        queued.result = nil
        XCTAssertNil(GeneratedMetricAdapter.metric(from: queued))
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: value))
        }
        return decoder
    }()
}
