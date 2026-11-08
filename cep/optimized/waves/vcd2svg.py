#!/usr/bin/env python3
"""vcd2svg.py - draw selected signals of a VCD file as a waveform SVG.
usage: python3 vcd2svg.py waves.vcd out.svg t_start t_end title sig1 sig2 ...
       a signal may be written name:fmt with fmt = hex (default) or dec"""
import sys, html
vcd, out, t0, t1, title = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
sigs = sys.argv[6:]
ids, width, name_of = {}, {}, {}
changes = {}
t = 0
scope = []
with open(vcd) as f:
    for line in f:
        p = line.split()
        if not p: continue
        if p[0] == '$scope': scope.append(p[2])
        elif p[0] == '$upscope': scope.pop()
        elif p[0] == '$var' and scope[-1:] == ['tb_waves']:
            ids.setdefault(p[4], p[3]); width[p[3]] = int(p[2]); changes.setdefault(p[3], [])
        elif p[0].startswith('#'): t = int(p[0][1:])
        elif p[0][0] in '01xzXZ' and len(p) == 1 and not p[0].startswith('$'):
            changes.get(p[0][1:], []).append((t, p[0][0]))
        elif p[0][0] in 'bB' and len(p) == 2:
            changes.get(p[1], []).append((t, p[0][1:]))
def value_at(code, tt):
    v = None
    for ct, cv in changes[code]:
        if ct <= tt: v = cv
        else: break
    return v
NAME_W, ROW_H, W = 150, 34, 1100
X = lambda tt: NAME_W + (tt - t0) * (W - NAME_W - 10) / (t1 - t0)
H = 40 + ROW_H * len(sigs) + 20
o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="DejaVu Sans Mono" font-size="12">',
     f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
     f'<text x="10" y="22" font-family="DejaVu Sans" font-size="15" font-weight="bold">{html.escape(title)}</text>']
# time grid every clock (20 ns) when zoomed in, labels
step = 20 if (t1 - t0) <= 1200 else max(20, ((t1 - t0) // 20) // 20 * 20)
g = (t0 // 20) * 20
while g <= t1:
    if g >= t0:
        o.append(f'<line x1="{X(g):.1f}" y1="34" x2="{X(g):.1f}" y2="{H-14}" stroke="#eceff4"/>')
    g += step
o.append(f'<text x="{NAME_W}" y="{H-3}" fill="#5b6475" font-size="10">{t0//1000} ns</text>')
o.append(f'<text x="{W-10}" y="{H-3}" fill="#5b6475" font-size="10" text-anchor="end">{t1//1000} ns</text>')
for r, s in enumerate(sigs):
    name, fmt = (s.split(':') + ['hex'])[:2]
    code = ids[name]; w = width[code]
    y = 40 + r * ROW_H; hi, lo = y + 6, y + ROW_H - 8
    o.append(f'<text x="8" y="{(hi+lo)/2+4:.0f}" font-weight="bold">{html.escape(name)}</text>')
    pts = [(t0, value_at(code, t0))] + [(ct, cv) for ct, cv in changes[code] if t0 < ct < t1]
    for i, (ct, cv) in enumerate(pts):
        nt = pts[i+1][0] if i + 1 < len(pts) else t1
        xa, xb = X(ct), X(nt)
        if w == 1:
            yy = hi if cv == '1' else lo
            col = '#2457a6' if name != 'clk' else '#1d2330'
            if cv in ('x', 'z', None):
                o.append(f'<rect x="{xa:.1f}" y="{hi}" width="{xb-xa:.1f}" height="{lo-hi}" fill="#f6d5cc"/>')
            else:
                o.append(f'<line x1="{xa:.1f}" y1="{yy}" x2="{xb:.1f}" y2="{yy}" stroke="{col}" stroke-width="1.6"/>')
                if i > 0 and pts[i-1][1] != cv:
                    o.append(f'<line x1="{xa:.1f}" y1="{hi}" x2="{xa:.1f}" y2="{lo}" stroke="{col}" stroke-width="1.6"/>')
        else:
            known = cv is not None and all(c in '01' for c in cv)
            fill = '#eef3fb' if known else '#f6d5cc'
            o.append(f'<polygon points="{xa+3:.1f},{hi} {xb-3:.1f},{hi} {xb:.1f},{(hi+lo)/2} {xb-3:.1f},{lo} {xa+3:.1f},{lo} {xa:.1f},{(hi+lo)/2}" fill="{fill}" stroke="#2457a6"/>')
            if known:
                n = int(cv, 2); txt = str(n) if fmt == 'dec' else f'{n:0{(w+3)//4}X}'
            else:
                txt = 'X'
            if xb - xa > 8 * len(txt) + 6:
                o.append(f'<text x="{(xa+xb)/2:.1f}" y="{(hi+lo)/2+4:.0f}" text-anchor="middle">{txt}</text>')
o.append('</svg>')
open(out, 'w').write('\n'.join(o))
