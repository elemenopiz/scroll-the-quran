#!/usr/bin/env python3
"""Reading-plan covers (1200x800) and charity cards (1200x600).

Everything is procedural: hand-written SVG for structure (beads, girih
screens, dunes, lanterns, branches) rasterised with rsvg-convert, plus
ImageMagick for fractal noise, depth-of-field blur, grain and vignettes.
No photographs, no traced artwork, no text.
"""
import math, os, random, subprocess, sys, tempfile, pathlib

CW, CH = 1200, 800          # plan cover
KW, KH = 1200, 600          # charity card
TMP = tempfile.mkdtemp()


def t(name):
    return os.path.join(TMP, name)


def run(*a):
    subprocess.run([str(x) for x in a], check=True)


def rasterize(svg, out, w, h):
    p = t("s.svg")
    open(p, "w").write(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}" fill="none">{svg}</svg>')
    run("rsvg-convert", "-w", w, "-h", h, p, "-o", out)


GRAIN_SCALE = 0.6          # keep the texture, keep the PNGs small


def grain(path, args=8, atten=0.6):
    """Fine film grain, alpha preserved."""
    args = max(3, round(args * GRAIN_SCALE))
    run("magick", "-seed", "20260909", path, "(", "+clone", "-attenuate", atten, "+noise", "Gaussian", ")",
        "-compose", "Blend", "-define", f"compose:args={args}", "-composite",
        "-depth", "8", path)


def vignette(path, strength=0.28, w=CW, h=CH):
    """Wide, gentle corner falloff - never a spotlight."""
    m = t("vig.png")
    run("magick", "-size", f"{w}x{h}", "radial-gradient:white-black",
        "-gamma", "2.1", "+level", f"{100 - strength * 100:.0f}%,100%", m)
    run("magick", path, m, "-compose", "Multiply", "-composite", "-depth", "8", path)


def noise(out, w, h, seed, blur, lo, hi):
    run("magick", "-size", f"{w}x{h}", "-seed", seed, "plasma:fractal",
        "-colorspace", "Gray", "-blur", f"0x{blur}", "-auto-level",
        "-level", f"{lo}%,{hi}%", out)


# ---------------------------------------------------------------- 1. mushaf
def mushaf(out):
    rnd = random.Random(11)
    s = ['<defs>'
         '<linearGradient id="pg" x1="0.1" y1="0" x2="0.9" y2="1">'
         '<stop offset="0" stop-color="#FAF2E1"/><stop offset="0.45" stop-color="#F0E4C9"/>'
         '<stop offset="1" stop-color="#D9C6A2"/></linearGradient>'
         '<linearGradient id="gut" x1="0" y1="0" x2="1" y2="0">'
         '<stop offset="0" stop-color="#6E5A34" stop-opacity="0.55"/>'
         '<stop offset="0.55" stop-color="#6E5A34" stop-opacity="0.04"/>'
         '<stop offset="1" stop-color="#6E5A34" stop-opacity="0"/></linearGradient>'
         '</defs>',
         f'<rect width="{CW}" height="{CH}" fill="url(#pg)"/>']
    y = 84
    while y < CH + 30:
        # lines of short cursive-looking marks in word-sized groups
        x = 190 + rnd.random() * 40
        while x < CW - 130:
            wlen = rnd.uniform(55, 165)
            end = min(x + wlen, CW - 120)
            wx = x
            d = [f"M{wx:.0f} {y:.0f}"]
            while wx < end:
                step = 13 + rnd.random() * 17
                up = 7 + rnd.random() * 15
                d.append(f"q{step * 0.5:.1f} {-up:.1f} {step:.1f} "
                         f"{rnd.uniform(-3.5, 3.5):.1f}")
                wx += step
            s.append(f'<path d="{" ".join(d)}" stroke="#2E2718" '
                     f'stroke-opacity="{rnd.uniform(0.5, 0.72):.2f}" '
                     f'stroke-width="{4.4 + rnd.random() * 2.4:.1f}" '
                     f'stroke-linecap="round" fill="none"/>')
            x = wx + rnd.uniform(16, 34)
        # descenders and diacritic specks
        for _ in range(rnd.randint(6, 12)):
            dx = rnd.uniform(210, CW - 130)
            s.append(f'<circle cx="{dx:.0f}" cy="{y - rnd.uniform(13, 21):.0f}" '
                     f'r="{rnd.uniform(1.7, 2.9):.1f}" fill="#2E2718" fill-opacity="0.45"/>')
        for _ in range(rnd.randint(2, 4)):
            dx = rnd.uniform(210, CW - 130)
            s.append(f'<path d="M{dx:.0f} {y:.0f} q{rnd.uniform(-9, 9):.0f} 14 '
                     f'{rnd.uniform(-16, 16):.0f} 20" stroke="#2E2718" stroke-opacity="0.5" '
                     f'stroke-width="4" stroke-linecap="round" fill="none"/>')
        y += 50 + rnd.random() * 6
    s.append(f'<rect x="0" y="0" width="190" height="{CH}" fill="url(#gut)"/>')
    s.append(f'<rect x="150" y="0" width="5" height="{CH}" fill="#5E4C2A" fill-opacity="0.35"/>')
    rasterize("\n".join(s), t("m0.png"), CW, CH)
    # shallow depth of field: a sharp band across the middle
    run("magick", "-size", f"{CW}x{CH}", "gradient:white-black",
        "-function", "polynomial", "4.4,-4.4,1.02", t("dof.png"))
    run("magick", t("m0.png"), "(", t("m0.png"), "-blur", "0x13", ")", t("dof.png"),
        "-compose", "Over", "-composite", out)
    grain(out, 9, 0.7)
    vignette(out, 0.26)


