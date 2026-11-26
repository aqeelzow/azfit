import AZModel
import Foundation
import Testing

@testable import AZMath

/// Loads a fixture from Div/evals/<job>/<name>.json and returns the value under `key`.
func fixture<T: Decodable>(_ job: String, _ name: String, key: String, as type: T.Type = T.self) throws -> T {
    let url = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Div/evals/\(job)/\(name).json")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    return try DivJSON.decode(T.self, from: JSONSerialization.data(withJSONObject: object[key]!))
}

func snapshot(_ name: String) throws -> WeeklySnapshot { try fixture("weekly-review", name, key: "snapshot") }
func session(_ name: String) throws -> SessionReport { try fixture("session-review", name, key: "session") }

@Suite struct WeeklyMathTests {
    @Test func recompReadsFlatScaleWaistDownStrengthUp() throws {
        let d = WeeklyMath.derive(try snapshot("recomp"))
        #expect(d.scaleDirection == .flat)
        #expect(d.waistDirection == .down)
        #expect(d.strengthDirection == .up)
    }

    @Test func impliedMaintenanceUsesTrendChangeTimes7700OverDays() throws {
        // 2900 - (1.4 x 7700) / 21 = 2386.7, rounded to 2390.
        #expect(WeeklyMath.derive(try snapshot("surplus-too-big")).impliedMaintenanceKcal == 2390)
    }

    @Test func maintenanceIsUnknownWithTooFewCompleteDays() throws {
        let d = WeeklyMath.derive(try snapshot("insufficient-data"))
        #expect(d.enoughCompleteDays == false)
        #expect(d.impliedMaintenanceKcal == nil)
    }

    @Test func losingOverOnePercentAWeekLiftsTheWait() throws {
        let d = WeeklyMath.derive(try snapshot("deficit-too-steep"))
        #expect(d.losingTooFast)
        #expect(d.calorieChangeAllowedByTime)
    }

    @Test func waterWeekShowsTheJump() throws {
        #expect(WeeklyMath.derive(try snapshot("water")).weightJumpKgThisWeek >= 1.5)
    }

    @Test func proteinRangesByGoal() {
        #expect(WeeklyMath.proteinRange(for: .cut) == 2.0...2.2)
        #expect(WeeklyMath.proteinRange(for: .build).contains(1.6))
    }
}

@Suite struct StrengthTests {
    @Test func e1rmCountsRepsInReserve() {
        #expect(rounded(Strength.e1rm(loadKg: 80, reps: 10, rir: 2)) == 112)
    }

    @Test func deriveSpotsTopOfRangeAndLowRIR() throws {
        let d = Strength.derive(try session("push-day"))
        let bench = try #require(d.exercises.first { $0.exercise == "Bench press" })
        let ohp = try #require(d.exercises.first { $0.exercise == "Overhead press" })
        #expect(bench.allSetsAtTopOfRange)
        #expect(bench.rirVsPrescribed == 0)
        #expect(ohp.allSetsAtTopOfRange == false)
        #expect(ohp.rirVsPrescribed == -2)
    }
}

@Suite struct InWorkoutMathTests {
    @Test func setsAreReadAgainstTheRangeAndRIR() throws {
        let r = try fixture("in-workout", "reps-dropping", key: "request", as: InWorkoutRequest.self)
        let d = Strength.derive(r)
        #expect(d.setsDone == 2 && d.setsLeft == 1)
        #expect(d.sets.map(\.repRange) == ["top", "in"])
        #expect(d.sets.map(\.rirVsPrescribed) == [0, -1])
        #expect(try #require(d.lastSetE1rm) < (try #require(d.firstSetE1rm)))
    }
}

@Suite struct MealMathTests {
    @Test func totalsAddUpTheItems() {
        let rice = MealItem(name: "Rice", portion: "1 cup", grams: 200, kcal: 260, proteinG: 5, carbsG: 57, fatG: 0.6)
        let chicken = MealItem(name: "Chicken", portion: "1 breast", grams: 150, kcal: 248, proteinG: 46, carbsG: 0, fatG: 5.4)
        let t = MealMath.totals([rice, chicken])
        #expect(t.kcal == 508)
        #expect(t.proteinG == 51)
        #expect(t.grams == 350)
    }

