import Foundation

/// Wire types for the AnyMetrics AI Builder API.
enum BuilderAPI {

    struct Failure: Codable, Equatable {
        var code: String?
        var message: String
        var balance: Int?
        var required: Int?
    }

    enum ClientError: Error, Equatable {
        case missingSession
        case status(Int, Failure?)
        case transport(URLError)
        case invalidResponse

        var isUnauthorized: Bool {
            switch self {
            case .missingSession:
                return true
            case .status(401, _):
                return true
            default:
                return false
            }
        }

        var failure: Failure? {
            if case .status(_, let failure) = self {
                return failure
            }
            return nil
        }
    }

    struct Health: Decodable, Equatable {
        enum Status: String, Decodable, Equatable {
            case ok
        }

        var status: Status
    }

    enum SignInProvider: String, Decodable, Equatable {
        case apple, google, github
    }

    struct AuthProviders: Decodable, Equatable {
        var providers: [SignInProvider]
    }

    struct User: Decodable, Equatable {
        var id: UUID
        var email: String?
        var name: String?
    }

    struct Account: Decodable, Equatable {
        var user: User
        var balance: Int
        var paid: Bool
    }

    struct Session: Decodable, Equatable {
        var token: String
        var user: User
        var balance: Int
        var paid: Bool

        var account: Account {
            Account(user: user, balance: balance, paid: paid)
        }
    }

    struct Billing: Decodable, Equatable {
        var balance: Int
        var paid: Bool
    }

    struct AppleSignIn: Encodable, Equatable {
        var identityToken: String
        var nonce: String? = nil
        var name: String? = nil
    }

    struct GoogleSignIn: Encodable, Equatable {
        var idToken: String
    }

    struct GitHubSignIn: Encodable, Equatable {
        var code: String
        var redirectUri: String? = nil
    }

    struct AppleTransaction: Encodable, Equatable {
        var signedTransaction: String
    }

    struct AppleTransactionResult: Decodable, Equatable {
        var balance: Int
        var credited: Int
        var duplicate: Bool
        var productId: String
        var transactionId: String
    }

    struct GenerateRequest: Encodable, Equatable {
        var prompt: String
        var locale: String? = nil
        var sourceUrl: String? = nil
    }

    struct AnswerRequest: Encodable, Equatable {
        var text: String
    }

    enum JobStatus: String, Codable, Equatable {
        case queued
        case running
        case needsInput = "needs_input"
        case completed
        case failed
        case cancelled

        /// Poll until the job pauses for an answer or reaches a final status.
        var isPolling: Bool {
            switch self {
            case .queued, .running:
                return true
            case .needsInput, .completed, .failed, .cancelled:
                return false
            }
        }
    }

    struct AcceptedJob: Decodable, Equatable {
        var jobId: UUID
        var status: JobStatus
    }

    struct JobList: Decodable, Equatable {
        var jobs: [JobSummary]
    }

    struct JobSummary: Decodable, Equatable {
        var jobId: UUID
        var status: JobStatus
        var prompt: String
        var createdAt: Date
        var question: Question?
        /// Present and true when the job was started with `test=1`.
        var simulation: Bool?
    }

    struct CancelledJob: Decodable, Equatable {
        var jobId: UUID
        var status: JobStatus
    }

    struct Question: Codable, Equatable {
        var text: String
        var options: [String]?
        var allowsFreeText: Bool
    }

    struct DialogTurn: Codable, Equatable {
        var question: Question
        var askedAt: Date
        var answer: String?
        var answeredAt: Date?
    }

    struct Job: Codable, Equatable {
        var jobId: UUID
        var status: JobStatus
        var prompt: String
        var createdAt: Date
        /// Questions this job asked, oldest first. An answer is present only after it was sent.
        var dialog: [DialogTurn]
        var question: Question?
        var error: Failure?
        var requirement: UserRequirement?
        var draft: DraftMetric?
        var result: GenerateResult?
        var alternative: MetricAlternative?
        /// Present and true when the job was started with `test=1`.
        var simulation: Bool?
    }

    struct GenerateResult: Codable, Equatable {
        var metric: GeneratedMetric
        var validation: Validation
        var source: MetricSource
    }

    struct MetricSource: Codable, Equatable {
        enum Kind: String, Codable, Equatable {
            case publicAPI = "public_api"
            case gallery
        }

