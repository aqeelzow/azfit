import type { DerivedState, WeeklySnapshot } from "./types.ts";

export const KCAL_PER_KG = 7700;
export const MIN_COMPLETE_DAYS = 10;
/** Below this weekly change (% of body weight) the scale counts as flat. */
const SCALE_FLAT_PCT = 0.15;
const WAIST_FLAT_CM = 0.5;
const STRENGTH_FLAT_PCT = 1.5;

const round = (n: number, dp = 1) => Math.round(n * 10 ** dp) / 10 ** dp;

function direction(value: number, flatBand: number): "up" | "flat" | "down" {
  if (value > flatBand) return "up";
  if (value < -flatBand) return "down";
  return "flat";
}

/** All the arithmetic, done in code so the model only has to judge. */
export function derive(s: WeeklySnapshot): DerivedState {
  const days = s.intake.window_days;
  const trendChange = s.weight.trend_kg_now - s.weight.trend_kg_window_start;
  const weeklyKg = (trendChange / days) * 7;
  const weeklyPct = (weeklyKg / s.weight.trend_kg_now) * 100;

  const enough = s.intake.complete_days >= MIN_COMPLETE_DAYS;
  const maintenance = enough
    ? s.intake.avg_kcal_complete_days - (trendChange * KCAL_PER_KG) / days
    : null;

  const lift_changes_pct = s.lifts.map((l) => ({
    name: l.name,
    change_pct: round(((l.e1rm_now - l.e1rm_window_start) / l.e1rm_window_start) * 100),
  }));
  const avgLift =
    lift_changes_pct.length === 0
      ? 0
      : lift_changes_pct.reduce((a, l) => a + l.change_pct, 0) / lift_changes_pct.length;

  const waistChange = s.waist_cm ? s.waist_cm.now - s.waist_cm.window_start : null;
  const daily = s.weight.daily_last_7;
  const rawJump = daily.length >= 2 ? daily[daily.length - 1]! - daily[0]! : 0;
  const losingTooFast = weeklyPct < -1;

  return {
    weekly_rate_pct: round(weeklyPct, 2),
    weekly_rate_kg: round(weeklyKg, 2),
    implied_maintenance_kcal: maintenance === null ? null : Math.round(maintenance / 10) * 10,
    enough_complete_days: enough,
    waist_change_cm: waistChange === null ? null : round(waistChange),
    lift_changes_pct,
    strength_direction: direction(avgLift, STRENGTH_FLAT_PCT),
    scale_direction: direction(weeklyPct, SCALE_FLAT_PCT),
    waist_direction: waistChange === null ? "unknown" : direction(waistChange, WAIST_FLAT_CM),
    raw_weight_jump_kg_7d: round(rawJump),
    losing_too_fast: losingTooFast,
    calorie_change_allowed_by_time: s.days_since_last_calorie_change >= 14 || losingTooFast,
    protein_target_g: Math.round(s.targets.protein_g_per_kg * s.weight.trend_kg_now),
    volume_status: s.volume.map((v) => ({
      muscle: v.muscle,
      sets: v.sets_this_week,
      status: v.sets_this_week < v.mev ? "below_mev" : v.sets_this_week > v.mrv ? "above_mrv" : "in_range",
    })),
  };
}
