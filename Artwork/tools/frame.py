#!/usr/bin/env python3
"""iPhone frame overlay: a 1179x2556 transparent PNG whose centre aperture is the
device's own screen, so a 402x874 pt capture placed *behind* it shows through
edge to edge with nothing cropped.

The numbers are the device's, in device points, and are the same ones
`FeatureOnboarding/Components/PhoneFrame.swift`'s `DeviceFrameMetrics` draws the
slides' frame from — screen 402 x 874 with a 55 pt corner radius, a 6 pt black
border, a 2.5 pt titanium rail, side buttons 3.5 pt proud of it. Everything below
is those numbers times one scale factor, chosen so the enclosure *plus* the proud
side buttons fills the canvas's width.

Printed alongside the SVG on stderr: the aperture rectangle
`Tools/release/screenshots.sh` has to composite into (WIN_X/Y/W/H/R) and the
enclosure's own box (FRAME_Y/H), so the two can never drift apart.
"""
import sys

# --- canvas ---------------------------------------------------------------
W, H = 1179, 2556

# --- the device, in device points (mirrors DeviceFrameMetrics) ------------
SCREEN_W, SCREEN_H = 402.0, 874.0
SCREEN_R = 55.0
BORDER = 6.0          # black, between the glass and the rail
RIM = 2.5             # titanium rail
INSET = BORDER + RIM  # 8.5
OUTER_W, OUTER_H = SCREEN_W + 2 * INSET, SCREEN_H + 2 * INSET   # 419 x 891
OUTER_R = SCREEN_R + INSET                                       # 63.5
PROUD = 3.5           # how far a side button stands out of the rail

# (top, height, on_left) from the enclosure's top edge — action, volume up,
# volume down, power.
BUTTONS = ((160.0, 30.0, True), (222.0, 60.0, True),
           (298.0, 60.0, True), (251.0, 96.0, False))

# --- one scale factor -----------------------------------------------------
# The widest thing on the frame is the enclosure plus a button nub on each edge.
U = W / (OUTER_W + 2 * PROUD)
FW, FH = OUTER_W * U, OUTER_H * U          # enclosure box in canvas pixels
FX, FY = PROUD * U, (H - FH) / 2
IN = INSET * U
APT_X, APT_Y = FX + IN, FY + IN
APT_W, APT_H = SCREEN_W * U, SCREEN_H * U
APT_R, RIM_PX, R_OUT = SCREEN_R * U, RIM * U, OUTER_R * U
R_IN1 = R_OUT - RIM_PX


def n(v):
    """Trim the float noise that would otherwise fill the file."""
    return f"{v:.2f}".rstrip("0").rstrip(".")


def rr(x, y, w, h, r, sweep=1):
    """Rounded-rect sub-path; sweep=0 reverses winding for even-odd holes."""
    x, y, w, h, r = map(float, (x, y, w, h, r))
    a = [n(v) for v in (x + r, y, x + w - r, r, r, x + w, y + r, y + h - r, r, r,
                        x + w - r, y + h, x + r, r, r, x, y + h - r, y + r, r, r, x + r, y)]
    if sweep:
        return (f"M{a[0]} {a[1]} H{a[2]} A{a[3]} {a[4]} 0 0 1 {a[5]} {a[6]} V{a[7]} "
                f"A{a[8]} {a[9]} 0 0 1 {a[10]} {a[11]} H{a[12]} A{a[13]} {a[14]} 0 0 1 "
                f"{a[15]} {a[16]} V{a[17]} A{a[18]} {a[19]} 0 0 1 {a[20]} {a[21]} Z")
    return (f"M{a[0]} {a[1]} A{a[18]} {a[19]} 0 0 0 {a[15]} {a[17]} V{a[16]} "
            f"A{a[13]} {a[14]} 0 0 0 {a[12]} {a[11]} H{a[10]} A{a[8]} {a[9]} 0 0 0 "
            f"{a[5]} {a[7]} V{a[6]} A{a[3]} {a[4]} 0 0 0 {a[2]} {a[1]} Z")


def build():
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" fill="none">', '<defs>']
    # The rail is #B9B9BE -> #8E8E93 down the device, with a lighter catch-light
    # along the top face — the same two greys DeviceFramePalette uses.
    p.append('<linearGradient id="rail" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="#E6E6EB"/>'
             '<stop offset="0.02" stop-color="#B9B9BE"/>'
             '<stop offset="1" stop-color="#8E8E93"/></linearGradient>')
    p.append('<linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">'
             '<stop offset="0" stop-color="#8E8E93"/>'
             '<stop offset="0.5" stop-color="#B9B9BE"/>'
             '<stop offset="1" stop-color="#8E8E93"/></linearGradient>')
    p.append('</defs>')
    # Side buttons, under the rail so they read as part of the edge.
    bw = (RIM_PX + PROUD * U)
    for top, height, on_left in BUTTONS:
        x = FX - PROUD * U if on_left else FX + FW - RIM_PX
        p.append(f'<rect x="{n(x)}" y="{n(FY + top * U)}" width="{n(bw)}" '
                 f'height="{n(height * U)}" rx="{n(bw / 2)}" fill="url(#btn)"/>')
    # Titanium rail: the enclosure with the bezel's rectangle knocked out.
    p.append(f'<path fill-rule="evenodd" fill="url(#rail)" d="{rr(FX, FY, FW, FH, R_OUT)} '
             f'{rr(FX + RIM_PX, FY + RIM_PX, FW - 2 * RIM_PX, FH - 2 * RIM_PX, R_IN1, 0)}"/>')
    # Black border between the rail and the glass.
    p.append(f'<path fill-rule="evenodd" fill="#050506" '
             f'd="{rr(FX + RIM_PX, FY + RIM_PX, FW - 2 * RIM_PX, FH - 2 * RIM_PX, R_IN1)} '
             f'{rr(APT_X, APT_Y, APT_W, APT_H, APT_R, 0)}"/>')
    # Hairline where the border meets the glass.
    p.append(f'<path d="{rr(APT_X, APT_Y, APT_W, APT_H, APT_R)}" fill="none" '
             f'stroke="#000000" stroke-opacity="0.55" stroke-width="3"/>')
    # No Dynamic Island: the capture behind the aperture carries the real one.
    p.append('</svg>')
    return "\n".join(p)


def window():
    """The constants Tools/release/screenshots.sh needs, as integers."""
    return dict(WIN_X=round(APT_X), WIN_Y=round(APT_Y), WIN_W=round(APT_W),
                WIN_H=round(APT_H), WIN_R=round(APT_R),
                FRAME_Y=round(FY), FRAME_H=round(FH))


if __name__ == "__main__":
    import pathlib
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    s = build()
    (out.write_text(s) if out else sys.stdout.write(s))
    print(" ".join(f"{k}={v}" for k, v in window().items()), file=sys.stderr)
