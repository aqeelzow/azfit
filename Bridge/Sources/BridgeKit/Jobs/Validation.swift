import AZModel
import Foundation

/// Checks what the phone sends before a job runs, so a bad request fails with a clear list of problems instead of
/// producing nonsense numbers.
public enum Validation {
    public static let maxPhotoBytes = 8 * 1024 * 1024

    /// Decodes a job's input and checks it. Throws `Invalid` with every problem found.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let value: T
        do {
            value = try DivJSON.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw Invalid(problems: [describe(error)])
        }
        let problems: [String] =
            switch value {
            case let s as WeeklySnapshot: check(s)
            case let s as SessionReport: check(s)
            case let r as MealPhotoRequest: check(r)
            case let r as ChatRequest: r.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ["message is empty"] : []
            default: []
            }
        if !problems.isEmpty { throw Invalid(problems: problems) }
        return value
    }

    public struct Invalid: Error, CustomStringConvertible {
        public var problems: [String]
        public var description: String { "invalid input: " + problems.joined(separator: "; ") }
    }

    public static func check(_ s: WeeklySnapshot) -> [String] {
        var problems: [String] = []
        if s.intake.windowDays <= 0 { problems.append("intake.window_days must be positive") }
        if [s.weight.trendKgNow, s.weight.trendKgWeekAgo, s.weight.trendKgWindowStart].contains(where: { $0 <= 0 }) {
            problems.append("weight trend values must be positive")
        }
        if s.lifts.contains(where: { $0.e1rmWindowStart <= 0 }) { problems.append("lifts need a positive e1rm_window_start") }
        if s.currentLoads.contains(where: { $0.loadKg <= 0 }) { problems.append("current_loads need a positive load_kg") }
        if s.user.calorieFloorKcal <= 0 || s.targets.caloriesKcal <= 0 { problems.append("calorie target and floor must be positive") }
        return problems
    }

    public static func check(_ s: SessionReport) -> [String] {
        if s.exercises.isEmpty { return ["exercises must not be empty"] }
        var problems: [String] = []
        for (i, e) in s.exercises.enumerated() {
            let p = e.prescribed
            if p.loadKg <= 0 || p.sets <= 0 || p.repMin > p.repMax { problems.append("exercises[\(i)].prescribed is incomplete") }
            if e.performed.contains(where: { $0.loadKg < 0 || $0.reps < 0 }) {
                problems.append("exercises[\(i)].performed has a negative value")
            }
        }
        if let soreness = s.soreness, !(1...5).contains(soreness) { problems.append("soreness must be 1 to 5") }
        return problems
    }

    public static func check(_ r: MealPhotoRequest) -> [String] {
        var problems: [String] = []
        if r.photo.count < 100 { problems.append("photo is missing") }
        if r.photo.count > maxPhotoBytes { problems.append("photo is over 8 MB; resize it on the phone") }
        if let plate = r.plateDiameterCm, plate <= 0 { problems.append("plate_diameter_cm must be positive") }
        if let weight = r.foodWeightG, weight <= 0 { problems.append("food_weight_g must be positive") }
        return problems
    }

    static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }
            return keys.isEmpty ? "body" : keys.joined(separator: ".").replacing(".[", with: "[")
        }
        switch error {
        case .keyNotFound(let key, let context): return "missing \(path(context)).\(key.stringValue)".replacing("body.", with: "")
        case .typeMismatch(_, let context), .valueNotFound(_, let context): return "wrong type at \(path(context))"
        case .dataCorrupted(let context): return "\(path(context)): \(context.debugDescription)"
        @unknown default: return "invalid JSON"
        }
    }
}
