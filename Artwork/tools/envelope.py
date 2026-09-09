#!/usr/bin/env python3
"""Gift envelope artwork (1200x900) - closed and opened, plus the two layers
of the opened version so a card view can be sandwiched between them.

All shapes are computed here and written as SVG; the wax seal is a jittered
blob path with radial-gradient shading and the app mark embossed into it.
"""
import math, random, pathlib, sys
import mark

W, H = 1200, 900
X0, X1, Y0, Y1 = 100, 1100, 140, 800          # closed-envelope body
RAD = 18

PAPER      = "#EFE1C2"
PAPER_L    = "#E5D5B1"
PAPER_R    = "#EADCBC"
PAPER_B    = "#F2E6CB"
FLAP_HI    = "#F7EDD7"
FLAP_LO    = "#E7D8B6"
INNER      = "#D9C79F"
CARD_HI    = "#FBF6EA"
CARD_LO    = "#EFE7D4"
GOLD_HI    = "#F2D394"
GOLD_MID   = "#C89A4E"
GOLD_LO    = "#8E6524"
GOLD_DEEP  = "#5E3F10"


def f(v):
    return f"{v:.2f}"


def rrect(x, y, w, h, r):
    return (f"M{f(x+r)} {f(y)} H{f(x+w-r)} A{f(r)} {f(r)} 0 0 1 {f(x+w)} {f(y+r)} "
            f"V{f(y+h-r)} A{f(r)} {f(r)} 0 0 1 {f(x+w-r)} {f(y+h)} H{f(x+r)} "
            f"A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y+h-r)} V{f(y+r)} "
            f"A{f(r)} {f(r)} 0 0 1 {f(x+r)} {f(y)} Z")


def blob(cx, cy, r, n=22, jitter=0.045, seed=3):
    """Closed Catmull-Rom path with a jittered radius - a poured wax edge."""
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (1 + rnd.uniform(-jitter, jitter) +
                  0.028 * math.sin(3 * a + seed) + 0.018 * math.sin(5 * a))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = [f"M{f(pts[0][0])} {f(pts[0][1])}"]
    for i in range(n):
        p0, p1 = pts[(i - 1) % n], pts[i]
        p2, p3 = pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    return " ".join(d) + " Z"


def mark_markup(cx, cy, size, fg, dy=0.0, opacity=1.0):
    k = size / 476.0                       # mark at scale 1.15 spans 476/512
    inner = mark.build(fg=fg, scale=1.15)
    inner = inner.split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (f'<g opacity="{opacity}" transform="translate({f(cx - 256 * k)} '
            f'{f(cy - 256 * k + dy)}) scale({f(k)})">{inner}</g>')


def seal(cx, cy, r=112, seed=3, with_mark=True):
    """Gold wax seal with the mark embossed."""
    s = []
    s.append(f'<g filter="url(#sealShadow)">'
             f'<path d="{blob(cx, cy, r, seed=seed)}" fill="url(#gWax)"/></g>')
    s.append(f'<path d="{blob(cx, cy, r, seed=seed)}" fill="none" '
             f'stroke="url(#gRim)" stroke-width="3" opacity="0.55"/>')
    # recessed disc
    s.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.70)}" fill="url(#gWell)"/>')
    s.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.70)}" fill="none" '
             f'stroke="{GOLD_DEEP}" stroke-opacity="0.35" stroke-width="2.5"/>')
    if with_mark:
        d = r * 1.02
        s.append(mark_markup(cx, cy, d, "#FFFFFF", dy=2.6, opacity=0.30))
        s.append(mark_markup(cx, cy, d, GOLD_DEEP, dy=0.0, opacity=0.88))
    # specular
    s.append(f'<ellipse cx="{f(cx - r * 0.34)}" cy="{f(cy - r * 0.46)}" '
             f'rx="{f(r * 0.36)}" ry="{f(r * 0.22)}" fill="#FFFFFF" opacity="0.20" '
             f'transform="rotate(-24 {f(cx - r * 0.34)} {f(cy - r * 0.46)})"/>')
    return "\n".join(s)


