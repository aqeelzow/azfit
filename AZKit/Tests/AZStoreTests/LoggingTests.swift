import AZMath
import AZModel
import Foundation
import Testing

@testable import AZStore

/// 2026-11-25 is a Wednesday. The 4-day plan is Push Mon, Pull Tue, Legs Thu, Upper Sat.
private let wednesday = "2026-11-25"

private func started() throws -> AZStore {
    let store = try AZStore.inMemory()
    var profile = person()
    profile.createdAt = Day.date("2026-10-01") ?? .distantPast
    try store.start(profile, weightKg: 82, today: "2026-10-01")
    return store
}

private func time(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

@Suite struct LoggingTests {
    @Test func aRemovedMealLeavesTheTotalsButStays() throws {
        let store = try started()
        let meal = Meal(day: wednesday, name: "Toast", kcal: 300, proteinG: 10, carbsG: 40, fatG: 9, source: .typed)
        try store.logMeal(meal)
        #expect(try store.food(on: wednesday).eatenKcal == 300)
        try store.removeMeal(meal.id)
        #expect(try store.food(on: wednesday).eatenKcal == 0)
        #expect(try store.all(Meal.self).map(\.removed) == [true])
    }

    @Test func recentMealsPutTheMostLoggedFirst() throws {
        let store = try started()
        try store.save(
            Meal(day: "2026-11-20", at: time(1), name: "Oats", kcal: 400, proteinG: 20, carbsG: 60, fatG: 8, source: .typed),
            Meal(day: "2026-11-21", at: time(2), name: "oats ", kcal: 420, proteinG: 22, carbsG: 60, fatG: 8, source: .typed),
            Meal(day: "2026-11-22", at: time(3), name: "Wrap", kcal: 600, proteinG: 35, carbsG: 50, fatG: 20, source: .photo),
            Meal(day: "2026-11-23", at: time(4), name: "Gone", kcal: 900, proteinG: 0, carbsG: 0, fatG: 0, source: .typed, removed: true))
        let recent = try store.recentMeals()
        #expect(recent.map(\.meal.name) == ["oats ", "Wrap"])
        #expect(recent.map(\.times) == [2, 1])
        #expect(recent[0].similar.kcal == 420)
        #expect(recent[0].similar.loggedTimes == 2)
    }

    @Test func weighInsShowInTheTrendAndTheWeeks() throws {
        let store = try started()
        // Onboarding weighed 82 on Oct 1. Then two weeks ago, last week and this week.
        try store.logWeighIn(kg: 82, day: "2026-11-10", at: time(1))
        try store.logWeighIn(kg: 81, day: "2026-11-17", at: time(2))
        try store.logWeighIn(kg: 80, day: wednesday, at: time(3))
        #expect(try store.latestWeighIn()?.kg == 80)
        #expect(try store.all(WeighIn.self).allSatisfy { $0.source == .manual })

        let weeks = try store.weeklyChanges(today: wednesday, weeks: 4)
        #expect(weeks.map(\.weekStart) == ["2026-11-02", "2026-11-09", "2026-11-16", "2026-11-23"])
        // No weigh-in the first week; the second held steady against October.
        #expect(weeks[0].kg == nil && weeks[1].kg == 0)
        #expect((weeks[2].kg ?? 0) < 0 && (weeks[3].kg ?? 0) < 0)
        #expect(!weeks.contains { $0.divChangedTarget })
    }

    @Test func weightCanCoverEveryWeighIn() throws {
        let store = try started()
        try store.logWeighIn(kg: 90, day: "2025-01-01", at: time(1))
        try store.logWeighIn(kg: 82, day: wednesday, at: time(2))
        #expect(try store.weight(today: wednesday).trendDays == [wednesday])
        // `start` saved the onboarding weight too.
        #expect(try store.weight(today: wednesday, days: nil).trendDays.first == "2025-01-01")
    }

    @Test func targetHistoryShowsDivsChangeAndUndo() throws {
        let store = try started()
        let before = try #require(try store.targetHistory(today: wednesday))
        #expect(before.previous == nil && before.change == nil)
        let saved = try store.record(
            [Checked(item: Proposal(.setCalorieTarget(newKcal: before.current.kcal + 150), reason: "Losing too fast."), verdict: .apply)],
            job: "weekly_review", today: "2026-11-23")
        let after = try #require(try store.targetHistory(today: wednesday))
        #expect(after.current.kcal == before.current.kcal + 150)
        #expect(after.previous?.kcal == before.current.kcal)
        #expect(after.change?.proposal.reason == "Losing too fast.")
        #expect(try store.weeklyChanges(today: wednesday, weeks: 1).first?.divChangedTarget == true)
        try store.undo(saved[0].id)
        #expect(try store.target(on: wednesday)?.kcal == before.current.kcal)
    }

    @Test func liftTrendsFollowEachDaysBestSet() throws {
        let store = try started()
        let push = try #require(try store.plan().first { $0.session.name == "Push" }?.session)
        for (day, load) in [("2026-11-16", 80.0), ("2026-11-23", 85.0)] {
            let workout = try store.startWorkout(push, today: day)
            try store.logSet(LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: 0, loadKg: load, reps: 8, rir: 2))
            try store.logSet(
                LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: 1, loadKg: load - 10, reps: 8, rir: 2))
        }
        let lifts = try store.liftTrends(today: wednesday)
        let bench = try #require(lifts.first)
        #expect(bench.name == "Barbell bench press" || bench.exerciseID == "barbell_bench_press")
        #expect(bench.bestDay == "2026-11-23")
        #expect(bench.best.loadKg == 85)
        #expect(bench.points.count == 2)
        #expect(bench.e1rmKg == ((Strength.e1rm(loadKg: 85, reps: 8, rir: 2)) * 10).rounded() / 10)
        #expect((bench.changeKg ?? 0) > 0)
    }

    @Test func swappingAndSwappingBack() throws {
        let store = try started()
        let from = try #require(try store.plan().flatMap { $0.exercises }.first?.exerciseID)
        let count = try store.plannedUses(of: from).count
        #expect(count > 0)
        try store.swapExercise(from, to: "landmine_press")
        let swapped = try store.plannedUses(of: "landmine_press")
        #expect(swapped.count == count)
        #expect(swapped.allSatisfy { $0.row.swappedFromID == from && $0.row.swapEndsDay == nil })
        try store.swapExercise("landmine_press", to: from)
        #expect(try store.plannedUses(of: from).allSatisfy { $0.row.swappedFromID == nil })
    }

    @Test func divSwapFindsTheChangeThatStillStands() throws {
        let store = try started()
        let from = try #require(try store.plan().flatMap { $0.exercises }.first?.exerciseID)
        let name = try #require(Library.standard.exercise(from)?.name)
        let saved = try store.record(
            [Checked(item: Proposal(.swapExercise(from: name, to: "Landmine press", weeks: 2), reason: "Shoulder."), verdict: .apply)],
            job: "chat", today: wednesday)
        #expect(try store.divSwap(into: "landmine_press")?.id == saved[0].id)
        try store.undo(saved[0].id)
        #expect(try store.divSwap(into: "landmine_press") == nil)
    }

    @Test func latestMeasurementsCompareWithTheOneBefore() throws {
        let store = try started()
        try store.save(
            BodyMeasurement(day: "2026-11-01", site: .waist, cm: 84),
            BodyMeasurement(day: "2026-11-20", site: .waist, cm: 82.5),
            BodyMeasurement(day: "2026-11-20", site: .chest, cm: 104))
        let readings = try store.latestMeasurements()
        #expect(readings.map(\.latest.site) == [.waist, .chest])
        #expect(readings[0].changeCm == -1.5)
        #expect(readings[1].changeCm == nil)
    }

    @Test func memoriesAndAutonomy() throws {
        let store = try started()
        let old = Memory(text: "Right knee: no deep lunges", source: .onboarding, createdAt: time(1))
        let new = Memory(text: "Short answers", source: .chat, createdAt: time(2))
        try store.save(old, new)
        #expect(try store.memories().map(\.text) == ["Short answers", "Right knee: no deep lunges"])
        try store.forget(new.id)
        #expect(try store.memories().map(\.id) == [old.id])
        try store.setAutonomy(.allOn)
        #expect(try store.profile()?.autonomy == .allOn)
    }
}
