#!/usr/bin/env python3
"""Procedural cumulus background for the gift screens (1179x2556).

Clouds are metaballs: a body tier and a smaller scallop tier of circles are
drawn, blurred and re-levelled so they fuse into one puffy silhouette;
fractal noise gently roughens the edge and an offset blur of the same mask
supplies top-lit shading.  Everything is ImageMagick primitives - no photos.
"""
import random, subprocess, sys, tempfile, os

W, H = 1179, 2556
BASE_TOP, BASE_BOT = "#E7E0CD", "#D5CCB2"
CLOUD_HI, CLOUD_LO = "#FFFFFF", "#DCD3BE"

# (cx, cy, width, height, body circles)
CLUSTERS = [
    (250,  720,  470, 300, 16),
    (880,  640,  520, 330, 18),
    (1140, 930,  380, 250, 12),
    (60,  1010,  360, 230, 11),
    (170, 1660,  450, 280, 15),
    (1060,1810,  450, 260, 14),
    (640, 1580,  330, 200,  9),
    (420, 2390,  540, 300, 17),
    (1080,2300,  400, 240, 12),
    (520,  330,  300, 150,  8),
    (980, 1290,  240, 120,  6),
    (120, 2020,  260, 130,  7),
]

def circles(seed=5):
    rnd = random.Random(seed)
    out = []
    for cx, cy, w, h, n in CLUSTERS:
        floor = cy + h / 2
        for _ in range(n):                       # body
            r = rnd.uniform(0.16, 0.30) * w
            x = cx + rnd.uniform(-0.42, 0.42) * w
            y = floor - r * rnd.uniform(0.8, 1.15) - rnd.uniform(0, 0.25) * h
            out.append((x, y, r))
        for _ in range(int(n * 1.1)):            # scallops along the crown
            r = rnd.uniform(0.07, 0.14) * w
            x = cx + rnd.uniform(-0.44, 0.44) * w
            y = floor - rnd.uniform(0.45, 1.05) * h
            out.append((x, y, r))
    return out

def draw_args(cs):
    a = []
    for x, y, r in cs:
        a += ["-draw", f"circle {x:.1f},{y:.1f} {x:.1f},{y + r:.1f}"]
    return a

def run(*a):
    subprocess.run(list(a), check=True)

def main(out_path, seed=5):
    d = tempfile.mkdtemp()
    p = lambda n: os.path.join(d, n)
    run("magick", "-size", f"{W}x{H}", "xc:black", "-fill", "white",
        *draw_args(circles(seed)),
        "-blur", "0x20", "-level", "46%,61%", p("m0.png"))
    run("magick", "-size", f"{W}x{H}", "-seed", str(seed * 13), "plasma:fractal",
        "-colorspace", "Gray", "-blur", "0x7", "-auto-level",
        "-level", "-45%,105%", p("n.png"))          # gentle, mostly bright
    run("magick", p("m0.png"), p("n.png"), "-compose", "Multiply", "-composite",
        "-level", "10%,74%", "-blur", "0x10", p("core.png"))
    # large-scale density variation -> wispy, uneven clouds instead of solid blobs
    run("magick", "-size", f"{W}x{H}", "-seed", str(seed * 29), "plasma:fractal",
        "-colorspace", "Gray", "-blur", "0x34", "-auto-level",
        "-level", "-10%,118%", p("w.png"))
    run("magick", p("core.png"), p("w.png"), "-compose", "Multiply", "-composite",
        "(", p("core.png"), "-blur", "0x38", "-evaluate", "multiply", "0.55", ")",
        "-compose", "Plus", "-composite", "-evaluate", "multiply", "0.92",
        p("mask.png"))
    run("magick", p("core.png"), "-blur", "0x55",
        "-gravity", "north", "-chop", "0x64",
        "-gravity", "south", "-background", "black", "-splice", "0x64",
        "+gravity", "-level", "12%,72%", p("shade.png"))
    run("magick", "-size", f"{W}x{H}", f"xc:{CLOUD_LO}",
        "(", "-size", f"{W}x{H}", f"xc:{CLOUD_HI}", ")",
        p("shade.png"), "-compose", "Over", "-composite", p("cloudcol.png"))
    run("magick", p("cloudcol.png"), p("mask.png"), "-alpha", "off",
        "-compose", "CopyAlpha", "-composite", p("cloud.png"))
    run("magick", "-size", f"{W}x{H}", f"gradient:{BASE_TOP}-{BASE_BOT}", p("base.png"))
    run("magick", "-seed", str(seed * 7 + 101), p("base.png"), p("cloud.png"),
        "-compose", "Over", "-composite",
        "(", "+clone", "-attenuate", "0.7", "+noise", "Gaussian", ")",
        "-compose", "Blend", "-define", "compose:args=5", "-composite",
        "-colorspace", "sRGB", "-depth", "8", out_path)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/clouds.png",
         int(sys.argv[2]) if len(sys.argv) > 2 else 5)
