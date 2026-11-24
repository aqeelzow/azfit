# AZfit decisions

The product spec is [product-brief.html](product-brief.html) (Aqeel, v0.2). The approved UI is in [design/](../design/README.md). This file has two parts: what we are building, and the decisions behind how. When a decision changes, add a new entry that supersedes the old one instead of rewriting history.

Status: **Accepted**, **Open** (needs Aqeel and Moiz), or **Superseded by D-xxx**.

---

## Part 1. Features

Grouped the way the app is. "v1" is what the first TestFlight build needs; "later" is in the brief but can wait.

### Onboarding
| Feature | Notes | When |
|---|---|---|
| Goal: lose fat, build muscle, get stronger, feel healthier | Sets protein g/kg and the starting deficit or surplus | v1 |
| Training days, session length, equipment, injuries | Div drafts a four-week block from this | v1 |
| Kidney disease question | If yes, protein is doctor-set and Div never changes it | v1 |
| Pair the bridge | QR code on the Mac, scan with the phone, bridge checks `claude` is signed in | v1 |
| Apple Health consent, per category | See D-016 | v1 |
| Baseline weigh-in and scan | | v1 |

### Train
| Feature | Notes | When |
|---|---|---|
| Exercise library, fully tagged | Muscles with involvement weights, pattern, equipment, joint stress, fatigue cost | v1 |
| Live workout logging | Weight, reps, RIR per set (RPE accepted and converted), warm-ups calculated, rest timer | v1 |
| e1RM per lift | `w × (1 + (reps + RIR) / 30)` | v1 |
| Effective sets per muscle per week | RIR ≤ 4, weighted by involvement, against MEV and MRV landmarks | v1 |
| Fatigue and readiness per muscle | Per-muscle decay, adjusted by sleep and soreness | v1 |
| Skipped sessions are gaps, never deleted | Detraining: after ~2 weeks off, start lighter and build back | v1 |
| Overreaching detection | e1RM falling at the same RIR over 2+ sessions, plus sleep and soreness | v1 |
| Muscle map | Heat map of this week's volume | v1 |
| Build or swap a workout by hand | Library with search and filters | v1 |

### Eat
| Feature | Notes | When |
|---|---|---|
| Snap a meal | Photo, plus optional words and plate weight. Estimate with a range | v1 |
| Context ladder | Photo only is wide; words narrow it; depth volume narrower; plate weight narrowest | v1 photo + words, later depth |
| Favorites | Same meal logs the same number every time (consistency over accuracy) | v1 |
| Protein as the daily target, shown as a bar | g/kg by goal, goal weight if body fat is high. See D-013 | v1 |
| Day completeness | "Done for today" tap, or asked next morning. Suspected partial under 60% of usual | v1 |
| Calorie calibration loop | Weekly, deterministic. See D-010 | v1 |
| "Why 2,350?" | The math behind any calorie change, with undo | v1 |
| Food depth scan (LiDAR, or ARKit sweep on base iPhones) | Volume helps, density still comes from the description | later |

### Body
| Feature | Notes | When |
|---|---|---|
| Daily weigh-in and trend weight | EWMA, ~10% per weigh-in | v1 |
| Tape measurements | Weekly waist check | v1 |
| Body scan, LiDAR (Pro) | One continuous turn, four key frames, circumferences and a body fat range | later |
| Progress model (base iPhones) | Vision silhouettes fitted to a body model. No body fat number | later |
| Progress view | Weight, waist and e1RM read together | v1 |

### Div
| Feature | Notes | When |
|---|---|---|
| Session review | After each workout, a one-line note and in-session tweaks | v1 |
| Sunday review | The only job that moves calories | v1 |
| Chat | Ask why anything changed, report pain, ask for changes | v1 |
| Voice | Talk to Div hands-free mid-workout | later |
| Div's log | Every change with its reason, undoable for 7 days | v1 |
| What Div knows | Memories and autonomy switches | v1 |
| Questions instead of guesses | "Did Thursday's dinner slip through?" | v1 |

