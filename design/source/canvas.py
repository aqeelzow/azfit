"""Lay out the screens as a canvas (canvas.json) for the published design artifact.
Run after `build.py pub`; writes design/.publish/canvas.json."""
import json, os
OUT = os.path.join(os.path.dirname(__file__), '..', '.publish')
os.makedirs(OUT, exist_ok=True)
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sections import SECTIONS, INTER
SRC = os.path.join(os.path.dirname(__file__), 'src')
boards, order, notes = {}, [], {}
y = 0
for si, (sec, items) in enumerate(SECTIONS):
    notes[f't{si}'] = {'x': 0, 'y': y, 'text': sec, 'kind': 'title1', 'maxW': 3300}
    for i, (n, t) in enumerate(items):
        x = i * 470
        b = {'x': x, 'y': y + 200, 'w': 390, 'h': 844, 'title': t}
        if n in INTER: b['is_interactive'] = True
        boards[f'{n}.dc.html'] = b; order.append(f'{n}.dc.html')
        if '<!--class: dark-->' not in open(os.path.join(SRC, n + '.html')).read():
            d = dict(b, y=y + 200 + 844 + 110, title=t + ' (dark)')
            boards[f'{n}Dark.dc.html'] = d
    for i, (n, t) in enumerate(items):
        if f'{n}Dark.dc.html' in boards: order.append(f'{n}Dark.dc.html')
    y += 200 + 844 + 110 + 844 + 300
x0 = len(SECTIONS[0][1]) * 470 + 60
notes['n1'] = {'x': x0, 'y': 200, 'w': 420, 'fill': 'gray', 'text':
  'Design language: calm and white, one idea per screen. Plain rows with hairlines instead of boxes. Figtree, fully rounded buttons, one purple accent with soft lavender fields. No yellow, no circles (no dots, rings or round crops), no emoji. Every screen has a light and a dark variant built from the same tokens; camera, scan and voice screens are always dark.'}
notes['n2'] = {'x': x0, 'y': 640, 'w': 420, 'fill': 'gray', 'text':
  "How Div shows its work. Lavender plus the small Div mark means 'Div touched this'. Every change shows four things: what changed, before and after (old value struck through), why in one sentence from your own data, and a way out (Undo / Keep mine). Examples: calorie target 2,200 to 2,350 on Eat and Why 2,350?; reps lowered on set 3 in Live workout; overhead press swapped for landmine press in Train, Exercise and Chat; Upper A moved to Sunday in Home and Train."}
notes['n3'] = {'x': x0, 'y': 1150, 'w': 420, 'fill': 'gray', 'text':
  "How much Div does on its own. 1) In-session tweaks (reps, weight, rest): applied and marked on the set. 2) Swaps and moved sessions: applied, logged, undoable for 7 days. 3) Calorie target: automatic within 200 kcal, bigger changes ask first. 4) Missing food or pain: Div never fills in data, it asks ('Did Thursday's dinner slip through?'). All of it is listed in Div's log and switchable in What Div knows."}
notes['n4'] = {'x': x0, 'y': 1720, 'w': 420, 'fill': 'gray', 'text':
  "Interactive boards: undo or keep Div's rep change in Live workout, go back to 2,200 in Why 2,350?, undo any change in Div's log, undo the swap in Chat and Exercise, flip autonomy switches in What Div knows, answer Div's question in Meal, pick options in Goal and Days."}
c = {'v': 3, 'createdOnFiles': {'v': 1, 'at': '2026-11-21T17:45:00Z'}, 'title': 'AZfit Screens', 'launch': {'view': 'canvas'},
     'pages': [], 'boards': boards, 'order': order, 'notes': notes, 'designSystems': []}
json.dump(c, open(os.path.join(OUT, 'canvas.json'), 'w'), indent=1)
print(len(boards), 'boards')
