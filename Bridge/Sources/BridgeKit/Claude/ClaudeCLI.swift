import Foundation
import Synchronization

/// Runs jobs through the user's own Claude Code (`claude -p`), signed in with their own Claude account (D-007).
/// AZfit never sees or stores the login.
public struct ClaudeCLI: ClaudeRunning {
    public let executable: URL

    public init(executable: URL) {
        self.executable = executable
    }

    /// Finds `claude` on PATH or in the usual install places. A menu bar app started from Finder gets a short PATH,
    /// so the common folders are checked as well.
    public static func locate() throws -> ClaudeCLI {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let dirs = path + ["\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin"]
        for dir in dirs where FileManager.default.isExecutableFile(atPath: "\(dir)/claude") {
            return ClaudeCLI(executable: URL(filePath: "\(dir)/claude"))
        }
        throw ClaudeError.notInstalled
    }

    /// The arguments for a call. Everything that isn't Div's is switched off: no settings, slash commands, saved
    /// sessions, or MCP servers other than ours.
    static func arguments(for call: ClaudeCall, workDir: URL) -> [String] {
        var args = [
            "-p",
            "--model", call.model,
            "--system-prompt", call.systemPrompt,
            "--json-schema", call.schema,
            "--output-format", "json",
            "--tools", call.builtInTools.joined(separator: ","),
            "--setting-sources", "",
            "--strict-mcp-config",
            "--disable-slash-commands",
            "--no-session-persistence",
        ]
        if let effort = call.effort { args += ["--effort", effort] }
        if let mcp = call.mcpConfig { args += ["--mcp-config", mcp.replacing("{workdir}", with: workDir.path)] }
        if !call.allowedTools.isEmpty { args += ["--allowedTools"] + call.allowedTools }
        return args
    }

    public func run(_ call: ClaudeCall) async throws -> ClaudeReply {
        // An empty folder, so no CLAUDE.md or project files are picked up. Deleted afterwards with everything in it.
        let workDir = FileManager.default.temporaryDirectory.appending(path: "azfit-job-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: workDir) }

        for (name, data) in call.files {
            guard !name.contains("/"), !name.hasPrefix(".") else { throw ClaudeError.failed("bad file name \"\(name)\"") }
            try data.write(to: workDir.appending(path: name))
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: workDir.appending(path: name).path)
        }

        let (status, stdout, stderr) = try await execute(arguments: Self.arguments(for: call, workDir: workDir), in: workDir, call: call)
        var reply = try Self.parse(stdout: stdout, stderr: stderr, status: status, model: call.model)
        for name in call.collect {
            if let data = try? Data(contentsOf: workDir.appending(path: name)) { reply.collected[name] = data }
        }
        return reply
    }

    private func execute(arguments: [String], in workDir: URL, call: ClaudeCall) async throws -> (Int32, Data, Data) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workDir
        // An API key in the environment would switch Claude Code to API billing. Remove it so the run always
        // uses the signed-in Claude account.
        var env = ProcessInfo.processInfo.environment
        env["ANTHROPIC_API_KEY"] = nil
        env["ANTHROPIC_AUTH_TOKEN"] = nil
        process.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ClaudeError.failed("couldn't start \(executable.path): \(error.localizedDescription)")
        }
        // Read both pipes while Claude runs, so a full pipe never blocks it.
        let out = Task.detached { (try? stdout.fileHandleForReading.readToEnd()) ?? Data() }
        let err = Task.detached { (try? stderr.fileHandleForReading.readToEnd()) ?? Data() }
        Task.detached {
            try? stdin.fileHandleForWriting.write(contentsOf: Data(call.userPrompt.utf8))
            try? stdin.fileHandleForWriting.close()
        }
        let timedOut = Atomic<Bool>(false)
        let watchdog = Task.detached {
            try await Task.sleep(for: call.timeout)
            timedOut.store(true, ordering: .relaxed)
            process.terminate()
        }
        defer { watchdog.cancel() }

        let output = await out.value
        let errors = await err.value
        process.waitUntilExit()
        if timedOut.load(ordering: .relaxed) { throw ClaudeError.timedOut(call.timeout) }
        return (process.terminationStatus, output, errors)
    }

    /// Reads the `--output-format json` envelope.
    static func parse(stdout: Data, stderr: Data, status: Int32, model: String) throws -> ClaudeReply {
        guard let envelope = try? JSONSerialization.jsonObject(with: stdout) as? [String: Any] else {
            let text = String(decoding: stdout.isEmpty ? stderr : stdout, as: UTF8.self)
            throw status == 0
                ? ClaudeError.badOutput(String(text.prefix(300)))
                : ClaudeError.failed("exit \(status): \(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))")
        }
        if envelope["is_error"] as? Bool == true || envelope["subtype"] as? String != "success" {
            let detail = envelope["result"] as? String ?? envelope["subtype"] as? String ?? "unknown error"
            throw ClaudeError.failed(detail)
        }
        guard let structured = envelope["structured_output"], !(structured is NSNull) else {
            throw ClaudeError.badOutput("no structured output")
        }
        // Claude Code can make small helper calls on another model; report the one we asked for.
        let models = (envelope["modelUsage"] as? [String: Any])?.keys.sorted() ?? []
        let run = RunInfo(
            model: models.first { $0.contains(model) } ?? models.first ?? model,
            durationMs: envelope["duration_ms"] as? Int ?? 0,
            turns: envelope["num_turns"] as? Int,
            costUsdEquivalent: envelope["total_cost_usd"] as? Double
        )
        return ClaudeReply(output: try JSONSerialization.data(withJSONObject: structured), run: run)
    }
}
