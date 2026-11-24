import Foundation

/// One run of Claude for a Div job.
public struct ClaudeCall: Sendable {
    /// "opus", "sonnet" or "haiku".
    public var model: String
    public var systemPrompt: String
    public var userPrompt: String
    /// JSON Schema the answer must match (`--json-schema`).
    public var schema: String
    public var effort: String?
    /// Built-in tools Claude may use. Empty means none: it only reasons over the prompt.
    public var builtInTools: [String] = []
    /// Permission rules that let those tools (or MCP tools) run without asking, which `-p` can't do.
    public var allowedTools: [String] = []
    /// MCP servers as `--mcp-config` JSON. "{workdir}" is replaced with the job's folder.
    public var mcpConfig: String?
    /// Files to put in the job's empty working folder first, e.g. the meal photo.
    public var files: [String: Data] = [:]
    /// Files to read back from the working folder afterwards, e.g. the tool server's call log.
    public var collect: [String] = []
    public var timeout: Duration = .seconds(300)

    public init(model: String, systemPrompt: String, userPrompt: String, schema: String) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.schema = schema
    }
}

/// Claude's answer, and what the run took.
public struct ClaudeReply: Sendable {
    /// The `structured_output`, as JSON.
    public var output: Data
    public var run: RunInfo
    /// The files named in `ClaudeCall.collect` that existed when Claude finished.
    public var collected: [String: Data] = [:]

    public init(output: Data, run: RunInfo, collected: [String: Data] = [:]) {
        self.output = output
        self.run = run
        self.collected = collected
    }
}

/// What a run took. The cost is what it would be at API prices; on a Claude plan it's usage, not dollars.
public struct RunInfo: Codable, Sendable, Equatable {
    public var model: String
    public var durationMs: Int
    public var turns: Int?
    public var costUsdEquivalent: Double?

    public init(model: String, durationMs: Int, turns: Int? = nil, costUsdEquivalent: Double? = nil) {
        self.model = model
        self.durationMs = durationMs
        self.turns = turns
        self.costUsdEquivalent = costUsdEquivalent
    }
}

/// Runs a ClaudeCall. `ClaudeCLI` is the real one; tests use a fake.
public protocol ClaudeRunning: Sendable {
    func run(_ call: ClaudeCall) async throws -> ClaudeReply
}

public enum ClaudeError: Error, CustomStringConvertible {
    case notInstalled
    case failed(String)
    case timedOut(Duration)
    case badOutput(String)

    public var description: String {
        switch self {
        case .notInstalled: "Couldn't find `claude`. Install Claude Code and sign in, then try again."
        case .failed(let message): "claude failed: \(message)"
        case .timedOut(let limit): "claude took longer than \(limit.components.seconds) s."
        case .badOutput(let message): "claude's answer couldn't be read: \(message)"
        }
    }
}
