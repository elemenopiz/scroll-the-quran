#!/usr/bin/env python3
"""Build Artwork/contact-sheet.png - every deliverable at a glance."""
import os, subprocess, tempfile, pathlib

ART = pathlib.Path(__file__).resolve().parents[1]
TMP = tempfile.mkdtemp()
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
if not os.path.exists(FONT_B):
    FONT_B = FONT
CELL_W = 300
PAD = 14
SHEET_BG = "#1A1A1C"
LABEL = "#C9C7C2"
n = [0]


def run(*a):
    subprocess.run([str(x) for x in a], check=True)


def tmp(ext="png"):
    n[0] += 1
    return os.path.join(TMP, f"t{n[0]}.{ext}")


def size(p):
    out = subprocess.run(["magick", "identify", "-format", "%wx%h", str(p)],
                         capture_output=True, text=True).stdout
    w, h = out.split("x")
    return int(w), int(h)


def cell(path, caption, back="#3A3A3E", w=CELL_W):
    """One captioned tile, checker-free, on a neutral card."""
    iw, ih = size(path)
    th = max(1, round(w * ih / iw))
    img = tmp()
    run("magick", path, "-resize", f"{w}x{th}!", "-background", back,
        "-alpha", "remove", "-alpha", "off", img)
    out = tmp()
    run("magick", img, "-bordercolor", "#000000", "-border", "1",
        "-background", SHEET_BG, "-gravity", "north", "-splice", f"0x8",
        "-gravity", "south", "-splice", "0x58",
        "-font", FONT, "-pointsize", "14", "-fill", LABEL, "-gravity", "south",
        "-annotate", "+0+10", caption, out)
    return out


def row(cells, gap=PAD):
    padded = []
    for c in cells:
        p = tmp()
        run("magick", c, "-background", SHEET_BG,
            "-gravity", "west", "-splice", f"{gap // 2}x0",
            "-gravity", "east", "-splice", f"{gap // 2}x0", p)
        padded.append(p)
    out = tmp()
    run("magick", *padded, "-background", SHEET_BG, "-gravity", "south", "+append", out)
    return out


def heading(text, width):
    out = tmp()
    run("magick", "-size", f"{width}x46", f"xc:{SHEET_BG}",
        "-font", FONT_B, "-pointsize", "21", "-fill", "#FFFFFF",
        "-gravity", "west", "-annotate", "+14+2", text, out)
    return out


def over(bg, fg, out, geom="+0+0"):
    run("magick", bg, fg, "-geometry", geom, "-composite", out)
    return out


