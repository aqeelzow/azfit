import type { CheckedProposal, DerivedState, Goal, Proposal, ReviewOutput, WeeklySnapshot } from "./types.ts";

// Hard limits from the brief. Claude proposes; this file decides.
// Nothing here trusts the model: every rule is checked against the snapshot.

export const LIMITS = {
  calorieStepMin: 100,
  calorieStepMax: 200,
  /** Calorie changes at or above this size need the user's tap. */
  calorieApprovalThreshold: 150,
  protein: { cut: [2.0, 2.2], recomp: [1.8, 2.2], build: [1.6, 2.0] } as Record<Goal, [number, number]>,
  /** Auto-applied load increases: at most this % or 2.5 kg, whichever is larger. */
  loadAutoPct: 5,
  loadAutoKg: 2.5,
  loadMaxPct: 10,
  volumeMaxDelta: 4,
  deloadMaxWeeks: 2,
} as const;

function checkOne(p: Proposal, s: WeeklySnapshot, d: DerivedState): CheckedProposal {
  const reject = (...notes: string[]): CheckedProposal => ({ proposal: p, verdict: "rejected", notes });
  const approve = (...notes: string[]): CheckedProposal => ({ proposal: p, verdict: "needs_approval", notes });
  const auto = (...notes: string[]): CheckedProposal => ({ proposal: p, verdict: "auto_apply", notes });

  switch (p.type) {
    case "set_calorie_target": {
      const delta = p.new_kcal - s.targets.calories_kcal;
      const size = Math.abs(delta);
      if (!d.enough_complete_days) return reject(`Only ${s.intake.complete_days} complete days; need 10 to change calories.`);
      if (!d.calorie_change_allowed_by_time)
        return reject(`Last calorie change was ${s.days_since_last_calorie_change} days ago; minimum is 14.`);
      if (p.new_kcal < s.user.calorie_floor_kcal) return reject(`Below the calorie floor of ${s.user.calorie_floor_kcal}.`);
      if (size === 0) return reject("No change from the current target.");
      if (size > LIMITS.calorieStepMax) return reject(`Step of ${size} is over the ${LIMITS.calorieStepMax} limit.`);
      if (size < LIMITS.calorieStepMin) return reject(`Step of ${size} is under the ${LIMITS.calorieStepMin} minimum.`);
      if (delta < 0 && d.losing_too_fast) return reject("Already losing faster than 1% a week; calories can't go down.");
      if (s.water_events.length > 0 && !d.losing_too_fast)
        return reject(`Water event in the window (${s.water_events.map((w) => w.type).join(", ")}); extend the window instead.`);
      return size >= LIMITS.calorieApprovalThreshold ? approve() : auto();
    }

    case "set_protein_target": {
      if (s.user.kidney_disease) return reject("Protein is set by the user's doctor (kidney disease).");
      const [lo, hi] = LIMITS.protein[s.user.goal];
      if (p.grams_per_kg < lo || p.grams_per_kg > hi)
        return reject(`${p.grams_per_kg} g/kg is outside ${lo}–${hi} for a ${s.user.goal}.`);
      return approve();
    }

    case "set_load": {
      const current = s.current_loads.find((l) => l.exercise.toLowerCase() === p.exercise.toLowerCase());
      if (!current) return reject(`Unknown exercise "${p.exercise}".`);
      const delta = p.new_load_kg - current.load_kg;
      const pct = (Math.abs(delta) / current.load_kg) * 100;
      if (pct > LIMITS.loadMaxPct) return reject(`Change of ${pct.toFixed(1)}% is over the ${LIMITS.loadMaxPct}% limit.`);
      const routine =
        delta > 0 &&
        current.hit_top_of_range_sessions >= 2 &&
        (pct <= LIMITS.loadAutoPct || delta <= LIMITS.loadAutoKg);
      return routine ? auto("Routine progression.") : approve();
    }

    case "swap_exercise":
      return approve();

    case "change_volume": {
      if (Math.abs(p.delta_sets_per_week) > LIMITS.volumeMaxDelta)
        return reject(`Change of ${p.delta_sets_per_week} sets is over the ±${LIMITS.volumeMaxDelta} limit.`);
      const v = s.volume.find((m) => m.muscle.toLowerCase() === p.muscle.toLowerCase());
      if (v && v.sets_this_week + p.delta_sets_per_week > v.mrv)
        return reject(`Would put ${p.muscle} above its recoverable volume (${v.mrv} sets).`);
      return approve();
    }

    case "schedule_deload":
      if (p.weeks < 1 || p.weeks > LIMITS.deloadMaxWeeks) return reject(`Deload of ${p.weeks} weeks is out of range.`);
      return approve();
  }
}

export function checkReview(review: ReviewOutput, s: WeeklySnapshot, d: DerivedState): CheckedProposal[] {
  const checked = review.proposals.map((p) => checkOne(p, s, d));
  // At most one calorie change per review.
  let seenCalorie = false;
  for (const c of checked) {
    if (c.proposal.type !== "set_calorie_target" || c.verdict === "rejected") continue;
    if (seenCalorie) {
      c.verdict = "rejected";
      c.notes.push("Only one calorie change per review.");
    }
    seenCalorie = true;
  }
  return checked;
}
