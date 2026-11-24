/// Hard limits from the brief (docs/product-brief.html) and D-009/D-010. Div proposes; these decide.
/// No setting changes them: the autonomy switches only choose between applying and asking.
public enum Limits {
    /// A calorie change moves the target by 100 to 200 kcal, in steps of 50.
    public static let calorieStep = 100...200
    public static let calorieStepMultiple = 50
    /// Load increases that count as routine (apply alone if allowed): up to 5% or 2.5 kg, whichever is larger.
    public static let loadRoutinePct = 5.0
    public static let loadRoutineKg = 2.5
    /// Any load change bigger than this is refused.
    public static let loadMaxUpPct = 10.0
    /// After a session: reductions up to 10% are routine, up to 20% ask, beyond that are refused.
    public static let loadRoutineDownPct = 10.0
    public static let loadMaxDownPct = 20.0
    /// Sessions at the top of the range before a weekly-review load increase counts as routine.
    public static let topOfRangeSessionsForRoutine = 2
    public static let volumeMaxDelta = 4
    public static let deloadWeeks = 1...2
    /// A swap lasts 1 to 12 weeks before the original comes back, or 0 for good.
    public static let swapWeeks = 0...12
    /// Mid-workout: rest between 30 seconds and 10 minutes, and at least 1 rep.
    public static let restSeconds = 30...600
    public static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
}
