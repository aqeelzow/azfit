import AZMath
import AZModel
import Foundation

/// Div's jobs. Each one: code computes the numbers (AZMath), Claude judges (with the prompt and schema from Div/),
/// and code decides what Div's answer may change (the policy).
public struct Div: Sendable {
    public var files: DivFiles
    public var claude: any ClaudeRunning
    public var autonomy: Autonomy
    /// The command that serves chat's read tools over MCP, e.g. ["/path/to/div", "tools"]. Div adds the data and
    /// log arguments. Without it, chat can't run.
    public var toolServer: [String]?

    public init(files: DivFiles, claude: any ClaudeRunning, autonomy: Autonomy = .standard, toolServer: [String]? = nil) {
        self.files = files
        self.claude = claude
        self.autonomy = autonomy
        self.toolServer = toolServer
    }

    /// The Sunday review. The only job that moves calories.
    public func weeklyReview(_ snapshot: WeeklySnapshot) async throws -> WeeklyReviewResult {
        let derived = WeeklyMath.derive(snapshot)
        let prompt = try """
        Here is this week's data. Write the weekly review.

        snapshot:
        \(DivJSON.string(snapshot))

        derived:
        \(DivJSON.string(derived))
        """
        let (output, run): (WeeklyReviewOutput, RunInfo) = try await ask(.weeklyReview, prompt)
        let checked = ChangePolicy.check(output.changes, context: PlanContext(weekly: snapshot, derived: derived), autonomy: autonomy)
        return WeeklyReviewResult(derived: derived, output: output, checked: checked, run: run)
    }

    /// The note after a workout, and next time's loads.
    public func sessionReview(_ session: SessionReport) async throws -> SessionReviewResult {
        let derived = Strength.derive(session)
        let prompt = try """
        Here is the workout that just finished. Write the note and set next time's loads.

        session:
        \(DivJSON.string(session))

        derived:
        \(DivJSON.string(derived))
        """
        let (output, run): (SessionReviewOutput, RunInfo) = try await ask(.sessionReview, prompt)
        let checked = SessionPolicy.check(output, session: session, derived: derived, autonomy: autonomy)
        return SessionReviewResult(derived: derived, output: output, checked: checked, run: run)
    }

    /// A calorie estimate from a meal photo. Claude reads the photo from the job's own folder with the Read tool.
    public func estimateMeal(_ request: MealPhotoRequest) async throws -> MealEstimateResult {
        let file = "photo.\(request.mediaType.fileExtension)"
        // Everything the phone sent except the photo itself, which Claude reads from the file.
        var context = try JSONSerialization.jsonObject(with: DivJSON.encode(request, pretty: false)) as? [String: Any] ?? [:]
        context["photo"] = nil
        let contextJSON = String(
            decoding: try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
        let prompt = """
            Estimate the meal in ./\(file).

            context:
            \(contextJSON)
            """
        var call = try makeCall(.estimateMeal, prompt)
        call.builtInTools = ["Read"]
        call.files = [file: request.photo]
        let (estimate, run): (MealEstimate, RunInfo) = try await ask(call)
        let totals = MealMath.totals(estimate.items)
        let warnings = MealChecks.warnings(estimate, totals: totals, foodWeightG: request.foodWeightG)
        return MealEstimateResult(estimate: estimate, totals: totals, warnings: warnings, run: run)
    }

    /// A chat message. Div looks up what it needs with the read tools (D-021), served from `data`.
    public func chat(_ request: ChatRequest, data: DivData) async throws -> ChatResult {
        guard let toolServer, let command = toolServer.first else { throw ClaudeError.failed("chat needs the read-tool server") }
        var lines = ["Today is \(data.today)."]
        if !request.history.isEmpty {
            lines += ["", "The conversation so far:"]
            lines += request.history.map { "\($0.role == .user ? "Them" : "You"): \($0.text)" }
        }
        lines += ["", "Their new message:", request.message]

        let server: [String: Any] = [
            "type": "stdio",
            "command": command,
            "args": Array(toolServer.dropFirst()) + [
                "--data", "{workdir}/data.json", "--tools", files.toolsURL.path, "--log", "{workdir}/\(Self.toolLog)",
            ],
        ]
        let config = try JSONSerialization.data(withJSONObject: ["mcpServers": [Self.toolServerName: server]], options: [.sortedKeys])

        var call = try makeCall(.chat, lines.joined(separator: "\n"))
        call.mcpConfig = String(decoding: config, as: UTF8.self)
        call.allowedTools = ["mcp__\(Self.toolServerName)"]
        call.files = ["data.json": try DivJSON.encode(data, pretty: false)]
        call.collect = [Self.toolLog]
        let reply = try await claude.run(call)
        let output = try decodeOutput(ChatOutput.self, reply.output)
        let toolCalls =
            reply.collected[Self.toolLog].map { String(decoding: $0, as: UTF8.self).split(separator: "\n").map(String.init) } ?? []
        let checked = ChangePolicy.check(output.changes, context: PlanContext(chat: data), autonomy: autonomy)
        return ChatResult(output: output, checked: checked, toolCalls: toolCalls, run: reply.run)
    }

    public static let toolServerName = "div"
    static let toolLog = "tool-calls.log"

    func makeCall(_ job: DivJob, _ prompt: String) throws -> ClaudeCall {
        var call = ClaudeCall(
            model: job.model, systemPrompt: try files.systemPrompt(for: job), userPrompt: prompt, schema: try files.schema(for: job))
        call.effort = job.effort
        call.timeout = job.timeout
        return call
    }

    func ask<T: Decodable>(_ job: DivJob, _ prompt: String) async throws -> (T, RunInfo) {
        try await ask(try makeCall(job, prompt))
    }

    func ask<T: Decodable>(_ call: ClaudeCall) async throws -> (T, RunInfo) {
        let reply = try await claude.run(call)
        return (try decodeOutput(T.self, reply.output), reply.run)
    }

    func decodeOutput<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try DivJSON.decode(T.self, from: data) } catch {
            throw ClaudeError.badOutput("didn't match the schema: \(error)")
        }
    }
}
