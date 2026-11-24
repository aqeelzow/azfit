// Mid-workout tweaks (Div/prompts/jobs/in-workout.md): after a set, adjust the next one.

/// The exercise in progress: what was prescribed and the sets done so far.
public struct InWorkoutRequest: Codable, Sendable, Equatable {
    public var exercise: String
    public var prescribed: SessionReport.Prescription
    /// Sets done so far in this exercise, in order.
    public var done: [SessionReport.PerformedSet]
    /// Planned rest between sets, in seconds.
    public var restS: Int?
    public var userNote: String?
    public var memories: [String]?

    public init(
        exercise: String, prescribed: SessionReport.Prescription, done: [SessionReport.PerformedSet], restS: Int? = nil,
        userNote: String? = nil, memories: [String]? = nil
    ) {
        self.exercise = exercise
        self.prescribed = prescribed
        self.done = done
        self.restS = restS
        self.userNote = userNote
        self.memories = memories
    }
}

/// Numbers computed by AZMath for the exercise in progress.
public struct InWorkoutDerived: Codable, Sendable, Equatable {
    public var setsDone: Int
    public var setsLeft: Int
    /// Per set done: reps against the range, RIR against the prescription.
    public var sets: [SetCheck]
    /// e1RM of the first set and of the last set, to see fatigue within the exercise.
    public var firstSetE1rm: Double?
    public var lastSetE1rm: Double?

    public struct SetCheck: Codable, Sendable, Equatable {
        public var reps: Int
        public var loadKg: Double
        /// "below", "in" or "top" of the rep range.
        public var repRange: String
        public var rirVsPrescribed: Double

        public init(reps: Int, loadKg: Double, repRange: String, rirVsPrescribed: Double) {
            self.reps = reps
            self.loadKg = loadKg
            self.repRange = repRange
            self.rirVsPrescribed = rirVsPrescribed
        }
    }

    public init(setsDone: Int, setsLeft: Int, sets: [SetCheck], firstSetE1rm: Double?, lastSetE1rm: Double?) {
        self.setsDone = setsDone
        self.setsLeft = setsLeft
        self.sets = sets
        self.firstSetE1rm = firstSetE1rm
        self.lastSetE1rm = lastSetE1rm
    }
}

/// What Div returns for the next set (Div/schemas/in-workout.json).
public struct InWorkoutOutput: Codable, Sendable, Equatable {
    public enum Call: String, Codable, Sendable {
        case keep
        case lowerLoad = "lower_load"
        case lowerReps = "lower_reps"
        case raiseLoad = "raise_load"
        /// End this exercise now (pain, or form breaking down).
        case stop
    }

    public var call: Call
    public var nextLoadKg: Double
    public var nextReps: Int
    public var restS: Int
    public var reason: String

    public init(call: Call, nextLoadKg: Double, nextReps: Int, restS: Int, reason: String = "") {
        self.call = call
        self.nextLoadKg = nextLoadKg
        self.nextReps = nextReps
        self.restS = restS
        self.reason = reason
    }
}
