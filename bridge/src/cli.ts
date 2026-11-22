import { readFile } from "node:fs/promises";
import { extname } from "node:path";
import { parseArgs } from "node:util";
import { runMeal, validateMeal } from "./meal.ts";
import { runReview } from "./review.ts";
import { runSession, validateSession } from "./session.ts";
import type { MealRequest, SessionRequest, WeeklySnapshot } from "./types.ts";

// Run a job from the Terminal, without the server.
//   npm run review  -- fixtures/reviews/recomp.json [--json]
//   npm run meal    -- photo.jpg [--note "half the rice"] [--plate 27] [--weight 450] [--json]
//   npm run session -- fixtures/sessions/push-day.json [--json]

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    json: { type: "boolean" },
    note: { type: "string" },
    plate: { type: "string" },
    weight: { type: "string" },
  },
});
const [command, file] = positionals;
const usage = "Usage: npm run review|meal|session -- <file> [options]";
if (!command || !file) {
  console.error(usage);
  process.exit(1);
}

const icon = { auto_apply: "✓ applied ", needs_approval: "? approve ", rejected: "✗ blocked " } as const;
const footer = (m: { model: string; duration_ms: number; cost_usd_equivalent: number | null }) =>
  `\n${m.model} · ${(m.duration_ms / 1000).toFixed(1)}s` +
  (m.cost_usd_equivalent != null ? ` · ~$${m.cost_usd_equivalent.toFixed(3)} at API prices (billed to your Claude plan)` : "");
const fail = (problems: string[]) => {
  console.error(problems.join("\n"));
  process.exit(1);
};

if (command === "review") {
  const fixture = JSON.parse(await readFile(file, "utf8"));
  const result = await runReview((fixture.snapshot ?? fixture) as WeeklySnapshot);
  if (values.json) console.log(JSON.stringify(result, null, 2));
  else {
    const r = result.review;
    console.log(`\n${r.summary}\n`);
    console.log(`Calories: ${r.calorie_action} (${r.calorie_reading})`);
    console.log(`  ${r.calorie_reasoning}\n`);
    for (const c of result.checked) {
      const { type, reason, evidence, ...args } = c.proposal;
      console.log(`${icon[c.verdict]} ${type} ${JSON.stringify(args)}`);
      console.log(`           ${reason}`);
      for (const n of c.notes) console.log(`           note: ${n}`);
    }
    if (result.checked.length === 0) console.log("No changes proposed.");
    for (const q of r.questions) console.log(`\nAsks: ${q}`);
    console.log(footer(result.meta));
  }
} else if (command === "meal") {
  const types: Record<string, MealRequest["media_type"]> = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };
  const req: MealRequest = {
    photo_base64: (await readFile(file)).toString("base64"),
    media_type: types[extname(file).toLowerCase()] ?? ("unknown" as MealRequest["media_type"]),
    ...(values.note ? { note: values.note } : {}),
    ...(values.plate ? { plate_diameter_cm: Number(values.plate) } : {}),
    ...(values.weight ? { food_weight_g: Number(values.weight) } : {}),
  };
  const problems = validateMeal(req);
  if (problems.length) fail(problems);
  const result = await runMeal(req);
  if (values.json) console.log(JSON.stringify(result, null, 2));
  else {
    const e = result.estimate;
    const t = result.totals;
    console.log(`\n${e.meal_name}  (${e.confidence} confidence)`);
    for (const i of e.items) {
      console.log(`  ${i.name.padEnd(28)} ${i.portion.padEnd(22)} ${String(Math.round(i.grams)).padStart(4)} g  ${String(Math.round(i.kcal)).padStart(4)} kcal  P${i.protein_g} C${i.carbs_g} F${i.fat_g}`);
    }
    console.log(`\nTotal: ${t.kcal} kcal (range ${e.kcal_low}–${e.kcal_high}) · protein ${t.protein_g} g · carbs ${t.carbs_g} g · fat ${t.fat_g} g`);
    if (e.matched_similar_meal) console.log(`Matched: ${e.matched_similar_meal}`);
    for (const a of e.assumptions) console.log(`Assumed: ${a}`);
    if (e.follow_up_question) console.log(`Asks: ${e.follow_up_question}`);
    for (const w of result.warnings) console.log(`Warning: ${w}`);
    console.log(footer(result.meta));
  }
} else if (command === "session") {
  const fixture = JSON.parse(await readFile(file, "utf8"));
  const req = (fixture.session ?? fixture) as SessionRequest;
  const problems = validateSession(req);
  if (problems.length) fail(problems);
  const result = await runSession(req);
  if (values.json) console.log(JSON.stringify(result, null, 2));
  else {
    console.log(`\n${result.output.note}\n`);
    for (const c of result.checked) {
      console.log(`${icon[c.verdict]} ${c.item.exercise}: ${c.item.call} → ${c.item.next_load_kg} kg`);
      console.log(`           ${c.item.reason}`);
      for (const n of c.notes) console.log(`           note: ${n}`);
    }
    console.log(footer(result.meta));
  }
} else {
  fail([usage]);
}
