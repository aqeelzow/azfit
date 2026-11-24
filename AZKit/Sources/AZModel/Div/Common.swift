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
/// Structural changes (volume, deloads, protein) always ask, whatever these say.
public struct Autonomy: Codable, Sendable, Equatable {
    /// "Reps, weight and rest": routine load changes after a workout or in the weekly review.
    public var workoutTweaks: Bool
    /// "Swap exercises, move sessions".
    public var swapsAndMoves: Bool
    /// "Calorie target, up to 200 kcal". Off means every calorie change asks first.
    public var calorieChanges: Bool

    public init(workoutTweaks: Bool, swapsAndMoves: Bool, calorieChanges: Bool) {
        self.workoutTweaks = workoutTweaks
        self.swapsAndMoves = swapsAndMoves
        self.calorieChanges = calorieChanges
    }

    /// The approved design's defaults: all three on. D-012 is still open; the brief would ask for swaps and
    /// for calorie changes of 150 kcal or more.
    public static let standard = Autonomy(workoutTweaks: true, swapsAndMoves: true, calorieChanges: true)
    /// Div suggests, the person decides, for everything.
    public static let askFirst = Autonomy(workoutTweaks: false, swapsAndMoves: false, calorieChanges: false)
}
