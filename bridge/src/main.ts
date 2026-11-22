import { execFile } from "node:child_process";
import { networkInterfaces, hostname } from "node:os";
import { promisify } from "node:util";
import QRCode from "qrcode";
import { loadConfig, resetToken, CONFIG_DIR } from "./config.ts";
import { runMeal, validateMeal } from "./meal.ts";
import { runReview } from "./review.ts";
import { createBridgeServer } from "./server.ts";
import { runSession, validateSession } from "./session.ts";
import { validateSnapshot } from "./validate.ts";
import type { MealRequest, SessionRequest, WeeklySnapshot } from "./types.ts";

// Entry point.
//   npm start            run the bridge
//   npm run pair         show the QR code the phone scans (--png <file> also saves it as an image)
//   npm run reset-token  make a new token (re-pair the phone afterwards)

const run = promisify(execFile);

async function claudeStatus(): Promise<{ loggedIn: boolean; authMethod?: string; planTier?: string }> {
  const { stdout } = await run("claude", ["auth", "status", "--json"], { timeout: 15_000 });
  const s = JSON.parse(stdout);
  // Only what the phone needs. The account's email and org stay on the Mac.
  return { loggedIn: Boolean(s.loggedIn), authMethod: s.authMethod, planTier: s.planTier };
}

function lanAddresses(): string[] {
  return Object.values(networkInterfaces())
    .flat()
    .filter((a) => a && a.family === "IPv4" && !a.internal)
    .map((a) => a!.address);
}

function pairingInfo(port: number, token: string) {
  const host = hostname().replace(/\.local$/, "") + ".local";
  return { addresses: [host, ...lanAddresses()].map((h) => `http://${h}:${port}`), token };
}

const command = process.argv[2] ?? "start";
const config = command === "reset-token" ? await resetToken() : await loadConfig();

if (command === "pair" || command === "reset-token") {
  const info = pairingInfo(config.port, config.token);
  // What the phone reads from the QR code. Versioned so the format can change later.
  const payload = JSON.stringify({ azfit: 1, urls: info.addresses, token: info.token });
  if (command === "reset-token") console.log("New token created. Restart the bridge, then re-pair your phone.\n");
  console.log("Scan this with the AZfit app to pair your phone:\n");
  console.log(await QRCode.toString(payload, { type: "terminal", small: true, errorCorrectionLevel: "M" }));
  const pngIndex = process.argv.indexOf("--png");
  if (pngIndex > 0 && process.argv[pngIndex + 1]) {
    await QRCode.toFile(process.argv[pngIndex + 1]!, payload, { width: 512, margin: 2 });
    console.log(`Saved the QR code to ${process.argv[pngIndex + 1]}. Delete it after pairing: it holds your token.\n`);
  }
  console.log("Bridge addresses (the phone tries them in this order):");
  for (const a of info.addresses) console.log(`  ${a}`);
  console.log(`\nToken (for testing with curl): ${info.token}`);
  console.log(`\nAnyone who sees this QR code or token can use your bridge. Run \`npm run reset-token\` if it leaks.`);
  console.log(`Stored in: ${CONFIG_DIR}`);
  process.exit(0);
}

if (command !== "start") {
  console.error(`Unknown command "${command}". Use start, pair or reset-token.`);
  process.exit(1);
}

const status: Awaited<ReturnType<typeof claudeStatus>> = await claudeStatus().catch(() => ({ loggedIn: false }));
if (!status.loggedIn) {
  console.error("Claude Code isn't signed in. Run `claude` and sign in to your Claude account, then start the bridge again.");
  process.exit(1);
}

const { server } = createBridgeServer({
  token: config.token,
  runners: {
    review: (input) => runReview(input as WeeklySnapshot),
    meal: (input) => runMeal(input as MealRequest),
    session: (input) => runSession(input as SessionRequest),
  },
  validators: {
    review: (input) => {
      const r = validateSnapshot(input);
      return r.ok ? [] : r.errors;
    },
    meal: validateMeal,
    session: validateSession,
  },
  // Room for an 8 MB photo once base64-encoded.
  maxBodyBytes: 12 * 1024 * 1024,
  claudeStatus,
  log: (line) => console.log(`${new Date().toISOString()}  ${line}`),
});

server.listen(config.port, "0.0.0.0", () => {
  console.log(`AZfit bridge listening on port ${config.port} (Claude: ${status.authMethod}, ${status.planTier} plan)`);
  console.log("Run `npm run pair` in another terminal to see the address and token for your phone.");
});

for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, () => {
    console.log("Stopping bridge.");
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3000).unref();
  });
}
