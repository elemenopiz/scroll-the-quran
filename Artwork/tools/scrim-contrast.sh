#!/usr/bin/env bash
# Would white type read over these covers?
#
#   scrim-contrast.sh            # every shipped cover and charity card
#   scrim-contrast.sh <file>…    # just these
#
# Each cover is composited under its scrim exactly as the app composites it
# (`PlanCoverScrim` / `CharityCardScrim`, normal blend, `.overlay`), then the **top 40 %**
# — the band a title would sit in — is measured:
#
#   * `mean`  the band's mean relative luminance, sRGB linearised, Rec. 709 weights;
#   * `worst` the brightest cell of an 8x4 grid over the same band, which is what a line of
#     text actually lands on when the frame has a highlight in it (a lamp flame, a window).
#
# Contrast against white is `1.05 / (L + 0.05)`, so WCAG 4.5:1 needs `L <= 0.1833` and
# 3:1 (large/bold text) needs `L <= 0.3`. A FAIL is reported, never repaired: the fix is a
# different render or a heavier scrim, and both are the owner's call.
#
# NOTE (2026-09, Phase 4k): no white type is drawn over a cover in the app today. Plan
# cards, the plan-detail hero and charity cards all set their labels on the card ground
# *below* the artwork; the only thing over a cover is the black "START HERE" ribbon, which
# carries its own ground. The scrim is also bottom-weighted — its alpha is still ~0 at 40 %
# down — so the top-band figures below are effectively the raw artwork. This is the guard
# for the day a title moves onto the image, not a measurement of a live defect.
set -euo pipefail
cd "$(dirname "$0")"
ART="$(cd .. && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

BAND=0.40
AA_LARGE=0.30      # L for 3:1
AA_NORMAL=0.1833   # L for 4.5:1

lum() {  # lum() <image> -> mean relative luminance of the whole image, linear light
  magick "$1" -colorspace RGB -format '%[fx:0.2126*mean.r+0.7152*mean.g+0.0722*mean.b]' info:
}

FAILED=0
measure() {  # measure() <cover> <scrim>
  local img="$1" scrim="$2" w h bh
  w=$(magick identify -format %w "$img"); h=$(magick identify -format %h "$img")
  bh=$(python3 -c "print(int($h * $BAND))")
  magick "$img" "$scrim" -compose over -composite \
    -gravity north -crop "${w}x${bh}+0+0" +repage "$TMP/band.png"
  local mean worst cr_mean cr_worst verdict
  mean=$(lum "$TMP/band.png")
  # Brightest cell of an 8x4 grid: -resize to the grid in linear light, then take the max.
  worst=$(magick "$TMP/band.png" -colorspace RGB -resize '8x4!' -colorspace sRGB "$TMP/cells.png"
          magick "$TMP/cells.png" -colorspace RGB -format \
            '%[fx:maxima.r*0.2126+maxima.g*0.7152+maxima.b*0.0722]' info:)
  cr_mean=$(python3 -c "print(f'{1.05/($mean+0.05):.2f}')")
  cr_worst=$(python3 -c "print(f'{1.05/($worst+0.05):.2f}')")
  verdict=$(python3 - "$mean" "$worst" "$AA_NORMAL" "$AA_LARGE" <<'PY'
import sys
mean, worst, aa, aal = (float(x) for x in sys.argv[1:5])
# The verdict is the mean's, which is the figure the brief asks for. A bright cell inside
# an otherwise dark band is reported beside it as a hotspot, not counted as a failure.
if mean <= aa:
    print("PASS" if worst <= aa else "PASS, hotspot %.1f:1" % (1.05 / (worst + 0.05)))
elif mean <= aal:
    print("FAIL 4.5:1, clears 3:1")
else:
    print("FAIL")
PY
)
  [[ "$verdict" == PASS* ]] || FAILED=$((FAILED + 1))
  printf '  %-34s %6.4f %7s:1   %6.4f %7s:1   %s\n' \
    "$(basename "$img")" "$mean" "$cr_mean" "$worst" "$cr_worst" "$verdict"
}

printf '  %-34s %6s %9s   %6s %9s   %s\n' file "mean L" "contrast" "worst" "contrast" "white text, top 40%"
if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    case "$f" in
      *charity-*) measure "$f" "$ART/Charity/charity-card-scrim-1200x600.png" ;;
      *) measure "$f" "$ART/PlanCovers/plan-cover-scrim-1200x800.png" ;;
    esac
  done
else
  for f in "$ART"/PlanCovers/plan-*-1200x800.jpg; do
    measure "$f" "$ART/PlanCovers/plan-cover-scrim-1200x800.png"
  done
  for f in "$ART"/Charity/charity-*-1200x600.jpg; do
    measure "$f" "$ART/Charity/charity-card-scrim-1200x600.png"
  done
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "  all frames clear 4.5:1 for white type in the top band"
else
  echo "  $FAILED frame(s) would not carry white type in the top band as scrimmed."
  echo "  Nothing was edited: re-roll the render or darken the scrim."
fi
