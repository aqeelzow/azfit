import AZModel
import AZStore
import Foundation

/// Everything the phone and the bridge send each other. On the wire: `{"type": "...", ...fields}`.
public enum Message: Sendable, Equatable {
    /// Phone to bridge, first thing after connecting.
    case hello(Hello)
    /// Bridge to phone: after hello, and whenever something the phone shows changes (Claude signed out).
    case status(BridgeStatus)
    /// Phone to bridge: run a Div job.
    case request(Request)
    /// Bridge to phone: the answer to a request, matched by `id`.
    case response(Response)
}

public struct Hello: Codable, Sendable, Equatable {
    public var wireVersion: Int
    public var phoneName: String
    /// Which pairing this phone holds, so the bridge can show its name next to it.
    public var pairingID: UUID?

    public init(phoneName: String, pairingID: UUID? = nil, wireVersion: Int = WireVersion.current) {
        self.wireVersion = wireVersion
        self.phoneName = phoneName
        self.pairingID = pairingID
    }
}

public struct BridgeStatus: Codable, Sendable, Equatable {
    public var wireVersion: Int
    public var bridgeName: String
    public var claude: ClaudeStatus

    public init(bridgeName: String, claude: ClaudeStatus, wireVersion: Int = WireVersion.current) {
        self.wireVersion = wireVersion
        self.bridgeName = bridgeName
        self.claude = claude
    }
}

/// Whether the bridge can run Div: the `claude` command is installed and signed in.
public enum ClaudeStatus: String, Codable, Sendable, Equatable {
    case ready
    case signedOut = "signed_out"
    case notInstalled = "not_installed"
    case unknown

    public var label: String {
        switch self {
        case .ready: "Signed in"
        case .signedOut: "Signed out"
        case .notInstalled: "Not installed"
        case .unknown: "Checking…"
        }
    }
}

public struct Request: Codable, Sendable, Equatable {
    public var id: UUID
    public var job: Job
    /// Whose data (`Profile.id`): the bridge keeps a database per person (D-024). Nil before onboarding.
    public var person: UUID?

    public init(id: UUID = UUID(), job: Job, person: UUID? = nil) {
        self.id = id
        self.job = job
        self.person = person
    }
}

/// What the phone asks for. More jobs (meal photos, session reviews) join as the screens need them.
public enum Job: Sendable, Equatable {
    case chat(ChatRequest)
    /// Send the phone's new rows and get the bridge's back (D-006).
    case sync(SyncPush)
    /// Review a finished workout (already synced): Div's note and next time's loads, saved on the bridge.
    case sessionReview(SessionReviewRequest)
}

public struct SessionReviewRequest: Codable, Sendable, Equatable {
    public var workoutID: UUID

    public init(workoutID: UUID) {
        self.workoutID = workoutID
    }
}

/// What the session review decided. Its note and changes also arrive with the next sync.
public struct SessionReviewReply: Codable, Sendable, Equatable {
    public var note: String
    /// Load changes applied now, and ones waiting for the person.
    public var applied: Int
    public var proposed: Int

    public init(note: String, applied: Int, proposed: Int) {
        self.note = note
        self.applied = applied
        self.proposed = proposed
    }
}

/// The phone's rows since the bridge last confirmed, and how far the phone has the bridge's rows.
public struct SyncPush: Codable, Sendable, Equatable {
    public var batch: SyncBatch
    /// The last bridge sequence the phone has.
    public var since: Int64

    public init(batch: SyncBatch, since: Int64) {
        self.batch = batch
        self.since = since
    }
}

/// The bridge's rows after `since`, and how far the bridge now has the phone's.
public struct SyncPull: Codable, Sendable, Equatable {
    public var batch: SyncBatch
    public var received: Int64

    public init(batch: SyncBatch, received: Int64) {
        self.batch = batch
        self.received = received
    }
}

public struct Response: Codable, Sendable, Equatable {
    public var id: UUID
    public var outcome: Outcome

    public init(id: UUID, outcome: Outcome) {
        self.id = id
        self.outcome = outcome
    }
}

public enum Outcome: Sendable, Equatable {
    case chat(ChatReply)
    case synced(SyncPull)
    case sessionReviewed(SessionReviewReply)
    /// The job couldn't run: Claude is signed out, timed out, or answered something invalid.
    case failed(String)
}