### Apple Health
| Reads | Used for | When |
|---|---|---|
| Steps, active energy | Explains maintenance shifts. Never added back as calories | v1 |
| Sleep | Readiness | v1 |
| Resting HR, HRV | Against a 30-day baseline | later |
| Workouts from other apps | Counted as fatigue | v1 |
| Weight, body fat from a smart scale | Straight into trend weight | v1 |
| Cycle tracking | Compare weigh-ins phase to phase | later |

Writes back: strength sessions, food (energy and macros), weigh-ins, waist and body fat.

### Bridge (Mac)
| Feature | Notes | When |
|---|---|---|
| Menu bar app | Phone, Claude and queue status. Pair a phone | v1 |
| Runs Div jobs with `claude -p` | See D-007 | v1 |
| MCP read tools | Served from its copy of the data | v1 |
| Scheduled reviews | Sunday review even if the phone is asleep | v1 |
| Job queue | Phone queues offline, bridge drains when reachable | v1 |

### Not doing
No AZfit cloud or accounts. No social feed. No streaks, badges or guilt notifications. No exercise calories added back. No ads.

---

## Part 2. Decision log

### D-001 Native Swift and SwiftUI, not Expo
**Accepted.** The core of the app is HealthKit background delivery, LiDAR and ARKit capture, a camera pipeline, Bonjour to the Mac, and a menu bar app on the Mac. All of these are first-class in Swift and wrappers or native modules in Expo. We also need a macOS app (the bridge), which SwiftUI gives us from the same code. The cost is no Android; the product is iPhone plus Mac by design (LiDAR, Apple Health, a Mac running Claude Code).

### D-002 iOS 26 and macOS 26 minimum
**Accepted.** We are starting in late 2026 with no installed base. The newest OS gives us `@Observable`, Swift 6 concurrency defaults, the current SwiftUI and Swift Testing without back-deployment code. Revisit only if testers are stuck on 18.

### D-003 Repo layout: app shells plus local Swift packages
**Accepted.**
```
App/       iPhone app (thin: views and app wiring)
Bridge/    BridgeKit package + App/ (the Mac menu bar shell)
AZKit/     shared packages: AZModel, AZMath, AZStore, AZSync
Div/       everything about the agent: prompts, tools, schema, evals
design/    the approved screens as HTML
docs/      brief, decisions, architecture
```
Logic lives in packages so it builds and tests with plain `swift test`, on any Mac, in CI, without a simulator. The app targets stay thin. Div gets its own top-level folder because its prompts and schemas are the product as much as the Swift is, and the people tuning Div should not have to dig through app code. See [architecture.md](architecture.md).

### D-004 XcodeGen, project file not checked in
**Accepted.** `project.yml` is the source of truth; `make gen` writes `AZfit.xcodeproj`. No merge conflicts in `project.pbxproj`, and settings are reviewable in plain text. Generated files (`*.xcodeproj`, `App/Info.plist`, entitlements) are git-ignored. Never edit them; change `project.yml`.

### D-005 SQLite through GRDB, not SwiftData or Core Data
**Accepted.** We need a sync log, explicit migrations, the same database on iOS and macOS, raw SQL for the analytics (weekly volume, complete-day windows) and tests against an in-memory database. GRDB does all of that and is predictable. SwiftData hides the schema and has no story for syncing to our own bridge. Snake_case columns, one `v1` migration until the first TestFlight, then additive migrations only.

### D-006 No cloud. Phone and Mac sync over the local network or Tailscale
**Accepted.** From the brief: no AZfit accounts to breach. The phone is the source of truth for what the user logs; the bridge keeps a copy so Div can read it. Every write goes into `sync_log` with a monotonic sequence, and peers exchange rows after the last sequence they saw (`AZSync`, wire version 1). Discovery is Bonjour (`_azfit-bridge._tcp`); pairing is a QR code with a shared key. Tailscale works because it is just another network.

