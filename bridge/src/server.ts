import { timingSafeEqual } from "node:crypto";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { JobQueue, type Runner } from "./jobs.ts";

// The bridge's HTTP server. The phone talks to it over Wi-Fi or Tailscale.
//
//   GET  /health              is the bridge up, which jobs it runs, is Claude signed in? (no token)
//   POST /jobs/<kind>         start a job; returns { id } right away       (token)
//   GET  /jobs/<id>?wait=25   job status; waits up to 25 s for it to finish (token)
//
// Every request except /health needs:  Authorization: Bearer <token>

export interface ServerOptions {
  token: string;
  /** Job kinds and the functions that run them, e.g. { review: runReviewJob }. */
  runners: Record<string, Runner>;
  /** Optional input checks per job kind. Return a list of problems, or an empty list. */
  validators?: Record<string, (input: unknown) => string[]>;
  /** Reports whether Claude Code is signed in. Never returns the account's email. */
  claudeStatus: () => Promise<{ loggedIn: boolean; authMethod?: string; planTier?: string }>;
  maxBodyBytes?: number;
  log?: (line: string) => void;
}

const MAX_WAIT_S = 60;

function send(res: ServerResponse, status: number, body: unknown): void {
  const json = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json", "content-length": Buffer.byteLength(json) });
  res.end(json);
}

function tokenMatches(header: string | undefined, token: string): boolean {
  const given = Buffer.from(header?.startsWith("Bearer ") ? header.slice(7) : "");
  const expected = Buffer.from(token);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

function readBody(req: IncomingMessage, limit: number): Promise<string> {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > limit) {
        reject(Object.assign(new Error("body too large"), { status: 413 }));
        req.destroy();
      } else chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

export function createBridgeServer(opts: ServerOptions): { server: Server; queue: JobQueue } {
  const queue = new JobQueue(opts.runners);
  const log = opts.log ?? (() => {});
  const limit = opts.maxBodyBytes ?? 2 * 1024 * 1024;

  const server = createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", "http://bridge");
    const started = Date.now();
    res.on("finish", () => log(`${req.method} ${url.pathname} → ${res.statusCode} (${Date.now() - started} ms)`));

    try {
      if (req.method === "GET" && url.pathname === "/health") {
        const claude = await opts.claudeStatus().catch(() => ({ loggedIn: false }));
        return send(res, 200, { ok: true, bridge: "azfit", version: 1, jobs: Object.keys(opts.runners), claude });
      }

      if (!tokenMatches(req.headers.authorization, opts.token)) {
        return send(res, 401, { error: "missing or wrong token" });
      }

      const parts = url.pathname.split("/").filter(Boolean); // ["jobs", "<kind or id>"]
      if (parts[0] !== "jobs" || parts.length !== 2) return send(res, 404, { error: "not found" });

      if (req.method === "POST") {
        const kind = parts[1]!;
        if (!queue.has(kind)) return send(res, 404, { error: `unknown job kind "${kind}"` });
        let input: unknown;
        try {
          input = JSON.parse(await readBody(req, limit));
        } catch (e) {
          const status = (e as { status?: number }).status ?? 400;
          return send(res, status, { error: status === 413 ? "body too large" : "body must be JSON" });
        }
        const problems = opts.validators?.[kind]?.(input) ?? [];
        if (problems.length) return send(res, 400, { error: "invalid input", problems });
        const job = queue.add(kind, input);
        return send(res, 202, { id: job.id, status: job.status });
      }

      if (req.method === "GET") {
        const wait = Math.min(Math.max(Number(url.searchParams.get("wait") ?? 0) || 0, 0), MAX_WAIT_S);
        const job = await queue.wait(parts[1]!, wait * 1000);
        if (!job) return send(res, 404, { error: "no such job (finished jobs are kept for 24 hours)" });
        return send(res, 200, job);
      }

      return send(res, 405, { error: "method not allowed" });
    } catch (e) {
      log(`error: ${(e as Error).message}`);
      if (!res.headersSent) send(res, 500, { error: "internal error" });
    }
  });

  return { server, queue };
}
