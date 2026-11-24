# Div

Div is AZfit's AI coach. This folder is everything Div is: to change how Div thinks, talks or what it may do, you change a file here. The Swift code in `BridgeKit` reads these files at run time; nothing here is compiled.

```
Div/
├── prompts/
│   ├── system.md               who Div is, its rules and voice (every job starts with this)
│   └── jobs/                   one prompt per job, appended after system.md
│       ├── weekly-review.md    every Sunday; the only job that moves calories
│       ├── session-review.md   after each workout: a note and next time's loads
│       ├── estimate-meal.md    photo + words -> items and a calorie range
│       └── chat.md             the Div screen
├── schemas/                    the JSON each job must return (one file per job)
├── tools/tools.json            the read tools chat can call (served over MCP)
└── evals/                      scenarios with the outcome Div should reach
```

## How a run works

```
phone ──job──▶ Mac bridge ──claude -p──▶ Claude (the person's own account)
                  ▲                          │
                  └──── answer as JSON ──────┘
```

1. The bridge gets a job: a weekly snapshot, a finished workout, a meal photo or a chat message.
2. AZMath computes the numbers first (trend rate, maintenance, e1RM, top of range), so Div never does arithmetic (D-010).
3. The bridge runs `claude -p` with `system.md` + the job prompt, the job's schema, and the data. Fixed jobs get the data in the prompt; chat looks it up with the read tools instead (D-021).
4. Div answers with a list of changes, each with a one-sentence reason (D-008).
5. The policy in `BridgeKit/Policy` decides each change: **apply** (undoable for 7 days), **propose** (waits for a tap) or **refuse** (breaks a hard limit). Hard limits always win; the person's switches on "What Div knows" choose between apply and propose; structural changes always ask (D-009).

| Job | Model (D-018) | Input | Div may change |
|---|---|---|---|
| weekly-review | Opus | `WeeklySnapshot` + derived numbers | calories, protein, loads, swaps, moves, volume, deloads |
| session-review | Sonnet | `SessionReport` + derived numbers | next time's load per exercise |
| estimate-meal | Haiku | photo (read from the job's folder), note, plate size, scale weight, similar meals | nothing: it estimates, the person logs |
| chat | Opus | the conversation; data through read tools | loads, swaps, moves, volume, deloads (never calories or protein) |

Every run uses an empty temporary folder, no Claude Code settings, no MCP servers but Div's own, and no tools except Read (meal photo) or Div's read tools (chat). The bridge removes `ANTHROPIC_API_KEY` from the environment so runs always use the person's Claude login, never API billing.

## Trying it

```sh
make div                                                    # builds Bridge/.build/debug/div
Bridge/.build/debug/div review Div/evals/weekly-review/recomp.json
Bridge/.build/debug/div session Div/evals/session-review/push-day.json
Bridge/.build/debug/div meal photo.jpg --note "half the rice" --plate 27
Bridge/.build/debug/div chat "Why did my calories go up?"   # uses Div/evals/chat/data.json
make eval                                                   # every scenario; make eval JOB=chat for one job
```

Add `--json` for the full result, `--ask-first` to turn off everything Div may do alone. Each run uses some of your Claude plan.

## Changing Div

- **A prompt:** edit it, then `make eval`. Every scenario should still pass.
- **A schema:** the Swift types in `AZKit/Sources/AZModel/Div/` must match it. `make test` decodes fixtures and fake answers through them.
- **A limit** (calorie step, load jumps): `Bridge/Sources/BridgeKit/Policy/Limits.swift`, with a test in `Bridge/Tests`.
- **A read tool:** add it to `tools/tools.json` and to `DivTools.swift`. A test checks every tool in the JSON is implemented.
- **A behavior bug:** add a scenario to `evals/` that fails, then fix the prompt until it passes.

Keys are snake_case in JSON and camelCase in Swift. Don't put a digit right after an underscore (`last_7`): it can't round-trip.
