#!/usr/bin/env python3
"""Expand AZfit screen sources (src/*.html) into standalone .dc.html screens.

usage:
  python3 design/source/build.py        # repo: writes design/screens/, images from design/img/
  python3 design/source/build.py pub    # canvas artifact: writes design/.publish/, images as artifact blobs

Every screen is built twice, light and dark (except camera, scan and voice, which are always dark).
The build fails on an em dash or an unexpanded macro.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')
MODE = sys.argv[1] if len(sys.argv) > 1 else 'repo'
if MODE not in ('repo', 'pub'):
    raise SystemExit('usage: build.py [repo|pub]')
OUT = os.path.join(HERE, '..', '.publish' if MODE == 'pub' else 'screens')
os.makedirs(OUT, exist_ok=True)

IMG = {
    'avatar': 'd84e859d0debe785809dbbe2b8c18ea6', 'bar_pull': '26a17a2d42de3bce713c6a4997ae396d',
    'bowl': '45cfc534e6533c3d3632ebcef42acba2', 'chicken': 'b5644ac18b22b278f066598b5baca073',
    'curl': '655565eeeb636cd4768fc1d464783c94', 'dark_dl': 'a323e5b689bce81353cee881f78ee92c',
    'deadlift': '753b150006ae59e99020350702bfb0d6', 'eggs': '099c2b4f365f826d69604cc9d67aebdf',
    'fruit': '91071974b7a1029e3d926bd5688c1297', 'gym': 'aabee702cc88f15a650dc820d62fd558',
    'ohp': 'e113e66d3369d7626c20fa3f572e68a0', 'pullup': '58d88f75ab82a78e6eed31092c3c6a67',
    'pushup': 'e770e6466e7538c1bfbe60d0bee625fb', 'quinoa': '75e1b408c5c8a6c2a288a581563edc81',
    'salmon': '1d635962148b28dbf998ad9f409ad62e', 'squat': '0ceded38fcce265d09664d313a0d10c7',
    'woman_gym': '48724e887e27ef0786ce65b771509abd', 'wrap': 'e1f117782351535ab60cf56966a1edb5',
    'yogurt': 'd466fb1ff9d880447c35461f51bf1b2e',
}

def img(name):
    return '/_blob/' + IMG[name] if MODE == 'pub' else '../img/' + name + '.jpg'

ORANGE = '#FA6A16'

CSS = """
body{margin:0;background:#FFFFFF}
*{box-sizing:border-box}
button,input{font:inherit;color:inherit}
button{cursor:pointer;border:0;background:none;padding:0;text-align:inherit}
a{color:inherit;text-decoration:none}
img{display:block}
p,h1,h2{margin:0}
.scr{--bg:#FFFFFF;--ink:#1D1B22;--mut:#7D7A86;--lt:#B3B0BB;--fill:#F5F4F7;--track:#EEECF2;--line:#ECEAF0;--card:#FFFFFF;--peach:#EFEAFF;--peach2:#F5F2FF;--pk:#5B3FE0;--pm:#615885;--o:#7C5CFF;--o2:#A68FFF;--sun:#FFFFFF;--btn:#1D1B22;--btnk:#FFFFFF;--nav:#FFFFFF;--navsh:rgba(40,20,90,.08);--rest:#1D1B22;--rest2:#37343F;--ghost:#C7C4CE;--sunf:#EFEAFF;--sk:#5B3FE0;--spark:#FFFFFF;--carb:#B7A4FF;--fatc:#FF8FB1;--f0:#E9E7EE;--f1:#E4DCFF;--f2:#C9B9FF;--f3:#A68FFF;--f4:#7C5CFF;--f5:#5432D9;--fa:#FF9F6B;--fn:#DAD7E0}
.scr.dark{--bg:#111015;--ink:#F3F1F7;--mut:#9C98A6;--lt:#67636F;--fill:#1E1C23;--track:#2A2730;--line:#24222A;--card:#2C2934;--peach:#251E40;--peach2:#1F1935;--pk:#C3B4FF;--pm:#ADA3D6;--o:#8E72FF;--o2:#5A44C4;--sun:#3B3170;--btn:#F3F1F7;--btnk:#111015;--nav:#1A1820;--navsh:rgba(0,0,0,.5);--rest:#211F27;--rest2:#36333E;--ghost:#57535F;--sunf:#251E40;--sk:#C3B4FF;--spark:#352B5E;--carb:#6F5BD6;--fatc:#FF9CBB;--f0:#2C2933;--f1:#3A2F66;--f2:#4F3FA0;--f3:#6A54D6;--f4:#8E72FF;--f5:#B7A4FF;--fa:#FF9F6B;--fn:#36333E}
.scr{width:390px;height:844px;position:relative;overflow:hidden;background:var(--bg);color:var(--ink);font-family:"Figtree",ui-sans-serif,system-ui,sans-serif;-webkit-font-smoothing:antialiased;font-size:16px;line-height:1.4}
.n{font-variant-numeric:tabular-nums}
.sb{position:absolute;top:0;left:0;right:0;height:50px;padding:4px 28px 0 34px;display:flex;align-items:center;justify-content:space-between;font-size:15.5px;font-weight:600;z-index:30;color:var(--ink)}
.sb.w{color:#FFFFFF}
.hb{position:absolute;bottom:8px;left:50%;width:134px;height:5px;margin-left:-67px;border-radius:3px;background:var(--ink);z-index:40}
.hb.w{background:#FFFFFF}
.ib{width:44px;height:44px;border-radius:14px;background:var(--fill);display:grid;place-items:center;flex-shrink:0;color:var(--ink)}
.top{position:absolute;top:56px;left:24px;right:24px;display:flex;align-items:center;justify-content:space-between;gap:12px;z-index:20}
.btn{height:56px;border-radius:28px;background:var(--btn);color:var(--btnk);display:flex;align-items:center;justify-content:center;gap:10px;font-size:16.5px;font-weight:700;width:100%}
.btn.o{background:var(--o);color:#FFFFFF}
.btn.soft{background:var(--fill);color:var(--ink)}
.h1{font-size:34px;line-height:38px;font-weight:800;letter-spacing:-.025em}
.h2{font-size:22px;line-height:28px;font-weight:800;letter-spacing:-.02em}
.mut{color:var(--mut)}
.lt{color:var(--lt)}
.lab{font-size:14px;font-weight:600;color:var(--mut)}
.abs{position:absolute}
.row{display:flex;align-items:center}
.col{display:flex;flex-direction:column}
.cover{width:100%;height:100%;object-fit:cover}
.hr{height:1px;background:var(--line)}
.bar{height:8px;border-radius:4px;background:var(--track);overflow:hidden}
.bar>i{display:block;height:100%;border-radius:4px;background:var(--o)}
.am{display:inline-flex;vertical-align:-3px;margin-left:5px}
.was{color:var(--lt);text-decoration:line-through;text-decoration-thickness:1.5px;font-weight:500}
.chg{background:var(--peach);color:var(--pk);border-radius:8px;padding:1px 7px;font-weight:700}
.an{background:var(--peach);border-radius:24px;padding:14px 16px 14px 14px;display:flex;gap:12px;align-items:flex-start}
.an .bd{flex:1;display:flex;flex-direction:column;gap:3px;min-width:0}
.an b{font-size:15px;font-weight:700;line-height:20px}
.an p{font-size:14px;line-height:19px;color:var(--pm)}
.an .acts{display:flex;gap:8px;margin-top:8px}
.pb{height:34px;padding:0 14px;border-radius:17px;font-size:14px;font-weight:700;display:inline-flex;align-items:center;gap:6px;white-space:nowrap;flex-shrink:0}
.pb.k{background:var(--btn);color:var(--btnk)}
.pb.w{background:var(--card);color:var(--ink)}
.pb.f{background:var(--fill);color:var(--ink)}
.pb.p{background:var(--o);color:#FFFFFF}
.chip{height:36px;padding:0 14px;border-radius:18px;background:var(--fill);font-size:14px;font-weight:600;display:inline-flex;align-items:center;gap:6px;white-space:nowrap;flex-shrink:0}
.chip.on{background:var(--btn);color:var(--btnk)}
.seg{display:flex;height:44px;border-radius:22px;background:var(--fill);padding:4px}
.seg span{flex:1;border-radius:18px;display:grid;place-items:center;font-size:14px;font-weight:600;color:var(--mut)}
.seg span.on{background:var(--card);color:var(--ink);box-shadow:0 2px 8px rgba(30,20,60,.08)}
.sec{display:flex;justify-content:space-between;align-items:baseline}
.sec h3{margin:0;font-size:19px;font-weight:800;letter-spacing:-.015em}
.sec a,.sec span{font-size:14px;font-weight:600;color:var(--mut)}
.li{display:flex;align-items:center;gap:14px;min-height:64px}
.li+.li{box-shadow:inset 0 1px 0 var(--line)}
.ph{width:48px;height:48px;border-radius:14px;overflow:hidden;flex-shrink:0;background:var(--fill)}
.ttl{font-size:17px;font-weight:800;text-align:center}
.grab{position:absolute;top:8px;left:50%;width:40px;height:5px;margin-left:-20px;border-radius:3px;background:var(--track)}
.nav{position:absolute;left:0;right:0;bottom:0;height:112px;z-index:25}
.nav .bg{position:absolute;left:0;top:0;filter:drop-shadow(0 -4px 18px var(--navsh))}
.nav .plus{position:absolute;left:165px;top:10px;width:60px;height:60px;border-radius:20px;background:var(--o);color:#FFFFFF;display:grid;place-items:center}
.nav .t{position:absolute;top:36px;width:50px;height:50px;display:grid;place-items:center;color:var(--lt)}
.nav .t.on{color:var(--ink)}
.nav .t.on::after{content:"";position:absolute;bottom:-3px;left:17px;width:16px;height:4px;border-radius:2px;background:var(--o)}
"""

FONTS = '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700;800;900&amp;display=swap">'

ICONS = {
    'home': ('<path d="M4 10.4 12 4l8 6.4V19a2 2 0 0 1-2 2h-3.5v-5.5h-5V21H6a2 2 0 0 1-2-2z"/>', False),
    'dumbbell': ('<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9.5v5M20.5 9.5v5M6.5 12h11"/>', False),
    'fork': ('<path d="M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10M17 3c-2.5 2-2.5 7 0 9v9"/>', False),
    'user': ('<circle cx="12" cy="7.5" r="3.5"/><path d="M5 20.5c0-3.9 3.1-6.5 7-6.5s7 2.6 7 6.5"/>', False),
    'plus': ('<path d="M12 5v14M5 12h14"/>', False),
    'back': ('<path d="M14.5 6 8.5 12l6 6"/>', False),
    'chev': ('<path d="M9.5 6l6 6-6 6"/>', False),
    'chevd': ('<path d="M6 9.5l6 6 6-6"/>', False),
    'chevu': ('<path d="M6 14.5l6-6 6 6"/>', False),
    'gear': ('<circle cx="12" cy="12" r="3"/><path d="M12 2.8l2 1.2 2.3-.3 1.2 2 2 1.2-.3 2.3 1.2 2-1.2 2 .3 2.3-2 1.2-1.2 2-2.3-.3-2 1.2-2-1.2-2.3.3-1.2-2-2-1.2.3-2.3L2.8 12l1.2-2-.3-2.3 2-1.2 1.2-2 2.3.3z"/>', False),
    'bell': ('<path d="M6.5 16v-5a5.5 5.5 0 0 1 11 0v5l1.5 2h-14zM10 20.5h4"/>', False),
    'mic': ('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>', False),
    'arrow': ('<path d="M5 12h14M13 6l6 6-6 6"/>', False),
    'arrowu': ('<path d="M12 19V5M6 11l6-6 6 6"/>', False),
    'check': ('<path d="M5 12.5 9.5 17 19 7.5"/>', False),
    'close': ('<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>', False),
    'flame': ('<path d="M12.3 2.5c.6 3.3 5.2 5.4 5.2 10.4A5.5 5.5 0 0 1 6.5 13c0-2.3 1.1-3.9 2.3-5 .1 1.7.9 2.8 2.1 3.3-.1-3.2.2-6 1.4-8.8z"/>', True),
    'drop': ('<path d="M12 3.2c3 3.7 6 7 6 10.6a6 6 0 0 1-12 0c0-3.6 3-6.9 6-10.6z"/>', True),
    'bolt': ('<path d="M13.5 2.5 5 13.5h6l-1 8 8.5-11h-6z"/>', True),
    'star': ('<path d="M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4l-5.3 3 1.2-6-4.5-4.1 6-.7z"/>', True),
    'spark': ('<path d="M12 2.5c.7 4.6 2.9 6.8 7.5 7.5-4.6.7-6.8 2.9-7.5 7.5-.7-4.6-2.9-6.8-7.5-7.5 4.6-.7 6.8-2.9 7.5-7.5zM19 15.5c.3 1.9 1.2 2.8 3 3-1.8.3-2.7 1.2-3 3-.3-1.8-1.2-2.7-3-3 1.8-.2 2.7-1.1 3-3z"/>', True),
    'clock': ('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', False),
    'cal': ('<rect x="4" y="5.5" width="16" height="14.5" rx="3"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>', False),
    'search': ('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>', False),
    'camera': ('<path d="M4 8.5A1.5 1.5 0 0 1 5.5 7h2.3l1.6-2.5h5.2L16.2 7h2.3A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"/><circle cx="12" cy="12.8" r="3.4"/>', False),
    'swap': ('<path d="M7.5 4 4 7.5 7.5 11M4 7.5h13M16.5 13l3.5 3.5-3.5 3.5M20 16.5H7"/>', False),
    'more': ('<circle cx="5.5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18.5" cy="12" r="1.4"/>', True),
    'sliders': ('<path d="M4 7h9M18 7h2M4 17h3M12 17h8"/><circle cx="15.5" cy="7" r="2.5"/><circle cx="9.5" cy="17" r="2.5"/>', False),
    'share': ('<path d="M12 15V4M7.5 8 12 3.5 16.5 8M5 12.5V18a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5.5"/>', False),
    'flash': ('<path d="M13 3 6 13h5l-1 8 7-10h-5z"/>', False),
    'image': ('<rect x="4" y="4.5" width="16" height="15" rx="3"/><circle cx="9" cy="9.5" r="1.6"/><path d="M5 17l4.5-4.5 3 3 2.5-2.5L20 18"/>', False),
    'scan': ('<path d="M4 8.5V6a2 2 0 0 1 2-2h2.5M15.5 4H18a2 2 0 0 1 2 2v2.5M20 15.5V18a2 2 0 0 1-2 2h-2.5M8.5 20H6a2 2 0 0 1-2-2v-2.5"/><circle cx="12" cy="9" r="2"/><path d="M8.5 16.5c.5-2 1.8-3 3.5-3s3 1 3.5 3"/>', False),
    'depth': ('<path d="M12 3.5 20 8v8l-8 4.5L4 16V8z"/><path d="M4 8l8 4.5L20 8M12 12.5v8"/>', False),
    'heart': ('<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.4 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>', True),
    'pulse': ('<path d="M3 12h4l2.5-6 4 12 2.5-6h5"/>', False),
    'target': ('<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor"/>', False),
    'barbell': ('<path d="M2.5 12h19M5 8v8M8 6.5v11M16 6.5v11M19 8v8"/>', False),
    'play': ('<path d="M8 5.5v13l10.5-6.5z"/>', True),
    'pause': ('<rect x="7" y="5.5" width="3.6" height="13" rx="1.2"/><rect x="13.4" y="5.5" width="3.6" height="13" rx="1.2"/>', True),
    'grid': ('<rect x="4" y="4" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="2"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="2"/>', False),
    'mac': ('<rect x="3.5" y="5" width="17" height="11" rx="2"/><path d="M2 19h20"/>', False),
    'phone': ('<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>', False),
    'wifi': ('<path d="M3.5 9.5a12 12 0 0 1 17 0M6.5 12.7a7.6 7.6 0 0 1 11 0M9.5 15.8a3.3 3.3 0 0 1 5 0"/><circle cx="12" cy="19" r="1" fill="currentColor"/>', False),
    'lock': ('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>', False),
    'trend': ('<path d="M3.5 16.5l5.5-5.5 4 4 7.5-7.5M15 7.5h5.5V13"/>', False),
    'trendd': ('<path d="M3.5 7.5l5.5 5.5 4-4 7.5 7.5M15 16.5h5.5V11"/>', False),
    'edit': ('<path d="M4 20h4L19 9l-4-4L4 16z"/>', False),
    'scale': ('<rect x="3.5" y="4" width="17" height="16" rx="4"/><path d="M8.5 10a5 5 0 0 1 7 0L13 12.5"/>', False),
    'text': ('<path d="M5 6.5h14M5 11h14M5 15.5h9"/>', False),
    'list': ('<path d="M9 6.5h11M9 12h11M9 17.5h11"/><circle cx="4.8" cy="6.5" r="1" fill="currentColor"/><circle cx="4.8" cy="12" r="1" fill="currentColor"/><circle cx="4.8" cy="17.5" r="1" fill="currentColor"/>', False),
    'moon': ('<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>', False),
    'brain': ('<path d="M9 4.5a3 3 0 0 0-3 3 3 3 0 0 0-2 5.2A3 3 0 0 0 6.5 18 3 3 0 0 0 12 19V5.5a3 3 0 0 0-3-1zM15 4.5a3 3 0 0 1 3 3 3 3 0 0 1 2 5.2 3 3 0 0 1-2.5 5.3A3 3 0 0 1 12 19"/>', False),
    'undo': ('<path d="M8 5 4 9l4 4"/><path d="M4 9h10a5.5 5.5 0 0 1 0 11H9"/>', False),
}

def icon(name, size=22, color='currentColor', sw=None):
    body, filled = ICONS[name]
    s = int(size)
    if sw is None:
        sw = 2.0 if s >= 18 else 2.4
    if filled:
        return f'<svg aria-hidden="true" width="{s}" height="{s}" viewBox="0 0 24 24" fill="{color}">{body}</svg>'
    return f'<svg aria-hidden="true" width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{body}</svg>'

SB_SVG = ('<svg aria-hidden="true" width="68" height="12" viewBox="0 0 68 12" fill="currentColor">'
          '<rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/>'
          '<rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y=".5" width="3" height="11.5" rx="1"/>'
          '<path d="M29.6 3.6a9.2 9.2 0 0 1 12.3 0l-1.4 1.5a7.1 7.1 0 0 0-9.5 0zM32.2 6.4a5.4 5.4 0 0 1 7.1 0l-1.4 1.5a3.3 3.3 0 0 0-4.3 0zM35.75 11.2l-1.9-1.9a2.7 2.7 0 0 1 3.8 0z"/>'
          '<rect x="45.5" y=".5" width="19" height="11" rx="3.6" fill="none" stroke="currentColor" opacity=".45"/>'
          '<rect x="47.2" y="2.2" width="15.6" height="7.6" rx="2.2"/><rect x="65.6" y="4" width="1.6" height="4" rx=".8" opacity=".45"/></svg>')

def sb(white=False):
    return f'<div class="sb{" w" if white else ""}"><span>9:41</span>{SB_SVG}</div>'

NAV_PATH = 'M0 48C0 34.7 10.7 24 24 24H124C139 24 145 30 149 42C155 62 168 80 195 80C222 80 235 62 241 42C245 30 251 24 266 24H366C379.3 24 390 34.7 390 48V112H0Z'
TABS = [('home', 'Home.dc.html', 'Home', 22), ('dumbbell', 'Train.dc.html', 'Train', 92), ('fork', 'Eat.dc.html', 'Eat', 248), ('user', 'Body.dc.html', 'Body', 318)]

def nav(active):
    out = [f'<nav class="nav" aria-label="Main"><svg class="bg" aria-hidden="true" width="390" height="112" viewBox="0 0 390 112"><path d="{NAV_PATH}" style="fill:var(--nav)"/></svg>']
    for ic, href, label, x in TABS:
        on = ic == active
        out.append(f'<a class="t{" on" if on else ""}" href="{href}" aria-label="{label}"{" aria-current=\"page\"" if on else ""} style="left:{x}px">{icon(ic, 24, sw=2.1)}</a>')
    if active == 'x':
        out.append(f'<a class="plus" href="Home.dc.html" aria-label="Close">{icon("close", 24, sw=2.6)}</a>')
    else:
        out.append(f'<a class="plus" href="QuickAdd.dc.html" aria-label="Quick add">{icon("plus", 26, sw=2.6)}</a>')
    out.append('<div class="hb"></div></nav>')
    return ''.join(out)



# ---------- Div, the AI buddy ----------
DIV_PATH = 'M-4 112L0 58L-8 40L14 40L22 18L38 32L56 12L62 38L84 34L76 56L96 70L80 82L84 112Z'
_aid = [0]
def div_face(mood, line):
    E = ((40, 56), (60, 52))
    if mood == 'side':
        return ''.join(f'<circle cx="{x}" cy="{y}" r="10" fill="#FFFFFF"/><circle cx="{x-3.4}" cy="{y+1}" r="5" fill="#16141A"/>' for x, y in E)
    if mood == 'wow':
        return ''.join(f'<circle cx="{x}" cy="{y}" r="12" fill="#FFFFFF"/><circle cx="{x}" cy="{y}" r="3.6" fill="#16141A"/>' for x, y in E) + f'<ellipse cx="51" cy="78" rx="5" ry="6" fill="{line}"/>'
    if mood == 'proud':
        return ''.join(f'<path d="M{x-8} {y+2}Q{x} {y-8} {x+8} {y+2}" fill="none" stroke="{line}" stroke-width="4.5" stroke-linecap="round"/>' for x, y in E) + f'<path d="M42 72Q51 82 60 70" fill="none" stroke="{line}" stroke-width="4.5" stroke-linecap="round"/>'
    if mood == 'rest':
        return ''.join(f'<path d="M{x-8} {y-1}Q{x} {y+6} {x+8} {y-1}" fill="none" stroke="{line}" stroke-width="4.5" stroke-linecap="round"/>' for x, y in E)
    return ''.join(f'<circle cx="{x}" cy="{y}" r="10" fill="#FFFFFF"/><circle cx="{x+2.8}" cy="{y-3}" r="5" fill="#16141A"/>' for x, y in E)

def div(size, mood='curious', bg='var(--o)', body='#16141A', r=30, inset=True):
    _aid[0] += 1
    cid = f'ar{_aid[0]}'
    w = float(size)
    line = '#FFFFFF' if body == '#16141A' else '#16141A'
    g = f'<g transform="translate(-4 20) scale(.84)">' if inset else '<g>'
    return (f'<svg aria-hidden="true" width="{w:g}" height="{w:g}" viewBox="0 0 100 100" style="display:block;flex-shrink:0"><defs><clipPath id="{cid}"><rect width="100" height="100" rx="{r}"/></clipPath></defs>'
            f'<g clip-path="url(#{cid})"><rect width="100" height="100" style="fill:{bg}"/>{g}<path d="{DIV_PATH}" style="fill:{body};stroke:{body}" stroke-width="12" stroke-linejoin="round"/>{div_face(mood, line)}</g></g></svg>')

def dmark(size=18):
    return f'<span class="am" title="Changed by Div" aria-label="Changed by Div">{div(size, r=32, inset=False)}</span>'

# ---------- body figure ----------
NEUTRAL = 'M96 11 h8 a13 13 0 0 1 13 13 v12 a13 13 0 0 1 -13 13 h-8 a13 13 0 0 1 -13 -13 v-12 a13 13 0 0 1 13 -13 Z M42 183 h2 a5 5 0 0 1 5 5 v8 a5 5 0 0 1 -5 5 h-2 a5 5 0 0 1 -5 -5 v-8 a5 5 0 0 1 5 -5 Z M156 183 h2 a5 5 0 0 1 5 5 v8 a5 5 0 0 1 -5 5 h-2 a5 5 0 0 1 -5 -5 v-8 a5 5 0 0 1 5 -5 Z M75 350 h6 a5 5 0 0 1 5 5 v2 a5 5 0 0 1 -5 5 h-6 a5 5 0 0 1 -5 -5 v-2 a5 5 0 0 1 5 -5 Z M119 350 h6 a5 5 0 0 1 5 5 v2 a5 5 0 0 1 -5 5 h-6 a5 5 0 0 1 -5 -5 v-2 a5 5 0 0 1 5 -5 Z'
FRONT = [
    'M90 48 C85 54 77 57 67 60 C77 62 86 62 93 60 Z',
    'M64 62 C53 63 45 72 45 86 C45 92 46 96 49 99 C53 88 59 80 68 74 C69 69 67 64 64 62 Z',
    'M72 66 C84 63 94 63 98 66 L98 95 C90 100 79 99 71 94 C65 90 64 82 67 74 Z',
    'M49 104 C53 100 58 100 60 106 C62 117 60 128 56 135 C52 137 48 136 46 132 C44 121 45 111 49 104 Z',
    'M45 141 C49 139 54 139 56 143 C56 158 52 175 48 187 C45 189 42 188 41 185 C39 170 40 155 45 141 Z',
    'M86 101 h10 a2 2 0 0 1 2 2 v12 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M86 119 h12 v14 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M86 137 h12 v14 h-12 a3 3 0 0 1 -3 -3 v-8 a3 3 0 0 1 3 -3 Z M87 155 h11 v18 c-5 0 -11 -3 -12 -8 v-7 a3 3 0 0 1 1 -3 Z',
    'M70 101 C75 104 79 106 80 110 L80 160 C78 166 75 168 72 166 C67 150 66 121 70 101 Z',
    'M71 181 C79 176 92 178 96 186 C98 211 94 240 88 258 C82 262 76 262 72 258 C64 236 63 205 71 181 Z',
    'M72 276 C78 272 86 274 88 280 C88 300 84 330 80 349 C77 351 74 351 72 347 C68 326 68 296 72 276 Z',
]
BACK = [
    'M100 45 C94 52 82 58 67 62 C80 66 92 76 100 102 Z',
    'M64 62 C53 63 45 72 45 86 C45 92 46 96 49 99 C53 88 59 80 68 74 C69 69 67 64 64 62 Z',
    'M71 78 C80 84 91 97 98 106 L98 132 C92 140 84 146 78 148 C72 130 67 101 71 78 Z',
    'M49 104 C53 100 58 100 61 106 C63 117 61 128 57 135 C53 137 48 136 46 132 C44 121 45 111 49 104 Z',
    'M45 141 C49 139 54 139 56 143 C56 158 52 175 48 187 C45 189 42 188 41 185 C39 170 40 155 45 141 Z',
    'M85 138 C90 139 95 140 98 142 L98 166 C92 167 86 165 83 161 C83 152 83 145 85 138 Z',
    'M72 170 C82 166 94 169 98 173 L98 205 C90 211 78 209 72 203 C68 193 68 180 72 170 Z',
    'M72 213 C80 211 92 213 95 217 C96 237 92 254 86 262 C80 264 76 263 73 260 C67 244 67 227 72 213 Z',
    'M72 276 C80 270 88 274 90 282 C90 300 86 320 80 342 C76 344 73 343 72 340 C66 318 66 294 72 276 Z',
]
RAMP = ['var(--f0)', 'var(--f1)', 'var(--f2)', 'var(--f3)', 'var(--f4)', 'var(--f5)']
ATROPHY = 'var(--fa)'

def fig(kind, fid, w, h, levels, neutral='var(--f0)', label=''):
    paths = FRONT if kind == 'f' else BACK
    if set(levels) == {'0'}:
        neutral = 'var(--fn)'
    parts = [f'<path d="{NEUTRAL}" style="fill:{neutral}"/>']
    for d, lv in zip(paths, levels):
        c = ATROPHY if lv == 'a' else (RAMP[int(lv)] if lv != '0' else neutral)
        parts.append(f'<path d="{d}" style="fill:{c}"/>')
    aria = f'role="img" aria-label="{label}"' if label else 'aria-hidden="true"'
    return (f'<svg {aria} viewBox="30 4 140 362" width="{w}" height="{h}"><g id="{fid}">{"".join(parts)}</g>'
            f'<use href="#{fid}" transform="translate(200 0) scale(-1 1)"/></svg>')

def figdot(fid, w, h, color):
    d = ' '.join(BACK)
    return (f'<svg aria-hidden="true" viewBox="30 4 140 362" width="{w}" height="{h}"><defs><pattern id="{fid}p" width="4" height="4" patternUnits="userSpaceOnUse">'
            f'<circle cx="2" cy="2" r=".95" fill="{color}"/></pattern></defs><g id="{fid}"><path d="{NEUTRAL}" fill="url(#{fid}p)"/><path d="{d}" fill="url(#{fid}p)"/></g>'
            f'<use href="#{fid}" transform="translate(200 0) scale(-1 1)"/></svg>')

def expand(s):
    s = s.replace('%SBW%', sb(True)).replace('%SB%', sb(False))
    s = s.replace('%HBW%', '<div class="hb w"></div>').replace('%HB%', '<div class="hb"></div>')
    s = re.sub(r'%NAV:(\w+)%', lambda m: nav(m.group(1)), s)
    s = re.sub(r'%DIV:(\d+)(?::(\w+))?(?::([^:%]+))?(?::([^:%]+))?%', lambda m: div(m.group(1), m.group(2) or 'curious', m.group(3) or 'var(--o)', m.group(4) or '#16141A'), s)
    s = re.sub(r'%DMARK(?::(\d+))?%', lambda m: dmark(int(m.group(1) or 18)), s)
    s = re.sub(r'%IMG:(\w+)%', lambda m: img(m.group(1)), s)
    s = re.sub(r'%BACK:([\w.]+)%', lambda m: f'<a class="ib" href="{m.group(1)}" aria-label="Back">{icon("back", 20, sw=2.4)}</a>', s)
    s = re.sub(r'%BACKD:([\w.]+)%', lambda m: f'<a class="ib d" href="{m.group(1)}" aria-label="Back">{icon("back", 20, sw=2.4)}</a>', s)
    s = re.sub(r'%I:(\w+)(?::([\d.]+))?(?::(#[0-9A-Fa-f]{3,8})?)?(?::([\d.]+))?%',
               lambda m: icon(m.group(1), float(m.group(2) or 22), m.group(3) or 'currentColor', float(m.group(4)) if m.group(4) else None), s)
    s = re.sub(r'%FIG(F|B):(\w+):(\d+):(\d+):([0-9a]{9})(?::([^%]*))?%',
               lambda m: fig(m.group(1).lower(), m.group(2), m.group(3), m.group(4), m.group(5), label=m.group(6) or ''), s)
    s = re.sub(r'%FIGD:(\w+):(\d+):(\d+):(#[0-9A-Fa-f]{6})%', lambda m: figdot(m.group(1), m.group(2), m.group(3), m.group(4)), s)
    return s

def build(fn, dark=False):
    raw = open(os.path.join(SRC, fn)).read()
    if dark and '<!--class: dark-->' in raw:
        return
    m = re.match(r'<!--title: (.*?)-->\s*', raw)
    title = m.group(1) if m else fn
    raw = raw[m.end():] if m else raw
    cls = 'scr dark' if dark else 'scr'
    if dark: title += ' (dark)'
    m2 = re.match(r'<!--class: (.*?)-->\s*', raw)
    if m2:
        cls += ' ' + m2.group(1)
        raw = raw[m2.end():]
    extra = ''
    m3 = re.search(r'<!--css-->(.*?)<!--/css-->', raw, re.S)
    if m3:
        extra = m3.group(1).strip()
        raw = raw[:m3.start()] + raw[m3.end():]
    if '<!--script-->' in raw:
        markup, script = raw.split('<!--script-->', 1)
    else:
        markup, script = raw, 'class Component extends DCLogic {\n  renderVals() { return {}; }\n}\n'
    markup = expand(markup).strip()
    if 'dark' in cls.split():
        extra += 'body{background:#111015}'  # the page around a dark screen matches it, no white bleed at the edges
    html = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            f'<title>AZfit {title}</title>\n<script src="./support.js"></script>\n</head>\n<body>\n<x-dc>\n'
            f'<helmet>\n{FONTS}\n<style>{CSS}{extra}</style>\n</helmet>\n'
            f'<div class="{cls}">\n{markup}\n</div>\n</x-dc>\n'
            '<script type="text/x-dc" data-dc-script data-props=\'{"$preview":{"width":390,"height":844}}\'>\n'
            f'{script.strip()}\n</script>\n</body>\n</html>\n')
    if '—' in html:
        raise SystemExit(f'em dash in {fn}')
    left = re.findall(r'%[A-Z]+:[^%\s]*%|%(?:SB|SBW|HB|HBW)%', html)
    if left:
        raise SystemExit(f'unexpanded macros in {fn}: {left[:5]}')
    open(os.path.join(OUT, fn.replace('.html', 'Dark.dc.html' if dark else '.dc.html')), 'w').write(html)

for fn in sorted(os.listdir(SRC)):
    if fn.endswith('.html'):
        build(fn)
        build(fn, True)
print('built', MODE, len([f for f in os.listdir(SRC) if f.endswith('.html')]))

# ---------- gallery (repo mode): design/index.html ----------
if MODE == 'repo':
    sys.path.insert(0, HERE)
    from sections import SECTIONS, INTER

    def has_dark(n):
        return '<!--class: dark-->' not in open(os.path.join(SRC, n + '.html')).read()

    cards = []
    for sec, items in SECTIONS:
        tiles = []
        for n, t in items:
            dark = f'screens/{n}Dark.dc.html' if has_dark(n) else f'screens/{n}.dc.html'
            tag = '<span class="tag">Interactive</span>' if n in INTER else ''
            always = '' if has_dark(n) else '<span class="tag">Always dark</span>'
            tiles.append(
                f'<figure><a class="frame" href="screens/{n}.dc.html" data-light="screens/{n}.dc.html" data-dark="{dark}">'
                f'<iframe src="screens/{n}.dc.html" data-light="screens/{n}.dc.html" data-dark="{dark}" title="{t}" loading="lazy" tabindex="-1"></iframe></a>'
                f'<figcaption>{t}{tag}{always}</figcaption></figure>')
        cards.append(f'<section><h2>{sec}</h2><div class="grid">{"".join(tiles)}</div></section>')
    total = sum(len(i) for _, i in SECTIONS)
    gallery = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AZfit Screens</title>
<!-- Generated by design/source/build.py. Do not edit by hand. -->
{FONTS}
<style>
:root{{--page:#F3F2F6;--ink:#1D1B22;--mut:#7D7A86;--fill:#FFFFFF;--line:#E4E2EA;--accent:#7C5CFF;--tint:#EFEAFF;--tink:#5B3FE0}}
:root[data-theme="dark"]{{--page:#1C1A21;--ink:#F3F1F7;--mut:#9C98A6;--fill:#2C2934;--line:#2E2B35;--accent:#8E72FF;--tint:#251E40;--tink:#C3B4FF}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--page);color:var(--ink);font-family:Figtree,system-ui,sans-serif;-webkit-font-smoothing:antialiased}}
main{{max-width:1240px;margin:0 auto;padding:56px 24px 96px}}
header{{display:flex;flex-wrap:wrap;gap:16px 24px;align-items:end;justify-content:space-between;margin-bottom:24px}}
h1{{font-size:34px;font-weight:800;letter-spacing:-.03em;margin:0 0 6px}}
header p{{margin:0;color:var(--mut);font-size:15px;max-width:620px;line-height:1.45}}
header p a{{color:var(--tink);font-weight:600;text-decoration:none}}
.seg{{display:inline-flex;background:var(--fill);border-radius:999px;padding:4px}}
.seg button{{font:inherit;font-size:14px;font-weight:700;border:0;background:none;color:var(--mut);padding:8px 18px;border-radius:999px;cursor:pointer}}
.seg button[aria-pressed="true"]{{background:var(--ink);color:var(--page)}}
section{{border-top:1px solid var(--line);padding-top:28px;margin-top:40px}}
h2{{font-size:20px;font-weight:800;letter-spacing:-.02em;margin:0 0 20px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(195px,1fr));gap:32px 24px}}
figure{{margin:0}}
.frame{{display:block;width:195px;height:422px;border-radius:24px;overflow:hidden;background:var(--fill)}}
.frame:focus-visible{{outline:2px solid var(--accent);outline-offset:3px}}
iframe{{width:390px;height:844px;border:0;transform:scale(.5);transform-origin:0 0;pointer-events:none;display:block}}
figcaption{{margin-top:12px;font-size:14px;font-weight:700;display:flex;flex-wrap:wrap;gap:6px;align-items:center}}
.tag{{font-size:11.5px;font-weight:700;color:var(--tink);background:var(--tint);border-radius:6px;padding:2px 7px}}
@media (max-width:480px){{.grid{{grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:24px 16px}}.frame{{width:150px;height:325px;border-radius:18px}}iframe{{transform:scale(.3846)}}}}
</style>
</head>
<body>
<main>
<header>
<div><h1>AZfit screens</h1>
<p>{total} screens, each in light and dark. Click one to open it full size; interactive screens respond to taps. Brand and mascot: <a href="brand/brand.html">brand</a>. Spec: <a href="../docs/product-brief.html">product brief</a>.</p></div>
<div class="seg" role="group" aria-label="Appearance"><button type="button" data-mode="light" aria-pressed="true">Light</button><button type="button" data-mode="dark" aria-pressed="false">Dark</button></div>
</header>
{"".join(cards)}
</main>
<script>
function setMode(m){{
  document.documentElement.dataset.theme = m;
  document.querySelectorAll('.seg button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.mode === m)));
  document.querySelectorAll('[data-light]').forEach(el => {{
    const url = el.dataset[m];
    if (el.tagName === 'IFRAME') {{ if (el.getAttribute('src') !== url) el.setAttribute('src', url); }}
    else el.setAttribute('href', url);
  }});
  try {{ localStorage.setItem('azfit-gallery-mode', m); }} catch (e) {{}}
}}
document.querySelectorAll('.seg button').forEach(b => b.addEventListener('click', () => setMode(b.dataset.mode)));
let saved = null;
try {{ saved = localStorage.getItem('azfit-gallery-mode'); }} catch (e) {{}}
if (saved === 'dark' || (!saved && matchMedia('(prefers-color-scheme: dark)').matches)) setMode('dark');
</script>
</body>
</html>
'''
    if '—' in gallery:
        raise SystemExit('em dash in gallery')
    open(os.path.join(HERE, '..', 'index.html'), 'w').write(gallery)
    print('wrote design/index.html')
