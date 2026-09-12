#!/usr/bin/env bash
# Cut the generated gift-envelope renders in Artwork/src/gift/ into the layers the gift
# screens ship (Artwork/Gift/), and print the geometry the app positions them by.
#
# The renders came back as flat images: the model paints a *fake* checkerboard instead of
# writing alpha, so every layer has to be keyed. The grey checkerboard is the only
# desaturated thing in frame, which is what `SAT_KEY` separates; the wax seal has to be
# cut off kraft paper instead, where no colour key works (the gold rim highlights are as
# light as the paper), so it is traced as a scalloped radial path — see `trace_seal`.
#
# Every number that shapes a layer is a constant at the top of the python block, so
# re-running this against a fresh render is one command:
#
#     Artwork/tools/gift-assets.sh
#
# Requires: ImageMagick 7 (`magick`), python3 with numpy, scipy and Pillow.
set -euo pipefail
cd "$(dirname "$0")"
ART="$(cd .. && pwd)"
SRC="$ART/src/gift"
OUT="$ART/Gift"

command -v magick >/dev/null || { echo "gift-assets.sh: ImageMagick 7 (magick) is required" >&2; exit 1; }
python3 -c 'import numpy, scipy, PIL' 2>/dev/null || {
  echo "gift-assets.sh: python3 with numpy, scipy and Pillow is required" >&2; exit 1; }

mkdir -p "$OUT"

python3 - "$SRC" "$OUT" <<'PY'
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])

# --- keying -----------------------------------------------------------------------
SAT_KEY = 0.12       # the painted checkerboard is grey; the paper never falls this low
OPEN_DISK = 13       # drops the checkerboard's own squares and the speckle between them
ERODE = 4            # trims the wavy painted halo that rings every render
CLOSE_DISK = 7       # rounds the nicks erosion leaves in a straight paper edge

# --- open envelope ----------------------------------------------------------------
FLAP_STRETCH = 1.85  # the render's flap is a squat triangle; a portrait phone needs a tower
OPEN_CANVAS = (1000, 1500)
OPEN_MARGIN = 40     # px of air on the left, right and bottom of the 1000x1500 canvas

# --- closed envelope --------------------------------------------------------------
CLOSED_CANVAS = (1200, 900)
CLOSED_FILL = 0.96   # fraction of the canvas width the envelope spans

# --- card -------------------------------------------------------------------------
CARD_CANVAS = (900, 1200)
CARD_FILL = 0.94     # fraction of the canvas height the card body spans (its drop
                     # shadow is allowed to spill into the margin)

# --- wax seal ---------------------------------------------------------------------
SEAL_CANVAS = 600
SEAL_FILL = 0.978    # matches the blank seal's own framing, so the two are interchangeable
SEAL_SAT = 0.47      # gold vs kraft paper; below this the rim highlights start to go
SEAL_RUN = 16        # samples (0.5 px each) that must be gold for a radius to count
SEAL_PCT, SEAL_WIN = 30, 61   # angular percentile filter: kills narrow spikes where the
                              # envelope's own fold shadow touches the rim, keeps the lobes
SEAL_TRIM = 2.0      # px pulled off the traced rim, inside the seal's own contact shadow

# --- sky --------------------------------------------------------------------------
SKY_CANVAS = (1179, 2556)
# Reference/gift-closed.png's sky, per channel. The render is a real cumulus sky and
# three times as contrasty as the reference's flat warm paper; matching mean and spread
# lands it in the same band without flattening the cloud forms away.
SKY_MEAN = np.array([227.8, 221.6, 203.8])
SKY_STD = np.array([7.4, 9.0, 13.7])

# --- paper tone --------------------------------------------------------------------
# The renders came back a darker, browner kraft than the reference's envelope, which is
# a lit cream (Reference/gift-closed.png samples 231.7/213.1/179.1, gift-open.png
# 242.9/219.6/181.2 — and the app's own palette calls the paper #E8D9B4 lit to #F3E7C9).
# The paper is lifted onto those means; the wax is left exactly as rendered, because its
# gold already matches the reference's to within 3 levels on red and green.
CLOSED_PAPER = np.array([231.7, 213.1, 179.1])
OPEN_PAPER = np.array([242.9, 219.6, 181.2])
PAPER_SAT, WAX_SAT = 0.42, 0.52   # saturation band the paper fades out over

PNG_ARGS = dict(optimize=True)


def disk(r):
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    return (yy ** 2 + xx ** 2) <= r * r


def saturation(rgb):
    hi, lo = rgb.max(2), rgb.min(2)
    return np.where(hi > 0, (hi - lo) / np.maximum(hi, 1), 0)


def largest_component(mask):
    labels, count = ndi.label(mask)
    if count == 0:
        return mask
    sizes = ndi.sum(mask, labels, range(1, count + 1))
    return labels == (int(np.argmax(sizes)) + 1)


