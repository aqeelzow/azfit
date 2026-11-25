import AZModel
import Foundation
import Testing

@testable import AZStore

func person(days: Int = 4) -> Profile {
    Profile(name: "Sam", sex: .male, birthYear: 1996, heightCm: 180, goal: .cut, trainingDays: days, units: .british)
}

@Suite struct AZStoreTests {
    @Test func columnNamesRoundTrip() {
        for key in ["plannedSessionID", "proteinGPerKg", "kcalLow", "hitTopOfRangeSessions", "id", "divChangeID", "at"] {
            #expect(ColumnName.camel(ColumnName.snake(key)) == key)
        }
        #expect(ColumnName.snake("plannedSessionID") == "planned_session_id")
        #expect(ColumnName.snake("proteinGPerKg") == "protein_g_per_kg")
    }

    @Test func onboardingSavesThePersonTargetsAndATemplatePlan() throws {
        let store = try AZStore.inMemory()
        try store.start(person(), weightKg: 82, today: "2026-11-25")
        let profile = try #require(try store.profile())
        #expect(profile.units == .british)
        #expect(profile.autonomy == .standard)
        let plan = try store.plan()
        #expect(plan.map(\.session.name) == ["Push", "Pull", "Legs", "Upper"])
        #expect(plan.map(\.session.weekday) == [1, 2, 4, 6])
        #expect(plan[0].exercises.first?.exerciseID == "barbell_bench_press")
        let target = try #require(try store.all(NutritionTarget.self).first)
        #expect(target.source == .onboarding)
        #expect(target.kcal > 1_800 && target.kcal < 2_600)
        #expect(try store.weighIns(since: "2026-11-01").map(\.kg) == [82])
    }

    @Test func recordsRoundTripWithNestedValues() throws {
        let store = try AZStore.inMemory()
        let change = DivChange(
            job: "chat", proposal: Proposal(.swapExercise(from: "Overhead press", to: "Landmine press", weeks: 2), reason: "Shoulder"),
            status: .proposed, notes: ["Swaps ask first in your settings."])
        try store.save(change)
        #expect(try store.all(DivChange.self) == [roundedDates(change)])
        let meal = Meal(day: "2026-11-25", name: "Oats", kcal: 420, proteinG: 20, carbsG: 60, fatG: 9, source: .barcode, barcode: "0123")
        try store.save(
            meal, Meal(day: "2026-11-25", name: "Mistake", kcal: 900, proteinG: 0, carbsG: 0, fatG: 0, source: .typed, removed: true))
        #expect(try store.meals(on: "2026-11-25").map(\.name) == ["Oats"])
    }

    @Test func divDataComesFromTheDatabase() throws {
        let store = try AZStore.inMemory()
        try store.start(person(), weightKg: 82, today: "2026-11-23")
        let push = try #require(try store.plan().first)
        let workout = Workout(plannedSessionID: push.session.id, name: "Push", day: "2026-11-23")
        try store.save(workout)
        try store.save(LoggedSet(workoutID: workout.id, exerciseID: "barbell_bench_press", position: 0, loadKg: 80, reps: 8, rir: 2))
        try store.save(FoodDay(day: "2026-11-23", complete: true))
        try store.save(Meal(day: "2026-11-23", name: "Chicken and rice", kcal: 650, proteinG: 50, carbsG: 70, fatG: 15, source: .photo))
        try store.save(BodyMeasurement(day: "2026-11-23", site: .waist, cm: 84))
        try store.save(Memory(text: "Left shoulder tight overhead", source: .chat))

        let data = try #require(try store.divData(today: "2026-11-25"))
        #expect(data.profile.age == 30)
        #expect(data.profile.calorieFloorKcal == 1_800)  // BMR: 820 + 1,125 - 150 + 5
        #expect(data.profile.caloriesKcal > 0)
        #expect(data.plan.first?.day == "Monday")
        #expect(data.plan.first?.exercises.first?.exercise == "Barbell bench press")
        #expect(data.workouts.first?.sets.first?.exercise == "Barbell bench press")
        #expect(data.days.first?.complete == true)
        #expect(data.days.first?.meals.first?.kcal == 650)
        #expect(data.waist.map(\.cm) == [84])
        #expect(data.weighIns.map(\.kg) == [82])
        #expect(data.memories.map(\.text) == ["Left shoulder tight overhead"])
    }

    @Test func syncCopiesNewRowsOnceAndDoesNotEchoThem() throws {
        let phone = try AZStore.inMemory()
        let bridge = try AZStore.inMemory()
        try phone.start(person(days: 2), weightKg: 82, today: "2026-11-25")

        let batch = try phone.changes(after: 0)
        try bridge.apply(batch, from: "phone")
        #expect(try bridge.records() == phone.records())
        #expect(try bridge.lastSeq() == 0)  // applied rows aren't logged to send back
        #expect(try bridge.receivedSeq(from: "phone") == batch.lastSeq)

        // The bridge changes the plan (Div's swap); the phone catches up.
        var exercise = try #require(try bridge.plan().first?.exercises.first)
        exercise.swappedFromID = exercise.exerciseID
        exercise.exerciseID = "goblet_squat"
        try bridge.save(exercise)
        let back = try bridge.changes(after: 0)
        #expect(back.rows.count == 1)
        try phone.apply(back, from: "bridge")
        #expect(try phone.plan().first?.exercises.first?.exerciseID == "goblet_squat")

        // A deleted plan row is deleted on the other side too. Only new rows travel.
        try phone.delete(PlannedExercise.self, id: exercise.id)
        let next = try phone.changes(after: batch.lastSeq)
        #expect(next.rows == [SyncRow(table: "planned_exercise", id: exercise.id.uuidString.lowercased(), columns: nil)])
        try bridge.apply(next, from: "phone")
        #expect(try bridge.plan().first?.exercises.contains { $0.id == exercise.id } == false)
    }

