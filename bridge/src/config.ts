import { randomBytes } from "node:crypto";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

// The bridge's own settings: the port and the pairing token.
// Stored outside the repo, readable only by your macOS user.

export interface BridgeConfig {
  port: number;
  token: string;
  created: string;
}

export const CONFIG_DIR =
  process.env.AZFIT_BRIDGE_DIR ?? join(homedir(), "Library", "Application Support", "AZfit Bridge");
const CONFIG_FILE = join(CONFIG_DIR, "config.json");
export const DEFAULT_PORT = 4848;

export function newToken(): string {
  return "azb_" + randomBytes(32).toString("base64url");
}

async function save(config: BridgeConfig): Promise<void> {
  await mkdir(CONFIG_DIR, { recursive: true, mode: 0o700 });
  await writeFile(CONFIG_FILE, JSON.stringify(config, null, 2) + "\n", { mode: 0o600 });
  await chmod(CONFIG_FILE, 0o600);
}

/** Loads the config, creating it with a fresh token on first run. */
export async function loadConfig(): Promise<BridgeConfig> {
  try {
    return JSON.parse(await readFile(CONFIG_FILE, "utf8")) as BridgeConfig;
  } catch {
    const config = { port: DEFAULT_PORT, token: newToken(), created: new Date().toISOString() };
    await save(config);
    return config;
  }
}

/** Replaces the token. The old one stops working once the bridge restarts. */
export async function resetToken(): Promise<BridgeConfig> {
  const config = { ...(await loadConfig()), token: newToken(), created: new Date().toISOString() };
  await save(config);
  return config;
}