def key_checkerboard(path):
    """Alpha for a render dropped on the model's painted grey checkerboard."""
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image).astype(np.float32)
    mask = saturation(rgb) > SAT_KEY
    mask = ndi.binary_opening(mask, disk(OPEN_DISK))
    mask = largest_component(mask)
    mask = ndi.binary_erosion(mask, disk(ERODE))
    mask = ndi.binary_closing(mask, disk(CLOSE_DISK))
    mask = ndi.binary_fill_holes(mask)
    return image, mask


def key_vignette(path):
    """Alpha for a render dropped on a flat beige vignette instead of a checkerboard.

    No colour key works there — the ground is the same family as the paper — so the
    distance from the *corner* colour is what separates them.
    """
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image).astype(np.float32)
    corner = np.median(
        np.concatenate([rgb[:24, :24].reshape(-1, 3), rgb[:24, -24:].reshape(-1, 3),
                        rgb[-24:, :24].reshape(-1, 3), rgb[-24:, -24:].reshape(-1, 3)]),
        axis=0,
    )
    mask = np.linalg.norm(rgb - corner, axis=2) > 26
    mask = ndi.binary_opening(mask, disk(OPEN_DISK))
    mask = largest_component(mask)
    mask = ndi.binary_fill_holes(mask)
    mask = ndi.binary_erosion(mask, disk(3))
    return image, mask


def soften(mask, blur=0.8):
    """Bool mask -> 8-bit alpha with a soft edge about a pixel wide."""
    alpha = ndi.gaussian_filter(mask.astype(np.float32) * 255, blur)
    return Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), "L")


def cut(image, mask):
    out = image.convert("RGBA")
    out.putalpha(soften(mask))
    return out


