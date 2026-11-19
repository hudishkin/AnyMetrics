import Foundation

/// Generate and job reads used by `GenerationJobService`. `APIClient` already implements this.
protocol GenerationNetworking {
    func generate(
        _ body: BuilderAPI.GenerateRequest,
        idempotencyKey: String?,
        simulation: Bool
    ) async throws -> BuilderAPI.AcceptedJob

    func job(_ id: UUID) async throws -> BuilderAPI.Job

    func answer(job id: UUID, text: String) async throws -> BuilderAPI.AcceptedJob
}

extension APIClient: GenerationNetworking {}

enum GenerationJobError: Error, Equatable {
    case emptyPrompt
    case promptTooLong
}

/// Signed-in generate and job calls. A 401 clears the session for the current server.
struct SessionGenerationNetworking: GenerationNetworking {
    func generate(
        _ body: BuilderAPI.GenerateRequest,
        idempotencyKey: String?,
        simulation: Bool
    ) async throws -> BuilderAPI.AcceptedJob {
        try await AuthSession.shared.authorized { client in
            try await client.generate(body, idempotencyKey: idempotencyKey, simulation: simulation)
        }
    }

    func job(_ id: UUID) async throws -> BuilderAPI.Job {
        try await AuthSession.shared.authorized { client in
            try await client.job(id)
        }
    }

    func answer(job id: UUID, text: String) async throws -> BuilderAPI.AcceptedJob {
        try await AuthSession.shared.authorized { client in
            try await client.answer(job: id, text: text)
        }
    }
}

/// Starts a metric search, stores the job, and polls it about once a second while it is `queued` or `running`.
@MainActor
final class GenerationJobService: ObservableObject {
    static let maximumPromptLength = 2000
    static let shared = GenerationJobService(networking: SessionGenerationNetworking())

    @Published private(set) var jobs: [GenerationJobRecord] = []

    private let networking: GenerationNetworking
    private let store: GenerationJobStore
    private let serverID: @MainActor () -> String
    private let hasSession: @MainActor () -> Bool
    private let intervalNanoseconds: UInt64
    private let now: () -> Date
    private let sleep: (UInt64) async throws -> Void

    private var loadedServerID: String?
    private var polls: [UUID: LivePoll] = [:]
    private var submissions: [String: Task<GenerationJobRecord, Error>] = [:]
    private var answers: [UUID: Task<GenerationJobRecord, Error>] = [:]
    /// Delay before the next get after a retryable failure. A successful read clears it.
    private var backoff: [UUID: UInt64] = [:]

    /// Set before the poll task is created so the task can see that it is current.
    private var pollGeneration: [UUID: UUID] = [:]

    private struct LivePoll {
        var task: Task<Void, Never>
    }

    init(
        networking: GenerationNetworking,
        defaults: UserDefaults = .standard,
        serverID: @escaping @MainActor () -> String = { APIServerStore.shared.current.id },
        hasSession: @escaping @MainActor () -> Bool = { AuthSession.shared.isSignedIn },
        intervalNanoseconds: UInt64 = 1_000_000_000,
        now: @escaping () -> Date = Date.init,
        sleep: ((UInt64) async throws -> Void)? = nil
    ) {
        self.networking = networking
        self.store = GenerationJobStore(defaults: defaults)
        self.serverID = serverID
        self.hasSession = hasSession
        self.intervalNanoseconds = intervalNanoseconds
        self.now = now
        self.sleep = sleep ?? { try await Task.sleep(nanoseconds: $0) }
    }

    func record(prompt: String) -> GenerationJobRecord? {
        jobs
            .filter { $0.prompt == prompt }
            .max { $0.startedAt < $1.startedAt }
    }

    func record(jobID: UUID) -> GenerationJobRecord? {
        jobs.first { $0.jobId == jobID }
    }

    var active: GenerationJobRecord? {
        jobs.filter(\.isPolling).max { $0.startedAt < $1.startedAt }
    }

    /// Newest session the gallery should reopen. A finished metric starts a blank screen instead.
    var live: GenerationJobRecord? {
        Self.liveJob(in: jobs)
    }