# ------------------------------------------------------------------ 2. beads
def beads(out):
    rnd = random.Random(4)
    s = ['<defs>'
         '<linearGradient id="bg" x1="0.15" y1="0" x2="0.9" y2="1">'
         '<stop offset="0" stop-color="#2A2620"/><stop offset="0.55" stop-color="#171512"/>'
         '<stop offset="1" stop-color="#0B0A09"/></linearGradient>'
         '<radialGradient id="bead" cx="34%" cy="28%" r="72%">'
         '<stop offset="0" stop-color="#8E7B60"/><stop offset="0.45" stop-color="#4E4235"/>'
         '<stop offset="1" stop-color="#1B1712"/></radialGradient>'
         '<radialGradient id="glow" cx="50%" cy="50%" r="50%">'
         '<stop offset="0" stop-color="#C9A05A" stop-opacity="0.30"/>'
         '<stop offset="1" stop-color="#C9A05A" stop-opacity="0"/></radialGradient>'
         '</defs>',
         f'<rect width="{CW}" height="{CH}" fill="url(#bg)"/>',
         f'<ellipse cx="820" cy="240" rx="520" ry="380" fill="url(#glow)"/>']

    def strand(p0, p1, sag, n, r, op=1.0):
        out_ = []
        for i in range(n + 1):
            u = i / n
            x = p0[0] + (p1[0] - p0[0]) * u
            y = (p0[1] + (p1[1] - p0[1]) * u) + sag * math.sin(math.pi * u)
            out_.append((x, y))
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in out_)
        seg = [f'<path d="{d}" stroke="#6A5A44" stroke-opacity="{0.5*op:.2f}" '
               f'stroke-width="{max(1.5, r*0.18):.1f}" fill="none"/>']
        for x, y in out_:
            rr = r * rnd.uniform(0.93, 1.07)
            seg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rr:.1f}" '
                       f'fill="url(#bead)" opacity="{op}"/>')
            seg.append(f'<circle cx="{x - rr*0.30:.1f}" cy="{y - rr*0.34:.1f}" '
                       f'r="{rr*0.22:.1f}" fill="#E4CFA6" opacity="{0.30*op:.2f}"/>')
        return "".join(seg)

    back = strand((-60, 250), (1260, 200), 210, 26, 20, 0.55)
    front = strand((-40, 470), (1240, 430), 190, 22, 30)
    rasterize("\n".join(s) + back, t("b_bg.png"), CW, CH)
    rasterize("\n".join(s[:1]) + f'<rect width="{CW}" height="{CH}" fill="none"/>' + front,
              t("b_fg.png"), CW, CH)
    run("magick", t("b_bg.png"), "-blur", "0x9", t("b_bg.png"))
    run("magick", t("b_bg.png"), t("b_fg.png"), "-compose", "Over", "-composite", out)
    grain(out, 7, 0.7)
    vignette(out, 0.5)


