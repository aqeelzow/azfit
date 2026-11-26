import AZMath
import AZModel
import Foundation
import Testing

@testable import AZStore

@Suite struct SessionReviewTests {
    /// A store with Push done twice: last Monday at 75 kg, this Monday at 80 kg.
    private func pushedTwice() throws -> (AZStore, Workout) {
        let store = try AZStore.inMemory()
        try store.start(person(), weightKg: 82, today: "2026-11-01")
        let push = try #require(try store.plan().first { $0.session.name == "Push" }?.session)
        let old = try store.startWorkout(push, today: "2026-11-16")
        for i in 0..<3 {
            try store.logSet(LoggedSet(workoutID: old.id, exerciseID: "barbell_bench_press", position: i, loadKg: 75, reps: 8, rir: 2))
        }
        try store.finishWorkout(old.id)
        let now = try store.startWorkout(push, today: "2026-11-23")
        for i in 0..<3 {
            try store.logSet(LoggedSet(workoutID: now.id, exerciseID: "barbell_bench_press", position: i, loadKg: 80, reps: 8, rir: nil))
        }
        try store.logSet(LoggedSet(workoutID: now.id, exerciseID: "triceps_pushdown", position: 3, loadKg: 30, reps: 12, rir: 1))
        try store.finishWorkout(now.id)
        return (store, now)
    }

    @Test func reportHasThePrescriptionTheSetsAndHistory() throws {
        let (store, workout) = try pushedTwice()
        let report = try #require(try store.sessionReport(workout.id))
        #expect(report.sessionName == "Push")
        #expect(report.exercises.map(\.exercise) == ["Barbell bench press", "Triceps pushdown"])
        let bench = report.exercises[0]
        #expect(bench.prescribed.sets == 3 && bench.prescribed.repMin == 6 && bench.prescribed.repMax == 8)
        // No planned load yet, so what was lifted is the starting point.
        #expect(bench.prescribed.loadKg == 80)
        // Logged without RIR, so Div gets none rather than a guess.
        #expect(bench.performed.map(\.rir) == [nil, nil, nil])
        #expect(Strength.derive(report).exercises[0].avgRir == nil)
        #expect(bench.e1rmHistory == [Strength.e1rm(loadKg: 75, reps: 8, rir: 2)])
        #expect(report.exercises[1].e1rmHistory.isEmpty)
    }

    @Test func noSetsNoReport() throws {
        let store = try AZStore.inMemory()
        try store.start(person(), weightKg: 82, today: "2026-11-01")
        let push = try #require(try store.plan().first?.session)
        let workout = try store.startWorkout(push, today: "2026-11-23")
        #expect(try store.sessionReport(workout.id) == nil)
    }

    @Test func savingSetsTheNoteStartingLoadsAndChanges() throws {
        let (store, workout) = try pushedTwice()
        let report = try #require(try store.sessionReport(workout.id))
        let next = [
            Checked(
                item: NextTime(exercise: "Barbell bench press", call: .progress, nextLoadKg: 82.5, reason: "All sets at 8."),
                verdict: .apply),
            Checked(item: NextTime(exercise: "Triceps pushdown", call: .repeat, nextLoadKg: 30), verdict: .apply),
        ]
        let saved = try store.saveSessionReview(workout.id, note: "Solid bench.", nextTime: next, report: report, today: "2026-11-23")
        #expect(saved.count == 1)
        #expect(saved.first?.status == .applied)
        #expect(try store.all(Workout.self).first { $0.id == workout.id }?.divNote == "Solid bench.")
        let plan = try #require(try store.plan().first { $0.session.name == "Push" })
        #expect(plan.exercises.first { $0.exerciseID == "barbell_bench_press" }?.loadKg == 82.5)
        #expect(plan.exercises.first { $0.exerciseID == "triceps_pushdown" }?.loadKg == 30)
        // Undo puts the bench back to where the review started it.
        try store.undo(try #require(saved.first).id)
        #expect(try store.plan().first?.exercises.first?.loadKg == 80)
    }
}

@Suite struct WeeklySnapshotTests {
    private let sunday = "2026-11-29"

    /// Joined Nov 1 at 84 kg, losing about 0.1 kg a day, eating 2,000 kcal most days, bench every Monday.
    private func threeWeeks() throws -> AZStore {
        let store = try AZStore.inMemory()
        var profile = person()
        profile.createdAt = Day.date("2026-11-01") ?? .now
        try store.start(profile, weightKg: 84, today: "2026-11-01")
        let target = try #require(try store.target(on: sunday))
        for offset in 1..<29 {
            let day = Day.adding(offset, to: "2026-11-01")
            try store.save(WeighIn(day: day, kg: 84 - Double(offset) * 0.1))
            // Every 4th day only a snack, never marked complete. The rest are marked "That's everything".
            let snackDay = offset % 4 == 0
            let kcal = snackDay ? 300.0 : Double(target.kcal)
            try store.save(Meal(day: day, name: "Food", kcal: kcal, proteinG: 170, carbsG: 200, fatG: 60, source: .typed))
            if !snackDay { try store.setDayComplete(day, true) }
        }
        let push = try #require(try store.plan().first { $0.session.name == "Push" }?.session)
        for (day, load) in [("2026-11-09", 70.0), ("2026-11-16", 72.5), ("2026-11-23", 75.0)] {
            let workout = try store.startWorkout(push, today: day)
            for i in 0..<3 {
                try store.logSet(
                    LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: i, loadKg: load, reps: 8, rir: 2))
            }
            try store.finishWorkout(workout.id)
        }
        return store
    }

