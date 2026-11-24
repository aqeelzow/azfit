import AZMath
import AZModel
import Foundation

/// Div's read tools for chat (Div/tools/tools.json), answered from a `DivData`. Pure: same data and arguments,
/// same answer. Numbers like the trend weight and e1RM are computed here, so Div quotes them instead of guessing.
public struct DivTools: Sendable {
    public enum Failure: Error, CustomStringConvertible {
        case unknownTool(String)
        case badArgument(String)

        public var description: String {
            switch self {
            case .unknownTool(let name): "No tool called \(name)."
            case .badArgument(let message): message
            }
        }
    }

    public let data: DivData

    public init(data: DivData) {
        self.data = data
    }

    /// Runs a tool and returns its answer as JSON text.
    public func call(_ name: String, arguments: [String: Any]) throws -> String {
        switch name {
        case "get_profile": return try json(Profile(profile: data.profile, memories: data.memories))
        case "get_plan": return try json(Plan(sessions: data.plan))
        case "get_training_log":
            return try json(trainingLog(days: try int(arguments, "days") ?? 28, exercise: arguments["exercise"] as? String))
        case "get_food_log":
            let to = try date(arguments, "to") ?? data.today
            let from = try date(arguments, "from") ?? daysBefore(to, 7)
            return try json(foodLog(from: from, to: to))
        case "get_weight_trend": return try json(weightTrend(days: try int(arguments, "days") ?? 28))
        case "get_div_log":
            let since = daysBefore(data.today, try int(arguments, "days") ?? 30)
            return try json(DivLog(changes: data.divLog.filter { $0.date >= since }.sorted { $0.date > $1.date }))
        default: throw Failure.unknownTool(name)
        }
    }

    // MARK: Answers

    struct Profile: Encodable {
        var profile: DivData.Profile
        var memories: [DivData.Memory]
    }

    struct Plan: Encodable {
        var sessions: [DivData.PlannedSession]
    }

    struct DivLog: Encodable {
        var changes: [DivData.LogEntry]
    }

    struct TrainingLog: Encodable {
        struct Session: Encodable {
            var date: String
            var name: String
            var exercises: [Exercise]
        }

        struct Exercise: Encodable {
            var exercise: String
            var sets: [DivData.WorkoutSet]
            var bestE1rm: Double
        }

        var from: String
        var to: String
        var sessions: [Session]
    }

    func trainingLog(days: Int, exercise: String?) -> TrainingLog {
        let since = daysBefore(data.today, days)
        let wanted = exercise?.lowercased()
        let sessions = data.workouts.filter { $0.date >= since && $0.date <= data.today }.sorted { $0.date > $1.date }.compactMap {
            workout -> TrainingLog.Session? in
            var order: [String] = []
            var byExercise: [String: [DivData.WorkoutSet]] = [:]
            for set in workout.sets where wanted == nil || set.exercise.lowercased() == wanted {
                if byExercise[set.exercise] == nil { order.append(set.exercise) }
                byExercise[set.exercise, default: []].append(set)
            }
            if order.isEmpty { return nil }
            let exercises = order.map { name in
                let sets = byExercise[name]!
                let best = sets.map { Strength.e1rm(loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir) }.max() ?? 0
                return TrainingLog.Exercise(exercise: name, sets: sets, bestE1rm: (best * 10).rounded() / 10)
            }
            return TrainingLog.Session(date: workout.date, name: workout.name, exercises: exercises)
        }
        return TrainingLog(from: since, to: data.today, sessions: sessions)
    }

    struct FoodLog: Encodable {
        struct Day: Encodable {
            var date: String
            var complete: Bool
            var totals: MealTotals
            var meals: [DivData.Meal]
        }

        var from: String
        var to: String
        var days: [Day]
        var completeDays: Int
        var avgKcalCompleteDays: Int?
        var targetKcal: Int
    }

    func foodLog(from: String, to: String) -> FoodLog {
        let days = data.days.filter { $0.date >= from && $0.date <= to }.sorted { $0.date < $1.date }.map { day in
            let items = day.meals.map {
                MealItem(name: $0.name, portion: "", grams: 0, kcal: $0.kcal, proteinG: $0.proteinG, carbsG: $0.carbsG, fatG: $0.fatG)
            }
            return FoodLog.Day(date: day.date, complete: day.complete, totals: MealMath.totals(items), meals: day.meals)
        }
        let complete = days.filter(\.complete)
        let avg = complete.isEmpty ? nil : complete.map(\.totals.kcal).reduce(0, +) / complete.count
        return FoodLog(
            from: from, to: to, days: days, completeDays: complete.count, avgKcalCompleteDays: avg, targetKcal: data.profile.caloriesKcal)
    }

    struct WeightAnswer: Encodable {
        struct Point: Encodable {
            var date: String
            var kg: Double
            var trendKg: Double
        }

        var from: String
        var to: String
        var weighIns: [Point]
        var trendChangeKg: Double?
        var weeklyRateKg: Double?
        var weeklyRatePct: Double?
        var targetRatePctPerWeek: Double
        var waist: [DivData.WaistMeasurement]
    }

    func weightTrend(days: Int) -> WeightAnswer {
        // The trend runs over every weigh-in so it's already settled at the start of the window.
        let all = data.weighIns.filter { $0.date <= data.today }.sorted { $0.date < $1.date }
        let trend = WeightTrend.trend(all.map(\.kg))
        let since = daysBefore(data.today, days)
        let points = zip(all, trend).filter { $0.0.date >= since }.map { WeightAnswer.Point(date: $0.0.date, kg: $0.0.kg, trendKg: $0.1) }
        var change: Double?
        var weekly: Double?
        var pct: Double?
        if let first = points.first, let last = points.last, first.date != last.date {
            let span = dayCount(from: first.date, to: last.date)
            change = ((last.trendKg - first.trendKg) * 100).rounded() / 100
            weekly = WeightTrend.weeklyRateKg([first.trendKg, last.trendKg], days: span)
            pct = weekly.map { ($0 / last.trendKg * 10_000).rounded() / 100 }
        }
        return WeightAnswer(
            from: since, to: data.today, weighIns: points, trendChangeKg: change, weeklyRateKg: weekly, weeklyRatePct: pct,
            targetRatePctPerWeek: data.profile.targetRatePctPerWeek, waist: data.waist.filter { $0.date >= since })
    }

    // MARK: Helpers

    func json(_ value: some Encodable) throws -> String { try DivJSON.string(value, pretty: false) }

    func int(_ arguments: [String: Any], _ key: String) throws -> Int? {
        guard let value = arguments[key] else { return nil }
        guard let number = value as? Int ?? (value as? Double).map({ Int($0) }), (1...365).contains(number) else {
            throw Failure.badArgument("\(key) must be a whole number from 1 to 365.")
        }
        return number
    }

    func date(_ arguments: [String: Any], _ key: String) throws -> String? {
        guard let value = arguments[key] else { return nil }
        guard let text = value as? String, isDate(text) else { throw Failure.badArgument("\(key) must be a date like 2026-11-23.") }
        return text
    }
}

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func parseDay(_ s: String) -> Date? {
    let parts = s.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

/// The date `days` before `date`, as YYYY-MM-DD.
func daysBefore(_ date: String, _ days: Int) -> String {
    guard let day = parseDay(date), let earlier = calendar.date(byAdding: .day, value: -days, to: day) else { return date }
    let c = calendar.dateComponents([.year, .month, .day], from: earlier)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

func dayCount(from: String, to: String) -> Int {
    guard let a = parseDay(from), let b = parseDay(to) else { return 0 }
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}
