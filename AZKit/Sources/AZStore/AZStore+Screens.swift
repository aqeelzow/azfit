import AZMath
import AZModel
import Foundation
import GRDB

// What the app's screens show, built from the database. Views stay thin: they format these, nothing more.

/// One day in the week strip.
public struct WeekDay: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        /// A workout was logged.
        case done
        /// Nothing logged and nothing missed: a rest day, or a session still to come.
        case open
        /// A planned session's day passed without a workout.
        case missed
        case today
        /// A session Div moved here for this week.
        case movedByDiv
    }

    public var day: String
    /// Day of the month.
    public var date: Int
    public var state: State
    public var sessionName: String?
    public var sessionID: UUID?
}

/// A planned session as a card shows it.
public struct SessionPreview: Sendable, Equatable {
    public struct Line: Sendable, Equatable {
        public var exerciseID: String
        public var name: String
        public var sets: Int
        public var repMin: Int
        public var repMax: Int
        /// The exercise's name before Div swapped this one in.
        public var swappedFrom: String?

        /// "6-8", or "8" when the range is one number.
        public var reps: String { repMin == repMax ? "\(repMin)" : "\(repMin)-\(repMax)" }
        /// "3 × 6-8"
        public var prescription: String { "\(sets) × \(reps)" }
    }

    public var session: PlannedSession
    public var day: String
    public var lines: [Line]
    /// Moved here by Div for this week.
    public var moved: Bool
    /// Finished this week, on any day.
    public var done = false

    /// A rough length: 2.5 minutes a set, rounded to 5.
    public var minutes: Int { Int((Double(lines.reduce(0) { $0 + $1.sets }) * 2.5 / 5).rounded()) * 5 }
}

/// The day's targets as the targets screen shows them. Macros are nil without a weigh-in (protein is per kg).
public struct DailyTargets: Sendable, Equatable {
    public var kcal: Int
    public var proteinG: Int?
    public var carbsG: Int?
    public var fatG: Int?
    public var waterMl: Int
    public var source: NutritionTarget.Source
    public var weightKg: Double?
}

/// Targets that can't be saved, and why.
public struct TargetProblem: Error, Equatable {
    public var problems: [String]
}

/// Today's food against the target.
public struct FoodSummary: Sendable, Equatable {
    public var targetKcal: Int?
    /// The current target came from Div.
    public var targetByDiv: Bool
    public var eatenKcal: Int
    public var eaten: (protein: Int, carbs: Int, fat: Int)
    public var targets: (protein: Int, carbs: Int, fat: Int)?
    public var meals: [Meal]
    /// Micronutrient totals from the meals that came with them, keyed by `Micronutrient.rawValue`.
    public var micros: [String: Double] = [:]
    /// How many of the day's meals had micronutrients, so a low total can be read for what it is.
    public var mealsWithMicros = 0
    /// The person said this is everything they ate (`FoodDay.complete`).
    public var dayComplete: Bool?
    public var waterMl = 0.0
    public var waterGoalMl = 0.0

    public var leftKcal: Int? { targetKcal.map { $0 - eatenKcal } }
    public var fraction: Double {
        guard let targetKcal, targetKcal > 0 else { return 0 }
        return min(1, Double(eatenKcal) / Double(targetKcal))
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.targetKcal == b.targetKcal && a.targetByDiv == b.targetByDiv && a.eatenKcal == b.eatenKcal && a.eaten == b.eaten
            && a.targets?.protein == b.targets?.protein && a.targets?.carbs == b.targets?.carbs && a.targets?.fat == b.targets?.fat
            && a.meals == b.meals && a.micros == b.micros && a.dayComplete == b.dayComplete && a.waterMl == b.waterMl
            && a.waterGoalMl == b.waterGoalMl
    }
}

/// The scale at a glance.
public struct WeightSummary: Sendable, Equatable {
    public var latestKg: Double?
    /// Trend change from the first weigh-in in the window to now.
    public var changeKg: Double?
    /// Days the change covers.
    public var days: Int
    /// The trend, oldest first, for a sparkline.
    public var trend: [Double]
    /// The day of each `trend` point.
    public var trendDays: [String]

