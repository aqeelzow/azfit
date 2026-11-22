import { readFile } from "node:fs/promises";
import { runClaude } from "./claude.ts";
import { derive } from "./derive.ts";
import { checkReview } from "./guardrails.ts";
import type { ReviewOutput, ReviewResult, WeeklySnapshot } from "./types.ts";

const root = new URL("../", import.meta.url);
const systemPrompt = await readFile(new URL("prompts/sunday-review.md", root), "utf8");
const schema = JSON.parse(await readFile(new URL("schemas/review.schema.json", root), "utf8"));

/** The Sunday review: derive numbers in code, ask Opus to judge, check its proposals in code. */
export async function runReview(snapshot: WeeklySnapshot): Promise<ReviewResult> {
  const derived = derive(snapshot);
  const userPrompt = [
    "Here is this week's data. Write the Sunday review.",
    "",
    "snapshot:",
    JSON.stringify(snapshot, null, 2),
    "",
    "derived:",
    JSON.stringify(derived, null, 2),
  ].join("\n");

  const res = await runClaude<ReviewOutput>({
    model: "opus",
    effort: "medium",
    systemPrompt,
    userPrompt,
    schema,
  });

  return {
    derived,
    review: res.output,
    checked: checkReview(res.output, snapshot, derived),
    meta: { model: res.model, duration_ms: res.duration_ms, cost_usd_equivalent: res.cost_usd_equivalent },
  };
}
