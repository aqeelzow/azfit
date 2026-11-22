import { readFile } from "node:fs/promises";
import { runClaude } from "./claude.ts";
import type { MealEstimate, MealRequest, MealResult } from "./types.ts";

const root = new URL("../", import.meta.url);
const systemPrompt = await readFile(new URL("prompts/meal-estimate.md", root), "utf8");
const schema = JSON.parse(await readFile(new URL("schemas/meal.schema.json", root), "utf8"));

const EXT = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" } as const;
export const MAX_PHOTO_BYTES = 8 * 1024 * 1024;

const r1 = (n: number) => Math.round(n * 10) / 10;

export function validateMeal(x: any): string[] {
  const errors: string[] = [];
  if (typeof x !== "object" || x === null) return ["body must be a JSON object"];
  if (typeof x.photo_base64 !== "string" || x.photo_base64.length < 100) errors.push("photo_base64 is missing");
  else if (Buffer.byteLength(x.photo_base64, "base64") > MAX_PHOTO_BYTES) errors.push("photo is over 8 MB; resize it on the phone");
  if (!(x.media_type in EXT)) errors.push("media_type must be image/jpeg, image/png or image/webp");
  if (x.note !== undefined && typeof x.note !== "string") errors.push("note must be text");
  for (const k of ["plate_diameter_cm", "food_weight_g"]) {
    if (x[k] !== undefined && !(typeof x[k] === "number" && x[k] > 0)) errors.push(`${k} must be a positive number`);
  }
  if (x.similar_meals !== undefined && !Array.isArray(x.similar_meals)) errors.push("similar_meals must be a list");
  return errors;
}

/** Checks the model's numbers in code. Totals always come from adding up the items. */
export function checkMeal(e: MealEstimate, req: Pick<MealRequest, "food_weight_g">): MealResult["totals"] & { warnings: string[] } {
  const warnings: string[] = [];
  const sum = (k: "kcal" | "protein_g" | "carbs_g" | "fat_g") => e.items.reduce((a, i) => a + i[k], 0);
  const totals = { kcal: Math.round(sum("kcal")), protein_g: r1(sum("protein_g")), carbs_g: r1(sum("carbs_g")), fat_g: r1(sum("fat_g")) };

  for (const i of e.items) {
    const fromMacros = 4 * i.protein_g + 4 * i.carbs_g + 9 * i.fat_g;
    if (i.kcal > 50 && Math.abs(fromMacros - i.kcal) / i.kcal > 0.2) {
      warnings.push(`${i.name}: ${i.kcal} kcal doesn't match its macros (~${Math.round(fromMacros)} kcal).`);
    }
    if (i.grams > 0 && i.kcal / i.grams > 9.5) warnings.push(`${i.name}: more calories per gram than pure fat.`);
  }
  if (e.items.length && (totals.kcal < e.kcal_low * 0.9 || totals.kcal > e.kcal_high * 1.1)) {
    warnings.push(`Items add up to ${totals.kcal} kcal, outside the stated range ${e.kcal_low}–${e.kcal_high}.`);
  }
  if (req.food_weight_g) {
    const grams = e.items.reduce((a, i) => a + i.grams, 0);
    if (Math.abs(grams - req.food_weight_g) / req.food_weight_g > 0.1) {
      warnings.push(`Items weigh ${Math.round(grams)} g but the scale said ${req.food_weight_g} g.`);
    }
  }
  return { ...totals, warnings };
}

export async function runMeal(req: MealRequest): Promise<MealResult> {
  const file = `photo.${EXT[req.media_type]}`;
  const { photo_base64, media_type, ...context } = req;
  const userPrompt = [
    `Estimate the meal in ./${file}.`,
    "",
    "context:",
    JSON.stringify(context, null, 2),
  ].join("\n");

  const res = await runClaude<MealEstimate>({
    model: "haiku",
    systemPrompt,
    userPrompt,
    schema,
    tools: ["Read"],
    files: { [file]: Buffer.from(photo_base64, "base64") },
    timeoutMs: 120_000,
  });

  const { warnings, ...totals } = checkMeal(res.output, req);
  return {
    estimate: res.output,
    totals,
    warnings,
    meta: { model: res.model, duration_ms: res.duration_ms, cost_usd_equivalent: res.cost_usd_equivalent },
  };
}
