/// What the person is training for. Sets the protein range and how the weekly review reads the scale.
public enum Goal: String, Codable, Sendable, CaseIterable {
    case cut
    case recomp
    case build
}

/// Which way a measurement moved over the review window, after ignoring noise.
public enum Direction: String, Codable, Sendable {
    case up
    case flat
    case down
    case unknown
}

/// What the bridge does with a change Div returned (D-009). Code decides this, never the prompt.
public enum Verdict: String, Codable, Sendable {
    /// Applied now, marked as Div's, undoable for 7 days.
    case apply
    /// Waits for the person to tap Approve.
    case propose
    /// Dropped: it broke a hard limit. The notes say which.
    case refuse
}

/// One thing Div returned, with the bridge's verdict on it and why.
public struct Checked<Item: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var item: Item
    public var verdict: Verdict
    public var notes: [String]

    public init(item: Item, verdict: Verdict, notes: [String] = []) {
        self.item = item
        self.verdict = verdict
        self.notes = notes
    }
}

/// What Div may do without asking: the switches on "What Div knows" (D-009, D-012).
/// Calorie changes always ask, and structural changes (volume, deloads, protein) always ask, whatever these say.
public struct Autonomy: Codable, Sendable, Equatable {
    /// "Reps, weight and rest": routine load changes after a workout or in the weekly review.
    public var workoutTweaks: Bool
    /// "Swap exercises".
    public var swaps: Bool
    /// "Move sessions".
    public var moves: Bool

    public init(workoutTweaks: Bool, swaps: Bool, moves: Bool) {
        self.workoutTweaks = workoutTweaks
        self.swaps = swaps
        self.moves = moves
    }

    /// D-012: routine progression and moving a session apply on their own; swaps ask first.
    public static let standard = Autonomy(workoutTweaks: true, swaps: false, moves: true)
    /// Div changes everything it may change alone. Calories still ask.
    public static let allOn = Autonomy(workoutTweaks: true, swaps: true, moves: true)
    /// Div suggests, the person decides, for everything.
    public static let askFirst = Autonomy(workoutTweaks: false, swaps: false, moves: false)
}