/// Div's chat answer as the phone shows it: the reply, and each change with the bridge's verdict.
public struct ChatReply: Codable, Sendable, Equatable {
    public var reply: String
    public var changes: [Checked<Proposal>]
    public var remember: [String]
    public var model: String
    /// The saved `DivChange` ID for each of `changes`, for Undo and Approve (nil when refused or not saved).
    /// Named so the snake_case JSON keys round-trip (`saved`, not `change_i_ds`).
    public var saved: [UUID?]

    public init(reply: String, changes: [Checked<Proposal>] = [], remember: [String] = [], model: String, saved: [UUID?] = []) {
        self.reply = reply
        self.changes = changes
        self.remember = remember
        self.model = model
        self.saved = saved
    }

    private enum CodingKeys: String, CodingKey { case reply, changes, remember, model, saved }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reply = try c.decode(String.self, forKey: .reply)
        changes = try c.decode([Checked<Proposal>].self, forKey: .changes)
        remember = try c.decode([String].self, forKey: .remember)
        model = try c.decode(String.self, forKey: .model)
        saved = try c.decodeIfPresent([UUID?].self, forKey: .saved) ?? []
    }
}

// MARK: - Coding

private enum TypeKey: String, CodingKey {
    case type
}

extension Message: Codable {
    private enum Kind: String, Codable {
        case hello, status, request, response
    }

    public init(from decoder: any Decoder) throws {
        switch try decoder.container(keyedBy: TypeKey.self).decode(Kind.self, forKey: .type) {
        case .hello: self = .hello(try Hello(from: decoder))
        case .status: self = .status(try BridgeStatus(from: decoder))
        case .request: self = .request(try Request(from: decoder))
        case .response: self = .response(try Response(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .hello(let value):
            try container.encode(Kind.hello, forKey: .type)
            try value.encode(to: encoder)
        case .status(let value):
            try container.encode(Kind.status, forKey: .type)
            try value.encode(to: encoder)
        case .request(let value):
            try container.encode(Kind.request, forKey: .type)
            try value.encode(to: encoder)
        case .response(let value):
            try container.encode(Kind.response, forKey: .type)
            try value.encode(to: encoder)
        }
    }
}

extension Job: Codable {
    private enum Keys: String, CodingKey {
        // Swift names: the wire coder (DivJSON) makes them snake_case, and a snake_case raw value wouldn't read back.
        case kind, chat, sync, sessionReview
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "chat": self = .chat(try container.decode(ChatRequest.self, forKey: .chat))
        case "sync": self = .sync(try container.decode(SyncPush.self, forKey: .sync))
        case "session_review": self = .sessionReview(try container.decode(SessionReviewRequest.self, forKey: .sessionReview))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "unknown job \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .chat(let request):
            try container.encode("chat", forKey: .kind)
            try container.encode(request, forKey: .chat)
        case .sync(let push):
            try container.encode("sync", forKey: .kind)
            try container.encode(push, forKey: .sync)
        case .sessionReview(let request):
            try container.encode("session_review", forKey: .kind)
            try container.encode(request, forKey: .sessionReview)
        }
    }
}

extension Outcome: Codable {
    private enum Keys: String, CodingKey {
        case kind, chat, synced, error, sessionReviewed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "chat": self = .chat(try container.decode(ChatReply.self, forKey: .chat))
        case "synced": self = .synced(try container.decode(SyncPull.self, forKey: .synced))
        case "session_reviewed": self = .sessionReviewed(try container.decode(SessionReviewReply.self, forKey: .sessionReviewed))
        case "failed": self = .failed(try container.decode(String.self, forKey: .error))
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "unknown outcome \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .chat(let reply):
            try container.encode("chat", forKey: .kind)
            try container.encode(reply, forKey: .chat)
        case .synced(let pull):
            try container.encode("synced", forKey: .kind)
            try container.encode(pull, forKey: .synced)
        case .sessionReviewed(let reply):
            try container.encode("session_reviewed", forKey: .kind)
            try container.encode(reply, forKey: .sessionReviewed)
        case .failed(let message):
            try container.encode("failed", forKey: .kind)
            try container.encode(message, forKey: .error)
        }
    }
}
