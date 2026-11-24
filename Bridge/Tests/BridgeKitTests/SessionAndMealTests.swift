import AZMath
import AZModel
import Foundation
import Testing

@testable import BridgeKit

@Suite struct SessionPolicyTests {
    func verdict(_ item: NextTime, _ autonomy: Autonomy = .standard) throws -> Verdict {
        let s = try session("push-day")
        return SessionPolicy.check(SessionReviewOutput(nextTime: [item]), session: s, derived: Strength.derive(s), autonomy: autonomy)[0]
            .verdict
    }

    @Test func routineProgressAppliesBiggerOrUnearnedJumpsAskHugeOnesAreRefused() throws {
        #expect(try verdict(NextTime(exercise: "Bench press", call: .progress, nextLoadKg: 82.5)) == .apply)
        #expect(try verdict(NextTime(exercise: "Bench press", call: .progress, nextLoadKg: 82.5), .askFirst) == .propose)
        #expect(try verdict(NextTime(exercise: "Bench press", call: .progress, nextLoadKg: 87.5)) == .propose)
        #expect(try verdict(NextTime(exercise: "Bench press", call: .progress, nextLoadKg: 90)) == .refuse)
        #expect(try verdict(NextTime(exercise: "Incline DB press", call: .progress, nextLoadKg: 32)) == .propose)
    }

    @Test func repeatKeepsTheLoadAndReduceLowersItWithinLimits() throws {
        #expect(try verdict(NextTime(exercise: "Incline DB press", call: .repeat, nextLoadKg: 30)) == .apply)
        #expect(try verdict(NextTime(exercise: "Incline DB press", call: .repeat, nextLoadKg: 32)) == .refuse)
        #expect(try verdict(NextTime(exercise: "Overhead press", call: .reduce, nextLoadKg: 47.5)) == .apply)
        #expect(try verdict(NextTime(exercise: "Overhead press", call: .reduce, nextLoadKg: 42.5)) == .propose)
        #expect(try verdict(NextTime(exercise: "Overhead press", call: .reduce, nextLoadKg: 35)) == .refuse)
        #expect(try verdict(NextTime(exercise: "Overhead press", call: .reduce, nextLoadKg: 52.5)) == .refuse)
        #expect(try verdict(NextTime(exercise: "Cable fly", call: .repeat, nextLoadKg: 20)) == .refuse)
    }

    @Test func exercisesDivLeavesOutKeepTheirLoad() throws {
        let s = try session("push-day")
        let checked = SessionPolicy.check(SessionReviewOutput(nextTime: []), session: s, derived: Strength.derive(s), autonomy: .standard)
        #expect(checked.count == s.exercises.count)
        #expect(checked.allSatisfy { $0.item.call == .repeat && $0.verdict == .apply })
    }
}

@Suite struct MealCheckTests {
    let rice = MealItem(name: "Rice", portion: "1 cup", grams: 200, kcal: 260, proteinG: 5, carbsG: 57, fatG: 0.6)
    let chicken = MealItem(name: "Chicken", portion: "1 breast", grams: 150, kcal: 248, proteinG: 46, carbsG: 0, fatG: 5.4)

    func warnings(_ items: [MealItem], _ low: Double = 0, _ high: Double = 9999, weight: Double? = nil) -> [String] {
        let e = MealEstimate(items: items, kcalLow: low, kcalHigh: high)
        return MealChecks.warnings(e, totals: MealMath.totals(items), foodWeightG: weight)
    }

    @Test func aConsistentMealHasNoWarnings() {
        #expect(warnings([rice, chicken], 450, 600).isEmpty)
    }

    @Test func flagsCaloriesThatDontMatchTheMacros() {
        var bad = rice
        bad.kcal = 600
        #expect(warnings([bad]).contains { $0.contains("doesn't match its macros") })
    }

    @Test func flagsTotalsOutsideTheRangeAndAWeightThatDisagreesWithTheScale() {
        let w = warnings([rice, chicken], 800, 900, weight: 500)
        #expect(w.contains { $0.contains("outside the stated range") })
        #expect(w.contains { $0.contains("scale said 500 g") })
    }
}

@Suite struct ValidationTests {
    @Test func badInputListsWhatsWrong() throws {
        #expect(throws: Validation.Invalid.self) { try Validation.decode(WeeklySnapshot.self, from: Data("{}".utf8)) }
        var s = try session("push-day")
        s.soreness = 9
        #expect(Validation.check(s) == ["soreness must be 1 to 5"])
        #expect(Validation.check(MealPhotoRequest(photo: Data(), mediaType: .jpeg)) == ["photo is missing"])
    }

    @Test func goodFixturesPass() throws {
        for name in ["recomp", "surplus-too-big", "lean-gain", "deficit-too-steep", "water", "insufficient-data"] {
            #expect(Validation.check(try snapshot(name)).isEmpty, "\(name)")
        }
        #expect(Validation.check(try session("leg-day")).isEmpty)
    }
}