    public init(latestKg: Double? = nil, changeKg: Double? = nil, days: Int = 0, trend: [Double] = [], trendDays: [String] = []) {
        self.latestKg = latestKg
        self.changeKg = changeKg
        self.days = days
        self.trend = trend
        self.trendDays = trendDays
    }
}

/// Hard sets a muscle got this week, credited by the library's share for each exercise.
public struct MuscleVolume: Sendable, Equatable {
    public var muscle: Muscle
    public var sets: Double
    /// Under the muscle's minimum while it has one.
    public var lagging: Bool { muscle.minSetsPerWeek > 0 && sets < Double(muscle.minSetsPerWeek) }
}

extension AZStore {
    /// Monday of the week `day` is in.
    public static func monday(of day: String) -> String {
        Day.adding(1 - (Day.weekday(day) ?? 1), to: day)
    }

    /// The seven days Monday to Sunday of the week `weekOf` is in (this week when nil), with each day's state as of
    /// `today`.
    public func week(today: String, weekOf: String? = nil) throws -> [WeekDay] {
        let monday = Self.monday(of: weekOf ?? today)
        let sessions = try writer.read { db in try PlannedSession.fetchAll(db) }
        let workouts = try writer.read { db in
            try Workout.filter(
                Column("day") >= monday && Column("day") <= Day.adding(6, to: monday) && Column("skipped") == false
            )
            .fetchAll(db)
        }
        let worked = Set(workouts.map(\.day))
        let finished = Set(workouts.filter { $0.endedAt != nil }.compactMap(\.plannedSessionID))
        // Days before the plan existed can't be missed.
        let joined = try profile().map { Day.string($0.createdAt) } ?? monday
        return (0..<7).map { offset in
            let day = Day.adding(offset, to: monday)
            let weekday = offset + 1
            let session = sessions.first { $0.weekday(on: day) == weekday }
            let moved = session.map { $0.weekday(on: day) != $0.weekday } ?? false
            // A planned day is done when its session is, on whatever day it was done.
            let done = session.map { finished.contains($0.id) } ?? worked.contains(day)
            let state: WeekDay.State =
                if done { .done } else if day == today { .today } else if session != nil && day < today && day >= joined {
                    .missed
                } else if moved { .movedByDiv } else { .open }
            let date = Int(day.suffix(2)) ?? 0
            return WeekDay(day: day, date: date, state: state, sessionName: session?.name, sessionID: session?.id)
        }
    }

    /// Every planned session in the week `weekOf` is in (this week when nil), Monday to Sunday, on the day it falls
    /// and marked done once finished that week.
    public func weekSessions(today: String, weekOf: String? = nil, library: Library = .standard) throws -> [SessionPreview] {
        let plan = try plan()
        let monday = Self.monday(of: weekOf ?? today)
        let finished = try writer.read { db in
            try Workout.filter(
                Column("day") >= monday && Column("day") <= Day.adding(6, to: monday) && Column("skipped") == false
                    && Column("ended_at") != nil
            )
            .fetchAll(db)
        }
        let done = Set(finished.compactMap(\.plannedSessionID))
        return plan.map { session, exercises in
            let weekday = session.weekday(on: weekOf.map { _ in monday } ?? today)
            let lines = exercises.map { row in
                SessionPreview.Line(
                    exerciseID: row.exerciseID, name: library.exercise(row.exerciseID)?.name ?? row.exerciseID, sets: row.sets,
                    repMin: row.repMin, repMax: row.repMax,
                    swappedFrom: row.swappedFromID.map { library.exercise($0)?.name ?? $0 })
            }
            return SessionPreview(
                session: session, day: Day.adding(weekday - 1, to: monday), lines: lines, moved: weekday != session.weekday,
                done: done.contains(session.id))
        }
        .sorted { $0.day < $1.day }
    }

