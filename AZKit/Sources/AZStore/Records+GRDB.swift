import AZModel
import Foundation
import GRDB

/// A table in the person's database. Columns are snake_case (`planned_session_id`), UUIDs lowercase text (D-019),
/// and nested values (`autonomy`, `proposal`, `notes`) JSON text.
public protocol StoredRecord: Codable, Sendable, FetchableRecord, PersistableRecord {}

/// Records that may be deleted, because they aren't something the person logged.
public protocol PlanOrMemory {}

extension StoredRecord {
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy {
        .custom { key in ColumnName.snake(key.stringValue) }
    }

    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy {
        .custom { column in ColumnName.Key(stringValue: ColumnName.camel(column)) }
    }

    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .lowercaseString }
}

extension Profile: StoredRecord { public static let databaseTableName = "profile" }
extension NutritionTarget: StoredRecord { public static let databaseTableName = "nutrition_target" }
extension PlannedSession: StoredRecord, PlanOrMemory { public static let databaseTableName = "planned_session" }
extension PlannedExercise: StoredRecord, PlanOrMemory { public static let databaseTableName = "planned_exercise" }
extension Workout: StoredRecord { public static let databaseTableName = "workout" }
extension LoggedSet: StoredRecord { public static let databaseTableName = "logged_set" }
extension Meal: StoredRecord { public static let databaseTableName = "meal" }
extension FoodDay: StoredRecord { public static let databaseTableName = "food_day" }
extension WeighIn: StoredRecord { public static let databaseTableName = "weigh_in" }
extension BodyMeasurement: StoredRecord { public static let databaseTableName = "body_measurement" }
extension DivChange: StoredRecord { public static let databaseTableName = "div_change" }
extension Memory: StoredRecord, PlanOrMemory { public static let databaseTableName = "memory" }
extension WeekReview: StoredRecord { public static let databaseTableName = "week_review" }

/// Swift property names to column names and back. "ID" is one word: `plannedSessionID` is `planned_session_id`.
enum ColumnName {
    static func snake(_ key: String) -> String {
        let characters = Array(key)
        var out = ""
        for (i, c) in characters.enumerated() {
            if c.isUppercase, i > 0 {
                let previous = characters[i - 1]
                let nextIsLower = i + 1 < characters.count && characters[i + 1].isLowercase
                if previous.isLowercase || previous.isNumber || (previous.isUppercase && nextIsLower) { out.append("_") }
            }
            out.append(contentsOf: c.lowercased())
        }
        return out
    }

    static func camel(_ column: String) -> String {
        let parts = column.split(separator: "_").map(String.init)
        guard let first = parts.first else { return column }
        return first + parts.dropFirst().map { $0 == "id" ? "ID" : $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
