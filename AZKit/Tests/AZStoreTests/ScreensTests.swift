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
    profile.createdAt = Day.date("2026-11-01") ?? .distantPast
    try store.start(profile, weightKg: 82, today: "2026-11-23")
    return store
}

@Suite struct ScreensTests {
    @Test func weekShowsDoneMissedAndToday() throws {
        let store = try started()
        let push = try #require(try store.plan().first { $0.session.name == "Push" }?.session)
        let workout = try store.startWorkout(push, today: "2026-11-23")
        try store.finishWorkout(workout.id)
        let week = try store.week(today: wednesday)
        #expect(week.map(\.day).first == "2026-11-23")
        #expect(week.map(\.state) == [.done, .missed, .today, .open, .open, .open, .open])
        #expect(week[3].sessionName == "Legs")
    }

    @Test func onboardingWithoutSexStillSetsATarget() throws {
        let store = try AZStore.inMemory()
        var profile = person()
        profile.sex = nil
        try store.start(profile, weightKg: 77, today: wednesday)
        let kcal = try #require(try store.target(on: wednesday)?.kcal)
        let male = Targets.startingCalories(
            sex: .male, weightKg: 77, heightCm: 180, age: 30, goal: .cut, ratePctPerWeek: profile.targetRatePctPerWeek)
        #expect(kcal > 1_200 && kcal <= male)
    }

    @Test func aMissingTargetIsFilledOnce() throws {
        let store = try AZStore.inMemory()
        try store.save(person())
        try store.save(WeighIn(day: wednesday, kg: 80))
        try store.fillMissingTarget(today: wednesday)
        try store.fillMissingTarget(today: wednesday)
        #expect(try store.all(NutritionTarget.self).count == 1)
    }

    @Test func daysBeforeJoiningArentMissed() throws {
        let store = try AZStore.inMemory()
        var profile = person()
        profile.createdAt = Day.date(wednesday) ?? .now
        try store.start(profile, weightKg: 82, today: wednesday)
        let week = try store.week(today: wednesday)
        #expect(week.prefix(3).map(\.state) == [.open, .open, .today])
        #expect(week.compactMap(\.sessionName) == ["Legs", "Upper"])
    }

    @Test func movedSessionShowsOnItsNewDay() throws {
        let store = try started()
        var upper = try #require(try store.plan().first { $0.session.name == "Upper" }?.session)
        upper.movedToWeekday = 7
        upper.movedUntilDay = "2026-11-29"
        try store.save(upper)
        let week = try store.week(today: wednesday)
        #expect(week[5].sessionName == nil)
        #expect(week[6].state == .movedByDiv)
        let ahead = try store.sessionsAhead(today: wednesday)
        #expect(ahead.map(\.session.name) == ["Legs", "Upper"])
        #expect(ahead.last?.moved == true)
    }

    @Test func todaySessionStaysUntilFinished() throws {
        let store = try started()
        let thursday = "2026-11-26"
        let legs = try #require(try store.todaySession(today: thursday))
        #expect(legs.session.name == "Legs")
        #expect(legs.lines.first?.name == "Back squat")
        #expect(legs.lines.first?.prescription == "3 × 6-8")
        #expect(legs.minutes > 0)
        #expect(try store.todaySession(today: wednesday) == nil)
        let workout = try store.startWorkout(legs.session, today: thursday)
        #expect(try store.todaySession(today: thursday) != nil)
        try store.finishWorkout(workout.id)
        #expect(try store.todaySession(today: thursday) == nil)
    }

    @Test func startingTwiceReusesTheWorkout() throws {
        let store = try started()
        let push = try #require(try store.plan().first?.session)
        let a = try store.startWorkout(push, today: "2026-11-23")
        let b = try store.startWorkout(push, today: "2026-11-23")
        #expect(a.id == b.id)
    }

    @Test func foodAddsUpMealsAgainstTheTarget() throws {
        let store = try started()
        try store.save(
            Meal(day: wednesday, name: "Oats", kcal: 400, proteinG: 20, carbsG: 60, fatG: 8, source: .typed),
            Meal(day: wednesday, name: "Gone", kcal: 900, proteinG: 0, carbsG: 0, fatG: 0, source: .typed, removed: true))
        let food = try store.food(on: wednesday)
        let target = try #require(food.targetKcal)
        #expect(food.eatenKcal == 400)
        #expect(food.leftKcal == target - 400)
        #expect(food.meals.map(\.name) == ["Oats"])
        #expect(food.targetByDiv == false)
        let targets = try #require(food.targets)
        #expect(targets.protein == Int((Targets.startingProtein(goal: .cut) * 82).rounded()))
        #expect(targets.fat == Int((Double(target) * 0.25 / 9).rounded()))
    }

    @Test func weightTrendsDown() throws {
        let store = try started()
        try store.save(
            WeighIn(day: "2026-11-24", at: Date(timeIntervalSince1970: 1), kg: 81),
            WeighIn(day: wednesday, at: Date(timeIntervalSince1970: 2), kg: 80))
        let weight = try store.weight(today: wednesday)
        #expect(weight.latestKg == 80)
        #expect(weight.trend.count == 3)
        #expect((weight.changeKg ?? 0) < 0)
        #expect(weight.days == 2)
    }

    @Test func volumeCreditsEachMuscleByShare() throws {
        let store = try started()
        let push = try #require(try store.plan().first?.session)
        let workout = try store.startWorkout(push, today: "2026-11-23")
        for i in 0..<3 {
            try store.logSet(
                LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: i, loadKg: 80, reps: 8, rir: 2))
        }
        let volume = Dictionary(uniqueKeysWithValues: try store.volume(today: wednesday).map { ($0.muscle.id, $0) })
        #expect(volume["lower_chest"]?.sets == 3)
        #expect(volume["triceps"]?.sets == 1.5)
        #expect(volume["lats"]?.lagging == true)
        #expect(volume["traps"]?.lagging == false)
    }

    @Test func previousSetsComeFromTheLastTime() throws {
        let store = try started()
        let push = try #require(try store.plan().first?.session)
        let old = try store.startWorkout(push, today: "2026-11-16")
        try store.logSet(LoggedSet(workoutID: old.id, exerciseID: "barbell_bench_press", position: 0, loadKg: 80, reps: 8, rir: nil))
        let previous = try store.previousSets(exerciseIDs: ["barbell_bench_press", "face_pull"], before: "2026-11-23")
        #expect(previous["barbell_bench_press"]?.map(\.reps) == [8])
        #expect(previous["face_pull"] == nil)
    }
}
