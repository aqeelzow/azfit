import Foundation

/// The exercise library that ships with the app (D-025): muscles in groups, and exercises tagged with the share
/// of a set each muscle gets. Edited in docs/library/draft.py, which writes Resources/exercises.json.
public struct Library: Codable, Sendable, Equatable {
    public var version: Int
    public var muscleGroups: [MuscleGroup]
    public var muscles: [Muscle]
    public var exercises: [Exercise]

    /// The library bundled with AZModel.
    public static let standard: Library = {
        guard let url = Bundle.module.url(forResource: "exercises", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let library = try? DivJSON.decode(Library.self, from: data)
        else { fatalError("AZModel's exercises.json is missing or unreadable") }
        return library
    }()

    public func exercise(_ id: String) -> Exercise? { exercisesByID[id] }
    public func muscle(_ id: String) -> Muscle? { muscles.first { $0.id == id } }
    public func group(_ id: String) -> MuscleGroup? { muscleGroups.first { $0.id == id } }

    /// Finds an exercise by its name, ignoring case, the way Div names them in its changes.
    public func exercise(named name: String) -> Exercise? {
        let key = name.lowercased()
        return exercises.first { $0.name.lowercased() == key || $0.id == key }
    }

    /// Exercises that work `muscle` as a main mover (a full set).
    public func exercises(for muscle: String) -> [Exercise] {
        exercises.filter { $0.muscles[muscle] == 1 }
    }

    private var exercisesByID: [String: Exercise] {
        Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private enum CodingKeys: String, CodingKey { case version, muscleGroups, muscles, exercises }
}

/// What a screen shows first ("Shoulders"); tapping it lists `muscles`.
public struct MuscleGroup: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var muscles: [String]
}

public struct Muscle: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var group: String
    public var name: String
    /// Below this many sets a week, a muscle doesn't grow. Div learns each person's own value.
    public var minSetsPerWeek: Int
    /// More than this is more than most people recover from.
    public var maxRecoverableSetsPerWeek: Int
    /// Roughly how long one hard session takes to clear.
    public var recoveryHours: Int
}

public struct Exercise: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var pattern: String
    public var equipment: String
    /// How much a hard set takes out of you overall, 1 (a curl) to 5 (a heavy deadlift).
    public var fatigueCost: Int
    /// Joints the lift loads hard, so Div can work around a sore one.
    public var jointStress: [String]
    /// Muscle ID to the share of a set it gets: 1, 0.5 or 0.25.
    public var muscles: [String: Double]

    /// The muscles that get a full set.
    public var primaryMuscles: [String] { muscles.filter { $0.value >= 1 }.keys.sorted() }
}
