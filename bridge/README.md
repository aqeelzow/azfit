# AZfit bridge

Runs AZfit's coaching jobs through **your own Claude Code**, signed in with your own Claude account (`claude -p`). AZfit never sees or stores your Claude login, and nothing is billed in dollars: each run uses some of your Claude plan's usage.

Each person runs their own bridge on their own Mac with their own account. Don't share one bridge between people.

## The three jobs

| Job | Model | Input from the phone | What code does around Claude |
|---|---|---|---|
| `review` (weekly) | Opus | A weekly snapshot (`WeeklySnapshot` in `src/types.ts`) | Works out trend rate, implied maintenance and scale/waist/strength directions first; afterwards checks every proposal against the limits |
| `meal` (each photo) | Haiku | Photo (JPEG/PNG/WebP), optional note, plate size, scale weight, similar past meals | Puts the photo in the job's own temporary folder (deleted afterwards); adds up totals from the items itself; warns when calories don't match macros, the range, or the scale |
| `session` (after a workout) | Sonnet | Prescribed and performed sets, e1RM history, sleep, soreness | Works out e1RM, top-of-range and RIR first; afterwards checks each next-time load (routine +2.5 kg applies; bigger jumps need approval; over 10% up or 20% down is blocked) |

Each job:
- runs `claude -p` in an empty temporary folder, with its prompt from `prompts/` and a required output shape from `schemas/`
- uses no settings, MCP servers or saved sessions
- has no tools, except Read for the meal photo, which can only read that folder

**The limits in `src/guardrails.ts`** (weekly review):
- calorie steps of 100 to 200, at most one change every 14 days, never below the floor
- at least 10 complete days, and a hold while a water event is in the window
- protein ranges per goal, load jumps, and volume limits

## Setup

Needs Node 23.6 or later, and Claude Code installed and signed in (`claude` on your PATH).

```sh
cd bridge
npm install
npm test                                         # math, limits and server tests (no Claude calls)
npm run review  -- fixtures/reviews/recomp.json  # one live review from the Terminal
npm run meal    -- photo.jpg --note "half the rice" --plate 27 --weight 450
npm run session -- fixtures/sessions/push-day.json
npm run eval                                     # every review scenario; checks each calorie decision
```

The bridge removes `ANTHROPIC_API_KEY` from Claude Code's environment, so the calls always go through your Claude login, never API billing.

## Running the server

```sh
npm start          # listens on port 4848; refuses to start if Claude Code isn't signed in
npm run pair       # shows the QR code the phone scans (add --png qr.png to save it as an image)
npm run reset-token  # new token; restart the bridge and re-pair the phone
```

The config, including the token, lives in `~/Library/Application Support/AZfit Bridge/config.json`. Only your macOS user can read it.

| Request | Token | What it does |
|---|---|---|
| `GET /health` | no | Bridge is up, which jobs it runs, Claude signed in or not, and the plan type (never the email) |
| `POST /jobs/review`, `/jobs/meal`, `/jobs/session` | yes | Checks the input (400 with a list of problems if it's bad), queues the job, returns `{ id }` at once |
| `GET /jobs/<id>?wait=25` | yes | Job status. With `wait`, holds the request until the job finishes (up to 60 s) |

Jobs run one at a time. A job's input is dropped from memory as soon as it starts, and finished results are kept for 24 hours.

The QR code holds `{"azfit": 1, "urls": [...], "token": "..."}`. The phone tries each address in order (`<name>.local` first, then the Mac's current IP addresses). Anyone who sees the QR code or token can use your bridge, so run `npm run reset-token` if it leaks.

Try it with curl:

```sh
TOKEN=...   # from npm run pair
curl -s localhost:4848/health
curl -s -X POST localhost:4848/jobs/review -H "Authorization: Bearer $TOKEN" \
  -H "content-type: application/json" --data @snapshot.json      # → {"id": "..."}
curl -s "localhost:4848/jobs/<id>?wait=60" -H "Authorization: Bearer $TOKEN"
```

**Network security:** on your own Wi-Fi this is plain HTTP, so the token is only as private as that network. Away from home, connect over Tailscale, which encrypts the traffic. Don't use the bridge over public Wi-Fi without Tailscale.

## Not built yet

- Starting at login (a launch agent), and the Sunday schedule with a wake timer
- Measuring food volume from the camera (needs the iPhone app; see the brief)
