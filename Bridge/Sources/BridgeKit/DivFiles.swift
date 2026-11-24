import Foundation

/// Div's jobs, with the model and effort each one runs on (D-018).
public enum DivJob: String, Codable, Sendable, CaseIterable {
    case weeklyReview = "weekly-review"
    case sessionReview = "session-review"
    case estimateMeal = "estimate-meal"
    case reviseMeal = "revise-meal"
    case inWorkout = "in-workout"
    case chat

    public var model: String {
        switch self {
        case .weeklyReview, .chat: "opus"
        case .sessionReview: "sonnet"
        case .estimateMeal, .reviseMeal, .inWorkout: "haiku"
        }
    }

    public var effort: String? {
        switch self {
        case .weeklyReview: "medium"
        case .sessionReview, .chat: "low"
        case .estimateMeal, .reviseMeal, .inWorkout: nil
        }
    }

    public var timeout: Duration {
        switch self {
        case .weeklyReview: .seconds(300)
        case .sessionReview, .estimateMeal, .chat: .seconds(150)
        case .reviseMeal, .inWorkout: .seconds(60)
        }
    }

    /// The schema file it returns. Revising a meal returns a new estimate.
    public var schemaName: String {
        self == .reviseMeal ? DivJob.estimateMeal.rawValue : rawValue
    }
}

/// The Div/ folder: prompts, schemas, read tools and evals. Everything Div is lives there, not in Swift.
public struct DivFiles: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case notFound
        case missing(String)

        public var description: String {
            switch self {
            case .notFound: "Couldn't find the Div folder. Run from the repo, or set AZFIT_DIV_DIR to its path."
            case .missing(let path): "Div folder is missing \(path)."
            }
        }
    }

    public let root: URL

    public init(root: URL) throws {
        self.root = root
        guard FileManager.default.fileExists(atPath: root.appending(path: "prompts/system.md").path) else {
            throw Failure.missing("prompts/system.md")
        }
    }

    /// Finds Div/: $AZFIT_DIV_DIR, then a "Div" folder in the app bundle, then the current folder and its parents.
    public static func locate() throws -> DivFiles {
        if let dir = ProcessInfo.processInfo.environment["AZFIT_DIV_DIR"], !dir.isEmpty {
            return try DivFiles(root: URL(filePath: dir))
        }
        if let bundled = Bundle.main.resourceURL?.appending(path: "Div"), let files = try? DivFiles(root: bundled) {
            return files
        }
        var dir = URL(filePath: FileManager.default.currentDirectoryPath)
        while true {
            if let files = try? DivFiles(root: dir.appending(path: "Div")) { return files }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { throw Failure.notFound }
            dir = parent
        }
    }

    /// system.md followed by the job's own prompt.
    public func systemPrompt(for job: DivJob) throws -> String {
        try text("prompts/system.md") + "\n\n" + text("prompts/jobs/\(job.rawValue).md")
    }

    /// The job's output schema, as compact JSON for `--json-schema`.
    public func schema(for job: DivJob) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data("schemas/\(job.schemaName).json"))
        return String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }

    /// The read tools chat may call (Div/tools/tools.json), in MCP's `tools/list` shape.
    public var toolsURL: URL { root.appending(path: "tools/tools.json") }

    public var evalsURL: URL { root.appending(path: "evals") }

    func text(_ path: String) throws -> String { String(decoding: try data(path), as: UTF8.self) }

    func data(_ path: String) throws -> Data {
        do { return try Data(contentsOf: root.appending(path: path)) } catch { throw Failure.missing(path) }
    }
}
