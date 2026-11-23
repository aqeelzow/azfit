# AZfit

A coach that reads every set you log, and runs on your own Claude.

AZfit logs training, food and body measurements on your iPhone. A small free app on your Mac (the bridge) runs Div, the AI coach, through your own Claude Code subscription. Div reads your data and adjusts your plan, and every change is marked, explained and undoable.

- Product brief: [docs/product-brief.html](docs/product-brief.html)
- Features and decisions: [docs/decisions.md](docs/decisions.md)
- How it fits together: [docs/architecture.md](docs/architecture.md)
- Div, the agent: [Div/README.md](Div/README.md)
- Design (open in a browser): [design/index.html](design/index.html)

## Setup

Needs macOS 26 and Xcode 26 to build the apps. The packages also build and test with only the Command Line Tools.

```sh
make bootstrap   # XcodeGen + package resolve
make test        # all package tests
make open        # generate AZfit.xcodeproj and open it
```

In Xcode, set your team on the AZfit and AZfitBridge targets, then run the AZfit scheme on an iPhone and AZfitBridge on your Mac. The bridge needs [Claude Code](https://claude.com/claude-code) installed and signed in.

## Repo

```
App/       iPhone app (SwiftUI)
Bridge/    Mac menu bar app + BridgeKit
AZKit/     shared Swift packages: model, math, store, sync
Div/       the agent: prompts, tools, schema, evals
design/    approved screens as HTML
docs/      brief, decisions, architecture
```

`make help` lists every command.
