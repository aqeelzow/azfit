import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { derive } from "../src/derive.ts";
import { checkReview } from "../src/guardrails.ts";
import type { Proposal, ReviewOutput, WeeklySnapshot } from "../src/types.ts";

const load = (name: string): WeeklySnapshot =>
  JSON.parse(readFileSync(new URL(`../fixtures/reviews/${name}.json`, import.meta.url), "utf8")).snapshot;

const ev = { reason: "r", evidence: [] };
function verdicts(s: WeeklySnapshot, ...proposals: Proposal[]) {
  const review: ReviewOutput = {
    summary: "", calorie_reading: "on_track", calorie_action: "hold", calorie_reasoning: "", proposals, questions: [],
  };
  return checkReview(review, s, derive(s)).map((c) => c.verdict);
}

test("derive: recomp reads flat scale, waist down, strength up", () => {
  const d = derive(load("recomp"));
  assert.equal(d.scale_direction, "flat");
  assert.equal(d.waist_direction, "down");
  assert.equal(d.strength_direction, "up");
});

test("derive: implied maintenance uses trend change × 7700 / days", () => {
  const d = derive(load("surplus-too-big"));
  // 2900 − (1.4 × 7700) / 21 = 2386.7 → 2390
  assert.equal(d.implied_maintenance_kcal, 2390);
});

test("derive: losing over 1% a week is flagged and lifts the 14-day wait", () => {
  const d = derive(load("deficit-too-steep"));
  assert.ok(d.losing_too_fast);
  assert.ok(d.calorie_change_allowed_by_time);
});

test("calories: a 200 kcal cut on a valid week needs approval; 100 applies alone", () => {
  const s = load("surplus-too-big");
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 2700, ...ev }), ["needs_approval"]);
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 2800, ...ev }), ["auto_apply"]);
});

test("calories: steps over 200 or under the floor are blocked", () => {
  const s = load("surplus-too-big");
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 2600, ...ev }), ["rejected"]);
  const cut = load("deficit-too-steep");
  assert.deepEqual(verdicts(cut, { type: "set_calorie_target", new_kcal: 1650, ...ev }), ["rejected"]);
});

test("calories: blocked with too few complete days, a water event, or too soon", () => {
  assert.deepEqual(verdicts(load("insufficient-data"), { type: "set_calorie_target", new_kcal: 1850, ...ev }), ["rejected"]);
  assert.deepEqual(verdicts(load("water"), { type: "set_calorie_target", new_kcal: 2200, ...ev }), ["rejected"]);
  const s = { ...load("surplus-too-big"), days_since_last_calorie_change: 7 };
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 2700, ...ev }), ["rejected"]);
});

test("calories: can't cut further while losing too fast, but can add food", () => {
  const s = load("deficit-too-steep");
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 1750, ...ev }), ["rejected"]);
  assert.deepEqual(verdicts(s, { type: "set_calorie_target", new_kcal: 2100, ...ev }), ["needs_approval"]);
});

test("calories: only one calorie change per review", () => {
  const s = load("surplus-too-big");
  assert.deepEqual(
    verdicts(s, { type: "set_calorie_target", new_kcal: 2700, ...ev }, { type: "set_calorie_target", new_kcal: 2750, ...ev }),
    ["needs_approval", "rejected"],
  );
});

test("protein: range depends on goal, and kidney disease blocks changes", () => {
  const s = load("recomp");
  assert.deepEqual(verdicts(s, { type: "set_protein_target", grams_per_kg: 2.0, ...ev }), ["needs_approval"]);
  assert.deepEqual(verdicts(s, { type: "set_protein_target", grams_per_kg: 2.6, ...ev }), ["rejected"]);
  const k = { ...s, user: { ...s.user, kidney_disease: true } };
  assert.deepEqual(verdicts(k, { type: "set_protein_target", grams_per_kg: 2.0, ...ev }), ["rejected"]);
});

test("loads: routine +2.5 kg applies alone; big jumps and unknown lifts are blocked", () => {
  const s = load("recomp");
  assert.deepEqual(verdicts(s, { type: "set_load", exercise: "Bench press", new_load_kg: 82.5, ...ev }), ["auto_apply"]);
  assert.deepEqual(verdicts(s, { type: "set_load", exercise: "Back squat", new_load_kg: 115, ...ev }), ["needs_approval"]);
  assert.deepEqual(verdicts(s, { type: "set_load", exercise: "Bench press", new_load_kg: 92.5, ...ev }), ["rejected"]);
  assert.deepEqual(verdicts(s, { type: "set_load", exercise: "Cable fly", new_load_kg: 20, ...ev }), ["rejected"]);
});

test("volume: capped at ±4 sets and at the muscle's recoverable volume", () => {
  const s = load("recomp");
  assert.deepEqual(verdicts(s, { type: "change_volume", muscle: "Rear delts", delta_sets_per_week: 2, ...ev }), ["needs_approval"]);
  assert.deepEqual(verdicts(s, { type: "change_volume", muscle: "Rear delts", delta_sets_per_week: 6, ...ev }), ["rejected"]);
  assert.deepEqual(verdicts(s, { type: "change_volume", muscle: "Hamstrings", delta_sets_per_week: 4, ...ev }), ["needs_approval"]);
  assert.deepEqual(
    verdicts({ ...s, volume: [{ muscle: "Chest", sets_this_week: 18, mev: 10, mrv: 20 }] },
      { type: "change_volume", muscle: "Chest", delta_sets_per_week: 4, ...ev }),
    ["rejected"],
  );
});
