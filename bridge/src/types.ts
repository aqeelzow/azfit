// Shapes shared by the phone, the bridge and Claude.
// The phone sends a WeeklySnapshot; the bridge derives the numbers in derive.ts,
// asks Claude for a ReviewOutput, then guardrails.ts decides what may apply.

export type Goal = "cut" | "recomp" | "build";

export interface WeeklySnapshot {
  week_ending: string; // YYYY-MM-DD
  user: {
    age: number;
    height_cm: number;
    goal: Goal;
    /** Target change in body weight per week, as % of body weight. Negative for a cut. */
    target_rate_pct_per_week: number;
    calorie_floor_kcal: number;
    kidney_disease: boolean;
  };
  targets: {
    calories_kcal: number;
    protein_g_per_kg: number;
  };
  weight: {
    /** Smoothed trend weight (each weigh-in counts ~10%). */
    trend_kg_now: number;
    trend_kg_7d_ago: number;
    trend_kg_window_start: number;
    /** Raw daily weigh-ins for the last 7 days, oldest first. */
    daily_last_7: number[];
  };
  intake: {
    window_days: number; // 14 to 21
    complete_days: number;
    avg_kcal_complete_days: number;
    protein_hit_days_last_7: number;
  };
  waist_cm: { now: number; window_start: number } | null;
  lifts: Array<{ name: string; e1rm_now: number; e1rm_window_start: number; avg_rir: number }>;
  volume: Array<{ muscle: string; sets_this_week: number; mev: number; mrv: number }>;
  recovery: {
    sleep_avg_h: number;
    sleep_baseline_h: number;
    hrv_vs_baseline_pct: number;
    steps_avg: number;
    steps_baseline: number;
  };
  water_events: Array<{ type: string; started: string }>;
  recent_changes: Array<{ date: string; type: string; detail: string; reason: string }>;
  days_since_last_calorie_change: number;
  current_loads: Array<{ exercise: string; load_kg: number; rep_range: string; hit_top_of_range_sessions: number }>;
}

/** Numbers computed in code so Claude never has to do arithmetic. */
export interface DerivedState {
  weekly_rate_pct: number;
  weekly_rate_kg: number;
  implied_maintenance_kcal: number | null;
  enough_complete_days: boolean;
  waist_change_cm: number | null;
  lift_changes_pct: Array<{ name: string; change_pct: number }>;
  strength_direction: "up" | "flat" | "down";
  scale_direction: "up" | "flat" | "down";
  waist_direction: "up" | "flat" | "down" | "unknown";
  raw_weight_jump_kg_7d: number;
  losing_too_fast: boolean;
  calorie_change_allowed_by_time: boolean;
  protein_target_g: number;
  volume_status: Array<{ muscle: string; sets: number; status: "below_mev" | "in_range" | "above_mrv" }>;
}

export type CalorieReading =
  | "recomposition"
  | "surplus_too_big"
  | "lean_gain"
  | "deficit_too_steep"
  | "water"
  | "on_track"
  | "off_track_watching"
  | "insufficient_data";

export type Proposal =
  | { type: "set_calorie_target"; new_kcal: number; reason: string; evidence: string[] }
  | { type: "set_protein_target"; grams_per_kg: number; reason: string; evidence: string[] }
  | { type: "set_load"; exercise: string; new_load_kg: number; reason: string; evidence: string[] }
  | { type: "swap_exercise"; from: string; to: string; reason: string; evidence: string[] }
  | { type: "change_volume"; muscle: string; delta_sets_per_week: number; reason: string; evidence: string[] }
  | { type: "schedule_deload"; start_date: string; weeks: number; reason: string; evidence: string[] };

export interface ReviewOutput {
  summary: string;
  calorie_reading: CalorieReading;
  calorie_action: "hold" | "decrease" | "increase";
  calorie_reasoning: string;
  proposals: Proposal[];
  questions: string[];
}

export type Verdict = "auto_apply" | "needs_approval" | "rejected";

export interface CheckedProposal {
  proposal: Proposal;
  verdict: Verdict;
  notes: string[];
}

export interface ReviewResult {
  derived: DerivedState;
  review: ReviewOutput;
  checked: CheckedProposal[];
  meta: { model: string; duration_ms: number; cost_usd_equivalent: number | null };
}

// ── Meal photo estimate ─────────────────────────────────────────────

export interface MealRequest {
  /** JPEG, PNG or WebP, base64-encoded. The phone converts HEIC before sending. */
  photo_base64: string;
  media_type: "image/jpeg" | "image/png" | "image/webp";
  /** What the user typed, e.g. "chicken shawarma plate, half the rice". */
  note?: string;
  /** Measured once in settings; used as the ruler in the photo. */
  plate_diameter_cm?: number;
  /** From a kitchen scale, food only. The most accurate input there is. */
  food_weight_g?: number;
  meal_time?: string;
  /** Favorites and recent meals, so the same meal is logged the same way. */
  similar_meals?: Array<{ name: string; kcal: number; protein_g: number; carbs_g: number; fat_g: number; logged_times: number }>;
}

export interface MealItem {
  name: string;
  portion: string;
  grams: number;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface MealEstimate {
  meal_name: string;
  items: MealItem[];
  kcal_low: number;
  kcal_high: number;
  confidence: "low" | "medium" | "high";
  matched_similar_meal: string;
  assumptions: string[];
  follow_up_question: string;
}

export interface MealResult {
  estimate: MealEstimate;
  /** Totals added up in code from the items, never taken from the model. */
  totals: { kcal: number; protein_g: number; carbs_g: number; fat_g: number };
  warnings: string[];
  meta: { model: string; duration_ms: number; cost_usd_equivalent: number | null };
}

// ── Post-workout session note ───────────────────────────────────────

export interface SessionRequest {
  date: string;
  session_name: string;
  exercises: Array<{
    exercise: string;
    prescribed: { sets: number; rep_min: number; rep_max: number; rir: number; load_kg: number };
    performed: Array<{ load_kg: number; reps: number; rir: number }>;
    /** Best e1RM from each of the last few sessions, oldest first. */
    e1rm_history: number[];
  }>;
  sleep_last_night_h?: number;
  soreness_1_to_5?: number;
  user_note?: string;
}

export interface SessionDerived {
  exercises: Array<{
    exercise: string;
    sets_done: number;
    sets_prescribed: number;
    best_e1rm: number;
    e1rm_change_pct_vs_last: number | null;
    all_sets_at_top_of_range: boolean;
    avg_rir: number;
    rir_vs_prescribed: number;
  }>;
}

export interface SessionPlanItem {
  exercise: string;
  call: "progress" | "repeat" | "reduce";
  next_load_kg: number;
  reason: string;
}

export interface SessionOutput {
  note: string;
  next_time: SessionPlanItem[];
}

export interface CheckedSessionItem {
  item: SessionPlanItem;
  verdict: Verdict;
  notes: string[];
}

export interface SessionResult {
  derived: SessionDerived;
  output: SessionOutput;
  checked: CheckedSessionItem[];
  meta: { model: string; duration_ms: number; cost_usd_equivalent: number | null };
}