# ------------------------------------------------------------------- 3. tile
def star_poly(cx, cy, R, n=8, ratio=0.4142, phase=0.0):
    pts = []
    for i in range(2 * n):
        a = phase + math.pi * i / n
        r = R if i % 2 == 0 else R * ratio
        pts.append(f"{cx + r*math.cos(a):.1f} {cy + r*math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


def tile(out):
    p = 300
    s = ['<defs>'
         '<linearGradient id="tg" x1="0.1" y1="0" x2="0.9" y2="1">'
         '<stop offset="0" stop-color="#F4EFE4"/><stop offset="0.5" stop-color="#E4DCCA"/>'
         '<stop offset="1" stop-color="#C8BCA1"/></linearGradient>'
         '<linearGradient id="lw" x1="0.05" y1="0" x2="0.95" y2="1">'
         '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.42"/>'
         '<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.06"/>'
         '<stop offset="1" stop-color="#4A4030" stop-opacity="0.16"/></linearGradient>'
         '</defs>',
         f'<rect width="{CW}" height="{CH}" fill="url(#tg)"/>',
         '<g stroke="#4A4030" stroke-opacity="0.40" stroke-width="4.4" fill="none">']
    ny = int(CH / p) + 3
    nx = int(CW / p) + 3
    for j in range(-1, ny):
        for i in range(-1, nx):
            cx, cy = i * p + p / 2, j * p + p / 2
            s.append(f'<path d="{star_poly(cx, cy, p*0.52)}"/>')
            s.append(f'<path d="{star_poly(cx + p/2, cy + p/2, p*0.235, 8, 0.4142, math.pi/8)}"/>')
            s.append(f'<rect x="{cx - p*0.19:.1f}" y="{cy - p*0.19:.1f}" '
                     f'width="{p*0.38:.1f}" height="{p*0.38:.1f}" '
                     f'transform="rotate(45 {cx:.1f} {cy:.1f})"/>')
    s.append('</g>')
    s.append(f'<rect width="{CW}" height="{CH}" fill="url(#lw)"/>')
    rasterize("\n".join(s), out, CW, CH)
    grain(out, 7, 0.6)
    vignette(out, 0.26)


# ------------------------------------------------------------------- 4. dawn
def dawn(out):
    s = ['<defs>'
         '<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#141C2E"/><stop offset="0.34" stop-color="#3B3A4A"/>'
         '<stop offset="0.60" stop-color="#8A6F58"/><stop offset="0.80" stop-color="#D79E5F"/>'
         '<stop offset="1" stop-color="#F2CE92"/></linearGradient>'
         '<radialGradient id="sun" cx="50%" cy="50%" r="50%">'
         '<stop offset="0" stop-color="#FFF3D4" stop-opacity="0.95"/>'
         '<stop offset="0.30" stop-color="#FFD79A" stop-opacity="0.55"/>'
         '<stop offset="1" stop-color="#FFB863" stop-opacity="0"/></radialGradient>'
         '<linearGradient id="haze" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#FFE6BE" stop-opacity="0"/>'
         '<stop offset="1" stop-color="#FFE6BE" stop-opacity="0.5"/></linearGradient>'
         '</defs>',
         f'<rect width="{CW}" height="{CH}" fill="url(#sky)"/>',
         '<ellipse cx="760" cy="690" rx="620" ry="420" fill="url(#sun)"/>',
         f'<rect x="0" y="560" width="{CW}" height="240" fill="url(#haze)"/>']
    # soft horizontal cloud slivers
    rnd = random.Random(9)
    for _ in range(14):
        y = rnd.uniform(300, 640)
        w = rnd.uniform(140, 520)
        x = rnd.uniform(-60, CW - 40)
        h = rnd.uniform(4, 13)
        op = rnd.uniform(0.05, 0.20) * (1 - abs(y - 470) / 420)
        s.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{w/2:.0f}" ry="{h:.0f}" '
                 f'fill="#FFE9CB" opacity="{max(op,0.02):.3f}"/>')
    rasterize("\n".join(s), t("d0.png"), CW, CH)
    run("magick", t("d0.png"), "-blur", "0x3", out)
    grain(out, 8, 0.7)
    vignette(out, 0.3)


