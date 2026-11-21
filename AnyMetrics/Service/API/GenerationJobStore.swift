import Foundation

/// One generate attempt and the latest job the server returned for it.
struct GenerationJobRecord: Codable, Equatable, Identifiable {
    var idempotencyKey: String
    var prompt: String
    var locale: String
    var sourceURL: String?
    var jobId: UUID?
    var status: BuilderAPI.JobStatus?
    /// Local time the attempt was created. Sorting uses this, not the server clock.
    var startedAt: Date
    /// Server `createdAt` after a snapshot. Until then it matches `startedAt`.
    var createdAt: Date
    var job: BuilderAPI.Job?
    var failure: String?
    /// True when this attempt was started with `test=1`. The idempotency key stays in that mode.
    var simulation: Bool

    var id: String { idempotencyKey }

    /// `failure` is only a message. A queued or running job keeps being polled.
    var isPolling: Bool {
        guard let status else { return jobId != nil }
        return status.isPolling
    }

    /// Still in progress or waiting for an answer. Finished and failed attempts stay in history.
    var isOpen: Bool {
        guard jobId != nil else { return false }
        switch status {
        case .queued, .running, .needsInput, nil:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    init(
        idempotencyKey: String,
        prompt: String,
        locale: String,
        sourceURL: String?,
        jobId: UUID?,
        status: BuilderAPI.JobStatus?,
        startedAt: Date,
        createdAt: Date,
        job: BuilderAPI.Job?,
        failure: String?,
        simulation: Bool = false
    ) {
        self.idempotencyKey = idempotencyKey
        self.prompt = prompt
        self.locale = locale
        self.sourceURL = sourceURL
        self.jobId = jobId
        self.status = status
        self.startedAt = startedAt
        self.createdAt = createdAt
        self.job = job
        self.failure = failure
        self.simulation = simulation
    }

    private enum CodingKeys: String, CodingKey {
        case idempotencyKey
        case prompt
        case locale
        case sourceURL
        case jobId
        case status
        case startedAt
        case createdAt
        case job
        case failure
        case simulation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idempotencyKey = try container.decode(String.self, forKey: .idempotencyKey)
        prompt = try container.decode(String.self, forKey: .prompt)
        locale = try container.decode(String.self, forKey: .locale)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        jobId = try container.decodeIfPresent(UUID.self, forKey: .jobId)
        status = try container.decodeIfPresent(BuilderAPI.JobStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? createdAt
        job = try container.decodeIfPresent(BuilderAPI.Job.self, forKey: .job)
        failure = try container.decodeIfPresent(String.self, forKey: .failure)
        simulation = try container.decodeIfPresent(Bool.self, forKey: .simulation) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(locale, forKey: .locale)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(job, forKey: .job)
        try container.encodeIfPresent(failure, forKey: .failure)
        try container.encode(simulation, forKey: .simulation)
    }
}

/// Jobs for one Builder API origin. The key survives a dropped generate call so the same search can be retried.
struct GenerationJobStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(serverID: String) -> [GenerationJobRecord] {
        let storageKey = key(serverID)
        guard let data = defaults.data(forKey: storageKey), !data.isEmpty else { return [] }
        do {
            return try Self.decoder.decode([GenerationJobRecord].self, from: data)
        } catch {
            let backup = corruptKey(serverID)
            if defaults.data(forKey: backup) == nil {
                defaults.set(data, forKey: backup)
            }
            return []
        }
    }

    func save(_ jobs: [GenerationJobRecord], serverID: String) {
        guard let data = try? Self.encoder.encode(jobs) else { return }
        defaults.set(data, forKey: key(serverID))
    }

    private func key(_ serverID: String) -> String {
        "generation.jobs.\(serverID)"
    }

    private func corruptKey(_ serverID: String) -> String {
        "generation.jobs.\(serverID).corrupt"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: value)
        }
        return decoder
    }()
}
