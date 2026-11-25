import AZMath
import AZModel

/// What the policy needs to know about the person's plan to check a change. Built from a weekly snapshot or from
/// the data behind chat, so the same rules apply to changes from either.
public struct PlanContext: Sendable {
    public struct Load: Sendable {
        public var loadKg: Double
        public var hitTopOfRangeSessions: Int
    }

    /// Which job the changes came from. Only the weekly review may move calories or protein.
    public var job: DivJob
    public var goal: Goal
    public var kidneyDisease: Bool
    public var caloriesKcal: Int
    public var calorieFloorKcal: Int
    public var completeDays: Int?
    public var enoughCompleteDays: Bool
    public var calorieChangeAllowedByTime: Bool
    public var daysSinceLastCalorieChange: Int?
    public var losingTooFast: Bool
    public var waterEvents: [String]
    /// Current working loads by exercise name, lowercased.
    public var loads: [String: Load]
    /// Weekly sets and maximum recoverable volume by muscle, lowercased.
    public var volume: [String: (sets: Int, mrv: Int)]
    /// Session names in the plan, lowercased. Nil when the job's data doesn't include the plan.
    public var sessions: Set<String>?

    public init(weekly s: WeeklySnapshot, derived d: WeeklyDerived) {
        job = .weeklyReview
        goal = s.user.goal
        kidneyDisease = s.user.kidneyDisease
        caloriesKcal = s.targets.caloriesKcal
        calorieFloorKcal = s.user.calorieFloorKcal
        completeDays = s.intake.completeDays
        enoughCompleteDays = d.enoughCompleteDays
        calorieChangeAllowedByTime = d.calorieChangeAllowedByTime
        daysSinceLastCalorieChange = s.daysSinceLastCalorieChange
        losingTooFast = d.losingTooFast
        waterEvents = s.waterEvents.map(\.type)
        loads = Dictionary(
            s.currentLoads.map { ($0.exercise.lowercased(), Load(loadKg: $0.loadKg, hitTopOfRangeSessions: $0.hitTopOfRangeSessions)) },
            uniquingKeysWith: { first, _ in first })
        volume = Dictionary(
            s.volume.map { ($0.muscle.lowercased(), (sets: $0.setsThisWeek, mrv: $0.mrv)) }, uniquingKeysWith: { first, _ in first })
        sessions = nil
    }

    public init(chat data: DivData) {
        job = .chat
        goal = data.profile.goal
        kidneyDisease = data.profile.kidneyDisease
        caloriesKcal = data.profile.caloriesKcal
        calorieFloorKcal = data.profile.calorieFloorKcal
        completeDays = nil
        enoughCompleteDays = false
        calorieChangeAllowedByTime = false
        daysSinceLastCalorieChange = nil
        losingTooFast = false
        waterEvents = []
        var loads: [String: Load] = [:]
        for exercise in data.plan.flatMap(\.exercises) where loads[exercise.exercise.lowercased()] == nil {
            loads[exercise.exercise.lowercased()] = Load(
                loadKg: exercise.loadKg, hitTopOfRangeSessions: exercise.hitTopOfRangeSessions ?? 0)
        }
        self.loads = loads
        volume = [:]
        sessions = Set(data.plan.map { $0.name.lowercased() })
    }
}

/// Decides each change Div returns: apply, propose (ask first) or refuse (D-009). Hard limits refuse; the
/// person's autonomy switches choose between applying and asking; structural changes always ask.
public enum ChangePolicy {
    public static func check(_ changes: [Proposal], context: PlanContext, autonomy: Autonomy) -> [Checked<Proposal>] {
        var checked = changes.map { check($0, context: context, autonomy: autonomy) }
        // At most one calorie change per review.
        var seenCalorie = false
        for i in checked.indices {
            guard case .setCalorieTarget = checked[i].item.change, checked[i].verdict != .refuse else { continue }
            if seenCalorie {
                checked[i].verdict = .refuse
                checked[i].notes.append("Only one calorie change per review.")
            }
            seenCalorie = true
        }
        return checked
    }