    /// Planned sessions from `today` to Sunday, in order.
    public func sessionsAhead(today: String, library: Library = .standard) throws -> [SessionPreview] {
        try weekSessions(today: today, library: library).filter { $0.day >= today }
    }

    /// Today's session, if one is planned and not yet finished. A started workout keeps it here so it can be resumed.
    public func todaySession(today: String, library: Library = .standard) throws -> SessionPreview? {
        try weekSessions(today: today, library: library).first { $0.day == today && !$0.done }
    }

    /// The target in force on `day`: the latest one starting on or before it.
    /// Everything the targets screen shows for `day`: calories, the macros in grams, and water.
    public func dailyTargets(on day: String) throws -> DailyTargets? {
        guard let target = try target(on: day) else { return nil }
        let weight = try latestWeighIn()?.kg
        let macros = weight.map {
            Targets.macroGrams(kcal: target.kcal, proteinGPerKg: target.proteinGPerKg, weightKg: $0, fatG: target.fatG)
        }
        return DailyTargets(
            kcal: target.kcal, proteinG: macros?.protein, carbsG: macros?.carbs, fatG: macros?.fat,
            waterMl: target.waterMl ?? Int(Targets.waterMl(weightKg: weight)), source: target.source, weightKg: weight)
    }

    /// The person's own targets, from today. Protein is typed in grams and kept per kg of body weight, so it follows
    /// the scale. Throws `TargetProblem` for impossible numbers; unusual ones are saved (Div talks them through).
    @discardableResult
    public func setOwnTargets(today: String, kcal: Int, proteinG: Int, fatG: Int, waterMl: Int) throws -> NutritionTarget {
        let problems = Targets.problems(kcal: kcal, proteinG: proteinG, fatG: fatG, waterMl: waterMl)
        guard problems.isEmpty else { throw TargetProblem(problems: problems) }
        guard let weight = try latestWeighIn()?.kg, weight > 0 else {
            throw TargetProblem(problems: ["Weigh in first: protein is set per kg."])
        }
        return try writer.write { db in
            let existing = try NutritionTarget.filter(Column("start_day") == today).fetchOne(db)
            let target = NutritionTarget(
                id: existing?.id ?? UUID(), startDay: today, kcal: kcal, proteinGPerKg: (Double(proteinG) / weight * 100).rounded() / 100,
                source: .person, fatG: fatG, waterMl: waterMl)
            try target.save(db)
            return target
        }
    }

    public func target(on day: String) throws -> NutritionTarget? {
        try writer.read { db in
            try NutritionTarget.filter(Column("start_day") <= day).order(Column("start_day").desc).fetchOne(db)
        }
    }

    public func latestWeighIn() throws -> WeighIn? {
        try writer.read { db in try WeighIn.order(Column("day").desc, Column("at").desc).fetchOne(db) }
    }

    public func food(on day: String) throws -> FoodSummary {
        let meals = try meals(on: day)
        let target = try target(on: day)
        let weight = try latestWeighIn()?.kg
        let eaten = (
            protein: Int(meals.reduce(0) { $0 + $1.proteinG }.rounded()), carbs: Int(meals.reduce(0) { $0 + $1.carbsG }.rounded()),
            fat: Int(meals.reduce(0) { $0 + $1.fatG }.rounded())
        )
        let targets = target.flatMap { target in
            weight.map { Targets.macroGrams(kcal: target.kcal, proteinGPerKg: target.proteinGPerKg, weightKg: $0, fatG: target.fatG) }
        }
        return FoodSummary(
            targetKcal: target?.kcal, targetByDiv: target?.source == .div, eatenKcal: Int(meals.reduce(0) { $0 + $1.kcal }.rounded()),
            eaten: eaten, targets: targets, meals: meals, micros: Micronutrient.total(meals.map(\.micros)),
            mealsWithMicros: meals.count { $0.micros != nil },
            dayComplete: try writer.read { db in try FoodDay.fetchOne(db, key: day)?.complete }, waterMl: try water(on: day),
            waterGoalMl: target?.waterMl.map(Double.init) ?? Targets.waterMl(weightKg: weight))
    }