# ---------------------------------------------------------------- 5. lantern
def lantern(out):
    cx, cy = 600, 400
    bw, bh = 250, 330
    s = ['<defs>'
         '<radialGradient id="lg" cx="50%" cy="48%" r="50%">'
         '<stop offset="0" stop-color="#FFD79B" stop-opacity="0.46"/>'
         '<stop offset="0.32" stop-color="#E8A55C" stop-opacity="0.20"/>'
         '<stop offset="1" stop-color="#B87A38" stop-opacity="0"/></radialGradient>'
         '<linearGradient id="lb" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#171310"/><stop offset="1" stop-color="#050505"/></linearGradient>'
         '<linearGradient id="bgl" x1="0.2" y1="0" x2="0.8" y2="1">'
         '<stop offset="0" stop-color="#241E17"/><stop offset="0.6" stop-color="#120F0C"/>'
         '<stop offset="1" stop-color="#070606"/></linearGradient>'
         '</defs>',
         f'<rect width="{CW}" height="{CH}" fill="url(#bgl)"/>',
         f'<ellipse cx="{cx}" cy="{cy+30}" rx="430" ry="380" fill="url(#lg)"/>',
         # chain
         f'<path d="M{cx} 0 L{cx} {cy-bh/2-96}" stroke="#2B241B" stroke-width="5"/>',
         f'<circle cx="{cx}" cy="{cy-bh/2-88}" r="16" fill="none" stroke="#2B241B" stroke-width="6"/>',
         # cap
         f'<path d="M{cx-92} {cy-bh/2-6} L{cx} {cy-bh/2-78} L{cx+92} {cy-bh/2-6} Z" fill="url(#lb)"/>',
         # body
         f'<path d="M{cx-bw/2} {cy-bh/2} L{cx+bw/2} {cy-bh/2} L{cx+bw/2-14} {cy+bh/2} '
         f'L{cx-bw/2+14} {cy+bh/2} Z" fill="url(#lb)"/>',
         # foot
         f'<path d="M{cx-70} {cy+bh/2} L{cx+70} {cy+bh/2} L{cx+44} {cy+bh/2+52} '
         f'L{cx-44} {cy+bh/2+52} Z" fill="url(#lb)"/>',
         f'<ellipse cx="{cx}" cy="{cy+bh/2+56}" rx="52" ry="10" fill="#0A0908"/>']
    # pierced star holes, glowing
    rnd = random.Random(6)
    holes = []
    for r_ in range(5):
        for c_ in range(4):
            inset = 10 * (r_ / 4.0)
            hx = cx - bw / 2 + 40 + inset + c_ * (bw - 80 - 2 * inset) / 3
            hy = cy - bh / 2 + 44 + r_ * (bh - 88) / 4
            big = (r_ + c_) % 2 == 0
            holes.append(f'<path d="{star_poly(hx, hy, 17 if big else 11, 8, 0.42, math.pi/8)}" '
                         f'fill="#FFDCA6" opacity="{rnd.uniform(0.80, 1.0):.2f}"/>')
    s += holes
    # warm light spilling from the body
    s.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{bw*0.62:.0f}" ry="{bh*0.60:.0f}" '
             f'fill="#FFC98A" opacity="0.10"/>')
    rasterize("\n".join(s), t("l0.png"), CW, CH)
    # bloom pass
    run("magick", t("l0.png"), "(", "+clone", "-blur", "0x22", "-evaluate", "multiply", "0.85", ")",
        "-compose", "Screen", "-composite", out)
    grain(out, 7, 0.7)
    vignette(out, 0.5)


# ---------------------------------------------------------------- 6. inkwash
def inkwash(out):
    """Sumi-e brush sweep: tapered stroke shapes give the silhouette, a
    direction-blurred noise field supplies the dry-brush streaking."""
    ang = 24
    run("magick", "-size", f"{CW}x{CH}", "gradient:#FBF7ED-#E7DECB", t("i_p.png"))
    # tapered brush strokes (white on black) -> the wash silhouette
    st = ['<g fill="#FFFFFF">']
    rnd = random.Random(5)
    for cy0, w0, w1, op in ((300, 150, 40, 1.0), (430, 210, 70, 1.0), (560, 96, 26, 0.8)):
        x0, x1 = -70, CW + 70
        st.append(f'<path d="M{x0} {cy0 - w0/2:.0f} '
                  f'C{CW*0.28:.0f} {cy0 - w0*0.86:.0f} {CW*0.62:.0f} {cy0 - w1*1.5:.0f} '
                  f'{x1} {cy0 - w1/2 - 160:.0f} '
                  f'L{x1} {cy0 + w1/2 - 160:.0f} '
                  f'C{CW*0.62:.0f} {cy0 + w1*1.6:.0f} {CW*0.28:.0f} {cy0 + w0*0.9:.0f} '
                  f'{x0} {cy0 + w0/2:.0f} Z" opacity="{op}"/>')
    st.append('</g>')
    rasterize(f'<rect width="{CW}" height="{CH}" fill="#000000"/>' + "".join(st),
              t("i_s.png"), CW, CH)
    run("magick", t("i_s.png"), "-colorspace", "Gray", "-blur", "0x14", t("i_s.png"))
    # dry-brush streaks along the stroke direction
    noise(t("i_n.png"), CW, CH, 33, 3, 20, 96)
    run("magick", t("i_n.png"), "-motion-blur", f"0x46+{ang}", "-auto-level",
        "+level", "26%,100%", t("i_n.png"))
    run("magick", t("i_s.png"), t("i_n.png"), "-compose", "Multiply", "-composite",
        "-level", "0%,58%", "-blur", "0x2", "-evaluate", "multiply", "0.97", t("i_m.png"))
    run("magick", "-size", f"{CW}x{CH}", "gradient:#2E2C28-#0A0908", t("i_ink.png"))
    run("magick", t("i_ink.png"), t("i_m.png"), "-alpha", "off",
        "-compose", "CopyAlpha", "-composite", t("i_l.png"))
    run("magick", t("i_p.png"), t("i_l.png"), "-compose", "Over", "-composite", out)
    grain(out, 10, 0.8)
    vignette(out, 0.2)


