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

@Suite struct MealMathTests {
    @Test func totalsAddUpTheItems() {
        let rice = MealItem(name: "Rice", portion: "1 cup", grams: 200, kcal: 260, proteinG: 5, carbsG: 57, fatG: 0.6)
        let chicken = MealItem(name: "Chicken", portion: "1 breast", grams: 150, kcal: 248, proteinG: 46, carbsG: 0, fatG: 5.4)
        let t = MealMath.totals([rice, chicken])
        #expect(t.kcal == 508)
        #expect(t.proteinG == 51)
        #expect(t.grams == 350)
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
