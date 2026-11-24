# Evals

Scenarios for Div: a situation and the outcome Div should reach. They check decisions, not wording. Run them before and after changing a prompt (`make eval`, or `make eval JOB=chat`). Each run uses some of your Claude plan.

| Folder | Each file has | Checked |
|---|---|---|
| `weekly-review/` | `snapshot`, `expected.calorie_action[]`, `expected.calorie_reading[]` | the calorie decision and how Div read the scale, waist and strength |
| `session-review/` | `session`, `expected.calls` (exercise -> allowed calls) | progress, repeat or reduce per exercise |
| `chat/` | `request`, `data` (a `DivData` file, `data.json` by default), `expected` | `change_types` it must make, `forbidden_change_types`, `no_changes`, `tools_any` it must look up |

The same fixtures are used by `make test` (no Claude calls) to check the math and the policy.

When Div does something wrong, add a scenario that catches it first.