    @Test func onlyDaysMarkedCompleteCount() throws {
        let store = try threeWeeks()
        // A full day left unmarked doesn't count, however much was logged.
        try store.setDayComplete("2026-11-27", nil)
        #expect(try store.weeklySnapshot(weekEnding: sunday)?.intake.completeDays == 14)
        try store.setDayComplete("2026-11-27", true)
        #expect(try store.food(on: "2026-11-27").dayComplete == true)
        #expect(try store.weeklySnapshot(weekEnding: sunday)?.intake.completeDays == 15)
    }

    @Test func setsWithoutRIRAssumeNothing() throws {
        let store = try threeWeeks()
        let push = try #require(try store.plan().first { $0.session.name == "Push" }?.session)
        let workout = try store.startWorkout(push, today: "2026-11-24")
        try store.logSet(LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: 0, loadKg: 80, reps: 8, rir: nil))
        try store.finishWorkout(workout.id)
        let bench = try #require(try store.weeklySnapshot(weekEnding: sunday)?.lifts.first)
        // The set without RIR counts its 8 reps alone, and leaves the average to the sets that recorded one.
        #expect(bench.e1rmNow == Strength.e1rm(loadKg: 80, reps: 8, rir: 0).rounded())
        #expect(bench.avgRir == 2)
        #expect(Strength.averageRIR([nil, nil]) == nil)
    }

    @Test func sundayOfAnyDay() {
        #expect(AZStore.sunday(onOrBefore: "2026-11-29") == "2026-11-29")
        #expect(AZStore.sunday(onOrBefore: "2026-11-30") == "2026-11-29")
        #expect(AZStore.sunday(onOrBefore: "2026-11-28") == "2026-11-22")
    }

    @Test func snapshotReadsTheWindow() throws {
        let store = try threeWeeks()
        let s = try #require(try store.weeklySnapshot(weekEnding: sunday))
        #expect(s.intake.windowDays == 21)
        // 21 days in the window (Nov 9 to 29), 6 of them snack days (Nov 9, 13, 17, 21, 25, 29).
        #expect(s.intake.completeDays == 15)
        #expect(s.weight.dailyThisWeek.count == 7)
        #expect(s.weight.trendKgNow < s.weight.trendKgWeekAgo && s.weight.trendKgWeekAgo < s.weight.trendKgWindowStart)
        // Bench on Monday Nov 23 is this week, against Nov 9 at the window start.
        #expect(s.lifts.map(\.e1rmNow) == [Strength.e1rm(loadKg: 75, reps: 8, rir: 2).rounded()])
        #expect(s.currentLoads.isEmpty)
        #expect(s.recovery == nil)
        #expect(s.volume.contains { $0.muscle == "Lats" && $0.setsThisWeek == 0 && $0.mev == 8 })
        let derived = WeeklyMath.derive(s)
        #expect(derived.enoughCompleteDays)
        #expect(derived.scaleDirection == .down)
        #expect(derived.impliedMaintenanceKcal != nil)
    }

    @Test func liftsCompareThisWeekToTheWindowStart() throws {
        let store = try threeWeeks()
        // Week ending Nov 22: bench on Nov 16 this week, and first in the window on Nov 9.
        let s = try #require(try store.weeklySnapshot(weekEnding: "2026-11-22"))
        let bench = try #require(s.lifts.first)
        #expect(bench.name == "Barbell bench press")
        #expect(bench.e1rmNow == Strength.e1rm(loadKg: 72.5, reps: 8, rir: 2).rounded())
        #expect(bench.e1rmWindowStart == Strength.e1rm(loadKg: 70, reps: 8, rir: 2).rounded())
        #expect(bench.avgRir == 2)
    }

    @Test func noTargetNoSnapshot() throws {
        let store = try AZStore.inMemory()
        try store.save(person())
        #expect(try store.weeklySnapshot(weekEnding: sunday) == nil)
    }

    @Test func savingKeepsTheSummaryAndChanges() throws {
        let store = try threeWeeks()
        let output = WeeklyReviewOutput(summary: "Down 0.7 kg a week.", calorieAction: .increase, questions: ["All good?"])
        let change = Checked(item: Proposal(.setCalorieTarget(newKcal: 2_200), reason: "Too fast."), verdict: .apply)
        let saved = try store.saveWeeklyReview(weekEnding: sunday, output: output, checked: [change], today: "2026-11-30")
        #expect(saved.first?.job == "weekly_review")
        #expect(try store.weekReview(weekEnding: sunday)?.questions == ["All good?"])
        #expect(try store.target(on: "2026-11-30")?.kcal == 2_200)
    }
}
