# The clickable prototype

The iPhone app in `App/` is a clickable prototype of every designed screen. It runs in the simulator with no
backend: all numbers, meals, sets and Div messages are hard-coded in the views. Buttons that the design shows
working (undo, keep, answer a question, toggles) change local state, so you can see both sides of a change.

Its job is to show what the agent layer has to produce. Every lavender card with the Div mark is something Div
returned. When you build Div, each of those cards becomes the output of one job in `Div/prompts/jobs/`, checked
by code (D-008, D-009). Numbers like 2,350 kcal or 14-17% body fat come from `AZMath`, not from Div (D-010).
Div only explains them.

## Run it

```sh
make gen        # needs Xcode; writes AZfit.xcodeproj
open AZfit.xcodeproj
```

Pick the `AZfit` scheme and an iPhone 17 Pro simulator. Onboarding comes first; tap through it to reach the app.

## Screens, and what Div has to do for each

| Screen | File | What Div produced | Job |
|---|---|---|---|
| Welcome, Goal, Days, Connect | `Features/Onboarding/OnboardingFlow.swift` | Nothing yet. Connect is the bridge pairing. | - |
| Home | `Features/Today/HomeView.swift` | "Div made 3 changes this week", the Sunday session it moved (lavender day in the week strip), the swapped exercise in Push A. | weekly-review, session-review |
| Quick add (+) | `Features/Today/QuickAddOverlay.swift` | "Log Thursday's dinner?": a question, not a change. | weekly-review |
| Train | `Features/Train/TrainView.swift` | Landmine press swapped in for overhead press; Upper A moved to Sunday, with Undo and Skip. | chat, weekly-review |
| Live workout | `Features/Train/WorkoutView.swift` | Set 3 lowered from 8 to 6 reps mid-session, with "Keep 8 reps". | session-review (in-workout) |
| Workout done | `Features/Train/WorkoutDoneView.swift` | "What I changed today": the session's changes as a list. | session-review |
| Swap exercise | `Features/Train/SwapExerciseView.swift` | "Div's picks": ranked swaps with a reason. | chat |
| Exercise | `Features/Train/ExerciseView.swift` | "Swapped in by Div", with the way back. | chat |
| Div chat | `Features/Div/DivChatView.swift` | Answers plus a tool card for a change made from chat, with Undo. | chat |
| Voice | `Features/Div/VoiceView.swift` | The same chat, spoken. | chat |
| Div's log | `Features/Div/DivLogView.swift` | Every change this week, each with a reason and Undo; one open question. | all |
| What Div knows | `Features/Div/MemoryView.swift` | What Div may do alone (toggles, D-009/D-012) and what it remembers. | all |
| Eat | `Features/Eat/EatView.swift` | "Did Thursday's dinner slip through?": a question from the logs and the weight trend. | weekly-review |
| Meal | `Features/Eat/MealView.swift` | The estimate range and one question that narrows it ("Was there dressing?"). | estimate-meal |
| Snap a meal | `Features/Eat/SnapMealView.swift` | Food tags on the photo; a library photo offered for the missed meal. | estimate-meal |
| Daily target | `Features/Eat/CalorieTargetView.swift` | Why the target went from 2,200 to 2,350, the evidence, and "Go back". | weekly-review |
| Body | `Features/Body/BodyView.swift` | "Rear delts only got 2 sets": face pulls added to Pull B. | weekly-review |
| Body scan | `Features/Body/BodyScanView.swift` | Spoken guidance while you turn (still frame here). | - |
| Scan result | `Features/Body/ScanResultView.swift` | "Waist down, arms holding": reading the trend, not the single scan. | weekly-review |
| Progress | `Features/Body/BodyProgressView.swift` | The marker where Div raised the target, and the caption explaining it. | weekly-review |

## The shape every change takes

Look at any lavender card and you can read off the fields Div's output needs (see `Div/schemas/`):

- **what changed**, as a before and after ("Set 3: 8 → 6 reps", "Overhead → landmine press")
- **one sentence of reason** ("You got 6 on set 2.")
- **when** and **which job** made it
- **status**: applied, undone, or asked (a question card like "Did Thursday's dinner slip through?")
- **whether it needed asking**, decided by code against the toggles in What Div knows, not by the prompt

## What the prototype does not do

- No data, store, sync, bridge or Claude calls. `AppEnvironment` is unused by the screens.
- The camera, LiDAR scan and microphone are still images.
- Dark mode works for the color tokens, but only the camera and voice screens were checked in dark.