def main():
    A = ART
    rows = []

    # --- identity -----------------------------------------------------------
    beige = tmp(); run("magick", "-size", "512x512", "xc:#DED6C0", beige)
    mark_on_beige = tmp()
    run("magick", beige, A / "Logo/mark-black-512.png", "-composite", mark_on_beige)
    dark = tmp(); run("magick", "-size", "512x512", "xc:#121214", dark)
    mark_on_dark = tmp()
    run("magick", dark, A / "Logo/mark-white-512.png", "-composite", mark_on_dark)

    rows.append(("Identity", [
        cell(A / "AppIcon/appicon-1024.png", "AppIcon/appicon-1024.png\n1024x1024, no alpha"),
        cell(A / "AppIcon/appicon-dark-1024.png", "appicon-dark-1024.png\n1024x1024, no alpha"),
        cell(A / "AppIcon/appicon-mono-1024.png", "appicon-mono-1024.png\ntinted/mono layer"),
        cell(mark_on_beige, "Logo/mark-black-512.png\n512x512, transparent"),
        cell(mark_on_dark, "Logo/mark-white-512.png\n512x512, transparent"),
    ]))

    # --- reader card + glyphs ----------------------------------------------
    card_ctx = tmp()
    run("magick", "-size", "600x600", "xc:#121214",
        A / "Logo/logo-card-288.png", "-gravity", "center", "-composite", card_ctx)
    cardl_ctx = tmp()
    run("magick", "-size", "600x600", "xc:#FAFAFC",
        A / "Logo/logo-card-light-288.png", "-gravity", "center", "-composite", cardl_ctx)
    glyphs = tmp()
    run("magick", "-size", "600x220", "xc:#121214",
        "(", A / "Icons/icon-lock-192.png", ")", "-gravity", "west", "-geometry", "+40+0",
        "-composite", glyphs)
    run("magick", glyphs, A / "Icons/icon-bell-192.png", "-gravity", "center",
        "-geometry", "+0+0", "-composite", glyphs)
    run("magick", glyphs, A / "Icons/icon-check-192.png", "-gravity", "east",
        "-geometry", "+40+0", "-composite", glyphs)
    rows.append(("Reader logo card & paywall glyphs", [
        cell(card_ctx, "Logo/logo-card-288.png\n@3x of a 96pt card"),
        cell(cardl_ctx, "Logo/logo-card-light-288.png\nlight-mode variant"),
        cell(glyphs, "Icons/icon-{lock,bell,check}-*.png\n64/128/192 white, transparent",
             w=CELL_W * 2 + PAD),
    ]))

    # --- gift ---------------------------------------------------------------
    sky = A / "Gift/gift-clouds-1179x2556.png"
    closed_ctx = tmp()
    run("magick", sky, "-gravity", "center", "-crop", "1179x1000+0-120", "+repage",
        "(", A / "Gift/envelope-closed-1200x900.png", "-resize", "980x", ")",
        "-gravity", "center", "-composite", closed_ctx)
    open_ctx = tmp()
    run("magick", sky, "-gravity", "center", "-crop", "1179x1000+0-120", "+repage",
        "(", A / "Gift/envelope-open-1200x900.png", "-resize", "1020x", ")",
        "-gravity", "center", "-composite", open_ctx)
    rows.append(("Gift screens", [
        cell(sky, "gift-clouds-1179x2556.png\nwarm beige sky", w=200),
        cell(closed_ctx, "Gift/envelope-closed-1200x900.png\ntransparent, shown on the sky"),
        cell(open_ctx, "Gift/envelope-open-1200x900.png\n(also -back / -front / -card layers)"),
        cell(A / "Gift/envelope-open-front-1200x900.png",
             "envelope-open-front-1200x900.png\nfront pocket layer", "#DED6C0"),
    ]))

    # --- phone frame --------------------------------------------------------
    stand_in = tmp()
    run("magick", "-size", "1119x2496", "gradient:#1D1D22-#0B0B0D",
        "(", A / "Logo/mark-white-192.png", "-resize", "300x300", ")",
        "-gravity", "north", "-geometry", "+0+520", "-composite", stand_in)
    framed = tmp()
    run("magick", "-size", "1179x2556", "xc:none", stand_in, "-geometry", "+30+30",
        "-composite", A / "Frames/phone-frame-1179x2556.png", "-composite",
        "-background", "#EFEDE7", "-alpha", "remove", "-alpha", "off", framed)
    covers = sorted((A / "PlanCovers").glob("plan-*-1200x800.png"))
    covers = [c for c in covers if "scrim" not in c.name]
    scrim_demo = tmp()
    run("magick", covers[0], A / "PlanCovers/plan-cover-scrim-1200x800.png",
        "-composite", scrim_demo)
    rows.append(("Onboarding frame & plan-cover scrim", [
        cell(framed, "phone-frame-1179x2556.png\nwindow 1119x2496 at +30+30", w=210),
        cell(A / "PlanCovers/plan-cover-scrim-1200x800.png",
             "PlanCovers/plan-cover-scrim-1200x800.png\nreusable dark overlay", "#8A8A8A"),
        cell(scrim_demo, "cover + scrim\nwhite titles stay legible"),
    ]))

    # --- plan covers --------------------------------------------------------
    cs = [cell(c, f"PlanCovers/{c.name}\n1200x800") for c in covers]
    rows.append(("Reading-plan covers (8)", cs[:4]))
    rows.append((None, cs[4:]))

    # --- charity ------------------------------------------------------------
    ch = sorted(p for p in (A / "Charity").glob("charity-*-1200x600.png")
                if "scrim" not in p.name)
    rows.append(("Charity cards (3)",
                 [cell(c, f"Charity/{c.name}\n1200x600") for c in ch] +
                 [cell(A / "Charity/charity-card-scrim-1200x600.png",
                       "charity-card-scrim-1200x600.png\nreusable dark overlay", "#8A8A8A")]))

    strips = []
    for title, cells in rows:
        r = row(cells)
        w, _ = size(r)
        if title:
            strips.append(heading(title, w))
        strips.append(r)

    widths = [size(s)[0] for s in strips]
    W = max(widths)
    norm = []
    for s in strips:
        p = tmp()
        run("magick", s, "-background", SHEET_BG, "-gravity", "west",
            "-extent", f"{W}x", p)
        norm.append(p)
    body = tmp()
    run("magick", *norm, "-background", SHEET_BG, "-append", body)
    title = tmp()
    run("magick", "-size", f"{W}x92", f"xc:{SHEET_BG}",
        "-font", FONT_B, "-pointsize", "30", "-fill", "#FFFFFF", "-gravity", "northwest",
        "-annotate", "+14+16", "Scroll the Quran - original artwork (Phase 2g)",
        "-font", FONT, "-pointsize", "15", "-fill", "#9A9A9E",
        "-annotate", "+16+58",
        "All assets generated procedurally with ImageMagick + hand-written SVG. "
        "No photographs, no traced artwork, no baked-in text.", title)
    run("magick", title, body, "-background", SHEET_BG, "-append",
        "-bordercolor", SHEET_BG, "-border", "18", "-resize", "1500x", "-depth", "8",
        "-strip", "-define", "png:compression-level=9", ART / "contact-sheet.png")
    print("  contact-sheet.png", size(ART / "contact-sheet.png"))


if __name__ == "__main__":
    main()
