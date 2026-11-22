import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { checkMeal, validateMeal } from "../src/meal.ts";
import { checkSession, deriveSession, e1rm, validateSession } from "../src/session.ts";
import type { MealEstimate, SessionPlanItem, SessionRequest } from "../src/types.ts";

// No Claude calls: these check the code that sits around the model.

const meal = (items: MealEstimate["items"], low = 0, high = 9999): MealEstimate => ({
  meal_name: "Test", items, kcal_low: low, kcal_high: high, confidence: "medium",
  matched_similar_meal: "", assumptions: [], follow_up_question: "",
});
const rice = { name: "Rice", portion: "1 cup", grams: 200, kcal: 260, protein_g: 5, carbs_g: 57, fat_g: 0.6 };
const chicken = { name: "Chicken", portion: "1 breast", grams: 150, kcal: 248, protein_g: 46, carbs_g: 0, fat_g: 5.4 };

test("meal: totals are added up in code from the items", () => {
  const r = checkMeal(meal([rice, chicken], 450, 600), {});
  assert.equal(r.kcal, 508);
  assert.equal(r.protein_g, 51);
  assert.deepEqual(r.warnings, []);
});

test("meal: flags calories that don't match the macros", () => {
  const r = checkMeal(meal([{ ...rice, kcal: 600 }]), {});
  assert.ok(r.warnings.some((w) => w.includes("doesn't match its macros")));
});

test("meal: flags totals outside the stated range and a weight that disagrees with the scale", () => {
  const r = checkMeal(meal([rice, chicken], 800, 900), { food_weight_g: 500 });
  assert.ok(r.warnings.some((w) => w.includes("outside the stated range")));
  assert.ok(r.warnings.some((w) => w.includes("scale said 500 g")));
});

test("meal: request validation", () => {
  assert.ok(validateMeal({}).length > 0);
  assert.ok(validateMeal({ photo_base64: "x".repeat(200), media_type: "image/heic" }).some((e) => e.includes("media_type")));
  assert.deepEqual(validateMeal({ photo_base64: "x".repeat(200), media_type: "image/jpeg", plate_diameter_cm: 27 }), []);
  assert.ok(validateMeal({ photo_base64: "x".repeat(200), media_type: "image/jpeg", food_weight_g: -5 }).length > 0);
});

const push: SessionRequest = JSON.parse(
  readFileSync(new URL("../fixtures/sessions/push-day.json", import.meta.url), "utf8"),
).session;
const plan = (exercise: string, call: SessionPlanItem["call"], next_load_kg: number) => ({ exercise, call, next_load_kg, reason: "r" });

test("session: e1RM counts reps in reserve", () => {
  assert.equal(Math.round(e1rm(80, 10, 2) * 10) / 10, 112);
});

test("session: derive spots top-of-range and low RIR", () => {
  const d = deriveSession(push);
  const bench = d.exercises.find((e) => e.exercise === "Bench press")!;
  const ohp = d.exercises.find((e) => e.exercise === "Overhead press")!;
  assert.equal(bench.all_sets_at_top_of_range, true);
  assert.equal(bench.rir_vs_prescribed, 0);
  assert.equal(ohp.all_sets_at_top_of_range, false);
  assert.equal(ohp.rir_vs_prescribed, -2);
});

test("session: routine +2.5 kg applies, bigger or unearned jumps need approval, huge ones are blocked", () => {
  const d = deriveSession(push);
  const v = (p: SessionPlanItem) => checkSession({ note: "", next_time: [p] }, push, d)[0]!.verdict;
  assert.equal(v(plan("Bench press", "progress", 82.5)), "auto_apply");
  assert.equal(v(plan("Bench press", "progress", 87.5)), "needs_approval");
  assert.equal(v(plan("Bench press", "progress", 90)), "rejected");
  assert.equal(v(plan("Incline DB press", "progress", 32)), "needs_approval");
});

test("session: repeat must keep the load; reduce must lower it within limits", () => {
  const d = deriveSession(push);
  const v = (p: SessionPlanItem) => checkSession({ note: "", next_time: [p] }, push, d)[0]!.verdict;
  assert.equal(v(plan("Incline DB press", "repeat", 30)), "auto_apply");
  assert.equal(v(plan("Incline DB press", "repeat", 32)), "rejected");
  assert.equal(v(plan("Overhead press", "reduce", 47.5)), "auto_apply");
  assert.equal(v(plan("Overhead press", "reduce", 42.5)), "needs_approval");
  assert.equal(v(plan("Overhead press", "reduce", 35)), "rejected");
  assert.equal(v(plan("Overhead press", "reduce", 52.5)), "rejected");
  assert.equal(v(plan("Cable fly", "repeat", 20)), "rejected");
});

test("session: request validation", () => {
  assert.deepEqual(validateSession(push), []);
  assert.ok(validateSession({ date: "x", session_name: "y", exercises: [] }).length > 0);
  assert.ok(validateSession({ ...push, exercises: [{ exercise: "Bench" }] }).length > 0);
});
