# AZfit

iPhone app + Mac menu bar bridge. A fitness coach ("Div") that runs on the user's own Claude through `claude -p`. Spec: `docs/product-brief.html`. Decisions: `docs/decisions.md`. Architecture: `docs/architecture.md`. Design: `design/` (open `design/index.html`).

## Layout
- `App/` iPhone app, SwiftUI, thin. `Features/<Area>/`, shared UI in `DesignSystem/`.
- `AZKit/` packages: `AZModel` (types), `AZMath` (pure math), `AZStore` (GRDB), `AZSync` (wire types).
- `Div/` the agent: `prompts/`, `tools/`, `schemas/`, `evals/`. Read `Div/README.md` before touching Div.
- `Bridge/` `BridgeKit` package + `App/` menu bar shell.
- `project.yml` is the Xcode project. The `.xcodeproj` and Info.plists are generated: never edit them.

## Commands
- `make test` all package tests (works with only the Command Line Tools). `make test-AZKit` for one.
- `make lint` / `make format` swift-format, strict.
- `make gen` generate the Xcode project (needs Xcode to build the apps).
- `make design` rebuild the design HTML after editing `design/source/src/`.

## Rules
- Swift 6, strict concurrency. App targets default to MainActor; packages are nonisolated and `Sendable`.
- Logic goes in a package with a Swift Testing test, not in a view.
- Calorie and training math is deterministic Swift in `AZMath`. Div explains it; it does not compute it (D-010).
- Div returns its changes as a list, each with a one-sentence reason, and code (not the prompt) decides what it may do alone (D-008, D-009).
- Never delete what the user logged. Skips are gaps, undo is a status.
- No em dashes anywhere (code, copy, docs, prompts). Use "-". Tests and `make lint` check.
- Design rules (D-013): no yellow, no circles (icons and Div's eyes excepted), no emoji, lavender + Div mark means "Div changed this". Protein is a bar. Use `DesignSystem` tokens, no hex in features.
- Don't edit generated files: `*.xcodeproj`, `App/Info.plist`, `Bridge/Info.plist`, `design/screens/`, `design/index.html`.
- Record new decisions in `docs/decisions.md` as a new D-number.
