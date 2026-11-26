import AZModel
import AZStore
import Foundation
import Synchronization

/// The Sunday review, run by the bridge on its own: from Sunday 6 pm until the end of Tuesday, for everyone whose
/// week hasn't been reviewed. A Mac that slept through Sunday catches up when it wakes.
public final class WeeklyReviews: Sendable {
    /// Hour on Sunday the review becomes due, so the day's food and training are in.
    public static let dueHour = 18
    /// Days after Sunday a missed review still runs.
    public static let catchUpDays = 2
    /// People who joined within this many days of the Sunday aren't reviewed yet: too little to read.
    public static let minimumDays = 7

    let div: @Sendable () throws -> Div
    let people: PeopleStores
    let onRun: @Sendable (String, RunInfo) -> Void
    /// Person and week pairs tried since launch, so a review that fails isn't retried every hour.
    private let tried = Mutex<Set<String>>([])

    public init(
        div: @escaping @Sendable () throws -> Div, people: PeopleStores, onRun: @escaping @Sendable (String, RunInfo) -> Void = { _, _ in }
    ) {
        self.div = div
        self.people = people
        self.onRun = onRun
    }

    /// The Sunday on or before `day`.
    public static func sunday(onOrBefore day: String) -> String { AZStore.sunday(onOrBefore: day) }

    /// The Sunday whose review is due at `now`, if any.
    public static func dueWeek(at now: Date, calendar: Calendar = .current) -> String? {
        let today = Day.string(now, calendar: calendar)
        let sunday = AZStore.sunday(onOrBefore: today)
        if today == sunday { return calendar.component(.hour, from: now) >= dueHour ? sunday : nil }
        return today <= Day.adding(catchUpDays, to: sunday) ? sunday : nil
    }

    /// Runs every review that's due. Returns one line per person for the log.
    @discardableResult
    public func runDue(now: Date = .now) async -> [String] {
        guard let week = Self.dueWeek(at: now) else { return [] }
        var lines: [String] = []
        for person in people.people() {
            let key = "\(person.uuidString)-\(week)"
            guard tried.withLock({ $0.insert(key).inserted }) else { continue }
            do {
                lines.append("\(person.uuidString.prefix(8)): " + (try await review(person, week: week, today: Day.string(now))))
            } catch {
                lines.append("\(person.uuidString.prefix(8)): failed, \(error)")
            }
        }
        return lines
    }

    /// Reviews one person's week, unless it's done or too early. Returns what happened.
    public func review(_ person: UUID, week: String, today: String) async throws -> String {
        let store = try people.store(for: person)
        guard try store.weekReview(weekEnding: week) == nil else { return "already reviewed" }
        guard let profile = try store.profile() else { return "not set up" }
        guard Day.string(profile.createdAt) <= Day.adding(-Self.minimumDays, to: week) else { return "too new" }
        guard let snapshot = try store.weeklySnapshot(weekEnding: week) else { return "no target or weigh-in" }
        var div = try div()
        div.autonomy = profile.autonomy
        let result = try await div.weeklyReview(snapshot)
        onRun("weekly_review", result.run)
        let saved = try store.saveWeeklyReview(weekEnding: week, output: result.output, checked: result.checked, today: today)
        return
            "reviewed, \(saved.filter { $0.status == .applied }.count) applied, \(saved.filter { $0.status == .proposed }.count) to check"
    }
}
