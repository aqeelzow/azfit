import { readFile } from "node:fs/promises";
import { runClaude } from "./claude.ts";
import type { CheckedSessionItem, SessionDerived, SessionOutput, SessionRequest, SessionResult, Verdict } from "./types.ts";

const root = new URL("../", import.meta.url);
const systemPrompt = await readFile(new URL("prompts/session-note.md", root), "utf8");
const schema = JSON.parse(await readFile(new URL("schemas/session.schema.json", root), "utf8"));

const r1 = (n: number) => Math.round(n * 10) / 10;
const isNum = (v: unknown) => typeof v === "number" && Number.isFinite(v);

/** Epley-style e1RM counting reps in reserve: load × (1 + (reps + RIR) / 30). */
export const e1rm = (load: number, reps: number, rir: number) => load * (1 + (reps + rir) / 30);

export const LOAD_LIMITS = { autoPct: 5, autoKg: 2.5, maxUpPct: 10, maxDownPct: 20, autoDownPct: 10 } as const;

export function validateSession(x: any): string[] {
  if (typeof x !== "object" || x === null) return ["body must be a JSON object"];
  const errors: string[] = [];
  if (typeof x.date !== "string") errors.push("date is missing");
  if (typeof x.session_name !== "string") errors.push("session_name is missing");
  if (!Array.isArray(x.exercises) || x.exercises.length === 0) return [...errors, "exercises must be a non-empty list"];
  x.exercises.forEach((e: any, i: number) => {
    const p = e?.prescribed;
    if (typeof e?.exercise !== "string") errors.push(`exercises[${i}].exercise is missing`);
    if (!p || !["sets", "rep_min", "rep_max", "rir", "load_kg"].every((k) => isNum(p[k])) || p.load_kg <= 0 || p.rep_min > p.rep_max)
      errors.push(`exercises[${i}].prescribed is incomplete`);
    if (!Array.isArray(e?.performed) || !e.performed.every((s: any) => isNum(s.load_kg) && isNum(s.reps) && isNum(s.rir)))
      errors.push(`exercises[${i}].performed must be a list of { load_kg, reps, rir }`);
    if (!Array.isArray(e?.e1rm_history) || !e.e1rm_history.every(isNum)) errors.push(`exercises[${i}].e1rm_history must be a list of numbers`);
  });
  return errors;
}

export function deriveSession(s: SessionRequest): SessionDerived {
  return {
    exercises: s.exercises.map((e) => {
      const sets = e.performed;
      const best = sets.length ? Math.max(...sets.map((x) => e1rm(x.load_kg, x.reps, x.rir))) : 0;
      const last = e.e1rm_history.at(-1);
      const avgRir = sets.length ? sets.reduce((a, x) => a + x.rir, 0) / sets.length : 0;
      return {
        exercise: e.exercise,
        sets_done: sets.length,
        sets_prescribed: e.prescribed.sets,
        best_e1rm: r1(best),
        e1rm_change_pct_vs_last: last ? r1(((best - last) / last) * 100) : null,
        all_sets_at_top_of_range:
          sets.length >= e.prescribed.sets && sets.every((x) => x.reps >= e.prescribed.rep_max && x.load_kg >= e.prescribed.load_kg),
        avg_rir: r1(avgRir),
        rir_vs_prescribed: r1(avgRir - e.prescribed.rir),
      };
    }),
  };
}

/** Code decides what each next-time load is allowed to be. */
export function checkSession(out: SessionOutput, s: SessionRequest, d: SessionDerived): CheckedSessionItem[] {
  return out.next_time.map((item) => {
    const verdict = (v: Verdict, ...notes: string[]): CheckedSessionItem => ({ item, verdict: v, notes });
    const ex = s.exercises.find((e) => e.exercise.toLowerCase() === item.exercise.toLowerCase());
    const dx = d.exercises.find((e) => e.exercise.toLowerCase() === item.exercise.toLowerCase());
    if (!ex || !dx) return verdict("rejected", `"${item.exercise}" wasn't in this session.`);

    const current = ex.prescribed.load_kg;
    const delta = item.next_load_kg - current;
    const pct = (Math.abs(delta) / current) * 100;

    switch (item.call) {
      case "repeat":
        return delta === 0 ? verdict("auto_apply") : verdict("rejected", `"repeat" must keep ${current} kg, not ${item.next_load_kg} kg.`);
      case "progress":
        if (delta <= 0) return verdict("rejected", "\"progress\" must increase the load.");
        if (pct > LOAD_LIMITS.maxUpPct) return verdict("rejected", `+${pct.toFixed(1)}% is over the ${LOAD_LIMITS.maxUpPct}% limit.`);
        if (dx.all_sets_at_top_of_range && (pct <= LOAD_LIMITS.autoPct || delta <= LOAD_LIMITS.autoKg))
          return verdict("auto_apply", "Routine progression.");
        return verdict("needs_approval", dx.all_sets_at_top_of_range ? "Bigger jump than routine." : "Not every set reached the top of the range.");
      case "reduce":
        if (delta >= 0) return verdict("rejected", "\"reduce\" must lower the load.");
        if (pct > LOAD_LIMITS.maxDownPct) return verdict("rejected", `−${pct.toFixed(1)}% is over the ${LOAD_LIMITS.maxDownPct}% limit.`);
        return pct <= LOAD_LIMITS.autoDownPct ? verdict("auto_apply") : verdict("needs_approval", "Large reduction.");
    }
  });
}

export async function runSession(s: SessionRequest): Promise<SessionResult> {
  const derived = deriveSession(s);
  const userPrompt = [
    "Here is the workout that just finished. Write the note and set next time's loads.",
    "",
    "session:",
    JSON.stringify(s, null, 2),
    "",
    "derived:",
    JSON.stringify(derived, null, 2),
  ].join("\n");

  const res = await runClaude<SessionOutput>({ model: "sonnet", effort: "low", systemPrompt, userPrompt, schema, timeoutMs: 120_000 });

  // Any exercise the model left out simply keeps its load.
  const checked = checkSession(res.output, s, derived);
  for (const e of s.exercises) {
    if (!checked.some((c) => c.item.exercise.toLowerCase() === e.exercise.toLowerCase())) {
      checked.push({
        item: { exercise: e.exercise, call: "repeat", next_load_kg: e.prescribed.load_kg, reason: "No change." },
        verdict: "auto_apply",
        notes: ["Not covered by the model; load kept."],
      });
    }
  }
  return {
    derived,
    output: res.output,
    checked,
    meta: { model: res.model, duration_ms: res.duration_ms, cost_usd_equivalent: res.cost_usd_equivalent },
  };
}
