# Tools

The read tools chat can call (D-021). `tools.json` is the list Claude sees, in MCP's `tools/list` shape; `Bridge/Sources/BridgeKit/Tools/DivTools.swift` answers them. The bridge serves them over MCP for each chat run (`div tools --data ... --tools tools.json`).

All of them only read. Div changes things by returning `changes` (D-008), never through a tool.

| Tool | Answers with |
|---|---|
| `get_profile` | goal, targets, calorie floor, doctor-set protein, memories |
| `get_plan` | sessions by weekday with exercises, sets, rep ranges and loads |
| `get_training_log` | workouts set by set, best e1RM per exercise per session (`days`, `exercise`) |
| `get_food_log` | meals and daily totals, which days were complete, average on complete days (`from`, `to`) |
| `get_weight_trend` | weigh-ins with the smoothed trend, weekly rate, waist (`days`) |
| `get_div_log` | Div's recent changes with reasons and status (`days`) |

The fixed jobs (weekly review, session review, meal) don't use tools: they get a snapshot in the prompt.
