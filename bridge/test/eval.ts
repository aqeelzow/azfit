import { readdir, readFile } from "node:fs/promises";
import { runReview } from "../src/review.ts";

// Runs every fixture through the real Sunday review (Opus via your Claude login)
// and checks the calorie decision against what the fixture expects.
// Each run uses some of your Claude plan's usage.
// Usage: npm run eval            (all fixtures)
//        npm run eval -- water   (fixtures whose name contains "water")

const filter = process.argv[2];
const dir = new URL("../fixtures/reviews/", import.meta.url);
const files = (await readdir(dir)).filter((f) => f.endsWith(".json") && (!filter || f.includes(filter)));

let passed = 0;
await Promise.all(
  files.map(async (f) => {
    const fx = JSON.parse(await readFile(new URL(f, dir), "utf8"));
    try {
      const r = await runReview(fx.snapshot);
      const actionOk = fx.expected.calorie_action.includes(r.review.calorie_action);
      const readingOk = fx.expected.calorie_reading.includes(r.review.calorie_reading);
      const blocked = r.checked.filter((c) => c.verdict === "rejected");
      const ok = actionOk && readingOk;
      if (ok) passed++;
      console.log(
        `${ok ? "PASS" : "FAIL"}  ${fx.name.padEnd(18)} ${r.review.calorie_action}/${r.review.calorie_reading}` +
          (ok ? "" : `  (expected ${fx.expected.calorie_action.join("|")}/${fx.expected.calorie_reading.join("|")})`) +
          `  · ${r.checked.length} proposals, ${blocked.length} blocked · ${(r.meta.duration_ms / 1000).toFixed(0)}s`,
      );
      for (const b of blocked) console.log(`        blocked ${b.proposal.type}: ${b.notes.join(" ")}`);
    } catch (e) {
      console.log(`ERROR ${fx.name}: ${(e as Error).message}`);
    }
  }),
);
console.log(`\n${passed}/${files.length} passed`);
process.exit(passed === files.length ? 0 : 1);
