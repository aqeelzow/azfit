import AZMath
import AZModel
import Foundation
import GRDB

// What the person logs by hand (meals, weigh-ins, measurements, swaps and settings), and the reads behind the
// screens that show it: the calorie target, progress, Div's memory and an exercise.

/// A meal the person has logged before, for one-tap logging and so a photo estimate can match it.
public struct RecentMeal: Sendable, Equatable {
    /// The latest time it was logged.
    public var meal: Meal
    public var times: Int

    /// The meal as the photo estimate reads it.
    public var similar: MealPhotoRequest.SimilarMeal {
        .init(name: meal.name, kcal: meal.kcal, proteinG: meal.proteinG, carbsG: meal.carbsG, fatG: meal.fatG, loggedTimes: times)
    }
}

/// The calorie target now, the one before it, and the Div change that set it.
public struct TargetHistory: Sendable, Equatable {
    public var current: NutritionTarget
    public var previous: NutritionTarget?
    /// Set when Div made the current target.
    public var change: DivChange?
}

/// One week of the scale: the trend's change from the end of the week before. Negative is a loss.
public struct WeekChange: Sendable, Equatable {
    /// Monday.
    public var weekStart: String
    /// Nil without a weigh-in that week, or before it to compare with.
    public var kg: Double?
    /// Div changed the calorie target that week.
    public var divChangedTarget: Bool
}

/// A lift's estimated one-rep max over time.
public struct LiftTrend: Sendable, Equatable {
    public var exerciseID: String
    public var name: String
    /// The best set (by e1RM) on the latest day it was done, and that day.
    public var best: LoggedSet
    public var bestDay: String
    public var e1rmKg: Double
    /// From the first day in the window to the latest. Nil when it was done on one day only.
    public var changeKg: Double?
    /// Each day's best e1RM, oldest first.
    public var points: [Double]
}

/// The latest reading at one site, and how it moved since the one before.
public struct MeasurementReading: Sendable, Equatable {
    public var latest: BodyMeasurement
    public var changeCm: Double?
}

/// An exercise in the plan: the session it's in and its row.
public struct PlannedUse: Sendable, Equatable {
    public var session: PlannedSession
    public var row: PlannedExercise
}

extension AZStore {

    // MARK: Food

    public func logMeal(_ meal: Meal) throws {
        try save(meal)
    }

    /// Takes a meal out of the totals. The row stays (never delete what the person logged).
    public func removeMeal(_ id: UUID) throws {
        try writer.write { db in
            guard var meal = try Meal.fetchOne(db, key: id.uuidString.lowercased()) else { return }
            meal.removed = true
            try meal.update(db)
        }
    }

    /// Marks a day's food log as everything eaten (true), not everything (false), or unsaid (nil). Only days marked
    /// true count in the weekly calorie review.
    public func setDayComplete(_ day: String, _ complete: Bool?) throws {
        try save(FoodDay(day: day, complete: complete))
    }

    /// Water drunk on a day, in ml.
    public func water(on day: String) throws -> Double {
        try writer.read { db in
            try WaterLog.filter(Column("day") == day && Column("removed") == false).fetchAll(db).reduce(0) { $0 + $1.ml }
        }
    }

    public func logWater(ml: Double = WaterLog.glassMl, day: String, at: Date = .now) throws {
        guard ml > 0 else { return }
        try save(WaterLog(day: day, at: at, ml: ml))
    }

    /// Takes back the day's latest water. The row stays, marked removed.
    public func removeLastWater(on day: String) throws {
        try writer.write { db in
            guard
                var last = try WaterLog.filter(Column("day") == day && Column("removed") == false).order(Column("at").desc)
                    .fetchOne(db)
            else { return }
            last.removed = true
            try last.update(db)
        }
    }

    /// Moves a logged food to another meal of the same day.
    public func moveMeal(_ id: UUID, to slot: Meal.Slot) throws {
        try writer.write { db in
            guard var meal = try Meal.fetchOne(db, key: id.uuidString.lowercased()) else { return }
            meal.slot = slot
            try meal.update(db)
        }
    }

    /// Saves a food the person made, so search and its barcode find it again.
    public func saveCustomFood(_ food: CustomFood) throws {
        try save(food)
    }

