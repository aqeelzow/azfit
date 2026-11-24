import AZModel

/// Decides each of next time's loads after a workout.
public enum SessionPolicy {
    public static func check(
        _ output: SessionReviewOutput, session s: SessionReport, derived d: SessionDerived, autonomy: Autonomy
    )
        -> [Checked<NextTime>]
    {
        var checked = output.nextTime.map { check($0, session: s, derived: d, autonomy: autonomy) }
        // Any exercise Div left out keeps its load.
        for e in s.exercises where !checked.contains(where: { $0.item.exercise.lowercased() == e.exercise.lowercased() }) {
            let item = NextTime(exercise: e.exercise, call: .repeat, nextLoadKg: e.prescribed.loadKg, reason: "No change.")
            checked.append(Checked(item: item, verdict: .apply, notes: ["Not covered by Div; load kept."]))
        }
        return checked
    }

    static func check(_ item: NextTime, session s: SessionReport, derived d: SessionDerived, autonomy: Autonomy) -> Checked<NextTime> {
        func verdict(_ v: Verdict, _ notes: String...) -> Checked<NextTime> { Checked(item: item, verdict: v, notes: notes) }
        func routine(_ notes: String...) -> Checked<NextTime> {
            autonomy.workoutTweaks
                ? Checked(item: item, verdict: .apply, notes: notes)
                : Checked(item: item, verdict: .propose, notes: notes + ["Load changes ask first in your settings."])
        }
        let name = item.exercise.lowercased()
        guard let ex = s.exercises.first(where: { $0.exercise.lowercased() == name }),
            let dx = d.exercises.first(where: { $0.exercise.lowercased() == name })
        else { return verdict(.refuse, "\"\(item.exercise)\" wasn't in this session.") }

        let current = ex.prescribed.loadKg
        let delta = item.nextLoadKg - current
        let pct = abs(delta) / current * 100

        switch item.call {
        case .repeat:
            return delta == 0 ? verdict(.apply) : verdict(.refuse, "\"repeat\" keeps \(current) kg, not \(item.nextLoadKg) kg.")
        case .progress:
            if delta <= 0 { return verdict(.refuse, "\"progress\" must raise the load.") }
            if pct > Limits.loadMaxUpPct { return verdict(.refuse, "+\(oneDecimal(pct))% is over the \(Int(Limits.loadMaxUpPct))% limit.") }
            if dx.allSetsAtTopOfRange && (pct <= Limits.loadRoutinePct || delta <= Limits.loadRoutineKg) {
                return routine("Routine progression.")
            }
            return verdict(.propose, dx.allSetsAtTopOfRange ? "Bigger jump than routine." : "Not every set reached the top of the range.")
        case .reduce:
            if delta >= 0 { return verdict(.refuse, "\"reduce\" must lower the load.") }
            if pct > Limits.loadMaxDownPct {
                return verdict(.refuse, "-\(oneDecimal(pct))% is over the \(Int(Limits.loadMaxDownPct))% limit.")
            }
            return pct <= Limits.loadRoutineDownPct ? routine() : verdict(.propose, "Large reduction.")
        }
    }
}