# ------------------------------------------------------------------- 7. dune
def dune(out):
    rnd = random.Random(15)
    s = ['<defs>'
         '<linearGradient id="dsky" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#E9D7B4"/><stop offset="0.55" stop-color="#F3E3C4"/>'
         '<stop offset="1" stop-color="#F7EBD2"/></linearGradient>'
         '<radialGradient id="dsun" cx="50%" cy="50%" r="50%">'
         '<stop offset="0" stop-color="#FFF6E0" stop-opacity="0.9"/>'
         '<stop offset="1" stop-color="#FFF0D2" stop-opacity="0"/></radialGradient>']
    bands = [("#EBD4AB", "#D2B482", 290), ("#E0C08C", "#B99461", 385),
             ("#CFA96C", "#96703F", 490), ("#B58B4E", "#6E4E27", 610),
             ("#8E6835", "#42301A", 730)]
    for i, (a, b, _) in enumerate(bands):
        s.append(f'<linearGradient id="dn{i}" x1="0.1" y1="0" x2="0.9" y2="1">'
                 f'<stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/>'
                 f'</linearGradient>')
    s.append('</defs>')
    s.append(f'<rect width="{CW}" height="{CH}" fill="url(#dsky)"/>')
    s.append('<ellipse cx="905" cy="185" rx="190" ry="160" fill="url(#dsun)"/>')
    s.append('<circle cx="905" cy="185" r="52" fill="#FFFAEC" opacity="0.85"/>')
    for i, (_, _, y0) in enumerate(bands):
        pts = []
        x = -80
        y = y0 + rnd.uniform(-20, 20)
        d = [f"M{x} {y:.0f}"]
        while x < CW + 80:
            dx = rnd.uniform(220, 400)
            dy = rnd.uniform(-90, 70) * (1 - i * 0.1)
            d.append(f"C{x+dx*0.42:.0f} {y-abs(dy)*0.9:.0f} {x+dx*0.60:.0f} {y+dy:.0f} "
                     f"{x+dx:.0f} {y+dy:.0f}")
            x += dx
            y += dy
        crest = " ".join(d)
        d.append(f"L{CW+80} {CH+40} L-80 {CH+40} Z")
        s.append(f'<path d="{" ".join(d)}" fill="url(#dn{i})"/>')
        s.append(f'<path d="{crest}" fill="none" stroke="#FFF3DA" '
                 f'stroke-opacity="{0.34 - i*0.05:.2f}" stroke-width="{3.4 - i*0.4:.1f}"/>')
    rasterize("\n".join(s), t("du0.png"), CW, CH)
    run("magick", t("du0.png"), "-blur", "0x1.5", out)
    grain(out, 11, 0.8)
    vignette(out, 0.24)


# ------------------------------------------------------------------ 8. olive
def _cubic(p0, p1, p2, p3, u):
    a, b = (1 - u), u
    x = (a**3 * p0[0] + 3*a*a*b * p1[0] + 3*a*b*b * p2[0] + b**3 * p3[0])
    y = (a**3 * p0[1] + 3*a*a*b * p1[1] + 3*a*b*b * p2[1] + b**3 * p3[1])
    dx = (3*a*a*(p1[0]-p0[0]) + 6*a*b*(p2[0]-p1[0]) + 3*b*b*(p3[0]-p2[0]))
    dy = (3*a*a*(p1[1]-p0[1]) + 6*a*b*(p2[1]-p1[1]) + 3*b*b*(p3[1]-p2[1]))
    return x, y, math.degrees(math.atan2(dy, dx))