    static func check(_ p: Proposal, context c: PlanContext, autonomy: Autonomy) -> Checked<Proposal> {
        func refuse(_ note: String) -> Checked<Proposal> { Checked(item: p, verdict: .refuse, notes: [note]) }
        func propose(_ notes: String...) -> Checked<Proposal> { Checked(item: p, verdict: .propose, notes: notes) }
        func apply(_ notes: String...) -> Checked<Proposal> { Checked(item: p, verdict: .apply, notes: notes) }

        switch p.change {
        case .setCalorieTarget(let newKcal):
            guard c.job == .weeklyReview else { return refuse("Only the Sunday review changes calories.") }
            let delta = newKcal - c.caloriesKcal
            let size = abs(delta)
            if !c.enoughCompleteDays { return refuse("Only \(c.completeDays ?? 0) complete days; calories need 10 to move.") }
            if !c.calorieChangeAllowedByTime {
                return refuse("The last calorie change was \(c.daysSinceLastCalorieChange ?? 0) days ago; the minimum is 14.")
            }
            if newKcal < c.calorieFloorKcal { return refuse("Below the calorie floor of \(c.calorieFloorKcal).") }
            if size == 0 { return refuse("No change from the current target.") }
            if !Limits.calorieStep.contains(size) {
                return refuse("A step of \(size) kcal is outside \(Limits.calorieStep.lowerBound) to \(Limits.calorieStep.upperBound).")
            }
            if size % Limits.calorieStepMultiple != 0 { return refuse("A step of \(size) kcal isn't a multiple of 50.") }
            if delta < 0 && c.losingTooFast { return refuse("Already losing over 1% a week; calories can't go down.") }
            if !c.waterEvents.isEmpty && !c.losingTooFast {
                return refuse("Water event in the window (\(c.waterEvents.joined(separator: ", "))); the window is extended instead.")
            }
            return propose("Calorie changes always ask first (D-012).")

        case .setProteinTarget(let gramsPerKg):
            guard c.job == .weeklyReview else { return refuse("Only the Sunday review changes protein.") }
            if c.kidneyDisease { return refuse("Protein is set by your doctor.") }
            let range = WeeklyMath.proteinRange(for: c.goal)
            if !range.contains(gramsPerKg) {
                return refuse("\(gramsPerKg) g/kg is outside \(range.lowerBound) to \(range.upperBound) for a \(c.goal.rawValue).")
            }
            return propose()

        case .setLoad(let exercise, let newLoadKg):
            guard let current = c.loads[exercise.lowercased()] else { return refuse("\"\(exercise)\" isn't in the plan.") }
            let delta = newLoadKg - current.loadKg
            let pct = current.loadKg > 0 ? abs(delta) / current.loadKg * 100 : 100
            if delta == 0 { return refuse("No change from \(current.loadKg) kg.") }
            if pct > Limits.loadMaxUpPct {
                return refuse("A change of \(oneDecimal(pct))% is over the \(Int(Limits.loadMaxUpPct))% limit.")
            }
            let routine =
                delta > 0 && current.hitTopOfRangeSessions >= Limits.topOfRangeSessionsForRoutine
                && (pct <= Limits.loadRoutinePct || delta <= Limits.loadRoutineKg)
            if !routine { return propose() }
            return autonomy.workoutTweaks ? apply("Routine progression.") : propose("Load changes ask first in your settings.")

        case .swapExercise(let from, let to, let weeks):
            if from.lowercased() == to.lowercased() { return refuse("Swapping \"\(from)\" for itself.") }
            if c.loads[from.lowercased()] == nil { return refuse("\"\(from)\" isn't in the plan.") }
            if !Limits.swapWeeks.contains(weeks) {
                return refuse("A swap of \(weeks) weeks is outside 0 to \(Limits.swapWeeks.upperBound).")
            }
            return autonomy.swaps ? apply() : propose("Swaps ask first in your settings.")

        case .moveSession(let session, let toDay, _):
            guard Limits.weekdays.contains(where: { $0.lowercased() == toDay.lowercased() }) else {
                return refuse("\"\(toDay)\" isn't a day of the week.")
            }
            guard let sessions = c.sessions else { return propose() }
            if !sessions.contains(session.lowercased()) { return refuse("\"\(session)\" isn't in the plan.") }
            return autonomy.moves ? apply() : propose("Moves ask first in your settings.")

        case .changeVolume(let muscle, let delta):
            if delta == 0 || abs(delta) > Limits.volumeMaxDelta {
                return refuse("A change of \(delta) sets is outside 1 to \(Limits.volumeMaxDelta) either way.")
            }
            if let v = c.volume[muscle.lowercased()], v.sets + delta > v.mrv {
                return refuse("That would put \(muscle) above the \(v.mrv) sets a week it can recover from.")
            }
            return propose()

        case .scheduleDeload(let startDate, let weeks):
            if !Limits.deloadWeeks.contains(weeks) { return refuse("A deload of \(weeks) weeks is out of range.") }
            if !isDate(startDate) { return refuse("\"\(startDate)\" isn't a date.") }
            return propose()
        }
    }
}

func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }

/// YYYY-MM-DD.
func isDate(_ s: String) -> Bool {
    s.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
}
