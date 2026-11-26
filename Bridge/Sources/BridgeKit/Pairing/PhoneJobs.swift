import AZModel
import AZStore
import AZSync
import Foundation

/// Runs what a phone asks for: syncing its data into the person's database here, and Div's jobs on that data.
public struct PhoneJobs: Sendable {
    /// Div, made when a job needs Claude (so syncing works even when Claude Code isn't installed).
    public var div: @Sendable () throws -> Div
    /// Each person's database on this Mac.
    public var people: PeopleStores
    /// What chat reads for a phone that hasn't finished onboarding: the sample person in Div/evals/chat/data.json.
    public var sampleData: (@Sendable () throws -> DivData)?
    /// Called after each run Claude finished, with the job's name, for the log.
    public var onRun: @Sendable (String, RunInfo) -> Void
    public var today: @Sendable () -> String

    public init(
        div: @escaping @Sendable () throws -> Div, people: PeopleStores, sampleData: (@Sendable () throws -> DivData)? = nil,
        onRun: @escaping @Sendable (String, RunInfo) -> Void = { _, _ in }, today: @escaping @Sendable () -> String = { Day.string(.now) }
    ) {
        self.div = div
        self.people = people
        self.sampleData = sampleData
        self.onRun = onRun
        self.today = today
    }

    public static func sampleData(_ files: DivFiles) -> @Sendable () throws -> DivData {
        let url = files.evalsURL.appending(path: "chat/data.json")
        return { try DivJSON.decode(DivData.self, from: Data(contentsOf: url)) }
    }

    /// The peer name the bridge's databases use for the phone.
    static let phonePeer = "phone"

    public func handle(_ request: Request) async -> Outcome {
        do {
            switch request.job {
            case .sync(let push):
                guard let person = request.person else { return .failed("Finish setting up AZfit first.") }
                let store = try people.store(for: person)
                try store.apply(push.batch, from: Self.phonePeer)
                return .synced(
                    SyncPull(batch: try store.changes(after: push.since), received: try store.receivedSeq(from: Self.phonePeer)))

            case .sessionReview(let review):
                guard let person = request.person else { return .failed("Finish setting up AZfit first.") }
                let store = try people.store(for: person)
                guard let report = try store.sessionReport(review.workoutID) else {
                    return .failed("There's nothing logged in that workout to review.")
                }
                var div = try div()
                div.autonomy = try store.profile()?.autonomy ?? .standard
                let result = try await div.sessionReview(report)
                onRun("session_review", result.run)
                let saved = try store.saveSessionReview(
                    review.workoutID, note: result.output.note, nextTime: result.checked, report: report, today: today())
                return .sessionReviewed(
                    SessionReviewReply(
                        note: result.output.note, applied: saved.filter { $0.status == .applied }.count,
                        proposed: saved.filter { $0.status == .proposed }.count))

            case .estimateMeal(let photo):
                let result = try await div().estimateMeal(photo)
                onRun("estimate_meal", result.run)
                return .mealEstimated(MealEstimateReply(estimate: result.estimate, totals: result.totals, warnings: result.warnings))

            case .reviseMeal(let revision):
                let result = try await div().reviseMeal(revision)
                onRun("revise_meal", result.run)
                return .mealEstimated(MealEstimateReply(estimate: result.estimate, totals: result.totals, warnings: result.warnings))

            case .chat(let chat):
                var div = try div()
                let today = today()
                let store = try request.person.map { try people.store(for: $0) }
                let profile = try store?.profile()
                let data: DivData
                if let store, let profile, let personal = try store.divData(today: today) {
                    try store.endSwaps(today: today)
                    div.autonomy = profile.autonomy
                    data = personal
                } else if let sampleData {
                    data = try sampleData()
                } else {
                    return .failed("Finish setting up AZfit first.")
                }
                let result = try await div.chat(chat, data: data)
                onRun("chat", result.run)
                var ids: [UUID?] = result.checked.map { _ in nil }
                if let store, profile != nil {
                    var saved = try store.record(result.checked, job: "chat", today: today)[...]
                    for (i, checked) in result.checked.enumerated() where checked.verdict != .refuse && !saved.isEmpty {
                        ids[i] = saved.removeFirst().id
                    }
                    try store.save(result.output.remember.map { Memory(text: $0, source: .chat) })
                }
                return .chat(
                    ChatReply(
                        reply: result.output.reply, changes: result.checked, remember: result.output.remember, model: result.run.model,
                        saved: ids))
            }
        } catch let error as ClaudeError {
            return .failed(Self.describe(error))
        } catch {
            return .failed("Div couldn't answer: \(error)")
        }
    }

    /// Short enough for a chat bubble on the phone.
    static func describe(_ error: ClaudeError) -> String {
        switch error {
        case .notInstalled: "Claude Code isn't installed on your Mac."
        case .timedOut: "Div took too long to answer. Try again."
        case .failed(let message) where message.localizedCaseInsensitiveContains("log"):
            "Claude is signed out on your Mac. Sign in from the AZfit Bridge menu."
        case .failed, .badOutput: "Div couldn't answer that time. Try again."
        }
    }
}