    @Test func syncRejectsTablesAndColumnsItDoesNotKnow() throws {
        let store = try AZStore.inMemory()
        let bad = SyncBatch(rows: [SyncRow(table: "sqlite_master", id: "x", columns: [])], lastSeq: 1, more: false)
        #expect(throws: AZStore.SyncError.unknownTable("sqlite_master")) { try store.apply(bad, from: "p") }
        let column = SyncBatch(
            rows: [SyncRow(table: "memory", id: "x", columns: [SyncColumn("evil", .text("1"))])], lastSeq: 1, more: false)
        #expect(throws: AZStore.SyncError.unknownColumn(table: "memory", column: "evil")) { try store.apply(column, from: "p") }
    }

    @Test func aDatabaseOnDiskKeepsItsRows() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "azfit-\(UUID().uuidString)/azfit.sqlite")
        try AZStore(url: url).start(person(), weightKg: nil, today: "2026-11-25")
        #expect(try AZStore(url: url).plan().count == 4)
    }
}

/// The database keeps dates to the millisecond.
func roundedDates(_ change: DivChange) -> DivChange {
    var c = change
    c.createdAt = Date(timeIntervalSinceReferenceDate: (c.createdAt.timeIntervalSinceReferenceDate * 1000).rounded() / 1000)
    return c
}

@Suite struct DivChangeTests {
    func store() throws -> AZStore {
        let store = try AZStore.inMemory()
        try store.start(person(), weightKg: 82, today: "2026-11-23")
        return store
    }

    func exercises(_ store: AZStore) throws -> [String] {
        try store.plan().flatMap(\.exercises).map(\.exerciseID)
    }

    @Test func anAppliedSwapChangesThePlanAndUndoPutsItBack() throws {
        let store = try store()
        let swap = Checked(
            item: Proposal(.swapExercise(from: "Seated dumbbell shoulder press", to: "Landmine press", weeks: 2), reason: "Shoulder"),
            verdict: .apply)
        let refused = Checked(item: Proposal(.setLoad(exercise: "x", newLoadKg: 1)), verdict: .refuse)
        let saved = try store.record([swap, refused], job: "chat", today: "2026-11-25")
        #expect(saved.map(\.status) == [.applied])
        #expect(try !exercises(store).contains("seated_dumbbell_press"))
        let swapped = try #require(try store.plan().flatMap(\.exercises).first { $0.exerciseID == "landmine_press" })
        #expect(swapped.swappedFromID == "seated_dumbbell_press")
        #expect(swapped.swapEndsDay == "2026-12-09")

        try store.undo(saved[0].id)
        #expect(try exercises(store).filter { $0 == "seated_dumbbell_press" }.count == 2)
        #expect(try store.all(DivChange.self).map(\.status) == [.undone])
        #expect(throws: AZStore.ChangeError.self) { try store.undo(saved[0].id) }
    }

    @Test func aSwapEndsOnItsOwn() throws {
        let store = try store()
        try store.record(
            [Checked(item: Proposal(.swapExercise(from: "Back squat", to: "Hack squat", weeks: 1)), verdict: .apply)], job: "chat",
            today: "2026-11-25")
        try store.endSwaps(today: "2026-12-01")
        #expect(try exercises(store).contains("hack_squat"))
        try store.endSwaps(today: "2026-12-02")
        #expect(try !exercises(store).contains("hack_squat"))
        #expect(try exercises(store).contains("back_squat"))
    }

    @Test func aCalorieSuggestionWaitsForApproveAndUndoRestoresTheOldTarget() throws {
        let store = try store()
        let before = try #require(try store.all(NutritionTarget.self).first)
        let saved = try store.record(
            [Checked(item: Proposal(.setCalorieTarget(newKcal: before.kcal - 150), reason: "Trend"), verdict: .propose)],
            job: "weekly-review", today: "2026-12-06")
        #expect(try store.all(NutritionTarget.self).count == 1)

        try store.approve(saved[0].id, today: "2026-12-06")
        let records = try #require(try store.records())
        #expect(records.target(on: "2026-12-06")?.kcal == before.kcal - 150)
        #expect(records.target(on: "2026-12-06")?.divChangeID == saved[0].id)
        #expect(records.target(on: "2026-12-05")?.kcal == before.kcal)

        try store.undo(saved[0].id)
        #expect(try store.records()?.target(on: "2026-12-06")?.kcal == before.kcal)
    }

    @Test func aOneWeekMoveOnlyLastsTheWeek() throws {
        let store = try store()
        try store.record(
            [Checked(item: Proposal(.moveSession(session: "Legs", toDay: "Friday", thisWeekOnly: true)), verdict: .apply)],
            job: "chat", today: "2026-11-25")
        let legs = try #require(try store.plan().first { $0.session.name == "Legs" }?.session)
        #expect(legs.weekday(on: "2026-11-27") == 5)
        #expect(legs.weekday(on: "2026-12-03") == 4)
    }

    @Test func declineLeavesThePlanAlone() throws {
        let store = try store()
        let saved = try store.record(
            [Checked(item: Proposal(.swapExercise(from: "Back squat", to: "Unknown lift", weeks: 2)), verdict: .apply)],
            job: "chat", today: "2026-11-25")
        #expect(saved.first?.status == .proposed)  // not in the library, so it can't apply on its own
        try store.decline(saved[0].id)
        #expect(try store.all(DivChange.self).first?.status == .declined)
        #expect(try exercises(store).contains("back_squat"))
    }
}