### D-007 Bring your own Claude through `claude -p`
**Accepted.** The bridge shells out to the user's own Claude Code CLI:
```
claude -p <prompt> --model <opus|sonnet|haiku> --output-format json --json-schema <schema>
  --system-prompt-file <file> --mcp-config <file> --strict-mcp-config --tools ""
  --setting-sources "" --no-session-persistence
```
Tried by hand on 2026-11-22; the answer is in `structured_output` of the JSON envelope. No API keys to manage, no markup, and the user's data only goes to their own account. `--tools ""` and `--strict-mcp-config` mean Div sees only our read tools, nothing on the user's machine. `--setting-sources ""` keeps the user's personal Claude settings out of Div's runs. The bridge is not sandboxed because it must run the user's CLI; it is hardened-runtime signed.

### D-008 Div returns the whole diff; it has no tools that write
**Accepted** (reads changed by D-021). The brief lists write tools (`set_prescription`, `swap_exercise`, ...). We keep those names but they are entries in the `changes` array of one JSON result (a schema in `Div/schemas/`), not tool calls. Div reads through MCP tools, thinks, and returns everything at the end. Why: a run that dies halfway changes nothing; the batch is checked by the policy and applied in one transaction; evals compare JSON; there is no way for a prompt injection in a meal note to make a tool call that changes data.

### D-009 Autonomy is enforced in code, not in the prompt
**Accepted.** A policy in Swift decides every action: apply (undoable for 7 days), propose (waits for a tap), ask, or refuse. The prompt explains the rules so Div proposes sensible things, but the code is what actually gates them, and it should have tests. Hard rules that no setting can change: Div never logs food, never decides a day was partial (it asks), never goes below the calorie floor, never touches doctor-set protein, and structural changes (add volume, deload, new workout, macros) are always proposals.

### D-010 Calorie math is deterministic Swift, not model judgment
**Accepted.** AZMath implements the brief's rules exactly: trend weight (EWMA α 0.1), implied maintenance from complete days only (min 10 in a 14 to 21 day window), ±0.15 kg/week tolerance, two weeks off target before moving ("watching" after one), 100 to 200 kcal steps rounded to 50, at most one change per 14 days, losing over 1% of body weight a week skips the wait, known water events hold. Div gets the decision through a read tool and explains it; it may propose a different number only with a reason, and the policy still applies. Same numbers in, same answer out, testable.

### D-011 The agent is called Div
**Accepted.** Renamed from "Arnie" (and "Spark", the mascot sketch) on 2026-11-22. Code, prompts and the design folder say Div. The published canvas artifact still says Arnie.

### D-012 Autonomy defaults: the design or the brief?
**Open.** They disagree:

| | Brief v0.2 | Approved design (current code) |
|---|---|---|
| Routine progression (load, reps) | auto | auto |
| Swap exercise, move session | asks first | auto, undo for 7 days |
| Calorie change | asks at 150 kcal or more | auto within 200 kcal, asks above |

The design's argument: every auto change is marked, explained and undoable, which is less friction than approving routine swaps, and the user can turn either switch off on "What Div knows". The brief's argument: early trust, and calories are sensitive. Aqeel and Moiz to decide before TestFlight.

