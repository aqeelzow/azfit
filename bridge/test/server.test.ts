import { test, after } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { createBridgeServer } from "../src/server.ts";
import { validateSnapshot } from "../src/validate.ts";

// Server tests use a fake runner, so they make no Claude calls.

const TOKEN = "azb_test_token_1234567890";
let release: () => void = () => {};
const gate = () => new Promise<void>((r) => (release = r));

const { server } = createBridgeServer({
  token: TOKEN,
  runners: {
    review: async (input: any) => {
      await gate();
      return { echoed_week: input.week_ending };
    },
    broken: async () => {
      throw new Error("claude exited with 1");
    },
  },
  validators: { review: (i) => { const r = validateSnapshot(i); return r.ok ? [] : r.errors; } },
  claudeStatus: async () => ({ loggedIn: true, authMethod: "claude.ai", planTier: "pro" }),
});
await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
after(() => server.close());

const auth = { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" };
const snapshot = JSON.parse(readFileSync(new URL("../fixtures/reviews/recomp.json", import.meta.url), "utf8")).snapshot;

test("health needs no token and never exposes the account email", async () => {
  const r = await fetch(`${base}/health`);
  assert.equal(r.status, 200);
  const body = await r.json();
  assert.equal(body.claude.loggedIn, true);
  assert.ok(!JSON.stringify(body).includes("@"));
});

test("jobs reject a missing or wrong token", async () => {
  assert.equal((await fetch(`${base}/jobs/review`, { method: "POST", body: "{}" })).status, 401);
  const wrong = await fetch(`${base}/jobs/review`, { method: "POST", headers: { authorization: "Bearer nope" }, body: "{}" });
  assert.equal(wrong.status, 401);
});

test("bad input gets a 400 with the problems listed", async () => {
  const r = await fetch(`${base}/jobs/review`, { method: "POST", headers: auth, body: JSON.stringify({ week_ending: "x" }) });
  assert.equal(r.status, 400);
  const body = await r.json();
  assert.ok(body.problems.some((p: string) => p.includes("user.goal")));
  assert.equal((await fetch(`${base}/jobs/review`, { method: "POST", headers: auth, body: "not json" })).status, 400);
  assert.equal((await fetch(`${base}/jobs/nope`, { method: "POST", headers: auth, body: "{}" })).status, 404);
});

test("a job returns an id at once, then waiting returns the finished result", async () => {
  const start = await fetch(`${base}/jobs/review`, { method: "POST", headers: auth, body: JSON.stringify(snapshot) });
  assert.equal(start.status, 202);
  const { id } = await start.json();

  // Still running: a short wait comes back without a result.
  const pending = await (await fetch(`${base}/jobs/${id}?wait=0`, { headers: auth })).json();
  assert.notEqual(pending.status, "done");

  // Long wait returns as soon as the job finishes, not after the full 30 s.
  const t0 = Date.now();
  const waiting = fetch(`${base}/jobs/${id}?wait=30`, { headers: auth });
  setTimeout(() => release(), 100);
  const done = await (await waiting).json();
  assert.equal(done.status, "done");
  assert.deepEqual(done.result, { echoed_week: snapshot.week_ending });
  assert.ok(Date.now() - t0 < 5000);
});

test("a failing job reports failed with the error", async () => {
  const { id } = await (await fetch(`${base}/jobs/broken`, { method: "POST", headers: auth, body: "{}" })).json();
  const job = await (await fetch(`${base}/jobs/${id}?wait=5`, { headers: auth })).json();
  assert.equal(job.status, "failed");
  assert.match(job.error, /exited with 1/);
});

test("unknown job ids are a 404", async () => {
  assert.equal((await fetch(`${base}/jobs/does-not-exist`, { headers: auth })).status, 404);
});
