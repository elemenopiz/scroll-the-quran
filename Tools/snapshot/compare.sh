#!/bin/bash
# Compare a captured screen against its reference and print the normalised RMSE.
#
#   Tools/snapshot/compare.sh tabbar-dark
#   Tools/snapshot/compare.sh --raw a.png b.png     # self-test two images directly
#
# Both images are normalised to 393x852 pt, then either cropped to the screen's `crop`
# region or masked over the status bar and home indicator, then blurred (sigma 6) so
# that different words in the same layout do not dominate the score. Exits non-zero
# when the score is above the screen's threshold in Tools/snapshot/thresholds.json.
# Writes a side-by-side reference | capture | difference PNG to
# .build/snapshots/<id>-diff.png.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THRESHOLDS="$ROOT/Tools/snapshot/thresholds.json"
OUTDIR="$ROOT/.build/snapshots"

command -v magick >/dev/null || { echo "compare.sh: ImageMagick 7 (magick) is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "compare.sh: jq is required" >&2; exit 1; }

WIDTH=393
HEIGHT=852
BLUR=6

# normalise <src> <dst> <crop-or-empty> <maskTop> <maskBottom>
normalise() {
  local src="$1" dst="$2" crop="$3" maskTop="$4" maskBottom="$5"
  local args=(magick "$src" -alpha remove -alpha off -colorspace sRGB -resize "${WIDTH}x${HEIGHT}!")
  if [ -n "$crop" ]; then
    args+=(-crop "$crop" +repage)
  else
    args+=(-fill black -stroke none)
    args+=(-draw "rectangle 0,0 $((WIDTH - 1)),$((maskTop - 1))")
    args+=(-draw "rectangle 0,$((HEIGHT - maskBottom)) $((WIDTH - 1)),$((HEIGHT - 1))")
  fi
  args+=(-blur "0x$BLUR" "$dst")
  "${args[@]}"
}

mkdir -p "$OUTDIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "${1:-}" = "--raw" ]; then
  [ $# -eq 3 ] || { echo "usage: compare.sh --raw <a.png> <b.png>" >&2; exit 2; }
  ID="raw"
  REF="$2"
  SHOT="$3"
  CROP=""
  MASK_TOP=54
  MASK_BOTTOM=34
  THRESHOLD=""
else
  ID="${1:-}"
  [ -n "$ID" ] || { echo "usage: compare.sh <screen-id>   |   compare.sh --raw <a.png> <b.png>" >&2; exit 2; }
  entry="$(jq -r --arg id "$ID" '.screens[$id] // empty' "$THRESHOLDS")"
  [ -n "$entry" ] || { echo "compare.sh: unknown screen id '$ID' (see $THRESHOLDS)" >&2; exit 1; }
  REF="$ROOT/Reference/$(printf '%s' "$entry" | jq -r '.file')"
  SHOT="${SCROLL_SNAPSHOT:-$OUTDIR/$ID.png}"
  CROP="$(printf '%s' "$entry" | jq -r '.crop // ""')"
  MASK_TOP="$(jq -r '.defaults.maskTopPT' "$THRESHOLDS")"
  MASK_BOTTOM="$(printf '%s' "$entry" | jq -r --argjson d "$(jq '.defaults.maskBottomPT' "$THRESHOLDS")" '.maskBottomPT // $d')"
  THRESHOLD="$(printf '%s' "$entry" | jq -r '.threshold')"
fi

[ -f "$REF" ] || { echo "compare.sh: missing reference $REF" >&2; exit 1; }
[ -f "$SHOT" ] || { echo "compare.sh: missing capture $SHOT — run Tools/snapshot/capture.sh $ID first" >&2; exit 1; }

normalise "$REF" "$TMP/ref.png" "$CROP" "$MASK_TOP" "$MASK_BOTTOM"
normalise "$SHOT" "$TMP/shot.png" "$CROP" "$MASK_TOP" "$MASK_BOTTOM"

# `compare -metric RMSE` writes "<absolute> (<normalised>)" to stderr and exits 1 when
# the images differ at all, which is not a failure for us.
raw="$(magick compare -metric RMSE "$TMP/ref.png" "$TMP/shot.png" "$TMP/diff.png" 2>&1 || true)"
score="$(printf '%s' "$raw" | sed -n 's/.*(\([0-9.e-]*\)).*/\1/p')"
[ -n "$score" ] || { echo "compare.sh: could not read a score out of: $raw" >&2; exit 1; }

# Side by side: reference | capture | difference, on the measured chip grey.
magick "$TMP/ref.png" "$TMP/shot.png" "$TMP/diff.png" \
  -background '#303035' -splice 4x0 +append -bordercolor '#303035' -border 4 \
  "$OUTDIR/$ID-diff.png"

printf '%s\n' "$score"

if [ -n "$THRESHOLD" ]; then
  if awk -v s="$score" -v t="$THRESHOLD" 'BEGIN { exit !(s <= t) }'; then
    echo "compare.sh: $ID $score <= $THRESHOLD  ->  $OUTDIR/$ID-diff.png" >&2
  else
    echo "compare.sh: $ID $score EXCEEDS $THRESHOLD  ->  $OUTDIR/$ID-diff.png" >&2
    exit 1
  fi
fi
