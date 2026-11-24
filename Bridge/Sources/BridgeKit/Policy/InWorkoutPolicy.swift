import AZModel

/// Decides Div's tweak to the next set. Mid-workout the person can't stop to approve much, so routine changes
/// apply (if "Reps, weight and rest" is on) and anything bigger is shown as a suggestion.
public enum InWorkoutPolicy {
    public static func check(_ out: InWorkoutOutput, request r: InWorkoutRequest, autonomy: Autonomy) -> Checked<InWorkoutOutput> {
        func verdict(_ v: Verdict, _ notes: String...) -> Checked<InWorkoutOutput> { Checked(item: out, verdict: v, notes: notes) }
        func routine(_ notes: String...) -> Checked<InWorkoutOutput> {
            autonomy.workoutTweaks
                ? Checked(item: out, verdict: .apply, notes: notes)
                : Checked(item: out, verdict: .propose, notes: notes + ["Set changes ask first in your settings."])
        }
        // The load the last set used, or the prescription before the first set.
        let current = r.done.last?.loadKg ?? r.prescribed.loadKg
        let delta = out.nextLoadKg - current
        let pct = current > 0 ? abs(delta) / current * 100 : 0

        if out.nextReps < 1 { return verdict(.refuse, "The next set needs at least 1 rep.") }
        if out.nextReps > r.prescribed.repMax + 2 {
            return verdict(.refuse, "\(out.nextReps) reps is well above the \(r.prescribed.repMax) planned.")
        }
        if !Limits.restSeconds.contains(out.restS) { return verdict(.refuse, "Rest of \(out.restS) s is outside 30 s to 10 min.") }

        switch out.call {
        case .keep:
            return delta == 0 ? verdict(.apply) : verdict(.refuse, "\"keep\" stays at \(number(current)) kg.")
        case .lowerReps:
            return delta == 0 ? routine() : verdict(.refuse, "\"lower_reps\" keeps the load at \(number(current)) kg.")
        case .lowerLoad:
            if delta >= 0 { return verdict(.refuse, "\"lower_load\" must lower the load.") }
            if pct > Limits.loadMaxDownPct {
                return verdict(.refuse, "-\(oneDecimal(pct))% is over the \(Int(Limits.loadMaxDownPct))% limit.")
            }
            return pct <= Limits.loadRoutineDownPct ? routine() : verdict(.propose, "Large drop for one set.")
        case .raiseLoad:
            if delta <= 0 { return verdict(.refuse, "\"raise_load\" must raise the load.") }
            if pct > Limits.loadMaxUpPct { return verdict(.refuse, "+\(oneDecimal(pct))% is over the \(Int(Limits.loadMaxUpPct))% limit.") }
            // Going heavier than planned mid-session is never automatic.
            return verdict(.propose, "Heavier than planned: your call.")
        case .stop:
            // Stopping is always the person's decision, but Div's reason is shown right away.
            return verdict(.propose, "Ending the exercise early is your call.")
        }
    }
}
