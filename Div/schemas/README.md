# Schemas

The JSON each job must return, one file per job. The bridge passes it to `claude -p --json-schema`, so the answer is always JSON the app can read, never prose.

| File | Swift type (AZModel) |
|---|---|
| `weekly-review.json` | `WeeklyReviewOutput` |
| `session-review.json` | `SessionReviewOutput` |
| `estimate-meal.json` | `MealEstimate` |
| `chat.json` | `ChatOutput` |

Changes are a list of objects with a `type` (`set_calorie_target`, `set_load`, `swap_exercise`, `move_session`, `change_volume`, `schedule_deload`, `set_protein_target`), the fields for that type, a `reason` and `evidence` (`Proposal` in Swift). Chat's schema leaves out the calorie and protein types. See docs/decisions.md D-008 and D-021.