def olive(out):
    rnd = random.Random(23)
    defs = ('<defs>'
            '<linearGradient id="og" x1="0.15" y1="0" x2="0.85" y2="1">'
            '<stop offset="0" stop-color="#F6F3EA"/><stop offset="0.5" stop-color="#E7E3D4"/>'
            '<stop offset="1" stop-color="#CBC7B4"/></linearGradient>'
            '<linearGradient id="lf" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#525C46"/><stop offset="1" stop-color="#2C3327"/>'
            '</linearGradient>'
            '<linearGradient id="lf2" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#697254"/><stop offset="1" stop-color="#3C4433"/>'
            '</linearGradient></defs>')

    def branch(p0, p1, p2, p3, n, scale, op, leaf="lf"):
        seg = [f'<path d="M{p0[0]:.0f} {p0[1]:.0f} C{p1[0]:.0f} {p1[1]:.0f} '
               f'{p2[0]:.0f} {p2[1]:.0f} {p3[0]:.0f} {p3[1]:.0f}" stroke="#3F4736" '
               f'stroke-opacity="{op}" stroke-width="{8 * scale:.1f}" fill="none" '
               f'stroke-linecap="round"/>']
        for i in range(n):
            u = 0.05 + 0.92 * i / (n - 1)
            x, y, th = _cubic(p0, p1, p2, p3, u)
            for k, side in enumerate((-1, 1)):
                ang = th + side * (46 + rnd.uniform(-10, 10))
                L = (108 + rnd.uniform(-20, 22)) * scale
                Wd = (27 + rnd.uniform(-4, 5)) * scale
                ox = x + math.cos(math.radians(ang)) * L * 0.52
                oy = y + math.sin(math.radians(ang)) * L * 0.52
                seg.append(f'<ellipse cx="{ox:.0f}" cy="{oy:.0f}" rx="{L/2:.0f}" '
                           f'ry="{Wd/2:.0f}" fill="url(#{leaf})" fill-opacity="{op}" '
                           f'transform="rotate({ang:.0f} {ox:.0f} {oy:.0f})"/>')
            if i % 3 == 1:
                ang = th + 90 * (1 if i % 2 else -1)
                ox = x + math.cos(math.radians(ang)) * 30 * scale
                oy = y + math.sin(math.radians(ang)) * 30 * scale
                seg.append(f'<ellipse cx="{ox:.0f}" cy="{oy:.0f}" rx="{15*scale:.0f}" '
                           f'ry="{18.5*scale:.0f}" fill="#333A28" fill-opacity="{op}"/>')
        return "".join(seg)

    bg = f'<rect width="{CW}" height="{CH}" fill="url(#og)"/>'
    back = branch((-80, 250), (240, 90), (700, 120), (1260, 360), 8, 1.2, 0.24, "lf2")
    mid = branch((-60, 780), (340, 700), (820, 760), (1270, 620), 8, 0.86, 0.45, "lf2")
    front = branch((-60, 700), (300, 470), (780, 620), (1270, 330), 11, 1.05, 0.95)
    rasterize(defs + bg + back + mid, t("o_b.png"), CW, CH)
    run("magick", t("o_b.png"), "-blur", "0x14", t("o_b.png"))
    rasterize(defs + front, t("o_f.png"), CW, CH)
    run("magick", t("o_b.png"), t("o_f.png"), "-compose", "Over", "-composite", out)
    grain(out, 8, 0.7)
    vignette(out, 0.24)


PLANS = [("mushaf-page", mushaf), ("prayer-beads", beads), ("geometric-tile", tile),
         ("dawn-light", dawn), ("lantern", lantern), ("ink-wash", inkwash),
         ("desert-dune", dune), ("olive-branch", olive)]


# ------------------------------------------------------------ charity cards
def charity_hands(out):
    """Two open palms cupped around a warm light - silhouette only, no faces."""
    rnd = random.Random(8)
    s = ['<defs>'
         '<linearGradient id="cg" x1="0.2" y1="0" x2="0.8" y2="1">'
         '<stop offset="0" stop-color="#221F1C"/><stop offset="0.55" stop-color="#141312"/>'
         '<stop offset="1" stop-color="#070707"/></linearGradient>'
         '<radialGradient id="cglow" cx="50%" cy="50%" r="50%">'
         '<stop offset="0" stop-color="#FFF3D8" stop-opacity="0.90"/>'
         '<stop offset="0.2" stop-color="#F2D293" stop-opacity="0.42"/>'
         '<stop offset="0.58" stop-color="#B78A45" stop-opacity="0.11"/>'
         '<stop offset="1" stop-color="#8E6F38" stop-opacity="0"/></radialGradient>'
         '<linearGradient id="hd" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#8A7D6C"/><stop offset="0.45" stop-color="#544A40"/>'
         '<stop offset="1" stop-color="#1A1815"/></linearGradient></defs>',
         f'<rect width="{KW}" height="{KH}" fill="url(#cg)"/>',
         '<ellipse cx="600" cy="290" rx="400" ry="270" fill="url(#cglow)"/>']

    def hand(sgn):
        """One open palm, fingers fanning up; sgn=-1 left, +1 right."""
        px, pw, ptop, pbot = 600 - sgn * 104, 196, 352, 566
        g = [f'<g transform="translate(600 616) scale(1.13) translate(-600 -616) '
             f'rotate({sgn * 19} 600 590)">',
             f'<path d="M{px - sgn*pw/2:.0f} {ptop} H{px + sgn*pw/2:.0f} '
             f'V{pbot - 46} Q{px + sgn*pw/2:.0f} {pbot} {px + sgn*(pw/2 - 46):.0f} {pbot} '
             f'H{px - sgn*(pw/2 - 40):.0f} Q{px - sgn*pw/2:.0f} {pbot} '
             f'{px - sgn*pw/2:.0f} {pbot - 46} Z" fill="url(#hd)"/>']
        for i in range(4):
            fx = px - sgn * (pw / 2 - 25) + sgn * i * 49
            L, Wd = (156, 180, 170, 140)[i], (41, 43, 41, 37)[i]
            fan = (-12, -4, 4, 13)[i] * sgn
            ex = fx + math.sin(math.radians(fan)) * L * 0.45
            ey = ptop - math.cos(math.radians(fan)) * L * 0.45
            g.append(f'<rect x="{ex - Wd/2:.0f}" y="{ey - L/2:.0f}" width="{Wd}" '
                     f'height="{L}" rx="{Wd/2}" fill="url(#hd)" stroke="#0C0B0A" '
                     f'stroke-opacity="0.55" stroke-width="3" '
                     f'transform="rotate({fan} {ex:.0f} {ey:.0f})"/>')
        tx, ty = px - sgn * (pw / 2 + 6), pbot - 130
        g.append(f'<rect x="{tx - 27:.0f}" y="{ty - 68:.0f}" width="54" height="136" rx="27" '
                 f'fill="url(#hd)" stroke="#0C0B0A" stroke-opacity="0.55" stroke-width="3" '
                 f'transform="rotate({-sgn * 58} {tx:.0f} {ty:.0f})"/>')
        g.append('</g>')
        return "".join(g)

    s.append(hand(-1))
    s.append(hand(1))
    s.append('<ellipse cx="600" cy="400" rx="190" ry="112" fill="url(#cglow)"/>')
    for _ in range(32):
        s.append(f'<circle cx="{rnd.uniform(400, 800):.0f}" cy="{rnd.uniform(50, 300):.0f}" '
                 f'r="{rnd.uniform(1.5, 4.4):.1f}" fill="#F8E9C6" '
                 f'opacity="{rnd.uniform(0.12, 0.7):.2f}"/>')
    rasterize("\n".join(s), t("h0.png"), KW, KH)
    run("magick", t("h0.png"), "(", "+clone", "-blur", "0x20", "-evaluate", "multiply", "0.5", ")",
        "-compose", "Screen", "-composite", out)
    grain(out, 8, 0.7)
    vignette(out, 0.34, KW, KH)


