# Evals

Scenarios for Div: a situation and the outcome Div should reach. They check decisions, not wording. Run them before and after changing a prompt (`make eval`, or `make eval JOB=chat`). Each run uses some of your Claude plan.

| Folder | Each file has | Checked |
|---|---|---|
| `weekly-review/` | `snapshot`, `expected.calorie_action[]`, `expected.calorie_reading[]` | the calorie decision and how Div read the scale, waist and strength |
| `session-review/` | `session`, `expected.calls` (exercise -> allowed calls) | progress, repeat or reduce per exercise |
| `estimate-meal/` | `photo` (a path in the repo), `request`, `expected` | `kcal_between`, `no_warnings`, `matched_similar`, `empty_items`, `follow_up` |
| `revise-meal/` | `request` (previous estimate, question, answer), `expected.kcal_change_between` | how much the answer moved the total |
| `in-workout/` | `request` (prescription and sets so far), `expected.calls` | keep, lower_reps, lower_load, raise_load or stop |
| `chat/` | `request`, `data` (a `DivData` file, `data.json` by default), `expected` | `change_types` it must make, `change_fields` they must have, `forbidden_change_types`, `no_changes`, `tools_any` it must look up |

The same fixtures are used by `make test` (no Claude calls) to check the math and the policy.

Meal photos are the stock images in `design/img`. The calorie ranges are wide on purpose: they catch an estimate that's badly off, not one that's 10% off. For real accuracy numbers we need photos of weighed meals.

When Div does something wrong, add a scenario that catches it first.
