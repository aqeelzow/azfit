import AZModel
import AZStore
import Foundation
import Testing

@testable import BridgeKit

@Suite struct WeeklyReviewsTests {
    private func at(_ day: String, _ hour: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hour, to: Day.date(day)!)!
    }

    @Test func dueFromSundayEveningUntilTuesday() {
        #expect(WeeklyReviews.dueWeek(at: at("2026-11-29", 17)) == nil)
        #expect(WeeklyReviews.dueWeek(at: at("2026-11-29", 18)) == "2026-11-29")
        #expect(WeeklyReviews.dueWeek(at: at("2026-11-30", 9)) == "2026-11-29")
        #expect(WeeklyReviews.dueWeek(at: at("2026-12-01", 23)) == "2026-11-29")
        #expect(WeeklyReviews.dueWeek(at: at("2026-12-02", 9)) == nil)
    }

    private func person(in people: PeopleStores, joined: String) throws -> UUID {
        var profile = Profile(name: "Sam", sex: .male, birthYear: 1996, heightCm: 180, goal: .cut, trainingDays: 4)
        profile.createdAt = Day.date(joined)!
        let store = try people.store(for: profile.id)
        try store.start(profile, weightKg: 82, today: joined)
        return profile.id
    }

    @Test func reviewsOncePerWeekAndSavesIt() async throws {
        let people = PeopleStores(folder: FileManager.default.temporaryDirectory.appending(path: "azfit-weekly-\(UUID().uuidString)"))
        let sam = try person(in: people, joined: "2026-11-01")
        let new = try person(in: people, joined: "2026-11-27")
        let answer = """
            {"summary":"Steady week.","calorie_reading":"insufficient_data","calorie_action":"hold",
             "calorie_reasoning":"Too few complete days.","changes":[],"questions":["Did you log every meal?"]}
            """
        let claude = FakeClaude(answer: answer)
        let reviews = WeeklyReviews(div: { Div(files: divFiles, claude: claude) }, people: people)

        let lines = await reviews.runDue(now: at("2026-11-29", 19))
        #expect(lines.count == 2)
        #expect(lines.contains { $0.hasPrefix(sam.uuidString.prefix(8)) && $0.contains("reviewed") })
        #expect(lines.contains { $0.hasPrefix(new.uuidString.prefix(8)) && $0.contains("too new") })
        let review = try #require(try people.store(for: sam).weekReview(weekEnding: "2026-11-29"))
        #expect(review.summary == "Steady week.")
        #expect(review.questions == ["Did you log every meal?"])

        // An hour later nothing runs again, and a fresh bridge sees the review is done.
        #expect(await reviews.runDue(now: at("2026-11-29", 20)).isEmpty)
        let restarted = WeeklyReviews(div: { Div(files: divFiles, claude: claude) }, people: people)
        #expect(try await restarted.review(sam, week: "2026-11-29", today: "2026-11-30") == "already reviewed")
        #expect(people.people().count == 2)
    }
}