def charity_wheat(out):
    rnd = random.Random(12)
    s = ['<defs>'
         '<linearGradient id="wg" x1="0.1" y1="0" x2="0.9" y2="1">'
         '<stop offset="0" stop-color="#FAF1DA"/><stop offset="0.5" stop-color="#E9D8AE"/>'
         '<stop offset="1" stop-color="#C3A66F"/></linearGradient>'
         '<linearGradient id="st" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#9A7A3E"/><stop offset="1" stop-color="#5A4319"/>'
         '</linearGradient>'
         '<linearGradient id="grn" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#A98442"/><stop offset="1" stop-color="#6E5223"/>'
         '</linearGradient></defs>',
         f'<rect width="{KW}" height="{KH}" fill="url(#wg)"/>']

    def stalk(x, head_top, scale, op, lean):
        head_h = 190 * scale
        base = KH + 30
        seg = [f'<g transform="rotate({lean:.1f} {x:.0f} {base:.0f})">',
               f'<path d="M{x:.0f} {base:.0f} C{x - 9*scale:.0f} {(base+head_top)/2:.0f} '
               f'{x + 7*scale:.0f} {head_top + head_h*0.7:.0f} {x:.0f} {head_top:.0f}" '
               f'stroke="url(#st)" stroke-opacity="{op}" stroke-width="{5*scale:.1f}" '
               f'fill="none"/>']
        rows = 11
        for i in range(rows):
            gy = head_top + 6 * scale + i * (head_h / rows)
            taper = 0.55 + 0.45 * math.sin(math.pi * (i + 0.7) / rows)
            for side in (-1, 1):
                gx = x + side * 11 * scale * taper
                seg.append(f'<ellipse cx="{gx:.1f}" cy="{gy:.1f}" rx="{15*scale*taper:.1f}" '
                           f'ry="{7*scale*taper:.1f}" fill="url(#grn)" fill-opacity="{op}" '
                           f'transform="rotate({side*-38} {gx:.1f} {gy:.1f})"/>')
                seg.append(f'<path d="M{gx:.1f} {gy:.1f} l{side*26*scale*taper:.1f} '
                           f'{-40*scale*taper:.1f}" stroke="#8A6C33" '
                           f'stroke-opacity="{op*0.45:.2f}" stroke-width="{1.6*scale:.1f}"/>')
        seg.append(f'<path d="M{x:.0f} {head_top:.0f} l0 {-46*scale:.0f}" stroke="#8A6C33" '
                   f'stroke-opacity="{op*0.7:.2f}" stroke-width="{2.6*scale:.1f}"/>')
        seg.append('</g>')
        return "".join(seg)

    back = "".join(stalk(rnd.uniform(-40, KW + 40), rnd.uniform(150, 260),
                         rnd.uniform(0.70, 0.92), 0.30, rnd.uniform(-9, 9))
                   for _ in range(20))
    front = "".join(stalk(-40 + i * 108 + rnd.uniform(-24, 24), rnd.uniform(120, 230),
                          rnd.uniform(1.0, 1.28), 0.92, rnd.uniform(-8, 8))
                    for i in range(12))
    rasterize("\n".join(s) + back, t("w_b.png"), KW, KH)
    run("magick", t("w_b.png"), "-blur", "0x11", t("w_b.png"))
    rasterize("\n".join(s[:1]) + front, t("w_f.png"), KW, KH)
    run("magick", t("w_b.png"), t("w_f.png"), "-compose", "Over", "-composite", out)
    grain(out, 9, 0.7)
    vignette(out, 0.28, KW, KH)