    /// The person's own foods whose name or brand contains `query` (all of them when it's empty), newest first.
    public func customFoods(matching query: String = "") throws -> [CustomFood] {
        let all = try writer.read { db in try CustomFood.order(Column("created_at").desc).fetchAll(db) }
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return all }
        return all.filter { food in
            let text = "\(food.name) \(food.brand ?? "")".lowercased()
            return words.allSatisfy { text.contains($0) }
        }
    }

    /// A food the person made with this barcode.
    public func customFood(barcode: String) throws -> CustomFood? {
        try writer.read { db in try CustomFood.filter(Column("barcode") == barcode).fetchOne(db) }
    }

    /// Meals logged before, one per name (the latest), the most logged first.
    public func recentMeals(limit: Int = 8) throws -> [RecentMeal] {
        let meals = try writer.read { db in
            try Meal.filter(Column("removed") == false).order(Column("at").desc).fetchAll(db)
        }
        var order: [String] = []
        var byName: [String: RecentMeal] = [:]
        for meal in meals {
            let key = meal.name.lowercased().trimmingCharacters(in: .whitespaces)
            if byName[key] == nil {
                order.append(key)
                byName[key] = RecentMeal(meal: meal, times: 0)
            }
            byName[key]?.times += 1
        }
        let recent = order.compactMap { byName[$0] }
        return Array(
            recent.enumerated().sorted { a, b in
                (a.element.times, a.element.meal.isFavorite ? 1 : 0, -a.offset) > (
                    b.element.times, b.element.meal.isFavorite ? 1 : 0, -b.offset
                )
            }
            .map(\.element)
            .prefix(limit))
    }

    // MARK: Body

    @discardableResult
    public func logWeighIn(kg: Double, day: String, at: Date = .now) throws -> WeighIn {
        let weighIn = WeighIn(day: day, at: at, kg: kg, source: .manual)
        try save(weighIn)
        return weighIn
    }

    /// Weigh-ins read from Apple Health, keyed by the Health sample's ID so reading them again adds nothing. Returns
    /// how many were new. Implausible readings are skipped.
    @discardableResult
    public func importWeighIns(_ weighIns: [WeighIn]) throws -> Int {
        try writer.write { db in
            var added = 0
            for weighIn in weighIns where UnitSystem.plausibleBodyWeightKg.contains(weighIn.kg) {
                guard try !WeighIn.exists(db, key: weighIn.id.uuidString.lowercased()) else { continue }
                try weighIn.insert(db)
                added += 1
            }
            return added
        }
    }

    /// The scale's trend change week by week, oldest first, ending with the week `today` is in.
    public func weeklyChanges(today: String, weeks: Int) throws -> [WeekChange] {
        let weighIns = try writer.read { db in try WeighIn.order(Column("day"), Column("at")).fetchAll(db) }
        let divTargets = try writer.read { db in
            try NutritionTarget.filter(Column("source") == NutritionTarget.Source.div.rawValue).fetchAll(db)
        }
        let trend = WeightTrend.trend(weighIns.map(\.kg))
        func trendKg(onOrBefore day: String) -> Double? {
            weighIns.lastIndex { $0.day <= day }.map { trend[$0] }
        }
        let thisMonday = Self.monday(of: today)
        return (0..<weeks).reversed().map { back in
            let monday = Day.adding(-7 * back, to: thisMonday)
            let end = min(Day.adding(6, to: monday), today)
            let weighed = weighIns.contains { $0.day >= monday && $0.day <= end }
            let kg: Double? =
                if weighed, let now = trendKg(onOrBefore: end), let before = trendKg(onOrBefore: Day.adding(-1, to: monday)) {
                    ((now - before) * 100).rounded() / 100
                } else { nil }
            let changed = divTargets.contains { $0.startDay >= monday && $0.startDay <= end }
            return WeekChange(weekStart: monday, kg: kg, divChangedTarget: changed)
        }
    }

    /// The latest reading at each site, in `BodyMeasurement.Site` order.
    public func latestMeasurements() throws -> [MeasurementReading] {
        let all = try writer.read { db in try BodyMeasurement.order(Column("day")).fetchAll(db) }
        return BodyMeasurement.Site.allCases.compactMap { site in
            let readings = all.filter { $0.site == site }
            guard let latest = readings.last else { return nil }
            let change = readings.count > 1 ? ((latest.cm - readings[readings.count - 2].cm) * 10).rounded() / 10 : nil
            return MeasurementReading(latest: latest, changeCm: change)
        }
    }

    // MARK: Targets

    /// The target in force on `today`, the one before it, and Div's change if Div set it.
    public func targetHistory(today: String) throws -> TargetHistory? {
        try writer.read { db in
            let targets = try NutritionTarget.filter(Column("start_day") <= today).order(Column("start_day").desc).limit(2)
                .fetchAll(db)
            guard let current = targets.first else { return nil }
            let change = try current.divChangeID.flatMap { try DivChange.fetchOne(db, key: $0.uuidString.lowercased()) }
            return TargetHistory(current: current, previous: targets.dropFirst().first, change: change)
        }
    }

    // MARK: Strength

    /// Lifts done in the last `days` days, the most often done first: each day's best e1RM.
    public func liftTrends(today: String, days: Int? = 90, limit: Int = 4, library: Library = .standard) throws -> [LiftTrend] {
        let since = days.map { Day.adding(-$0, to: today) } ?? ""
        let (workouts, sets) = try writer.read { db in
            let workouts = try Workout.filter(Column("day") >= since && Column("day") <= today && Column("skipped") == false)
                .fetchAll(db)
            let ids = workouts.map { $0.id.uuidString.lowercased() }
            return (workouts, try LoggedSet.filter(ids.contains(Column("workout_id"))).fetchAll(db))
        }
        let dayOf = Dictionary(workouts.map { ($0.id, $0.day) }, uniquingKeysWith: { first, _ in first })
        func e1rm(_ set: LoggedSet) -> Double {
            Strength.e1rm(loadKg: set.loadKg, reps: set.reps, rir: set.rir)
        }
        let trends = Dictionary(grouping: sets.filter { $0.reps > 0 && $0.loadKg > 0 }, by: \.exerciseID).compactMap {
            id, sets -> LiftTrend? in
            let byDay = Dictionary(grouping: sets) { dayOf[$0.workoutID] ?? "" }
            let days = byDay.keys.sorted()
            guard let lastDay = days.last, let best = byDay[lastDay]?.max(by: { e1rm($0) < e1rm($1) }) else { return nil }
            let points = days.map { day in byDay[day]?.map(e1rm).max() ?? 0 }.map { ($0 * 10).rounded() / 10 }
            return LiftTrend(
                exerciseID: id, name: library.exercise(id)?.name ?? id, best: best, bestDay: lastDay, e1rmKg: points[points.count - 1],
                changeKg: points.count > 1 ? ((points[points.count - 1] - points[0]) * 10).rounded() / 10 : nil, points: points)
        }
        return Array(trends.sorted { ($0.points.count, $1.name) > ($1.points.count, $0.name) }.prefix(limit))
    }

    // MARK: Plan

    /// Where an exercise is in the plan, in session order.
    public func plannedUses(of exerciseID: String) throws -> [PlannedUse] {
        try plan().flatMap { session, rows in
            rows.filter { $0.exerciseID == exerciseID }.map { PlannedUse(session: session, row: $0) }
        }
    }

    /// The person swapped an exercise in their plan, for good. Swapping back to what it replaced clears the swap.
    public func swapExercise(_ from: String, to: String) throws {
        guard from != to else { return }
        try writer.write { db in
            for var row in try PlannedExercise.filter(Column("exercise_id") == from).fetchAll(db) {
                if row.swappedFromID == to {
                    row.swappedFromID = nil
                } else {
                    row.swappedFromID = row.swappedFromID ?? row.exerciseID
                }
                row.exerciseID = to
                row.swapEndsDay = nil
                row.loadKg = nil
                row.hitTopOfRangeSessions = 0
                try row.update(db)
            }
        }
    }

    /// The Div change that swapped `exerciseID` into the plan and still stands, for its reason and its Undo.
    public func divSwap(into exerciseID: String, library: Library = .standard) throws -> DivChange? {
        let changes = try writer.read { db in try DivChange.order(Column("created_at").desc).fetchAll(db) }
        return changes.first { change in
            guard change.status == .applied || change.status == .approved,
                case .swapExercise(_, let to, _) = change.proposal.change
            else { return false }
            return (library.exercise(named: to)?.id ?? to.lowercased()) == exerciseID
        }
    }

    // MARK: Div

    /// What Div remembers, newest first.
    public func memories() throws -> [Memory] {
        try writer.read { db in try Memory.order(Column("created_at").desc).fetchAll(db) }
    }

    /// The person told Div to forget something. Memories aren't logs, so the row goes.
    public func forget(_ memoryID: UUID) throws {
        try delete(Memory.self, id: memoryID)
    }

    /// What Div may do without asking (D-009). The bridge reads it from the profile on each job.
    public func setAutonomy(_ autonomy: Autonomy) throws {
        try writer.write { db in
            guard var profile = try Profile.fetchOne(db) else { return }
            profile.autonomy = autonomy
            try profile.update(db)
        }
    }
}
