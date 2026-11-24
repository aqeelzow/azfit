// BridgeKit: what the Mac menu bar app does, as a library so it can be tested without the UI.
//
// Built:
// - Div's jobs (`Div`): weekly review, session review, meal estimate and chat, each run with the user's own
//   `claude -p` (`ClaudeCLI`, D-007), using the prompts, schemas and tools in Div/ (`DivFiles`).
// - The policy that decides what Div's changes may do (`ChangePolicy`, `SessionPolicy`, `MealChecks`, D-009).
// - The read tools chat uses, served over MCP (`DivToolServer`, D-021), and the eval runner (`DivEvals`, D-015).
//
// TODO (brief: "Bring your own Claude"):
// - Pair with the phone and keep a copy of its data (AZSync, AZStore).
// - Save checked changes and their undo, and run the Sunday review on a schedule.
