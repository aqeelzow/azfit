import type { WeeklySnapshot } from "./types.ts";

// Checks that a snapshot from the phone has the fields the math depends on,
// so a bad request fails with a clear message instead of producing NaN.

const isNum = (v: unknown) => typeof v === "number" && Number.isFinite(v);

export function validateSnapshot(x: any): { ok: true; snapshot: WeeklySnapshot } | { ok: false; errors: string[] } {
  const errors: string[] = [];
  const need = (path: string, ok: boolean) => {
    if (!ok) errors.push(path);
  };
  if (typeof x !== "object" || x === null) return { ok: false, errors: ["body must be a JSON object"] };

  need("week_ending", typeof x.week_ending === "string");
  need("user.goal", ["cut", "recomp", "build"].includes(x.user?.goal));
  for (const k of ["age", "height_cm", "target_rate_pct_per_week", "calorie_floor_kcal"]) need(`user.${k}`, isNum(x.user?.[k]));
  need("user.kidney_disease", typeof x.user?.kidney_disease === "boolean");
  need("targets.calories_kcal", isNum(x.targets?.calories_kcal));
  need("targets.protein_g_per_kg", isNum(x.targets?.protein_g_per_kg));
  for (const k of ["trend_kg_now", "trend_kg_7d_ago", "trend_kg_window_start"]) need(`weight.${k}`, isNum(x.weight?.[k]) && x.weight[k] > 0);
  need("weight.daily_last_7", Array.isArray(x.weight?.daily_last_7) && x.weight.daily_last_7.every(isNum));
  need("intake.window_days", isNum(x.intake?.window_days) && x.intake.window_days > 0);
  for (const k of ["complete_days", "avg_kcal_complete_days", "protein_hit_days_last_7"]) need(`intake.${k}`, isNum(x.intake?.[k]));
  need("waist_cm", x.waist_cm === null || (isNum(x.waist_cm?.now) && isNum(x.waist_cm?.window_start)));
  need("lifts", Array.isArray(x.lifts) && x.lifts.every((l: any) => typeof l.name === "string" && isNum(l.e1rm_now) && isNum(l.e1rm_window_start) && l.e1rm_window_start > 0));
  need("volume", Array.isArray(x.volume) && x.volume.every((v: any) => typeof v.muscle === "string" && isNum(v.sets_this_week) && isNum(v.mev) && isNum(v.mrv)));
  for (const k of ["sleep_avg_h", "sleep_baseline_h", "hrv_vs_baseline_pct", "steps_avg", "steps_baseline"]) need(`recovery.${k}`, isNum(x.recovery?.[k]));
  need("water_events", Array.isArray(x.water_events));
  need("recent_changes", Array.isArray(x.recent_changes));
  need("days_since_last_calorie_change", isNum(x.days_since_last_calorie_change));
  need("current_loads", Array.isArray(x.current_loads) && x.current_loads.every((l: any) => typeof l.exercise === "string" && isNum(l.load_kg) && l.load_kg > 0));

  return errors.length ? { ok: false, errors: errors.map((e) => `missing or invalid: ${e}`) } : { ok: true, snapshot: x };
}