DEFS = f'''<defs>
  <linearGradient id="gPaper" x1="0.1" y1="0" x2="0.85" y2="1">
    <stop offset="0" stop-color="#F6EBD5"/><stop offset="0.55" stop-color="{PAPER}"/>
    <stop offset="1" stop-color="#E3D2AC"/></linearGradient>
  <linearGradient id="gFlap" x1="0.2" y1="0" x2="0.7" y2="1">
    <stop offset="0" stop-color="{FLAP_HI}"/><stop offset="1" stop-color="{FLAP_LO}"/></linearGradient>
  <linearGradient id="gFlapIn" x1="0.25" y1="0" x2="0.75" y2="1">
    <stop offset="0" stop-color="#F0E2C4"/><stop offset="1" stop-color="#DCC9A0"/></linearGradient>
  <linearGradient id="gInner" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#C9B489"/><stop offset="1" stop-color="{INNER}"/></linearGradient>
  <linearGradient id="gCard" x1="0.2" y1="0" x2="0.8" y2="1">
    <stop offset="0" stop-color="{CARD_HI}"/><stop offset="1" stop-color="{CARD_LO}"/></linearGradient>
  <radialGradient id="gWax" cx="34%" cy="28%" r="86%">
    <stop offset="0" stop-color="{GOLD_HI}"/><stop offset="0.45" stop-color="{GOLD_MID}"/>
    <stop offset="0.86" stop-color="{GOLD_LO}"/><stop offset="1" stop-color="{GOLD_DEEP}"/></radialGradient>
  <radialGradient id="gWell" cx="62%" cy="70%" r="80%">
    <stop offset="0" stop-color="#D8A85E"/><stop offset="0.6" stop-color="#BE8F45"/>
    <stop offset="1" stop-color="#9A7030"/></radialGradient>
  <linearGradient id="gRim" x1="0.2" y1="0" x2="0.8" y2="1">
    <stop offset="0" stop-color="#FFE7B8"/><stop offset="1" stop-color="{GOLD_DEEP}"/></linearGradient>
  <filter id="sealShadow" x="-40%" y="-40%" width="180%" height="180%">
    <feDropShadow dx="0" dy="9" stdDeviation="11" flood-color="#5C4718" flood-opacity="0.42"/></filter>
  <filter id="softShadow" x="-25%" y="-25%" width="150%" height="150%">
    <feDropShadow dx="0" dy="16" stdDeviation="20" flood-color="#6B5C3C" flood-opacity="0.30"/></filter>
  <filter id="foldShadow" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="7"/></filter>
</defs>'''


def svg(body, w=W, h=H):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}" fill="none">\n{DEFS}\n{body}\n</svg>\n')


def closed():
    cx = (X0 + X1) / 2
    C = (cx, 470.0)            # where the three back panels meet
    CF = (cx, 512.0)           # flap apex, a little lower so it overlaps
    body = rrect(X0, Y0, X1 - X0, Y1 - Y0, RAD)
    p = [f'<g filter="url(#softShadow)"><path d="{body}" fill="url(#gPaper)"/></g>',
         f'<clipPath id="cBody"><path d="{body}"/></clipPath>',
         '<g clip-path="url(#cBody)">',
         f'<path d="M{X0} {Y1} L{X1} {Y1} L{f(C[0])} {f(C[1])} Z" fill="{PAPER_B}"/>',
         f'<path d="M{X0} {Y0} L{X0} {Y1} L{f(C[0])} {f(C[1])} Z" fill="{PAPER_L}"/>',
         f'<path d="M{X1} {Y0} L{X1} {Y1} L{f(C[0])} {f(C[1])} Z" fill="{PAPER_R}"/>',
         # fold shadows under the flap edges
         f'<g filter="url(#foldShadow)" opacity="0.45">'
         f'<path d="M{X0} {Y0+14} L{f(CF[0])} {f(CF[1]+16)} L{X1} {Y0+14} L{X1} {Y0+40} '
         f'L{f(CF[0])} {f(CF[1]+44)} L{X0} {Y0+40} Z" fill="#8C7742"/></g>',
         f'<path d="M{X0} {Y0} L{X1} {Y0} L{f(CF[0])} {f(CF[1])} Z" fill="url(#gFlap)"/>',
         # crisp fold lines
         f'<path d="M{X0} {Y1} L{f(C[0])} {f(C[1])} L{X1} {Y1}" fill="none" '
         f'stroke="#C6B084" stroke-opacity="0.55" stroke-width="2"/>',
         f'<path d="M{X0} {Y0} L{f(CF[0])} {f(CF[1])} L{X1} {Y0}" fill="none" '
         f'stroke="#C6B084" stroke-opacity="0.5" stroke-width="2"/>',
         '</g>',
         seal(cx, CF[1] - 6)]
    return svg("\n".join(p))


