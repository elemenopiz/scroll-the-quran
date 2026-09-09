#!/usr/bin/env python3
"""Generate the Scroll the Quran mark: an interlaced rub' al-hizb octagram
(two squares woven over/under) enclosing a crescent.  Pure geometry, no
tracing of any third-party artwork."""
import math, sys

CX = CY = 256.0
R  = 200.0                 # circumradius of both squares
H  = R / math.sqrt(2.0)    # half-side of the axis-aligned square

def f(v): return f"{v:.4f}"

def geometry(w):
    a0, a1 = CX - H, CX + H            # axis-aligned square extents
    cross_a = R - H                    # offset of a crossing along a side
    # crossings, clockwise from the top-left crossing on the top edge
    xs = [(CX - cross_a, a0), (CX + cross_a, a0),
          (a1, CY - cross_a), (a1, CY + cross_a),
          (CX + cross_a, a1), (CX - cross_a, a1),
          (a0, CY + cross_a), (a0, CY - cross_a)]
    return a0, a1, xs[0::2], xs[1::2]

def crescent_paths(cr_out, cr_cut, cr_d, cr_ang, ox, oy, fg):
    dx = cr_d * math.cos(math.radians(cr_ang))
    dy = cr_d * math.sin(math.radians(cr_ang))
    return (f'<mask id="mc" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">'
            f'<circle cx="{f(CX+ox)}" cy="{f(CY+oy)}" r="{f(cr_out)}" fill="#fff"/>'
            f'<circle cx="{f(CX+ox+dx)}" cy="{f(CY+oy+dy)}" r="{f(cr_cut)}" fill="#000"/></mask>'
            f'<circle cx="{f(CX+ox)}" cy="{f(CY+oy)}" r="{f(cr_out)}" fill="{fg}" mask="url(#mc)"/>')


def build(fg="#000000", w=14.0, gap=5.0, crescent=True,
          cr_out=84.0, cr_cut=79.0, cr_d=27.0, cr_ang=-32.0,
          cr_ox=9.0, cr_oy=0.0, size=512, scale=1.0,
          bg=None, bg_radius=0.0):
    a0, a1, a_over, b_over = geometry(w)
    side = a1 - a0
    A = (f"M{f(a0)} {f(a0)} L{f(a1)} {f(a0)} L{f(a1)} {f(a1)} "
         f"L{f(a0)} {f(a1)} Z")
    B = (f"M{f(CX)} {f(CY-R)} L{f(CX+R)} {f(CY)} L{f(CX)} {f(CY+R)} "
         f"L{f(CX-R)} {f(CY)} Z")
    ew = w + 2 * gap
    rc = ew * 0.75 + 6
    def clip(pts, name):
        c = "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(rc)}"/>' for x, y in pts)
        return f'<clipPath id="{name}">{c}</clipPath>'
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
           f'viewBox="0 0 512 512" fill="none">']
    if bg:
        out.append(f'<rect x="0" y="0" width="512" height="512" rx="{f(bg_radius)}" '
                   f'ry="{f(bg_radius)}" fill="{bg}"/>')
    out.append(f'<g transform="translate({f(CX)} {f(CY)}) scale({f(scale)}) '
               f'translate({f(-CX)} {f(-CY)})">')
    out += ['<defs>',
           clip(b_over, "cbo"), clip(a_over, "cao"),
           f'<mask id="mA" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">'
           f'<rect width="512" height="512" fill="#fff"/>'
           f'<g clip-path="url(#cbo)"><path d="{B}" stroke="#000" stroke-width="{f(ew)}" '
           f'stroke-linejoin="miter" stroke-miterlimit="10"/></g></mask>',
           f'<mask id="mB" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">'
           f'<rect width="512" height="512" fill="#fff"/>'
           f'<g clip-path="url(#cao)"><path d="{A}" stroke="#000" stroke-width="{f(ew)}" '
           f'stroke-linejoin="miter" stroke-miterlimit="10"/></g></mask>',
           '</defs>',
           f'<g stroke="{fg}" stroke-width="{f(w)}" stroke-linejoin="miter" stroke-miterlimit="10">',
           f'<path d="{A}" mask="url(#mA)"/>',
           f'<path d="{B}" mask="url(#mB)"/>',
           '</g>']
    if crescent:
        out.append(crescent_paths(cr_out, cr_cut, cr_d, cr_ang, cr_ox, cr_oy, fg))
    out.append('</g>')
    out.append('</svg>')
    return "\n".join(out)

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--fg", default="#000000")
    p.add_argument("--w", type=float, default=14.0)
    p.add_argument("--gap", type=float, default=5.0)
    p.add_argument("--no-crescent", action="store_true")
    p.add_argument("--cr-out", type=float, default=84.0)
    p.add_argument("--cr-cut", type=float, default=79.0)
    p.add_argument("--cr-d", type=float, default=27.0)
    p.add_argument("--cr-ang", type=float, default=-32.0)
    p.add_argument("--cr-ox", type=float, default=9.0)
    p.add_argument("--cr-oy", type=float, default=0.0)
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--bg", default=None)
    p.add_argument("--bg-radius", type=float, default=0.0)
    p.add_argument("-o", default="-")
    a = p.parse_args()
    s = build(a.fg, a.w, a.gap, not a.no_crescent, a.cr_out, a.cr_cut,
              a.cr_d, a.cr_ang, a.cr_ox, a.cr_oy, 512, a.scale, a.bg, a.bg_radius)
    (open(a.o, "w") if a.o != "-" else sys.stdout).write(s)
