# Schemas

The JSON shape every Div run must return. The bridge passes it to `claude -p --json-schema`, so Claude's answer is always JSON the app can read, never prose.

See docs/decisions.md D-008: Div returns its changes as a list, each with a reason, instead of changing data through tools.