### D-013 Design rules are product rules
**Accepted.** From the approved design: no yellow, no circles (no dots, rings or round crops; icons and Div's eyes excepted), no emoji, no em dashes, lavender plus the Div mark means "Div changed this". The brief's "protein ring" is therefore a **bar**. Every change shows what, before and after, why, and a way out. These apply to SwiftUI code as much as to the HTML.

### D-014 Swift Testing everywhere
**Accepted.** `import Testing`, `@Test`, `#expect`. On a Mac with only the Command Line Tools (no Xcode), `swift test` needs extra framework flags; `make test` adds them automatically. CI uses Xcode and needs nothing extra.

### D-015 Div evals run in BridgeKit
**Accepted, built** (`DivEvals`, run with `make eval`). Scenarios live in `Div/evals/` (state + job + expected outcome). The runner belongs in BridgeKit because it needs the real `claude -p` path, the MCP read tools and the policy. It checks outcomes (which actions, which verdicts, no forbidden actions), not wording. Run before changing a prompt; add a scenario for every behavior bug.

### D-016 Apple Health consent per category, and a separate consent for Claude
**Accepted.** Each Health category is its own switch. Reading Health into AZfit and sending it to Claude are separate consents (Apple requires explicit consent before health data goes to a third party, the user's own Claude account included). Until the second one is given, Health read tools return `not_shared` and Div works without them. Images (meal photos, scans) never go to Div except a meal photo for its own estimate.

### D-017 Calorie floor 1,200 kcal
**Open.** Proposed default: 1,200. That is a common floor for women and low for most men; a per-person floor (for example from BMR) may be better. Div refuses anything below the floor either way. Aqeel and Moiz to decide.

### D-018 Model per job
**Accepted.** Weekly review and chat: Opus (reasoning over many signals). Session review: Sonnet (frequent, narrow). Meal estimate: Haiku (fast, cheap, one image).

### D-019 UUIDs stored as lowercase text
**Accepted.** Readable in the SQLite shell, stable across platforms, and the same string Div sees in tool results and returns in actions. In GRDB, set this with `databaseUUIDEncodingStrategy`.

### D-020 Figtree, bundled
**Accepted.** The design's typeface, under the SIL Open Font License (`App/Resources/Fonts/OFL.txt`). One variable font file covers every weight.

---

### D-021 Fixed jobs get a snapshot; chat looks things up
**Accepted** (Aqeel, 2026-11-23). Supersedes the "reads through MCP tools" part of D-008. The weekly review, session review and meal estimate get exactly the data they need in the prompt (a `WeeklySnapshot`, a `SessionReport`, a photo) plus the numbers AZMath derived from it. One model turn, so they're faster, use less of the person's plan, and evals are repeatable: the same fixture always shows Div the same data. Chat can't know in advance what it will be asked, so it gets six read tools (`Div/tools/tools.json`) served by the bridge over MCP (`DivToolServer`, started by Claude Code as `div tools`). Chat can't change calories or protein (only the weekly review does, from two weeks of data); its schema leaves them out and the policy refuses them anyway. Today the tools answer from a `DivData` file the bridge writes per run; with sync they'll read the bridge's copy of the database.

### D-022 The agent is Swift; the Node prototype is gone
**Accepted** (Aqeel, 2026-11-23). The first bridge was Node (branch `bridge`, before this). It was ported so the app and the bridge share one model and one set of formulas: types in `AZModel`, formulas in `AZMath`, the `claude -p` runner, policy, read tools and evals in `BridgeKit`, and a `div` command line (`Bridge/Sources/DivCLI`) for running jobs and evals by hand. The policy's verdicts are D-009's: `apply`, `propose` (ask first) and `refuse`. Autonomy is a value passed to the policy (`Autonomy`, the three switches on "What Div knows"); it defaults to the design's (all on) until D-012 is settled. The Node version's HTTP server and QR pairing weren't ported: phone-to-bridge transport belongs with sync (D-006).

## Open questions

1. **D-012** autonomy defaults: design or brief.
2. **D-017** calorie floor: fixed 1,200 or per person.
3. Bridge distribution: notarized download, or Mac App Store (sandboxing conflicts with running `claude`, so probably download).
4. What happens when the Mac is off for a week: the phone keeps working; reviews wait. Should the phone show "Div is offline since Tuesday"?
5. Pairing more than one phone to a bridge (couples sharing a Mac).
6. LiDAR scan and food depth: build in v1 or after the first TestFlight.
7. Bundle identifiers and the Apple team: `com.azfit.*` is a placeholder.