    nonisolated static func liveJob(in jobs: [GenerationJobRecord]) -> GenerationJobRecord? {
        jobs.filter(\.isOpen).max { $0.startedAt < $1.startedAt }
    }

    /// Loads this server's jobs and continues polling anything still queued or running.
    func resume() async {
        alignServer()
        guard hasSession(), let server = loadedServerID else { return }
        for record in jobs where record.isPolling {
            guard let jobId = record.jobId else { continue }
            beginPolling(jobId, serverID: server)
        }
    }

    @discardableResult
    func start(
        prompt: String,
        locale: String,
        sourceURL: String? = nil,
        simulation: Bool = false,
        idempotencyKey: String? = nil
    ) async throws -> GenerationJobRecord {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GenerationJobError.emptyPrompt }
        guard text.count <= Self.maximumPromptLength else { throw GenerationJobError.promptTooLong }
        alignServer()
        let requestedKey = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let requestedKey, !requestedKey.isEmpty {
            if let existing = jobs.first(where: { $0.idempotencyKey == requestedKey }),
               existing.jobId == nil || existing.isPolling {
                return try await continueExisting(existing)
            }
            let key = jobs.contains(where: { $0.idempotencyKey == requestedKey })
                ? UUID().uuidString.lowercased()
                : requestedKey
            let record = makeRecord(
                key: key,
                prompt: text,
                locale: locale,
                sourceURL: sourceURL,
                simulation: simulation
            )
            upsert(record)
            return try await submit(record)
        }
        if let existing = jobs.first(where: {
            $0.prompt == text
                && $0.locale == locale
                && $0.sourceURL == sourceURL
                && $0.simulation == simulation
                && ($0.jobId == nil || $0.isPolling)
        }) {
            return try await continueExisting(existing)
        }

