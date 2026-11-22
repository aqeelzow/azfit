# Design

The approved AZfit design (v3), as plain HTML. Open `index.html` in a browser. No server needed.

```
design/
├── index.html          gallery of every screen, light and dark (generated)
├── screens/            one standalone page per screen and mode (generated)
│   └── support.js      tiny runtime that makes the interactive screens work offline
├── img/                photos used by the screens (stock, placeholder only)
├── brand/
│   ├── brand.html      Div, the app icon, logo and expressions (approved)
│   └── lab.html        the first mascot exploration, six directions (history; "Spark" became Div)
└── source/             what the screens are built from
    ├── build.py        expands src/ into screens/ and index.html
    ├── sections.py     screen list and order, shared by the gallery and the canvas
    ├── canvas.py       lays the screens out for the published canvas artifact
    └── src/*.html      one file per screen, with %MACROS% for icons, status bar and Div
```

The same screens are published as a canvas at https://claude.ai/artifact/6mdv9yaLXpBTZLt2Jai955. That canvas still says "Arnie"; this folder is current.

## Changing a screen

1. Edit `source/src/<Screen>.html`. Never edit `screens/` or `index.html` by hand.
2. `make design` (or `python3 design/source/build.py`).
3. Open the screen in light and dark and look at it at 390 × 844.

The build fails on an em dash or a macro it did not expand.

Macros worth knowing: `%DIV:size:mood%` draws Div (moods: curious, side, wow, proud, rest), `%DMARK%` is the small "Changed by Div" mark, `%I:name:size%` is an icon, `%IMG:name%` a photo, `%SB%` / `%HB%` the status bar and home bar.

## Rules the design follows

These are product decisions (docs/decisions.md D-013), not taste. The Swift UI follows them too.

- Calm and white. One idea per screen. Rows with hairlines instead of boxes.
- Figtree. One purple accent (`#7C5CFF`, dark `#8E72FF`) and soft lavender for anything Div touched.
- **No yellow. No circles**: no dots, rings, round avatars or round crops. Icons and Div's eyes are the only round things. The protein ring from the brief is a bar.
- No emoji, no streaks, no guilt copy. "-" instead of an em dash.
- Div appears only as an avatar and as the change mark. Lavender plus the mark means "Div changed this", and every change shows what, before and after, why, and a way out (Undo / Keep mine).
- Every screen has a dark variant from the same tokens. Camera, scan and voice are always dark.

## Publishing the canvas

`python3 design/source/build.py pub && python3 design/source/canvas.py` writes `design/.publish/` (ignored by git), which is what the canvas artifact is made from.