    @Test func aTypedMealUsesItsCaloriesOrItsMacros() {
        #expect(MealMath.typed(kcal: 450, proteinG: 30, carbsG: nil, fatG: nil)?.kcal == 450)
        let fromMacros = MealMath.typed(kcal: nil, proteinG: 30, carbsG: 50, fatG: 10)
        #expect(fromMacros?.kcal == 410)
        #expect(fromMacros?.carbsG == 50)
        #expect(MealMath.typed(kcal: nil, proteinG: nil, carbsG: nil, fatG: nil) == nil)
        #expect(MealMath.typed(kcal: -5, proteinG: nil, carbsG: nil, fatG: nil) == nil)
        #expect(MealMath.typed(kcal: 40_000, proteinG: nil, carbsG: nil, fatG: nil) == nil)
    }
}

@Suite struct WeightTrendTests {
    @Test func eachWeighInMovesTheTrendTenPercent() {
        #expect(WeightTrend.trend([80, 81, 81]) == [80, 80.1, 80.19])
    }

    @Test func weeklyRate() {
        #expect(WeightTrend.weeklyRateKg([82, 81], days: 14) == -0.5)
    }
}

@Suite struct TargetTests {
    @Test func theFloorIsBMRRoundedUpAndNeverUnder1200() {
        // Mifflin-St Jeor: 10 × 80 + 6.25 × 180 - 5 × 30 + 5 = 1,780.
        #expect(Targets.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 30) == 1_780)
        #expect(Targets.calorieFloor(sex: .male, weightKg: 80, heightCm: 180, age: 30) == 1_800)
        #expect(Targets.calorieFloor(sex: .female, weightKg: 45, heightCm: 150, age: 70) == 1_200)
        #expect(Targets.calorieFloor(sex: nil, weightKg: nil, heightCm: nil, age: nil) == 1_200)
        #expect(Targets.calorieFloor(sex: .male, weightKg: nil, heightCm: nil, age: nil) == 1_500)
    }

    @Test func breakdownAddsUpToTheTarget() {
        let b = Targets.startingBreakdown(sex: .male, weightKg: 80, heightCm: 180, age: 30, goal: .cut, ratePctPerWeek: -0.5)
        // 800 + 1,125 - 150 + 5 = 1,780 resting, × 1.5 = 2,670, and 0.4 kg a week off is -440 a day.
        #expect(b.bmr == 1_780)
        #expect(b.maintenance == 2_670)
        #expect(b.goalAdjustment == -440)
        #expect(b.kcal == 2_250 && !b.heldAtFloor)
        #expect(b.kcal == Targets.startingCalories(sex: .male, weightKg: 80, heightCm: 180, age: 30, goal: .cut, ratePctPerWeek: -0.5))
        let tiny = Targets.startingBreakdown(sex: .female, weightKg: 45, heightCm: 150, age: 60, goal: .cut, ratePctPerWeek: -1)
        #expect(tiny.heldAtFloor && tiny.kcal == tiny.floor)
    }

    @Test func startingCaloriesFollowTheGoal() {
        let maintain = Targets.startingCalories(sex: .male, weightKg: 80, heightCm: 180, age: 30, goal: .recomp, ratePctPerWeek: 0)
        let cut = Targets.startingCalories(sex: .male, weightKg: 80, heightCm: 180, age: 30, goal: .cut, ratePctPerWeek: -0.5)
        #expect(maintain == 2_650)  // 1,780 × 1.5 = 2,670, to the nearest 50
        #expect(cut == 2_250)  // 0.4 kg a week is 440 kcal a day less: 2,230, to the nearest 50
        #expect(Targets.startingProtein(goal: .cut) == 2.1)
    }
}