# ---- opened envelope -------------------------------------------------------
OX0, OX1 = 90, 1110
OY_BACK = 250                      # top edge of the back panel / flap hinge
OY_TOP, OY_BOT = 380, 830          # front pocket
OFLAP_APEX = 30                    # opened flap tip
CARD = (250, 110, 700, 530, 24)    # x, y, w, h, r


def open_back():
    """Opened flap + back panel - drawn behind the card."""
    cx = (OX0 + OX1) / 2
    p = [f'<g filter="url(#softShadow)">',
         f'<path d="{rrect(OX0, OY_BACK, OX1 - OX0, OY_BOT - OY_BACK, RAD)}" '
         f'fill="url(#gInner)"/>',
         f'<path d="M{OX0} {OY_BACK} L{f(cx)} {OFLAP_APEX} L{OX1} {OY_BACK} Z" '
         f'fill="url(#gFlapIn)"/>',
         '</g>',
         f'<path d="M{OX0} {OY_BACK} L{f(cx)} {OFLAP_APEX} L{OX1} {OY_BACK}" '
         f'fill="none" stroke="#C0A87C" stroke-opacity="0.55" stroke-width="2"/>']
    return svg("\n".join(p))


def card_only():
    x, y, w, h, r = CARD
    return svg(f'<g filter="url(#softShadow)"><path d="{rrect(x, y, w, h, r)}" '
               f'fill="url(#gCard)"/></g>')


def open_front():
    """Front pocket with the seal - drawn over the card."""
    cx = (OX0 + OX1) / 2
    pocket = rrect(OX0, OY_TOP, OX1 - OX0, OY_BOT - OY_TOP, RAD)
    p = [f'<g filter="url(#softShadow)"><path d="{pocket}" fill="url(#gPaper)"/></g>',
         f'<clipPath id="cPocket"><path d="{pocket}"/></clipPath>',
         '<g clip-path="url(#cPocket)">',
         f'<path d="M{OX0} {OY_TOP} L{f(cx)} {OY_BOT - 40} L{OX0} {OY_BOT} Z" fill="{PAPER_L}"/>',
         f'<path d="M{OX1} {OY_TOP} L{f(cx)} {OY_BOT - 40} L{OX1} {OY_BOT} Z" fill="{PAPER_R}"/>',
         f'<path d="M{OX0} {OY_BOT} L{f(cx)} {OY_BOT - 40} L{OX1} {OY_BOT} Z" fill="{PAPER_B}"/>',
         f'<path d="M{OX0} {OY_TOP} L{f(cx)} {OY_BOT - 40} L{OX1} {OY_TOP}" fill="none" '
         f'stroke="#C6B084" stroke-opacity="0.5" stroke-width="2"/>',
         '</g>',
         seal(cx, 632, r=106)]
    return svg("\n".join(p))


def open_full():
    cx = (OX0 + OX1) / 2
    x, y, w, h, r = CARD
    back = open_back().split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    front = open_front().split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    front = front.replace('id="cPocket"', 'id="cPocket2"').replace('url(#cPocket)', 'url(#cPocket2)')
    card = (f'<g filter="url(#softShadow)"><path d="{rrect(x, y, w, h, r)}" '
            f'fill="url(#gCard)"/></g>')
    return svg(back + "\n" + card + "\n" + front)


if __name__ == "__main__":
    out = pathlib.Path(__file__).resolve().parents[1] / "src"
    (out / "envelope-closed.svg").write_text(closed())
    (out / "envelope-open.svg").write_text(open_full())
    (out / "envelope-open-back.svg").write_text(open_back())
    (out / "envelope-open-front.svg").write_text(open_front())
    (out / "envelope-card.svg").write_text(card_only())
    print("wrote envelope svgs")
