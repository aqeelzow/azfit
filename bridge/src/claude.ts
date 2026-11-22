import { spawn } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Runs one job through the user's own Claude Code install (`claude -p`),
// signed in with their own Claude account. AZfit never sees or stores the login.

export type ModelAlias = "opus" | "sonnet" | "haiku";

export interface ClaudeCall {
  model: ModelAlias;
  systemPrompt: string;
  userPrompt: string;
  schema: object;
  effort?: "low" | "medium" | "high";
  /** Tools the model may use. Empty (the default) means none: pure reasoning over the prompt. */
  tools?: string[];
  /** Extra permission rules for the tools above. */
  allowedTools?: string[];
  /**
   * Files to place in the job's empty working folder before Claude starts, e.g. a meal
   * photo. With the Read tool, Claude can read files in that folder without asking;
   * reads anywhere else need permission, which `-p` mode denies.
   */
  files?: Record<string, Buffer>;
  timeoutMs?: number;
}

export interface ClaudeResult<T> {
  output: T;
  model: string;
  duration_ms: number;
  /** What the call would cost at API list prices. Billed to the user's plan, not in dollars. */
  cost_usd_equivalent: number | null;
}

export class ClaudeError extends Error {}

export async function runClaude<T>(call: ClaudeCall): Promise<ClaudeResult<T>> {
  const args = [
    "-p",
    "--model", call.model,
    "--system-prompt", call.systemPrompt,
    "--json-schema", JSON.stringify(call.schema),
    "--output-format", "json",
    "--tools", (call.tools ?? []).join(","),
    // Keep each call lean and isolated: no user/project settings, MCP servers,
    // slash commands or saved sessions.
    "--setting-sources", "",
    "--strict-mcp-config",
    "--disable-slash-commands",
    "--no-session-persistence",
  ];
  if (call.effort) args.push("--effort", call.effort);
  if (call.allowedTools?.length) args.push("--allowedTools", ...call.allowedTools);

  // An ANTHROPIC_API_KEY in the environment would switch Claude Code to API billing.
  // Remove it so the call always uses the signed-in Claude account.
  const env = { ...process.env };
  delete env.ANTHROPIC_API_KEY;
  delete env.ANTHROPIC_AUTH_TOKEN;

  // Run in an empty folder so no CLAUDE.md or project files are picked up.
  // Any files the job needs go there too, and everything is deleted afterwards.
  const cwd = await mkdtemp(join(tmpdir(), "azfit-job-"));
  try {
    for (const [name, data] of Object.entries(call.files ?? {})) {
      if (name.includes("/") || name.startsWith(".")) throw new ClaudeError(`bad file name "${name}"`);
      await writeFile(join(cwd, name), data, { mode: 0o600 });
    }
    const stdout = await new Promise<string>((resolve, reject) => {
      const child = spawn("claude", args, { cwd, env, stdio: ["pipe", "pipe", "pipe"] });
      let out = "";
      let err = "";
      const timer = setTimeout(() => {
        child.kill("SIGTERM");
        reject(new ClaudeError(`claude timed out after ${call.timeoutMs ?? 300_000} ms`));
      }, call.timeoutMs ?? 300_000);
      child.stdout.on("data", (d) => (out += d));
      child.stderr.on("data", (d) => (err += d));
      child.on("error", (e) => {
        clearTimeout(timer);
        reject(new ClaudeError(`Could not start claude. Is Claude Code installed and on PATH? (${e.message})`));
      });
      child.on("close", (code) => {
        clearTimeout(timer);
        if (code !== 0 && !out) reject(new ClaudeError(`claude exited with ${code}: ${err.trim()}`));
        else resolve(out);
      });
      child.stdin.end(call.userPrompt);
    });

    let parsed: any;
    try {
      parsed = JSON.parse(stdout);
    } catch {
      throw new ClaudeError(`claude returned something that isn't JSON: ${stdout.slice(0, 300)}`);
    }
    if (parsed.is_error || parsed.subtype !== "success") {
      throw new ClaudeError(`claude reported an error (${parsed.subtype}): ${parsed.result ?? parsed.api_error_status ?? "unknown"}`);
    }
    if (parsed.structured_output == null) {
      throw new ClaudeError("claude finished without structured output.");
    }
    // Claude Code can also make small helper calls on another model, so report
    // the model that matches the alias we asked for.
    const models = Object.keys(parsed.modelUsage ?? {});
    return {
      output: parsed.structured_output as T,
      model: models.find((m) => m.includes(call.model)) ?? models.join(", ") ?? call.model,
      duration_ms: parsed.duration_ms,
      cost_usd_equivalent: typeof parsed.total_cost_usd === "number" ? parsed.total_cost_usd : null,
    };
  } finally {
    await rm(cwd, { recursive: true, force: true });
  }
}
