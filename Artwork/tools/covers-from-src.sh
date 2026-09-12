#!/usr/bin/env bash
# Reading-plan covers and charity cards, cut from the owner's renders in
# `Artwork/src/{covers,charity}/`.
#
#   covers-from-src.sh              # covers + charity cards + both scrims
#   covers-from-src.sh plans        # covers + the plan scrim
#   covers-from-src.sh charity      # charity cards + the charity scrim
#
# Each source is a 1536x1024 (covers) or 1536x768 (cards) render made to the prompts in
# `docs/design/asset-prompts.md`. They are photographic, carry no alpha and no baked-in
# text, so they ship as **JPEG quality 88** rather than PNG: a 1200x800 PNG of a
# photograph is 1.5-2.5 MB, the same frame as a 4:2:0 JPEG is ~150-300 KB, and the asset
# catalog compiles either one. The budget is 350 KB per file.
#
# Sizes. The covers are drawn at three places, all of which crop rather than letterbox:
#   * plans-grid tile   173.5 pt square  -> 520 px @3x -> needs 781 px of a 3:2 frame
#   * active-plan cover 133 pt square    -> 399 px @3x -> needs 599 px
#   * today's cover     125 pt square    -> 375 px @3x -> needs 563 px
#   * plan-detail hero  361 x ~185 pt    -> 1083 px wide @3x
# The hero alone needs 1083 px, so 1200x800 is the shipped size. **No 600x400 "card" 2x
# variant is emitted**: even the smallest tile needs 563 px of the frame's width, so a
# 600 px master would be upscaled everywhere except the phone-less previews, and the
# 1200 px file is only ~200 KB to begin with. Charity cards are cropped to a 160 pt band
# across a full-width card (1083 px @3x), so they ship at 1200x600.
#
# The scrims (`plan-cover-scrim`, `charity-card-scrim`) stay PNG: they are pure alpha
# ramps, 4 KB each, and JPEG has no alpha. The command below is the same one in
# `tools/covers.py`, kept here so this script can replace it wholesale in `build.sh`.
set -euo pipefail
cd "$(dirname "$0")"
ART="$(cd .. && pwd)"
SRC="$ART/src"
WHICH="${1:-all}"

QUALITY=88
BUDGET_KB=350

jpeg() {  # jpeg() <src.png> <w> <h> <out.jpg>
  magick "$1" -auto-orient -colorspace sRGB \
    -resize "${2}x${3}^" -gravity center -extent "${2}x${3}" \
    -strip -interlace none -sampling-factor 4:2:0 -quality "$QUALITY" \
    "$4"
}

scrim() {  # scrim() <out.png> <w> <h>
  # Clear for the top ~45 %, ramping to ~80 % black at the bottom edge.
  magick -size "${2}x${3}" gradient:none-black \
    -channel A -function polynomial "1.34,-0.54,0" +channel \
    -depth 8 -strip -define png:compression-level=9 -define png:compression-filter=5 "$1"
}

FAILED=0
row() {  # row() <file>
  local kb
  kb=$(( ($(stat -f%z "$1") + 512) / 1024 ))
  printf '  %-46s %5s x %-5s %6s KB  %s\n' \
    "${1#"$ART"/}" "$(magick identify -format %w "$1")" "$(magick identify -format %h "$1")" \
    "$kb" "$([ "$kb" -le "$BUDGET_KB" ] && echo ok || { FAILED=1; echo "OVER ${BUDGET_KB}KB"; })"
}

if [ "$WHICH" = all ] || [ "$WHICH" = plans ]; then
  mkdir -p "$ART/PlanCovers"
  echo "Reading-plan covers  (1200x800, JPEG q$QUALITY)"
  for f in "$SRC"/covers/*.png; do
    slug="$(basename "$f" .png)"
    out="$ART/PlanCovers/plan-$slug-1200x800.jpg"
    jpeg "$f" 1200 800 "$out"
    row "$out"
  done
  scrim "$ART/PlanCovers/plan-cover-scrim-1200x800.png" 1200 800
  row "$ART/PlanCovers/plan-cover-scrim-1200x800.png"
fi

if [ "$WHICH" = all ] || [ "$WHICH" = charity ]; then
  mkdir -p "$ART/Charity"
  echo "Charity cards        (1200x600, JPEG q$QUALITY)"
  for f in "$SRC"/charity/*.png; do
    slug="$(basename "$f" .png)"
    out="$ART/Charity/charity-$slug-1200x600.jpg"
    jpeg "$f" 1200 600 "$out"
    row "$out"
  done
  scrim "$ART/Charity/charity-card-scrim-1200x600.png" 1200 600
  row "$ART/Charity/charity-card-scrim-1200x600.png"
fi

[ "$FAILED" = 0 ] || { echo "covers-from-src.sh: a file is over the ${BUDGET_KB} KB budget" >&2; exit 1; }
