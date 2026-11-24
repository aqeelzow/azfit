import AZMath
import AZModel
import Foundation
import Testing

@testable import BridgeKit

/// Verdicts for proposals against a weekly snapshot, with the given autonomy.
func verdicts(_ s: WeeklySnapshot, _ autonomy: Autonomy = .standard, _ changes: PlanChange...) -> [Verdict] {
    ChangePolicy.check(changes.map { Proposal($0) }, context: PlanContext(weekly: s, derived: WeeklyMath.derive(s)), autonomy: autonomy)
        .map(\.verdict)
}

@Suite struct CalorieTests {
    @Test func validStepAppliesWhenAllowedAndAsksWhenNot() throws {
        let s = try snapshot("surplus-too-big")
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2700)) == [.apply])
        #expect(verdicts(s, .askFirst, .setCalorieTarget(newKcal: 2700)) == [.propose])
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2800)) == [.apply])
    }

    @Test func stepsOver200UnderTheFloorOrOffThe50sAreRefused() throws {
        let s = try snapshot("surplus-too-big")
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2600)) == [.refuse])
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2770)) == [.refuse])
        #expect(verdicts(try snapshot("deficit-too-steep"), .standard, .setCalorieTarget(newKcal: 1650)) == [.refuse])
    }

    @Test func refusedWithTooFewCompleteDaysAWaterEventOrTooSoon() throws {
        #expect(verdicts(try snapshot("insufficient-data"), .standard, .setCalorieTarget(newKcal: 1850)) == [.refuse])
        #expect(verdicts(try snapshot("water"), .standard, .setCalorieTarget(newKcal: 2200)) == [.refuse])
        var s = try snapshot("surplus-too-big")
        s.daysSinceLastCalorieChange = 7
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2700)) == [.refuse])
    }

    @Test func cantCutWhileLosingTooFastButCanAddFood() throws {
        let s = try snapshot("deficit-too-steep")
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 1750)) == [.refuse])
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2100)) == [.apply])
    }

    @Test func onlyOneCalorieChangePerReview() throws {
        let s = try snapshot("surplus-too-big")
        #expect(verdicts(s, .standard, .setCalorieTarget(newKcal: 2700), .setCalorieTarget(newKcal: 2750)) == [.apply, .refuse])
    }

    @Test func chatCantMoveCaloriesOrProtein() throws {
        let context = PlanContext(chat: try chatData())
        let checked = ChangePolicy.check(
            [Proposal(.setCalorieTarget(newKcal: 2450)), Proposal(.setProteinTarget(gramsPerKg: 2.1))], context: context,
            autonomy: .standard)
        #expect(checked.map(\.verdict) == [.refuse, .refuse])
    }
}

@Suite struct TrainingChangeTests {
    @Test func proteinRangeDependsOnGoalAndKidneyDiseaseBlocksIt() throws {
        var s = try snapshot("recomp")
        #expect(verdicts(s, .standard, .setProteinTarget(gramsPerKg: 2.0)) == [.propose])
        #expect(verdicts(s, .standard, .setProteinTarget(gramsPerKg: 2.6)) == [.refuse])
        s.user.kidneyDisease = true
        #expect(verdicts(s, .standard, .setProteinTarget(gramsPerKg: 2.0)) == [.refuse])
    }

    @Test func routineLoadIncreaseAppliesBigJumpsAskAndUnknownLiftsAreRefused() throws {
        let s = try snapshot("recomp")
        #expect(verdicts(s, .standard, .setLoad(exercise: "Bench press", newLoadKg: 82.5)) == [.apply])
        #expect(verdicts(s, .askFirst, .setLoad(exercise: "Bench press", newLoadKg: 82.5)) == [.propose])
        #expect(verdicts(s, .standard, .setLoad(exercise: "Back squat", newLoadKg: 115)) == [.propose])
        #expect(verdicts(s, .standard, .setLoad(exercise: "Bench press", newLoadKg: 92.5)) == [.refuse])
        #expect(verdicts(s, .standard, .setLoad(exercise: "Cable fly", newLoadKg: 20)) == [.refuse])
    }

    @Test func volumeIsCappedAndAlwaysAsks() throws {
        var s = try snapshot("recomp")
        #expect(verdicts(s, .standard, .changeVolume(muscle: "Rear delts", deltaSetsPerWeek: 2)) == [.propose])
        #expect(verdicts(s, .standard, .changeVolume(muscle: "Rear delts", deltaSetsPerWeek: 6)) == [.refuse])
        s.volume = [.init(muscle: "Chest", setsThisWeek: 18, mev: 10, mrv: 20)]
        #expect(verdicts(s, .standard, .changeVolume(muscle: "Chest", deltaSetsPerWeek: 4)) == [.refuse])
    }

    @Test func deloadsAlwaysAsk() throws {
        let s = try snapshot("recomp")
        #expect(verdicts(s, .standard, .scheduleDeload(startDate: "2026-11-23", weeks: 1)) == [.propose])
        #expect(verdicts(s, .standard, .scheduleDeload(startDate: "2026-11-23", weeks: 3)) == [.refuse])
        #expect(verdicts(s, .standard, .scheduleDeload(startDate: "next week", weeks: 1)) == [.refuse])
    }

    @Test func swapsAndMovesFollowTheSwitchAndMustNameRealThings() throws {
        let context = PlanContext(chat: try chatData())
        func check(_ change: PlanChange, _ autonomy: Autonomy = .standard) -> Verdict {
            ChangePolicy.check([Proposal(change)], context: context, autonomy: autonomy)[0].verdict
        }
        #expect(check(.swapExercise(from: "Overhead press", to: "Landmine press")) == .apply)
        #expect(check(.swapExercise(from: "Overhead press", to: "Landmine press"), .askFirst) == .propose)
        #expect(check(.swapExercise(from: "Snatch", to: "Landmine press")) == .refuse)
        #expect(check(.moveSession(session: "Legs", toDay: "Friday")) == .apply)
        #expect(check(.moveSession(session: "Legs", toDay: "Someday")) == .refuse)
        #expect(check(.moveSession(session: "Arms", toDay: "Friday")) == .refuse)
    }
}