        var kind: Kind
        var name: String?
        var url: String
        var website: String?
    }

    struct MetricAlternative: Codable, Equatable {
        var reason: String
        var metric: GeneratedMetric
        var requirement: UserRequirement
    }

    struct DraftMetric: Codable, Equatable {
        var metric: GeneratedMetric
        var validated: Bool
    }

    struct UserRequirement: Codable, Equatable {
        enum Kind: String, Codable, Equatable {
            case apiKey = "api_key"
            case account
            case other
        }

        var kind: Kind
        var text: String
        var url: String?
    }

    struct GeneratedMetric: Codable, Equatable {
        enum Kind: String, Codable, Equatable {
            case json, web, checkStatus
        }

        enum ResultKind: String, Codable, Equatable {
            case content, image
        }

        var id: String
        var title: String
        var measure: String
        var type: Kind
        var resultKind: ResultKind
        var interval: Int
        var request: GeneratedRequest
        var formatter: Formatter
        var rules: Rules
        var author: String?
        var description: String?
        var website: String?
    }

    struct GeneratedRequest: Codable, Equatable {
        enum Method: String, Codable, Equatable {
            case GET, HEAD
        }

        var url: String
        var method: Method
        var headers: [String: String]
    }

    struct Formatter: Codable, Equatable {
        enum Format: String, Codable, Equatable {
            case none, currency
        }

        var format: Format
        var fraction: Int? = nil
        var length: Int? = nil
    }

    struct Rules: Codable, Equatable {
        enum Kind: String, Codable, Equatable {
            case none, equal, contains
        }

        var type: Kind
        var parseRules: String? = nil
        var value: String? = nil
        var caseSensitive: Bool
    }

    struct ValidateRequest: Encodable, Equatable {
        var metric: MetricInput
    }

    struct MetricInput: Encodable, Equatable {
        var id: String? = nil
        var title: String
        var measure: String
        var type: GeneratedMetric.Kind
        var resultKind: GeneratedMetric.ResultKind? = nil
        var interval: Int? = nil
        var request: MetricRequestInput? = nil
        var formatter: Formatter? = nil
        var rules: RulesInput? = nil
        var author: String? = nil
        var description: String? = nil
        var website: String? = nil
    }

    struct MetricRequestInput: Encodable, Equatable {
        var url: String
        var method: String
        var headers: [String: String]
        var timeout: Double? = nil
        var requestBody: String? = nil
    }

    struct RulesInput: Encodable, Equatable {
        var type: Rules.Kind? = nil
        var parseRules: String? = nil
        var value: String? = nil
        var caseSensitive: Bool? = nil
    }

    struct ValidateResponse: Decodable, Equatable {
        var validation: Validation
    }

    struct Validation: Codable, Equatable {
        enum ValueKind: String, Codable, Equatable {
            case content, status
        }

        var success: Bool
        var code: String?
        var message: String?
        var valueKind: ValueKind?
        var rawValue: String?
        var sampleValue: String?
        var status: Bool?
        var statusCode: Int?
        var finalUrl: String?
        var validatedAt: Date
    }
}

extension BuilderAPI.Job {
    private enum CodingKeys: String, CodingKey {
        case jobId, status, prompt, createdAt, dialog, question, error
        case requirement, draft, result, alternative, simulation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        status = try container.decode(BuilderAPI.JobStatus.self, forKey: .status)
        prompt = try container.decode(String.self, forKey: .prompt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        dialog = try container.decodeIfPresent([BuilderAPI.DialogTurn].self, forKey: .dialog) ?? []
        question = try container.decodeIfPresent(BuilderAPI.Question.self, forKey: .question)
        error = try container.decodeIfPresent(BuilderAPI.Failure.self, forKey: .error)
        requirement = try container.decodeIfPresent(BuilderAPI.UserRequirement.self, forKey: .requirement)
        draft = try container.decodeIfPresent(BuilderAPI.DraftMetric.self, forKey: .draft)
        result = try container.decodeIfPresent(BuilderAPI.GenerateResult.self, forKey: .result)
        alternative = try container.decodeIfPresent(BuilderAPI.MetricAlternative.self, forKey: .alternative)
        simulation = try container.decodeIfPresent(Bool.self, forKey: .simulation)
    }
}
