#!/usr/bin/env python3
"""iPhone frame overlay: 1179x2556 transparent PNG, titanium rail + black
bezel + Dynamic Island.  The centre aperture is transparent so a screenshot
placed *behind* it shows through."""
W, H = 1179, 2556
RAIL, BEZEL = 12, 18            # rail band, then black bezel
INSET = RAIL + BEZEL            # 30 -> aperture 1119 x 2496
R_OUT = 190
R_IN1 = R_OUT - RAIL
R_APT = R_OUT - INSET
DI_W, DI_H, DI_Y = 375, 111, INSET + 36

def rr(x, y, w, h, r, sweep=1):
    """Rounded-rect sub-path; sweep=0 reverses winding for even-odd holes."""
    if sweep:
        return (f"M{x+r} {y} H{x+w-r} A{r} {r} 0 0 1 {x+w} {y+r} V{y+h-r} "
                f"A{r} {r} 0 0 1 {x+w-r} {y+h} H{x+r} A{r} {r} 0 0 1 {x} {y+h-r} "
                f"V{y+r} A{r} {r} 0 0 1 {x+r} {y} Z")
    return (f"M{x+r} {y} A{r} {r} 0 0 0 {x} {y+r} V{y+h-r} A{r} {r} 0 0 0 {x+r} {y+h} "
            f"H{x+w-r} A{r} {r} 0 0 0 {x+w} {y+h-r} V{y+r} A{r} {r} 0 0 0 {x+w-r} {y} Z")

def build():
    a = INSET
    p = []
    p.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
             f'viewBox="0 0 {W} {H}" fill="none">')
    p.append('<defs>')
    p.append('<linearGradient id="rail" x1="0" y1="0" x2="1" y2="0.08">'
             '<stop offset="0" stop-color="#B9B6AF"/>'
             '<stop offset="0.14" stop-color="#F0EEE9"/>'
             '<stop offset="0.34" stop-color="#C2BFB8"/>'
             '<stop offset="0.52" stop-color="#EEECE7"/>'
             '<stop offset="0.72" stop-color="#BEBBB4"/>'
             '<stop offset="0.88" stop-color="#EDEBE5"/>'
             '<stop offset="1" stop-color="#AFACA5"/></linearGradient>')
    p.append('<linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">'
             '<stop offset="0" stop-color="#6E6C68"/>'
             '<stop offset="0.5" stop-color="#C6C4BF"/>'
             '<stop offset="1" stop-color="#7A7873"/></linearGradient>')
    p.append(f'<clipPath id="apt"><path d="{rr(a,a,W-2*a,H-2*a,R_APT)}"/></clipPath>')
    p.append('</defs>')
    # side buttons, drawn under the rail so they read as part of the edge
    for x, y, h in ((0, 640, 96), (0, 812, 150), (0, 1000, 150), (W-9, 858, 250)):
        p.append(f'<rect x="{x}" y="{y}" width="9" height="{h}" rx="4.5" fill="url(#btn)"/>')
    # titanium rail: outer rounded rect with the inner one knocked out
    p.append(f'<path fill-rule="evenodd" fill="url(#rail)" d="{rr(0,0,W,H,R_OUT)} '
             f'{rr(RAIL,RAIL,W-2*RAIL,H-2*RAIL,R_IN1,0)}"/>')
    # black bezel between rail and aperture
    p.append(f'<path fill-rule="evenodd" fill="#08080A" '
             f'd="{rr(RAIL,RAIL,W-2*RAIL,H-2*RAIL,R_IN1)} '
             f'{rr(a,a,W-2*a,H-2*a,R_APT,0)}"/>')
    # hairline where the bezel meets the glass
    p.append(f'<path d="{rr(a,a,W-2*a,H-2*a,R_APT)}" fill="none" stroke="#000000" '
             f'stroke-opacity="0.55" stroke-width="3"/>')
    # Dynamic Island
    p.append(f'<rect x="{(W-DI_W)/2}" y="{DI_Y}" width="{DI_W}" height="{DI_H}" '
             f'rx="{DI_H/2}" fill="#000000"/>')
    p.append('</svg>')
    return "\n".join(p)

if __name__ == "__main__":
    import pathlib, sys
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    s = build()
    (out.write_text(s) if out else sys.stdout.write(s))
