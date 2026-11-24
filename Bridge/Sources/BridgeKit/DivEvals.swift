import AZModel
import Foundation

/// Runs the scenarios in Div/evals through the real jobs and checks the outcome, not the wording (D-015).
/// Each run uses some of the person's Claude plan. Run them before changing a prompt.
public struct DivEvals: Sendable {
    public struct Outcome: Sendable {
        public var job: DivJob
        public var name: String
        public var passed: Bool
        /// One line: what Div decided.
        public var summary: String
        /// Why it failed, and any changes the policy refused.
        public var details: [String]
    }

    public let div: Div

    public init(div: Div) {
        self.div = div
    }

    /// Every scenario file for the given jobs whose name contains `filter`.
    public func scenarios(jobs: [DivJob] = DivJob.allCases, filter: String? = nil) -> [(DivJob, URL)] {
        jobs.flatMap { job in
            let dir = div.files.evalsURL.appending(path: job.rawValue)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            return names.filter { $0.hasSuffix(".json") && $0 != "data.json" && (filter == nil || $0.contains(filter!)) }.sorted()
                .map { (job, dir.appending(path: $0)) }
        }
    }

    /// Runs scenarios a few at a time and reports each as it finishes.
    public func run(_ scenarios: [(DivJob, URL)], parallel: Int = 3, report: @Sendable (Outcome) -> Void) async -> [Outcome] {
        await withTaskGroup(of: Outcome.self) { group in
            var outcomes: [Outcome] = []
            var pending = scenarios[...]
            for _ in 0..<min(parallel, pending.count) {
                let (job, url) = pending.removeFirst()
                group.addTask { await self.run(job, url) }
            }
            for await outcome in group {
                report(outcome)
                outcomes.append(outcome)
                if let (job, url) = pending.popFirst() { group.addTask { await self.run(job, url) } }
            }
            return outcomes
        }
    }

    public func run(_ job: DivJob, _ url: URL) async -> Outcome {
        let name = url.deletingPathExtension().lastPathComponent
        do {
            let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
            let expected = fixture["expected"] as? [String: Any] ?? [:]
            switch job {
            case .weeklyReview: return try await weekly(name, fixture, expected)
            case .sessionReview: return try await session(name, fixture, expected)
            case .chat: return try await chat(name, url, fixture, expected)
            case .estimateMeal: return Outcome(job: job, name: name, passed: false, summary: "no meal evals yet", details: [])
            }
        } catch {
            return Outcome(job: job, name: name, passed: false, summary: "error", details: ["\(error)"])
        }
    }

    func weekly(_ name: String, _ fixture: [String: Any], _ expected: [String: Any]) async throws -> Outcome {
        let snapshot = try decode(WeeklySnapshot.self, fixture["snapshot"])
        let r = try await div.weeklyReview(snapshot)
        let actions = expected["calorie_action"] as? [String] ?? []
        let readings = expected["calorie_reading"] as? [String] ?? []
        var failures: [String] = []
        if !actions.contains(r.output.calorieAction.rawValue) {
            failures.append("calorie_action: expected \(actions.joined(separator: " or "))")
        }
        if !readings.contains(r.output.calorieReading.rawValue) {
            failures.append("calorie_reading: expected \(readings.joined(separator: " or "))")
        }
        return Outcome(
            job: .weeklyReview, name: name, passed: failures.isEmpty,
            summary:
                "\(r.output.calorieAction.rawValue)/\(r.output.calorieReading.rawValue), \(r.checked.count) changes, \(seconds(r.run))",
            details: failures + refused(r.checked))
    }

    func session(_ name: String, _ fixture: [String: Any], _ expected: [String: Any]) async throws -> Outcome {
        let report = try decode(SessionReport.self, fixture["session"])
        let r = try await div.sessionReview(report)
        let calls = expected["calls"] as? [String: [String]] ?? [:]
        var failures: [String] = []
        for (exercise, allowed) in calls.sorted(by: { $0.key < $1.key }) {
            let got = r.output.nextTime.first { $0.exercise.lowercased() == exercise.lowercased() }?.call.rawValue ?? "missing"
            if !allowed.contains(got) { failures.append("\(exercise): \(got), expected \(allowed.joined(separator: " or "))") }
        }
        let plan = r.checked.map { "\($0.item.exercise) \($0.item.call.rawValue) \(number($0.item.nextLoadKg))" }.joined(separator: ", ")
        let refusedItems = r.checked.filter { $0.verdict == .refuse }.map {
            "refused \($0.item.exercise): \($0.notes.joined(separator: " "))"
        }
        return Outcome(
            job: .sessionReview, name: name, passed: failures.isEmpty, summary: "\(plan), \(seconds(r.run))",
            details: failures + refusedItems)
    }

    func chat(_ name: String, _ url: URL, _ fixture: [String: Any], _ expected: [String: Any]) async throws -> Outcome {
        let dataFile = url.deletingLastPathComponent().appending(path: fixture["data"] as? String ?? "data.json")
        let data = try DivJSON.decode(DivData.self, from: Data(contentsOf: dataFile))
        let request = try decode(ChatRequest.self, fixture["request"])
        let r = try await div.chat(request, data: data)

        let kinds = r.output.changes.map(\.change.kind)
        let tools = r.toolCalls.map { String($0.split(separator: " ").first ?? "") }
        var failures: [String] = []
        for kind in expected["change_types"] as? [String] ?? [] where !kinds.contains(kind) { failures.append("expected a \(kind)") }
        for kind in expected["forbidden_change_types"] as? [String] ?? [] where kinds.contains(kind) { failures.append("must not \(kind)") }
        if expected["no_changes"] as? Bool == true && !kinds.isEmpty {
            failures.append("expected no changes, got \(kinds.joined(separator: ", "))")
        }
        if let any = expected["tools_any"] as? [String], !any.contains(where: tools.contains) {
            failures.append("expected a call to \(any.joined(separator: " or "))")
        }
        let summary =
            "\(kinds.isEmpty ? "no changes" : kinds.joined(separator: ", ")); tools: \(tools.joined(separator: ", ")); \(seconds(r.run))"
        return Outcome(
            job: .chat, name: name, passed: failures.isEmpty, summary: summary,
            details: failures + ["reply: \(r.output.reply)"] + refused(r.checked))
    }

    func decode<T: Decodable>(_ type: T.Type, _ value: Any?) throws -> T {
        try Validation.decode(T.self, from: JSONSerialization.data(withJSONObject: value ?? [:]))
    }

    func refused(_ checked: [Checked<Proposal>]) -> [String] {
        checked.filter { $0.verdict == .refuse }.map { "refused \($0.item.change.kind): \($0.notes.joined(separator: " "))" }
    }

    func seconds(_ run: RunInfo) -> String { "\(run.durationMs / 1000) s" }
}

func number(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
