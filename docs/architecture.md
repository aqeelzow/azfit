# Architecture

How the pieces are meant to fit. For why, see [decisions.md](decisions.md). Div's side is built (the jobs, policy, read tools and evals in BridgeKit, the math in AZMath); pairing and the phone-to-bridge connection work for chat (AZSync, D-023); storage and sync work (AZStore). Home, Train, Eat, Body, Div's log and the workout screen read the database through `AZStore+Screens.swift`, and workouts log real sets. Div reviews every finished workout (D-030) and the bridge runs the Sunday review itself (D-031); both are built from the database in `AZStore+Reviews.swift`. Still sample data: meal logging (snap, describe, say), meal and exercise detail, body scan and progress, the calorie target screen and Div's memory.

## The big picture

```
┌────────── iPhone ──────────┐         ┌──────────── Mac ────────────┐         ┌── your account ──┐
│ AZfit app (SwiftUI)        │  sync   │ AZfit Bridge (menu bar)     │ claude  │                  │
│  logs training, food, body │◀───────▶│  keeps a copy of the data   │ ───-p──▶│  Claude          │
│  SQLite on the phone       │  LAN or │  runs Div jobs              │         │  (as Div)        │
│  HealthKit, camera         │Tailscale│  checks Div's changes       │◀──JSON──│                  │
└────────────────────────────┘         └─────────────────────────────┘         └──────────────────┘
```

1. You log on the phone. It is saved locally first, so the app works offline.
2. The phone syncs to the bridge on your Mac and asks it to run a Div job (after a workout, for a meal photo, in chat). The bridge runs the Sunday review on its own.
3. The bridge runs `claude -p` with Div's prompts and the answer schema from `Div/`. Fixed jobs get a snapshot of the data in the prompt; chat looks things up with read tools the bridge serves over MCP (D-021).
4. Div answers with a list of changes, each with a reason.
5. The bridge decides which changes apply now, which wait for your tap, and which are refused, then saves them.
6. They sync back to the phone, shown in lavender with the Div mark and an Undo.

## Where code goes

```
App/                    iPhone app. Thin: screens and wiring only.
├── Sources/
│   ├── AZfitApp.swift          app entry point
│   ├── AppEnvironment.swift    shared dependencies, passed to views through the environment
│   ├── RootView.swift          the four tabs
│   ├── DesignSystem/           colors, type, Div's avatar, shared components (from design/)
│   └── Features/<Area>/        one folder per area: Today, Train, Eat, Body, Div, Onboarding
└── Tests/

AZKit/                  shared Swift package, no UI. Used by the app and the bridge.
├── AZModel             data types: exercises, sets, meals, weigh-ins, plan changes
├── AZMath              pure functions: the formulas and rules in the brief
├── AZStore             the SQLite database (GRDB)
└── AZSync              messages between phone and bridge

Bridge/                 Mac menu bar app
├── App/                the SwiftUI shell (menu with phone, Claude and queue status)
├── Sources/BridgeKit/  the real work: running Div, the policy, read tools, evals, pairing and the server phones talk to (saving: TODO)
└── Sources/DivCLI/     `div`: run Div's jobs and evals from the Terminal

Div/                    the agent's prompts, tools, schema and evals. No Swift. See Div/README.md.
```

Dependencies only point one way: `App → AZKit`, `Bridge → AZKit`, and inside AZKit `AZMath → AZModel ← AZStore`. AZKit never imports the app or the bridge.

Guidelines:
- Logic goes in a package, with a test. Views stay simple.
- Math is deterministic and lives in AZMath, so the same numbers always give the same answer.
- Colors, spacing and fonts come from `DesignSystem`, not hard-coded in a screen.
- Never delete what the user logged. A skipped workout is a gap; undo is a status change.

## Testing

Packages use Swift Testing (`@Test`, `#expect`). Each test target has one disabled example test to replace. `make test` runs them all; the app's tests run in Xcode.

## Building

See the [README](../README.md#setup).
