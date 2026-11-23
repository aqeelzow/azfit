# Div

Div is AZfit's AI coach (called "Arnie" in early design files). This folder is everything Div is: if you want to change how Div thinks, talks or what it may do, you change a file here.

```
Div/
├── prompts/
│   ├── system.md          who Div is, its rules and voice (every job starts with this)
│   └── jobs/              one prompt per job
│       ├── session-review.md   after each workout
│       ├── weekly-review.md    every Sunday
│       ├── estimate-meal.md    photo + words → calorie estimate with a range
│       └── chat.md             the Div screen
├── tools/                 what Div can read (served by the bridge over MCP)
├── schemas/               the JSON every run must return
└── evals/                 scenarios with the outcome Div should reach
```

## How a Div run will work

```
phone ──job──▶ Mac bridge ──claude -p──▶ Claude (your account)
                  ▲                          │
                  └──── answer as JSON ──────┘
```

1. The phone asks the bridge for a job (review this workout, estimate this meal).
2. The bridge runs `claude -p` with the prompts here, the tools, and the schema.
3. Div answers with a list of changes, each with a reason.
4. The bridge checks each change against what Div is allowed to do alone, and saves it.

Where to read more: the brief's "The coach" and "Bring your own Claude" sections, and docs/decisions.md D-007 to D-009 and D-012.
