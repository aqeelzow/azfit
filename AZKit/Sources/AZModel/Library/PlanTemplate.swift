/// The plan a new person starts with, picked from how many days they train (D-028). Div changes it afterwards
/// through ordinary changes. The splits and training days match the onboarding Days screen.
public struct PlanTemplate: Sendable, Equatable {
    public struct Session: Sendable, Equatable {
        public var name: String
        /// 1 is Monday.
        public var weekday: Int
        public var exercises: [Item]
    }

    public struct Item: Sendable, Equatable {
        public var exerciseID: String
        public var sets: Int
        public var repMin: Int
        public var repMax: Int
    }

    public var days: Int
    public var name: String
    public var sessions: [Session]

    /// The template for `days` a week, 2 to 6 (clamped), on the weekdays the person picked (1 is Monday) when they
    /// picked that many, else the usual days for that many.
    public static func forDays(_ days: Int, on picked: Set<Int>? = nil) -> PlanTemplate {
        let days = min(max(days, 2), 6)
        let valid = picked.map { $0.filter { (1...7).contains($0) } }
        let weekdays = valid.flatMap { $0.count == days ? $0.sorted() : nil } ?? trainingWeekdays[days] ?? [1, 4]
        let blocks: [(String, [Item])] =
            switch days {
            case 2: [("Full body A", fullA), ("Full body B", fullB)]
            case 3: [("Full body A", fullA), ("Full body B", fullB), ("Full body C", fullC)]
            case 4: [("Push", push), ("Pull", pull), ("Legs", legs), ("Upper", upper)]
            case 5: [("Push", push), ("Pull", pull), ("Legs", legs), ("Upper", upper), ("Lower", lower)]
            default: [("Push A", push), ("Pull A", pull), ("Legs A", legs), ("Push B", push), ("Pull B", pull), ("Legs B", legs)]
            }
        return PlanTemplate(
            days: days, name: splitNames[days] ?? "",
            sessions: zip(blocks, weekdays).map { Session(name: $0.0, weekday: $1, exercises: $0.1) })
    }

    /// What the Days screen says for each choice.
    public static let splitNames = [
        2: "Full body, twice a week", 3: "Full body A, B and C", 4: "Push, Pull, Legs, Upper",
        5: "Push, Pull, Legs, Upper, Lower", 6: "Push, Pull, Legs, twice",
    ]

    /// Which weekdays get a session (1 is Monday).
    public static let trainingWeekdays: [Int: [Int]] = [
        2: [1, 4], 3: [1, 3, 5], 4: [1, 2, 4, 6], 5: [1, 2, 3, 5, 6], 6: [1, 2, 3, 4, 5, 6],
    ]

    private static func i(_ id: String, _ sets: Int, _ reps: ClosedRange<Int>) -> Item {
        Item(exerciseID: id, sets: sets, repMin: reps.lowerBound, repMax: reps.upperBound)
    }

    static let fullA = [
        i("back_squat", 3, 6...8), i("barbell_bench_press", 3, 6...8), i("seated_cable_row", 3, 8...12),
        i("romanian_deadlift", 2, 8...10), i("dumbbell_lateral_raise", 2, 12...15), i("cable_curl", 2, 10...12),
    ]
    static let fullB = [
        i("trap_bar_deadlift", 3, 5...8), i("incline_dumbbell_press", 3, 8...10), i("lat_pulldown", 3, 8...12),
        i("bulgarian_split_squat", 2, 8...10), i("face_pull", 2, 12...15), i("triceps_pushdown", 2, 10...12),
    ]
    static let fullC = [
        i("leg_press", 3, 10...12), i("overhead_press", 3, 6...8), i("chest_supported_row", 3, 8...12),
        i("lying_leg_curl", 2, 10...12), i("cable_fly", 2, 12...15), i("hammer_curl", 2, 10...12),
        i("standing_calf_raise", 2, 10...15),
    ]
    static let push = [
        i("barbell_bench_press", 3, 6...8), i("incline_dumbbell_press", 3, 8...10), i("seated_dumbbell_press", 3, 8...10),
        i("cable_lateral_raise", 3, 12...15), i("triceps_pushdown", 3, 10...12), i("overhead_cable_extension", 2, 10...12),
    ]
    static let pull = [
        i("lat_pulldown", 3, 8...12), i("barbell_row", 3, 6...8), i("seated_cable_row", 2, 10...12),
        i("face_pull", 3, 12...15), i("barbell_curl", 3, 8...12), i("hammer_curl", 2, 10...12),
    ]
    static let legs = [
        i("back_squat", 3, 6...8), i("romanian_deadlift", 3, 8...10), i("leg_press", 3, 10...12),
        i("lying_leg_curl", 3, 10...12), i("standing_calf_raise", 3, 10...15), i("hanging_leg_raise", 2, 10...15),
    ]
    static let upper = [
        i("incline_barbell_press", 3, 6...8), i("chest_supported_row", 3, 8...12), i("seated_dumbbell_press", 2, 8...10),
        i("lat_pulldown", 3, 8...12), i("dumbbell_lateral_raise", 2, 12...15), i("ez_bar_curl", 2, 10...12),
        i("skull_crusher", 2, 10...12),
    ]
    static let lower = [
        i("trap_bar_deadlift", 3, 5...8), i("bulgarian_split_squat", 3, 8...10), i("seated_leg_curl", 3, 10...12),
        i("leg_extension", 2, 12...15), i("hip_thrust", 2, 8...12), i("seated_calf_raise", 3, 12...15),
    ]
}
