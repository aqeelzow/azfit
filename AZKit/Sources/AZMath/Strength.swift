import AZModel

/// Estimated one-rep max and the per-exercise numbers behind a session review.
public enum Strength {
    /// Epley's formula, counting reps in reserve as reps you could have done: load x (1 + (reps + RIR) / 30).
    public static func e1rm(loadKg: Double, reps: Int, rir: Double) -> Double {
        loadKg * (1 + (Double(reps) + rir) / 30)
    }

    public static func derive(_ s: SessionReport) -> SessionDerived {
        SessionDerived(
            exercises: s.exercises.map { e in
                let sets = e.performed
                let best = sets.map { e1rm(loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir) }.max() ?? 0
                let avgRir = sets.isEmpty ? 0 : sets.map(\.rir).reduce(0, +) / Double(sets.count)
                let last = e.e1rmHistory.last
                return SessionDerived.Exercise(
                    exercise: e.exercise,
                    setsDone: sets.count,
                    setsPrescribed: e.prescribed.sets,
                    bestE1rm: rounded(best),
                    e1rmChangePctVsLast: last.flatMap { $0 > 0 ? rounded((best - $0) / $0 * 100) : nil },
                    allSetsAtTopOfRange: sets.count >= e.prescribed.sets
                        && sets.allSatisfy { $0.reps >= e.prescribed.repMax && $0.loadKg >= e.prescribed.loadKg },
                    avgRir: rounded(avgRir),
                    rirVsPrescribed: rounded(avgRir - e.prescribed.rir)
                )
            }
        )
    }
}

extension Strength {
    /// The exercise in progress, set by set, so Div can see where the reps and RIR are heading.
    public static func derive(_ r: InWorkoutRequest) -> InWorkoutDerived {
        let p = r.prescribed
        let sets = r.done.map { s in
            InWorkoutDerived.SetCheck(
                reps: s.reps, loadKg: s.loadKg, repRange: s.reps < p.repMin ? "below" : s.reps >= p.repMax ? "top" : "in",
                rirVsPrescribed: rounded(s.rir - p.rir))
        }
        let e1rms = r.done.map { rounded(e1rm(loadKg: $0.loadKg, reps: $0.reps, rir: $0.rir)) }
        return InWorkoutDerived(
            setsDone: r.done.count, setsLeft: max(p.sets - r.done.count, 0), sets: sets, firstSetE1rm: e1rms.first, lastSetE1rm: e1rms.last)
    }
}