    /// The trend weight over the last `days` days (every weigh-in when nil).
    public func weight(today: String, days: Int? = 21) throws -> WeightSummary {
        let all = try writer.read { db in try WeighIn.order(Column("day"), Column("at")).fetchAll(db) }
        let since = days.map { Day.adding(-$0, to: today) } ?? ""
        let window = all.filter { $0.day >= since }
        let trend = WeightTrend.trend(window.map(\.kg))
        let span =
            if let first = window.first.flatMap({ Day.date($0.day) }), let last = window.last.flatMap({ Day.date($0.day) }) {
                Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
            } else { 0 }
        let change: Double? = trend.count > 1 ? ((trend[trend.count - 1] - trend[0]) * 10).rounded() / 10 : nil
        return WeightSummary(latestKg: all.last?.kg, changeKg: change, days: span, trend: trend, trendDays: window.map(\.day))
    }

    /// Div's changes from the last `days` days, newest first.
    public func recentChanges(today: String, days: Int = 7) throws -> [DivChange] {
        let since = Day.date(Day.adding(-days, to: today)) ?? .distantPast
        return try writer.read { db in
            try DivChange.filter(Column("created_at") >= since).order(Column("created_at").desc).fetchAll(db)
        }
    }

    /// Sets per muscle this week (Monday to `today`), in the library's muscle order.
    public func volume(today: String, library: Library = .standard) throws -> [MuscleVolume] {
        let monday = Self.monday(of: today)
        let sets = try writer.read { db in
            let workouts = try Workout.filter(Column("day") >= monday && Column("day") <= today && Column("skipped") == false)
                .fetchAll(db).map { $0.id.uuidString.lowercased() }
            return try LoggedSet.filter(workouts.contains(Column("workout_id"))).fetchAll(db)
        }
        var totals: [String: Double] = [:]
        for set in sets {
            for (muscle, share) in library.exercise(set.exerciseID)?.muscles ?? [:] { totals[muscle, default: 0] += share }
        }
        return library.muscles.map { MuscleVolume(muscle: $0, sets: totals[$0.id] ?? 0) }
    }

    // MARK: Logging a workout

    /// Today's unfinished workout for a session, or a new one: a second start resumes it, and starting a finished one again
    /// begins a new workout. Logged data is never deleted.
    public func startWorkout(_ session: PlannedSession, today: String, now: Date = .now) throws -> Workout {
        try writer.write { db in
            if let open = try Workout.filter(
                Column("planned_session_id") == session.id.uuidString.lowercased() && Column("day") == today
                    && Column("skipped") == false && Column("ended_at") == nil
            ).fetchOne(db) {
                return open
            }
            let workout = Workout(plannedSessionID: session.id, name: session.name, day: today, startedAt: now)
            try workout.insert(db)
            return workout
        }
    }

    public func logSet(_ set: LoggedSet) throws {
        try save(set)
    }

    public func finishWorkout(_ id: UUID, now: Date = .now) throws {
        try writer.write { db in
            guard var workout = try Workout.fetchOne(db, key: id.uuidString.lowercased()) else { return }
            workout.endedAt = now
            try workout.update(db)
        }
    }

    /// The last time each exercise was done before `workout`: its sets in order, for the "Previous" column.
    public func previousSets(exerciseIDs: [String], before day: String) throws -> [String: [LoggedSet]] {
        try writer.read { db in
            var out: [String: [LoggedSet]] = [:]
            let workouts = try Workout.filter(Column("day") < day && Column("skipped") == false).order(Column("day").desc)
                .fetchAll(db)
            for id in exerciseIDs {
                for workout in workouts {
                    let sets = try LoggedSet.filter(
                        Column("workout_id") == workout.id.uuidString.lowercased() && Column("exercise_id") == id
                    ).order(Column("position")).fetchAll(db)
                    if !sets.isEmpty {
                        out[id] = sets
                        break
                    }
                }
            }
            return out
        }
    }
}