def tone_paper(rgba, target):
    """Lift the envelope's kraft onto the reference's cream, leaving the wax alone.

    A per-channel gain, faded out over `PAPER_SAT`...`WAX_SAT` so the seal — whose gold
    already matches the reference's — keeps its own colour and its contact shadow still
    blends into the paper it sits on.
    """
    arr = np.asarray(rgba).astype(np.float32)
    rgb, alpha = arr[..., :3], arr[..., 3]
    paper = np.clip((WAX_SAT - saturation(rgb)) / (WAX_SAT - PAPER_SAT), 0, 1)
    measured = rgb[(paper > 0.99) & (alpha > 250)].reshape(-1, 3).mean(0)
    gain = np.asarray(target) / np.maximum(measured, 1)
    lifted = rgb + (np.clip(rgb * gain, 0, 255) - rgb) * paper[..., None]
    out = np.dstack([lifted, alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), measured, gain


def bbox(rgba, floor=8):
    alpha = np.asarray(rgba)[..., 3]
    ys, xs = np.nonzero(alpha > floor)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def place(layer, canvas, width=None, height=None, anchor="center", margin=0):
    """Scale `layer` to the given content width/height and drop it on a clear canvas."""
    x0, y0, x1, y1 = bbox(layer)
    layer = layer.crop((x0, y0, x1, y1))
    if width is None:
        width = round(layer.width * height / layer.height)
    if height is None:
        height = round(layer.height * width / layer.width)
    layer = layer.resize((width, height), Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (canvas[0] - width) // 2
    y = (canvas[1] - height) // 2 if anchor == "center" else canvas[1] - margin - height
    out.alpha_composite(layer, (x, y))
    return out, (x, y, width, height)


def pocket_line(mask):
    """First row where the envelope body reaches its full width — the top edge of the
    front pocket, and the line the offer card is clipped at."""
    widths = mask.sum(1)
    full = widths.max()
    return int(np.argmax(widths >= full * 0.995))


def pocket_apex(rgb, mask, corner_y):
    """Where the front pocket's two top edges meet, on the centre column: the step from
    the shaded lining up to the lit front flap."""
    h, w = mask.shape
    column = rgb[:, w // 2 - 12:w // 2 + 12].mean(axis=(1, 2))
    column = ndi.uniform_filter1d(column, 9)
    lo = corner_y + int(0.02 * h)
    hi = min(h - 1, corner_y + int(0.55 * h))
    step = np.diff(column[lo:hi])
    return lo + int(np.argmax(step)) + 1


def trace_seal(path):
    """Cut the logo-embossed wax seal off the kraft paper it was pressed on.

    Colour keys fail: the gold rim highlights run as light and as unsaturated as the
    paper, and the envelope's fold shadow under the rim is as dark and as saturated as
    the wax. So the rim is *traced* instead — for each of 1440 angles, the furthest
    radius that is still gold — and the profile is then percentile-filtered around the
    circle, which keeps the wax's broad scalloped lobes and discards the narrow spikes
    where the fold shadow reaches out past them.
    """
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image).astype(np.float32)
    h, w, _ = rgb.shape
    gold = saturation(rgb) > SEAL_SAT
    body = largest_component(ndi.binary_closing(gold, disk(6)))
    ys, xs = np.nonzero(body)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2

    angles = np.linspace(0, 2 * np.pi, 1440, endpoint=False)
    radii = np.arange(0, min(w, h) / 2 + 20, 0.5)
    xi = np.clip(np.round(cx + np.cos(angles)[:, None] * radii).astype(int), 0, w - 1)
    yi = np.clip(np.round(cy + np.sin(angles)[:, None] * radii).astype(int), 0, h - 1)
    hits = gold[yi, xi].astype(np.float32)
    run = np.stack([np.convolve(row, np.ones(SEAL_RUN) / SEAL_RUN, mode="same") for row in hits])
    solid = run > 0.6
    last = np.where(solid.any(1), solid.shape[1] - 1 - np.argmax(solid[:, ::-1], axis=1), 0)
    profile = radii[last]

    tripled = np.concatenate([profile, profile, profile])
    profile = ndi.percentile_filter(tripled, SEAL_PCT, size=SEAL_WIN)[len(profile):2 * len(profile)]
    n = len(profile)
    bell = np.exp(-0.5 * (np.minimum(np.arange(n), n - np.arange(n)) / 5.0) ** 2)
    profile = np.real(np.fft.ifft(np.fft.fft(profile) * np.fft.fft(bell / bell.sum())))
    profile = np.maximum(profile - SEAL_TRIM, 1)

    # Rasterise the closed scalloped path at 4x and box-filter it down for a soft edge.
    outline = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(outline).polygon(
        list(zip(((cx + np.cos(angles) * profile) * 4).tolist(),
                 ((cy + np.sin(angles) * profile) * 4).tolist())),
        fill=255,
    )
    out = image.convert("RGBA")
    out.putalpha(outline.resize((w, h), Image.LANCZOS))
    return out


def tone_sky(path):
    """Land the render's sky in the reference's flat warm-paper band (mean and spread
    matched per channel), then fit it to the phone canvas."""
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image).astype(np.float32)
    flat = rgb.reshape(-1, 3)
    scaled = (rgb - flat.mean(0)) * (SKY_STD / np.maximum(flat.std(0), 1e-3)) + SKY_MEAN
    image = Image.fromarray(np.clip(scaled, 0, 255).astype(np.uint8), "RGB")
    # Scale to fill, then centre-crop: the sky has no horizon, so any crop reads.
    scale = max(SKY_CANVAS[0] / image.width, SKY_CANVAS[1] / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (image.width - SKY_CANVAS[0]) // 2
    top = (image.height - SKY_CANVAS[1]) // 2
    return image.crop((left, top, left + SKY_CANVAS[0], top + SKY_CANVAS[1]))


report = {}

# --- 1. closed envelope, wax seal baked in -----------------------------------------
image, mask = key_checkerboard(SRC / "closed-sealed-raw.png")
toned, was, gain = tone_paper(cut(image, mask), CLOSED_PAPER)
report["closed.paper"] = (was.round(1).tolist(), gain.round(3).tolist())
layer, _ = place(toned, CLOSED_CANVAS, width=round(CLOSED_CANVAS[0] * CLOSED_FILL))
layer.save(OUT / "envelope-closed-1200x900.png", **PNG_ARGS)
report["envelope-closed-1200x900"] = bbox(layer)

# --- 1b. closed envelope without the seal (fallback for a code-drawn seal) ----------
image, mask = key_vignette(SRC / "closed-noseal-raw.png")
toned, _, _ = tone_paper(cut(image, mask), CLOSED_PAPER)
layer, _ = place(toned, CLOSED_CANVAS, width=round(CLOSED_CANVAS[0] * CLOSED_FILL))
layer.save(OUT / "envelope-closed-noseal-1200x900.png", **PNG_ARGS)
report["envelope-closed-noseal-1200x900"] = bbox(layer)

# --- 2. open envelope: stretch the flap, then pad to a portrait canvas -------------
image, mask = key_checkerboard(SRC / "open-empty-raw.png")
cutout, was, gain = tone_paper(cut(image, mask), OPEN_PAPER)
report["open.paper"] = (was.round(1).tolist(), gain.round(3).tolist())
x0, y0, x1, y1 = bbox(cutout)
cutout = cutout.crop((x0, y0, x1, y1))
body_mask = mask[y0:y1, x0:x1]
body_rgb = np.asarray(image)[y0:y1, x0:x1].astype(np.float32)
corner = pocket_line(body_mask)
apex = pocket_apex(body_rgb, body_mask, corner)

flap = cutout.crop((0, 0, cutout.width, corner))
flap = flap.resize((flap.width, round(flap.height * FLAP_STRETCH)), Image.LANCZOS)
body = cutout.crop((0, corner, cutout.width, cutout.height))
tower = Image.new("RGBA", (cutout.width, flap.height + body.height), (0, 0, 0, 0))
tower.alpha_composite(flap, (0, 0))
tower.alpha_composite(body, (0, flap.height))

layer, (cx0, cy0, cw, ch) = place(
    tower, OPEN_CANVAS, width=OPEN_CANVAS[0] - 2 * OPEN_MARGIN, anchor="bottom", margin=OPEN_MARGIN
)
layer.save(OUT / "envelope-open-1000x1500.png", **PNG_ARGS)
report["envelope-open-1000x1500"] = (cx0, cy0, cx0 + cw, cy0 + ch)

# Re-measure on the finished layer rather than trusting the arithmetic that built it:
# these six fractions are copied straight into `PaywallMetrics.openEnvelopeArt`.
placed = np.asarray(layer)
placed_mask = placed[..., 3] > 128
placed_corner = pocket_line(placed_mask)
report["open.flapApexY"] = cy0 / OPEN_CANVAS[1]
report["open.bodyLeftX"] = cx0 / OPEN_CANVAS[0]
report["open.bodyRightX"] = (cx0 + cw) / OPEN_CANVAS[0]
report["open.pocketCornerY"] = placed_corner / OPEN_CANVAS[1]
report["open.pocketApexY"] = pocket_apex(
    placed[..., :3].astype(np.float32), placed_mask, placed_corner
) / OPEN_CANVAS[1]
report["open.bottomY"] = (cy0 + ch) / OPEN_CANVAS[1]

# --- 3. the blank offer card (the render already carries straight alpha) -----------
card = Image.open(SRC / "card-blank.png").convert("RGBA")
pixels = np.asarray(card)
solid = (pixels[..., 3] > 250) & (pixels[..., :3].mean(2) > 200)   # the paper, not its shadow
ys, xs = np.nonzero(solid)
height = round(CARD_CANVAS[1] * CARD_FILL)
scale = height / (ys.max() - ys.min() + 1)
card = card.resize((round(card.width * scale), round(card.height * scale)), Image.LANCZOS)
layer = Image.new("RGBA", CARD_CANVAS, (0, 0, 0, 0))
layer.alpha_composite(card, (round(CARD_CANVAS[0] / 2 - (xs.min() + xs.max() + 1) / 2 * scale),
                             round(CARD_CANVAS[1] / 2 - (ys.min() + ys.max() + 1) / 2 * scale)))
layer.save(OUT / "envelope-card-900x1200.png", **PNG_ARGS)
report["envelope-card-900x1200"] = bbox(layer)
report["card.bodyRect"] = (
    round(CARD_CANVAS[0] / 2 - (xs.max() - xs.min() + 1) / 2 * scale),
    round(CARD_CANVAS[1] / 2 - height / 2),
    round((xs.max() - xs.min() + 1) * scale),
    height,
)

# --- 4. wax seals: the blank one, and the logo-embossed one traced off the paper ----
blank = Image.open(SRC / "seal-blank.png").convert("RGBA")
layer, _ = place(blank, (SEAL_CANVAS, SEAL_CANVAS), width=round(SEAL_CANVAS * SEAL_FILL))
layer.save(OUT / "wax-seal-blank-600.png", **PNG_ARGS)
report["wax-seal-blank-600"] = bbox(layer)

logo = trace_seal(SRC / "seal-logo-crop-raw.png")
layer, _ = place(logo, (SEAL_CANVAS, SEAL_CANVAS), width=round(SEAL_CANVAS * SEAL_FILL))
layer.save(OUT / "wax-seal-logo-600.png", **PNG_ARGS)
report["wax-seal-logo-600"] = bbox(layer)

# --- 5. the sky --------------------------------------------------------------------
tone_sky(SRC / "sky-raw.png").save(OUT / "gift-clouds-1179x2556.png", **PNG_ARGS)

print("  measured geometry (PaywallMetrics.openEnvelopeArt / giftCardArt):")
for key, value in report.items():
    if isinstance(value, float):
        print(f"    {key:26s} {value:.4f}")
    else:
        print(f"    {key:26s} {value}")
PY

echo "  optimising"
for f in "$OUT"/envelope-closed-1200x900.png "$OUT"/envelope-closed-noseal-1200x900.png \
         "$OUT"/envelope-open-1000x1500.png "$OUT"/envelope-card-900x1200.png \
         "$OUT"/wax-seal-blank-600.png "$OUT"/wax-seal-logo-600.png \
         "$OUT"/gift-clouds-1179x2556.png; do
  magick "$f" -depth 8 -strip -define png:compression-level=9 -define png:compression-filter=5 "$f"
  printf '  %-44s %s\n' "$(basename "$f")" "$(du -h "$f" | cut -f1)"
done
