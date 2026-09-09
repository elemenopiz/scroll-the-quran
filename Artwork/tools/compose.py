#!/usr/bin/env python3
"""Assemble the app icon / logo-card SVG documents around the mark."""
import mark, re, pathlib, argparse

def inner(**kw):
    """Return the mark markup without the enclosing <svg> element."""
    s = mark.build(**kw)
    s = s.split(">", 1)[1]          # drop the opening <svg ...>
    return s.rsplit("</svg>", 1)[0].strip()

TPL = ('<svg xmlns="http://www.w3.org/2000/svg" width="{sz}" height="{sz}" '
       'viewBox="0 0 512 512" fill="none">\n{defs}{bg}\n{mark}\n</svg>\n')

def doc(path, sz=512, defs="", bg="", **kw):
    pathlib.Path(path).write_text(
        TPL.format(sz=sz, defs=defs, bg=bg, mark=inner(**kw)))

VIGNETTE = ('<defs><radialGradient id="bg" cx="42%" cy="34%" r="78%">'
            '<stop offset="0" stop-color="#FFFEFC"/>'
            '<stop offset="0.62" stop-color="#FAF8F3"/>'
            '<stop offset="1" stop-color="#EFEBE1"/></radialGradient></defs>\n')
VIGNETTE_D = ('<defs><radialGradient id="bg" cx="42%" cy="32%" r="80%">'
              '<stop offset="0" stop-color="#26262C"/>'
              '<stop offset="0.6" stop-color="#1A1A1E"/>'
              '<stop offset="1" stop-color="#0D0D10"/></radialGradient></defs>\n')
FILL = '<rect width="512" height="512" fill="url(#bg)"/>'

def rrect(r, fill):
    return f'<rect width="512" height="512" rx="{r}" ry="{r}" fill="{fill}"/>'

if __name__ == "__main__":
    src = pathlib.Path(__file__).resolve().parents[1] / "src"
    src.mkdir(exist_ok=True)
    # standalone marks (transparent, near full-bleed)
    doc(src / "mark-black.svg", scale=1.15, fg="#000000")
    doc(src / "mark-white.svg", scale=1.15, fg="#FFFFFF", w=15.5)
    # app icon, light + dark
    doc(src / "appicon.svg",      sz=1024, defs=VIGNETTE,   bg=FILL, scale=0.77, fg="#0B0B0D")
    doc(src / "appicon-dark.svg", sz=1024, defs=VIGNETTE_D, bg=FILL, scale=0.77,
        fg="#FFFFFF", w=15.5)
    # tinted / monochrome icon layer: white mark on solid black
    doc(src / "appicon-mono.svg", sz=1024, bg=rrect(0, "#000000"), scale=0.77,
        fg="#FFFFFF", w=15.5)
    # reader logo card: white line-art in a rounded dark square
    doc(src / "logo-card.svg", sz=512, bg=rrect(116, "#1E1E23"), scale=0.77,
        fg="#FFFFFF", w=15.5)
    doc(src / "logo-card-light.svg", sz=512, bg=rrect(116, "#EFEDE7"), scale=0.77,
        fg="#0B0B0D")
    print("wrote", *(p.name for p in sorted(src.glob("*.svg"))))
