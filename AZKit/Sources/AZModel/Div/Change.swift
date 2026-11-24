/// One change to the plan, as Div returns it in `changes` (D-008). Div has no tools that write: this list is the
/// whole diff, and the bridge checks each one before anything is saved.
public enum PlanChange: Sendable, Equatable {
    case setCalorieTarget(newKcal: Int)
    case setProteinTarget(gramsPerKg: Double)
    case setLoad(exercise: String, newLoadKg: Double)
    case swapExercise(from: String, to: String)
    case moveSession(session: String, toDay: String)
    case changeVolume(muscle: String, deltaSetsPerWeek: Int)
    case scheduleDeload(startDate: String, weeks: Int)

    /// The `type` string in the JSON, e.g. "set_calorie_target".
    public var kind: String {
        switch self {
        case .setCalorieTarget: "set_calorie_target"
        case .setProteinTarget: "set_protein_target"
        case .setLoad: "set_load"
        case .swapExercise: "swap_exercise"
        case .moveSession: "move_session"
        case .changeVolume: "change_volume"
        case .scheduleDeload: "schedule_deload"
        }
    }
}

/// A change with the sentence the person reads and the numbers it rests on.
public struct Proposal: Codable, Sendable, Equatable {
    public var change: PlanChange
    public var reason: String
    public var evidence: [String]

    public init(_ change: PlanChange, reason: String = "", evidence: [String] = []) {
        self.change = change
        self.reason = reason
        self.evidence = evidence
    }

    // Flat on the wire: { "type": "set_load", "exercise": ..., "new_load_kg": ..., "reason": ..., "evidence": [...] }.
    // Case names are camelCase because DivJSON converts keys from snake_case before matching them.
    private enum CodingKeys: String, CodingKey {
        case type, reason, evidence
        case newKcal, gramsPerKg, exercise, newLoadKg, from, to, session, toDay, muscle, deltaSetsPerWeek, startDate, weeks
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reason = try c.decode(String.self, forKey: .reason)
        evidence = try c.decodeIfPresent([String].self, forKey: .evidence) ?? []
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "set_calorie_target":
            change = .setCalorieTarget(newKcal: try c.decode(Int.self, forKey: .newKcal))
        case "set_protein_target":
            change = .setProteinTarget(gramsPerKg: try c.decode(Double.self, forKey: .gramsPerKg))
        case "set_load":
            change = .setLoad(
                exercise: try c.decode(String.self, forKey: .exercise), newLoadKg: try c.decode(Double.self, forKey: .newLoadKg))
        case "swap_exercise":
            change = .swapExercise(from: try c.decode(String.self, forKey: .from), to: try c.decode(String.self, forKey: .to))
        case "move_session":
            change = .moveSession(session: try c.decode(String.self, forKey: .session), toDay: try c.decode(String.self, forKey: .toDay))
        case "change_volume":
            change = .changeVolume(
                muscle: try c.decode(String.self, forKey: .muscle), deltaSetsPerWeek: try c.decode(Int.self, forKey: .deltaSetsPerWeek))
        case "schedule_deload":
            change = .scheduleDeload(
                startDate: try c.decode(String.self, forKey: .startDate), weeks: try c.decode(Int.self, forKey: .weeks))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown change type \"\(type)\"")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(change.kind, forKey: .type)
        switch change {
        case .setCalorieTarget(let newKcal):
            try c.encode(newKcal, forKey: .newKcal)
        case .setProteinTarget(let gramsPerKg):
            try c.encode(gramsPerKg, forKey: .gramsPerKg)
        case .setLoad(let exercise, let newLoadKg):
            try c.encode(exercise, forKey: .exercise)
            try c.encode(newLoadKg, forKey: .newLoadKg)
        case .swapExercise(let from, let to):
            try c.encode(from, forKey: .from)
            try c.encode(to, forKey: .to)
        case .moveSession(let session, let toDay):
            try c.encode(session, forKey: .session)
            try c.encode(toDay, forKey: .toDay)
        case .changeVolume(let muscle, let deltaSetsPerWeek):
            try c.encode(muscle, forKey: .muscle)
            try c.encode(deltaSetsPerWeek, forKey: .deltaSetsPerWeek)
        case .scheduleDeload(let startDate, let weeks):
            try c.encode(startDate, forKey: .startDate)
            try c.encode(weeks, forKey: .weeks)
        }
        try c.encode(reason, forKey: .reason)
        try c.encode(evidence, forKey: .evidence)
    }
}
