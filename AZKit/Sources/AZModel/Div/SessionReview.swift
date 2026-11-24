// The review right after a workout (Div/prompts/jobs/session-review.md).

/// A finished workout: what was prescribed and what was done, set by set.
public struct SessionReport: Codable, Sendable, Equatable {
    public var date: String
    public var sessionName: String
    public var exercises: [Exercise]
    public var sleepLastNightH: Double?
    /// 1 (fresh) to 5 (very sore).
    public var soreness: Int?
    public var userNote: String?
    public var memories: [String]?

    public struct Exercise: Codable, Sendable, Equatable {
        public var exercise: String
        public var prescribed: Prescription
        public var performed: [PerformedSet]
        /// Best e1RM from each of the last few sessions, oldest first.
        public var e1rmHistory: [Double]
    }

    public struct Prescription: Codable, Sendable, Equatable {
        public var sets: Int
        public var repMin: Int
        public var repMax: Int
        public var rir: Double
        public var loadKg: Double
    }

    public struct PerformedSet: Codable, Sendable, Equatable {
        public var loadKg: Double
        public var reps: Int
        public var rir: Double
    }
}

/// Numbers computed by AZMath from a SessionReport.
public struct SessionDerived: Codable, Sendable, Equatable {
    public var exercises: [Exercise]

    public struct Exercise: Codable, Sendable, Equatable {
        public var exercise: String
        public var setsDone: Int
        public var setsPrescribed: Int
        public var bestE1rm: Double
        public var e1rmChangePctVsLast: Double?
        public var allSetsAtTopOfRange: Bool
        public var avgRir: Double
        /// Average RIR minus the prescribed RIR. Negative means the sets were harder than planned.
        public var rirVsPrescribed: Double

        public init(
            exercise: String, setsDone: Int, setsPrescribed: Int, bestE1rm: Double, e1rmChangePctVsLast: Double?,
            allSetsAtTopOfRange: Bool, avgRir: Double, rirVsPrescribed: Double
        ) {
            self.exercise = exercise
            self.setsDone = setsDone
            self.setsPrescribed = setsPrescribed
            self.bestE1rm = bestE1rm
            self.e1rmChangePctVsLast = e1rmChangePctVsLast
            self.allSetsAtTopOfRange = allSetsAtTopOfRange
            self.avgRir = avgRir
            self.rirVsPrescribed = rirVsPrescribed
        }
    }

    public init(exercises: [Exercise]) {
        self.exercises = exercises
    }
}

/// Next time's load for one exercise.
public struct NextTime: Codable, Sendable, Equatable {
    public enum Call: String, Codable, Sendable {
        case progress
        case `repeat`
        case reduce
    }

    public var exercise: String
    public var call: Call
    public var nextLoadKg: Double
    public var reason: String

    public init(exercise: String, call: Call, nextLoadKg: Double, reason: String = "") {
        self.exercise = exercise
        self.call = call
        self.nextLoadKg = nextLoadKg
        self.reason = reason
    }
}

/// What Div returns for a session review (Div/schemas/session-review.json).
public struct SessionReviewOutput: Codable, Sendable, Equatable {
    public var note: String
    public var nextTime: [NextTime]

    public init(note: String = "", nextTime: [NextTime]) {
        self.note = note
        self.nextTime = nextTime
    }
}