        let record = makeRecord(
            key: UUID().uuidString.lowercased(),
            prompt: text,
            locale: locale,
            sourceURL: sourceURL,
            simulation: simulation
        )
        upsert(record)
        return try await submit(record)
    }

    private func continueExisting(_ existing: GenerationJobRecord) async throws -> GenerationJobRecord {
        if existing.jobId == nil {
            return try await submit(existing)
        }
        if let jobId = existing.jobId, let server = loadedServerID {
            beginPolling(jobId, serverID: server)
        }
        return existing
    }

    private func makeRecord(
        key: String,
        prompt: String,
        locale: String,
        sourceURL: String?,
        simulation: Bool
    ) -> GenerationJobRecord {
        let stamp = now()
        return GenerationJobRecord(
            idempotencyKey: key,
            prompt: prompt,
            locale: locale,
            sourceURL: sourceURL,
            jobId: nil,
            status: nil,
            startedAt: stamp,
            createdAt: stamp,
            job: nil,
            failure: nil,
            simulation: simulation
        )
    }

    /// Sends the user's reply and continues the same job. The server does not spend another credit.
    @discardableResult
    func answer(jobID: UUID, text: String) async throws -> GenerationJobRecord {
        let reply = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { throw GenerationJobError.emptyPrompt }
        alignServer()
        guard let waiting = record(jobID: jobID) else { throw GenerationJobError.emptyPrompt }
        guard waiting.status == .needsInput else { return waiting }
        if let existing = answers[jobID] {
            return try await existing.value
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            defer { self.answers[jobID] = nil }
            return try await self.runAnswer(jobID: jobID, text: reply)
        }
        answers[jobID] = task
        return try await task.value
    }

    private func runAnswer(jobID: UUID, text: String) async throws -> GenerationJobRecord {
        let server = loadedServerID
        releasePoll(jobID)
        do {
            let accepted = try await networking.answer(job: jobID, text: text)
            guard loadedServerID == server else { throw CancellationError() }
            resumeAccepted(accepted, serverID: server)
            guard let record = record(jobID: jobID) else { throw CancellationError() }
            return record
        } catch {
            guard loadedServerID == server else { throw error }
            if let client = error as? BuilderAPI.ClientError, case .status(let code, _) = client {
                if code == 409, let server {
                    return try await refreshAnswer(jobID, serverID: server)
                }
                if code == 404 {
                    markFailed(jobID, serverID: server, error: error)
                }
            }
            throw error
        }
    }

    private func resumeAccepted(_ accepted: BuilderAPI.AcceptedJob, serverID: String?) {
        guard var record = jobs.first(where: { $0.jobId == accepted.jobId }) else { return }
        record.status = accepted.status
        record.failure = nil
        if var job = record.job {
            job.status = accepted.status
            job.question = nil
            record.job = job
        }
        upsert(record, serverID: serverID)
        guard accepted.status.isPolling, let serverID else { return }
        beginPolling(accepted.jobId, serverID: serverID)
    }

    private func refreshAnswer(_ jobID: UUID, serverID: String) async throws -> GenerationJobRecord {
        let job = try await networking.job(jobID)
        guard loadedServerID == serverID else { throw CancellationError() }
        apply(job, serverID: serverID)
        if job.status.isPolling {
            beginPolling(jobID, serverID: serverID)
        }
        if job.status != .needsInput, let record = record(jobID: jobID) {
            return record
        }
        throw BuilderAPI.ClientError.status(409, nil)
    }

    private func markFailed(_ jobID: UUID, serverID: String?, error: Error) {
        guard var record = jobs.first(where: { $0.jobId == jobID }) else { return }
        record.status = .failed
        record.failure = describe(error)
        if var job = record.job {
            job.status = .failed
            record.job = job
        }
        upsert(record, serverID: serverID)
    }

    private func releasePoll(_ jobID: UUID) {
        polls[jobID]?.task.cancel()
        polls[jobID] = nil
        pollGeneration[jobID] = nil
        backoff[jobID] = nil
    }

    private func submit(_ record: GenerationJobRecord) async throws -> GenerationJobRecord {
        if let existing = submissions[record.idempotencyKey] {
            return try await existing.value
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            defer { self.submissions[record.idempotencyKey] = nil }
            return try await self.runSubmit(record)
        }
        submissions[record.idempotencyKey] = task
        return try await task.value
    }

    private func runSubmit(_ record: GenerationJobRecord) async throws -> GenerationJobRecord {
        let server = loadedServerID
        let body = BuilderAPI.GenerateRequest(
            prompt: record.prompt,
            locale: record.locale,
            sourceUrl: record.sourceURL
        )
        do {
            let accepted = try await generate(
                body,
                idempotencyKey: record.idempotencyKey,
                simulation: record.simulation
            )
            guard loadedServerID == server else {
                throw CancellationError()
            }
            var updated = record
            updated.jobId = accepted.jobId
            updated.status = accepted.status
            updated.failure = nil
            upsert(updated)
            if let server {
                beginPolling(accepted.jobId, serverID: server)
            }
            return jobs.first { $0.idempotencyKey == record.idempotencyKey } ?? updated
        } catch {
            if loadedServerID == server {
                if keepsKey(error) {
                    var updated = record
                    updated.failure = describe(error)
                    upsert(updated)
                } else {
                    remove(record.idempotencyKey)
                }
            }
            throw error
        }
    }

    private func generate(
        _ body: BuilderAPI.GenerateRequest,
        idempotencyKey: String,
        simulation: Bool
    ) async throws -> BuilderAPI.AcceptedJob {
        do {
            return try await networking.generate(body, idempotencyKey: idempotencyKey, simulation: simulation)
        } catch {
            guard keepsKey(error) else { throw error }
            return try await networking.generate(body, idempotencyKey: idempotencyKey, simulation: simulation)
        }
    }

    private func beginPolling(_ jobId: UUID, serverID: String) {
        guard polls[jobId] == nil else { return }
        let generation = UUID()
        pollGeneration[jobId] = generation
        let task = Task { [weak self] in
            guard let self else { return }
            await self.poll(jobId, serverID: serverID, generation: generation)
        }
        polls[jobId] = LivePoll(task: task)
    }

    private func poll(_ jobId: UUID, serverID: String, generation: UUID) async {
        defer { finishPoll(jobId, generation: generation) }
        while isCurrent(jobId, generation: generation) {
            guard self.serverID() == serverID else { return }
            do {
                let job = try await networking.job(jobId)
                guard isCurrent(jobId, generation: generation), self.serverID() == serverID else { return }
                apply(job, serverID: serverID)
                if !job.status.isPolling {
                    return
                }
                backoff[jobId] = nil
                try await sleep(intervalNanoseconds)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrent(jobId, generation: generation) else { return }
                if shouldStop(error) {
                    stop(jobId, serverID: serverID, error: error, generation: generation)
                    return
                }
                let delay = failureDelay(for: jobId)
                do {
                    try await sleep(delay)
                } catch {
                    return
                }
            }
        }
    }

    /// 1×, 2×, 4×, 8×, then the 15× cap. A successful read starts the sequence over.
    private func failureDelay(for jobId: UUID) -> UInt64 {
        let cap = intervalNanoseconds * 15
        let current = min(backoff[jobId] ?? intervalNanoseconds, cap)
        let next = current > cap / 2 ? cap : current * 2
        backoff[jobId] = min(next, cap)
        return current
    }

    private func isCurrent(_ jobId: UUID, generation: UUID) -> Bool {
        pollGeneration[jobId] == generation && !Task.isCancelled
    }

    private func finishPoll(_ jobId: UUID, generation: UUID) {
        guard pollGeneration[jobId] == generation else { return }
        pollGeneration[jobId] = nil
        polls[jobId] = nil
        backoff[jobId] = nil
    }

    private func apply(_ job: BuilderAPI.Job, serverID: String) {
        guard var record = jobs.first(where: { $0.jobId == job.jobId }) else { return }
        record.status = job.status
        record.job = job
        record.createdAt = job.createdAt
        record.failure = job.status == .failed ? job.error?.message : nil
        upsert(record, serverID: serverID)
    }

    private func stop(_ jobId: UUID, serverID: String, error: Error, generation: UUID) {
        guard isCurrent(jobId, generation: generation) else { return }
        guard var record = jobs.first(where: { $0.jobId == jobId }) else { return }
        record.status = .failed
        record.failure = describe(error)
        upsert(record, serverID: serverID)
    }

    private func alignServer() {
        let server = serverID()
        guard loadedServerID != server else { return }
        for poll in polls.values {
            poll.task.cancel()
        }
        polls.removeAll()
        pollGeneration.removeAll()
        backoff.removeAll()
        loadedServerID = server
        jobs = Self.ordered(store.load(serverID: server))
    }

    private func upsert(_ record: GenerationJobRecord, serverID: String? = nil) {
        guard let serverID = serverID ?? loadedServerID else { return }
        var updated = jobs.filter { $0.idempotencyKey != record.idempotencyKey }
        updated.append(record)
        jobs = Self.ordered(updated)
        store.save(jobs, serverID: serverID)
    }

    private static func ordered(_ records: [GenerationJobRecord]) -> [GenerationJobRecord] {
        records.sorted { $0.startedAt > $1.startedAt }
    }

    private func remove(_ idempotencyKey: String) {
        guard let serverID = loadedServerID else { return }
        jobs.removeAll { $0.idempotencyKey == idempotencyKey }
        store.save(jobs, serverID: serverID)
    }

    /// A dropped call or HTTP 500/503 can be repeated with the same key. The server spends the credit once.
    private func keepsKey(_ error: Error) -> Bool {
        guard let error = error as? BuilderAPI.ClientError else { return true }
        switch error {
        case .transport, .invalidResponse:
            return true
        case .missingSession:
            return false
        case .status(let code, _):
            return code == 500 || code == 503
        }
    }

    /// 400 and 409 will not succeed on another try. 401 and 404 mean the session or the job is gone.
    private func shouldStop(_ error: Error) -> Bool {
        guard let error = error as? BuilderAPI.ClientError else { return false }
        switch error {
        case .missingSession:
            return true
        case .status(let code, _) where code == 400 || code == 401 || code == 404 || code == 409:
            return true
        default:
            return false
        }
    }

    private func describe(_ error: Error) -> String {
        if let error = error as? BuilderAPI.ClientError {
            if let message = error.failure?.message, !message.isEmpty {
                return message
            }
            if case .transport(let urlError) = error {
                return ErrorMessageFormatter.message(for: urlError as Error)
            }
        }
        return ErrorMessageFormatter.message(for: error)
    }
}
