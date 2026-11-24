// Chat with Div (Div/prompts/jobs/chat.md). Unlike the other jobs, chat gets no snapshot: Div looks things up
// with read tools served by the bridge over MCP (D-021), from a `DivData`.

public struct ChatRequest: Codable, Sendable, Equatable {
    public var message: String
    /// The conversation so far, oldest first.
    public var history: [ChatMessage]

    public init(message: String, history: [ChatMessage] = []) {
        self.message = message
        self.history = history
    }
}

public struct ChatMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable {
        case user
        case div
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// What Div returns in chat (Div/schemas/chat.json).
public struct ChatOutput: Codable, Sendable, Equatable {
    public var reply: String
    public var changes: [Proposal]
    /// Lasting facts the person shared ("Left shoulder tight overhead"), for "What Div knows".
    public var remember: [String]

    public init(reply: String, changes: [Proposal] = [], remember: [String] = []) {
        self.reply = reply
        self.changes = changes
        self.remember = remember
    }
}

/// The data Div's read tools answer from. Today the bridge builds it from what the phone sends; once sync exists
/// it comes from the bridge's copy of the database (AZStore).
public struct DivData: Codable, Sendable, Equatable {
    /// YYYY-MM-DD. Tools count "the last N days" back from this.
    public var today: String
    public var profile: Profile
    public var memories: [Memory]
    public var plan: [PlannedSession]
    public var weighIns: [WeighIn]
    public var waist: [WaistMeasurement]
    public var days: [FoodDay]
    public var workouts: [Workout]
    public var divLog: [LogEntry]

    public struct Profile: Codable, Sendable, Equatable {
        public var name: String?
        public var age: Int
        public var heightCm: Double
        public var goal: Goal
        public var targetRatePctPerWeek: Double
        public var caloriesKcal: Int
        public var proteinGPerKg: Double
        public var calorieFloorKcal: Int
        public var kidneyDisease: Bool
    }

    public struct Memory: Codable, Sendable, Equatable {
        public var text: String
        /// "onboarding", "chat" or "learned".
        public var source: String
        public var date: String?
    }

    public struct PlannedSession: Codable, Sendable, Equatable {
        /// Weekday, e.g. "Monday".
        public var day: String
        public var name: String
        public var exercises: [PlannedExercise]
    }

    public struct PlannedExercise: Codable, Sendable, Equatable {
        public var exercise: String
        public var sets: Int
        public var repMin: Int
        public var repMax: Int
        public var loadKg: Double
        public var hitTopOfRangeSessions: Int?
    }

    public struct WeighIn: Codable, Sendable, Equatable {
        public var date: String
        public var kg: Double
    }

    public struct WaistMeasurement: Codable, Sendable, Equatable {
        public var date: String
        public var cm: Double
    }

    public struct FoodDay: Codable, Sendable, Equatable {
        public var date: String
        /// The person marked the day as fully logged.
        public var complete: Bool
        public var meals: [Meal]
    }

    public struct Meal: Codable, Sendable, Equatable {
        public var time: String
        public var name: String
        public var kcal: Double
        public var proteinG: Double
        public var carbsG: Double
        public var fatG: Double
    }

    public struct Workout: Codable, Sendable, Equatable {
        public var date: String
        public var name: String
        public var sets: [WorkoutSet]
    }

    public struct WorkoutSet: Codable, Sendable, Equatable {
        public var exercise: String
        public var loadKg: Double
        public var reps: Int
        public var rir: Double
    }

    public struct LogEntry: Codable, Sendable, Equatable {
        public var date: String
        /// The Div job that made it, e.g. "weekly-review".
        public var job: String
        public var change: String
        public var reason: String
        public var evidence: [String]?
        /// "applied", "proposed" or "undone".
        public var status: String
    }
}