def charity_water(out):
    rnd = random.Random(19)
    cx, cy = 560, 360
    s = ['<defs>'
         '<linearGradient id="aq" x1="0.2" y1="0" x2="0.8" y2="1">'
         '<stop offset="0" stop-color="#DCE6E5"/><stop offset="0.45" stop-color="#A9BCBF"/>'
         '<stop offset="1" stop-color="#5F7377"/></linearGradient>'
         '<radialGradient id="dl" cx="50%" cy="50%" r="50%">'
         '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.60"/>'
         '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
         '<linearGradient id="drp" x1="0.3" y1="0" x2="0.8" y2="1">'
         '<stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#BFD1D3"/>'
         '</linearGradient></defs>',
         f'<rect width="{KW}" height="{KH}" fill="url(#aq)"/>',
         f'<ellipse cx="{cx}" cy="{cy}" rx="470" ry="290" fill="url(#dl)"/>']
    for i in range(11):
        r = 40 + i * 62 + rnd.uniform(-9, 9)
        op = max(0.05, 0.66 - i * 0.056)
        ry = r * (0.31 + rnd.uniform(-0.02, 0.02))
        s.append(f'<ellipse cx="{cx + rnd.uniform(-5, 5):.0f}" cy="{cy + 4 + i*1.2:.0f}" '
                 f'rx="{r:.0f}" ry="{ry:.0f}" fill="none" stroke="#2E4145" '
                 f'stroke-opacity="{op*0.42:.2f}" stroke-width="{max(1.1, 5.4 - i*0.36):.1f}"/>')
        s.append(f'<ellipse cx="{cx:.0f}" cy="{cy:.0f}" rx="{r:.0f}" ry="{ry:.0f}" fill="none" '
                 f'stroke="#FFFFFF" stroke-opacity="{op:.2f}" '
                 f'stroke-width="{max(1.2, 5.8 - i*0.38):.1f}"/>')
    s.append(f'<ellipse cx="{cx}" cy="{cy}" rx="26" ry="9" fill="#FFFFFF" opacity="0.6"/>')
    # falling drop
    dx, dy = cx, 120
    s.append(f'<path d="M{dx} {dy - 62} C{dx+40} {dy-6} {dy*0+dx+62} {dy+30} {dx+62} {dy+56} '
             f'A62 62 0 0 1 {dx-62} {dy+56} C{dx-62} {dy+30} {dx-40} {dy-6} {dx} {dy-62} Z" '
             f'fill="url(#drp)" opacity="0.94"/>')
    s.append(f'<ellipse cx="{dx-20}" cy="{dy+40}" rx="16" ry="22" fill="#FFFFFF" opacity="0.6"/>')
    rasterize("\n".join(s), t("q0.png"), KW, KH)
    run("magick", t("q0.png"), "-blur", "0x1.4", out)
    grain(out, 8, 0.7)
    vignette(out, 0.3, KW, KH)


CHARITY = [("giving-hands", charity_hands), ("harvest-wheat", charity_wheat),
           ("clean-water", charity_water)]


def scrim(out, w=CW, h=CH):
    """Reusable bottom-weighted dark scrim so white titles read on any cover.
    Fully clear for the top ~45%, ramping to ~80% black at the bottom edge."""
    run("magick", "-size", f"{w}x{h}", "gradient:none-black",
        "-channel", "A", "-function", "polynomial", "1.34,-0.54,0", "+channel",
        "-depth", "8", out)


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[1]
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "plans"):
        d = root / "PlanCovers"; d.mkdir(exist_ok=True)
        for name, fn in PLANS:
            p = d / f"plan-{name}-1200x800.png"
            fn(str(p)); print("  ", p.name)
        scrim(str(d / "plan-cover-scrim-1200x800.png"))
    if which in ("all", "charity"):
        d = root / "Charity"; d.mkdir(exist_ok=True)
        for name, fn in CHARITY:
            p = d / f"charity-{name}-1200x600.png"
            fn(str(p)); print("  ", p.name)
        scrim(str(d / "charity-card-scrim-1200x600.png"), KW, KH)
