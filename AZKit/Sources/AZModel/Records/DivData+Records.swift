import Foundation

/// Everything one person recorded, as read from their database. `DivData` is built from it for Div's read tools.
public struct PersonRecords: Sendable, Equatable {
    public var profile: Profile
    public var targets: [NutritionTarget]
    public var memories: [Memory]
    public var sessions: [PlannedSession]
    public var plannedExercises: [PlannedExercise]
    public var weighIns: [WeighIn]
    public var measurements: [BodyMeasurement]
    public var meals: [Meal]
    public var foodDays: [FoodDay]
    public var workouts: [Workout]
    public var sets: [LoggedSet]
    public var changes: [DivChange]

    public init(
        profile: Profile, targets: [NutritionTarget] = [], memories: [Memory] = [], sessions: [PlannedSession] = [],
        plannedExercises: [PlannedExercise] = [], weighIns: [WeighIn] = [], measurements: [BodyMeasurement] = [],
        meals: [Meal] = [], foodDays: [FoodDay] = [], workouts: [Workout] = [], sets: [LoggedSet] = [],
        changes: [DivChange] = []
    ) {
        self.profile = profile
        self.targets = targets
        self.memories = memories
        self.sessions = sessions
        self.plannedExercises = plannedExercises
        self.weighIns = weighIns
        self.measurements = measurements
        self.meals = meals
        self.foodDays = foodDays
        self.workouts = workouts
        self.sets = sets
        self.changes = changes
    }

    /// The target in force on `day`: the latest one that started on or before it.
    public func target(on day: String) -> NutritionTarget? {
        targets.filter { $0.startDay <= day }.max { $0.startDay < $1.startDay }
    }
}

extension DivData {
    /// What Div's read tools answer from, for `today`. Exercises are named as in the library, because Div names them
    /// back in its changes. `calorieFloorKcal` comes from AZMath (`Targets.calorieFloor`).
    public init(_ r: PersonRecords, today: String, calorieFloorKcal: Int, library: Library = .standard) {
        func name(_ id: String) -> String { library.exercise(id)?.name ?? id }
        let target = r.target(on: today)

        self.today = today
        profile = Profile(
            name: r.profile.name, age: r.profile.age(on: today) ?? 0, heightCm: r.profile.heightCm ?? 0, goal: r.profile.goal,
            targetRatePctPerWeek: r.profile.targetRatePctPerWeek, caloriesKcal: target?.kcal ?? 0,
            proteinGPerKg: target?.proteinGPerKg ?? 0, calorieFloorKcal: calorieFloorKcal, kidneyDisease: r.profile.kidneyDisease)
        memories = r.memories.sorted { $0.createdAt < $1.createdAt }.map {
            Memory(text: $0.text, source: $0.source.rawValue, date: Day.string($0.createdAt))
        }
        plan = r.sessions.sorted { ($0.weekday, $0.position) < ($1.weekday, $1.position) }.map { session in
            PlannedSession(
                day: session.weekdayName, name: session.name,
                exercises: r.plannedExercises.filter { $0.sessionID == session.id }.sorted { $0.position < $1.position }.map {
                    PlannedExercise(
                        exercise: name($0.exerciseID), sets: $0.sets, repMin: $0.repMin, repMax: $0.repMax, loadKg: $0.loadKg ?? 0,
                        hitTopOfRangeSessions: $0.hitTopOfRangeSessions)
                })
        }
        weighIns = r.weighIns.sorted { $0.at < $1.at }.map { WeighIn(date: $0.day, kg: $0.kg) }
        waist = r.measurements.filter { $0.site == .waist }.sorted { $0.day < $1.day }.map {
            WaistMeasurement(date: $0.day, cm: $0.cm)
        }
        let meals = r.meals.filter { !$0.removed }
        let foodDays = Set(meals.map(\.day)).union(r.foodDays.map(\.day)).sorted()
        let complete = Dictionary(r.foodDays.map { ($0.day, $0.complete ?? false) }, uniquingKeysWith: { _, last in last })
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        days = foodDays.map { day in
            FoodDay(
                date: day, complete: complete[day] ?? false,
                meals: meals.filter { $0.day == day }.sorted { $0.at < $1.at }.map {
                    Meal(
                        time: time.string(from: $0.at), name: $0.name, kcal: $0.kcal, proteinG: $0.proteinG, carbsG: $0.carbsG,
                        fatG: $0.fatG)
                })
        }
        workouts = r.workouts.filter { !$0.skipped }.sorted { $0.startedAt < $1.startedAt }.map { workout in
            Workout(
                date: workout.day, name: workout.name,
                sets: r.sets.filter { $0.workoutID == workout.id }.sorted { $0.position < $1.position }.map {
                    WorkoutSet(exercise: name($0.exerciseID), loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir ?? 2)
                })
        }
        divLog = r.changes.sorted { $0.createdAt < $1.createdAt }.map { change in
            let summary = change.proposal.change.summary
            let status: String =
                switch change.status {
                case .applied, .approved: "applied"
                case .proposed: "proposed"
                case .declined, .undone: "undone"
                }
            return LogEntry(
                date: Day.string(change.createdAt), job: change.job, change: "\(summary.title) (\(summary.detail))",
                reason: change.proposal.reason, evidence: change.proposal.evidence, status: status)
        }
    }
}
