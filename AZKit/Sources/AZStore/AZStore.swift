import AZMath
import AZModel
import Foundation
import GRDB

// AZStore: one person's SQLite database, through GRDB (D-005). The phone has one; the bridge keeps one per person
// (D-024). Every write lands in `sync_log` so the other side can catch up (D-006, `AZStore+Sync.swift`).

public final class AZStore: Sendable {
    public let writer: any DatabaseWriter

    /// Opens (or creates) the database at `url`, and brings its schema up to date.
    public convenience init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Wait for a lock instead of failing at once: the bridge's menu app and `div serve` may share a file.
        var config = Configuration()
        config.busyMode = .timeout(5)
        try self.init(writer: DatabasePool(path: url.path, configuration: config))
    }

    /// An empty database in memory, for tests and previews.
    public static func inMemory() throws -> AZStore {
        try AZStore(writer: DatabaseQueue())
    }

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Schema.migrator.migrate(writer)
    }

    // MARK: Writing

    /// Inserts or replaces records of one kind.
    public func save<R: StoredRecord>(_ records: R...) throws {
        try save(records)
    }

    public func save<R: StoredRecord>(_ records: [R]) throws {
        try writer.write { db in
            for record in records { try record.save(db) }
        }
    }

    /// Only for things that aren't logs: plan rows and memories. Logged data is never deleted (CLAUDE.md).
    public func delete<R: StoredRecord & PlanOrMemory>(_ type: R.Type, id: UUID) throws {
        _ = try writer.write { db in try R.deleteOne(db, key: id.uuidString.lowercased()) }
    }

    // MARK: Reading

    public func all<R: StoredRecord>(_ type: R.Type) throws -> [R] {
        try writer.read { db in try R.fetchAll(db) }
    }

    public func profile() throws -> Profile? {
        try writer.read { db in try Profile.fetchOne(db) }
    }

    /// Everything the person recorded, for building Div's data or a screen.
    public func records() throws -> PersonRecords? {
        try writer.read { db in
            guard let profile = try Profile.fetchOne(db) else { return nil }
            return PersonRecords(
                profile: profile, targets: try NutritionTarget.fetchAll(db), memories: try Memory.fetchAll(db),
                sessions: try PlannedSession.fetchAll(db), plannedExercises: try PlannedExercise.fetchAll(db),
                weighIns: try WeighIn.fetchAll(db), measurements: try BodyMeasurement.fetchAll(db), meals: try Meal.fetchAll(db),
                foodDays: try FoodDay.fetchAll(db), workouts: try Workout.fetchAll(db), sets: try LoggedSet.fetchAll(db),
                changes: try DivChange.fetchAll(db))
        }
    }

    /// What Div's read tools answer from, built from this database.
    public func divData(today: String, library: Library = .standard) throws -> DivData? {
        guard let records = try records() else { return nil }
        let latestWeight = records.weighIns.max { $0.at < $1.at }?.kg
        let floor = Targets.calorieFloor(
            sex: records.profile.sex, weightKg: latestWeight, heightCm: records.profile.heightCm,
            age: records.profile.age(on: today))
        return DivData(records, today: today, calorieFloorKcal: floor, library: library)
    }

    /// The plan as sessions in week order, each with its exercises in order.
    public func plan() throws -> [(session: PlannedSession, exercises: [PlannedExercise])] {
        try writer.read { db in
            let exercises = try PlannedExercise.order(Column("position")).fetchAll(db)
            return try PlannedSession.order(Column("weekday"), Column("position")).fetchAll(db).map { session in
                (session, exercises.filter { $0.sessionID == session.id })
            }
        }
    }

    public func meals(on day: String) throws -> [Meal] {
        try writer.read { db in
            try Meal.filter(Column("day") == day && Column("removed") == false).order(Column("at")).fetchAll(db)
        }
    }

    public func weighIns(since day: String) throws -> [WeighIn] {
        try writer.read { db in try WeighIn.filter(Column("day") >= day).order(Column("at")).fetchAll(db) }
    }

    public func sets(in workout: UUID) throws -> [LoggedSet] {
        try writer.read { db in
            try LoggedSet.filter(Column("workout_id") == workout.uuidString.lowercased()).order(Column("position")).fetchAll(db)
        }
    }

    // MARK: Starting out

    /// Sets a starting target for someone who finished onboarding without one (D-029). Does nothing once any exists.
    public func fillMissingTarget(today: String) throws {
        try writer.write { db in
            guard try NutritionTarget.fetchCount(db) == 0, let profile = try Profile.fetchOne(db),
                let weightKg = try WeighIn.order(Column("day").desc).fetchOne(db)?.kg, let heightCm = profile.heightCm,
                let age = profile.age(on: today)
            else { return }
            let kcal = Targets.startingCalories(
                sex: profile.sex, weightKg: weightKg, heightCm: heightCm, age: age, goal: profile.goal,
                ratePctPerWeek: profile.targetRatePctPerWeek)
            try NutritionTarget(
                startDay: today, kcal: kcal, proteinGPerKg: Targets.startingProtein(goal: profile.goal), source: .onboarding
            ).insert(db)
        }
    }

    /// Onboarding: saves the person, their starting targets and a plan from the template for their training days
    /// (D-028). `weightKg` gives the first weigh-in when the person entered it.
    public func start(_ profile: Profile, weightKg: Double?, today: String, library: Library = .standard) throws {
        let template = PlanTemplate.forDays(profile.trainingDays)
        try writer.write { db in
            try profile.save(db)
            if let weightKg {
                try WeighIn(day: today, kg: weightKg).insert(db)
                if let heightCm = profile.heightCm, let age = profile.age(on: today) {
                    let kcal = Targets.startingCalories(
                        sex: profile.sex, weightKg: weightKg, heightCm: heightCm, age: age, goal: profile.goal,
                        ratePctPerWeek: profile.targetRatePctPerWeek)
                    try NutritionTarget(
                        startDay: today, kcal: kcal, proteinGPerKg: Targets.startingProtein(goal: profile.goal), source: .onboarding
                    ).insert(db)
                }
            }
            for (position, session) in template.sessions.enumerated() {
                let row = PlannedSession(name: session.name, weekday: session.weekday, position: position)
                try row.insert(db)
                for (index, item) in session.exercises.enumerated() where library.exercise(item.exerciseID) != nil {
                    try PlannedExercise(
                        sessionID: row.id, exerciseID: item.exerciseID, position: index, sets: item.sets, repMin: item.repMin,
                        repMax: item.repMax
                    ).insert(db)
                }
            }
        }
    }
}
