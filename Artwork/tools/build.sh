#!/usr/bin/env bash
# Regenerate every asset in Artwork/ from source.
# Requires: ImageMagick 7 (`magick`), librsvg (`rsvg-convert`), python3.
#
#   build.sh                 gift layers cut from the generated renders (tools/gift-assets.sh),
#                            plan covers and charity cards cut from src/{covers,charity}/
#   build.sh --vector-gift   the superseded procedural envelopes and sky instead
#   build.sh --procedural    the superseded procedural covers and charity cards (tools/covers.py)
set -euo pipefail
VECTOR_GIFT=0
PROCEDURAL_COVERS=0
for arg in "$@"; do
  case "$arg" in
    --vector-gift) VECTOR_GIFT=1 ;;
    --procedural)  PROCEDURAL_COVERS=1 ;;
    *) echo "build.sh: unknown argument '$arg'" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")"
ART="$(cd .. && pwd)"
SRC="$ART/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PNGOPT=(-strip -define png:compression-level=9 -define png:compression-filter=5)

say() { printf '  %s\n' "$1"; }

svg() {  # svg() <src.svg> <w> <h> <out.png>
  rsvg-convert -w "$2" -h "$3" "$1" -o "$4"
  magick "$4" -background none -alpha Background "${PNGOPT[@]}" "$4"
}

# fine paper grain that leaves the alpha channel untouched
grain() {  # grain() <png> [amount] [attenuate]
  local f="$1" amt="${2:-7}" att="${3:-0.55}"
  magick "$f" -alpha extract "$TMP/ga.png"
  magick -seed 20260909 "$f" -alpha off \
    \( +clone -attenuate "$att" +noise Gaussian \) \
    -compose Blend -define "compose:args=$amt" -composite \
    "$TMP/ga.png" -alpha off -compose CopyAlpha -composite \
    -background none -alpha Background \
    "${PNGOPT[@]}" "$f"
}

echo "1/7  SVG sources (mark/appicon SVGs here are superseded by the supplied logo)"
python3 compose.py  >/dev/null
python3 envelope.py >/dev/null
python3 frame.py "$SRC/phone-frame.svg"
say "src/*.svg"

echo "2/7  App icon"
echo "3/7  Logo mark + reader logo card"
# Both come from the supplied logo, not from src/*.svg — see tools/logo.sh.
./logo.sh

echo "4/7  Paywall timeline glyphs"
mkdir -p "$ART/Icons"
for g in lock bell check; do
  for s in 64 128 192; do svg "$SRC/glyph-$g.svg" $s $s "$ART/Icons/icon-$g-$s.png"; done
done
say "Icons/icon-{lock,bell,check}-{64,128,192}.png"

echo "5/7  Gift: envelopes + cloud sky"
mkdir -p "$ART/Gift"
# The shipped gift screens are cut from the generated renders in src/gift/. The
# procedural envelopes and sky below are superseded but kept as the --vector-gift
# fallback: they are also what the app draws when the asset catalog is absent.
if [ "$VECTOR_GIFT" = 1 ]; then
  for n in closed open open-back open-front card; do
    svg "$SRC/envelope-$n.svg" 1200 900 "$ART/Gift/envelope-$n-1200x900.png"
    grain "$ART/Gift/envelope-$n-1200x900.png" 4 0.45
    say "Gift/envelope-$n-1200x900.png"
  done
  python3 clouds.py "$ART/Gift/gift-clouds-1179x2556.png" 5
  magick "$ART/Gift/gift-clouds-1179x2556.png" "${PNGOPT[@]}" "$ART/Gift/gift-clouds-1179x2556.png"
  say "Gift/gift-clouds-1179x2556.png"
else
  ./gift-assets.sh
fi

echo "6/7  Onboarding phone frame"
mkdir -p "$ART/Frames"
svg "$SRC/phone-frame.svg" 1179 2556 "$ART/Frames/phone-frame-1179x2556.png"
say "Frames/phone-frame-1179x2556.png"

echo "7/7  Reading-plan covers + charity cards"
# The shipped covers and cards are cut from the owner's renders in src/{covers,charity}/
# (see tools/covers-from-src.sh). The procedural set from covers.py is superseded but kept
# behind --procedural, and is what a checkout without src/covers/ falls back to.
if [ "$PROCEDURAL_COVERS" = 1 ] || [ ! -d "$SRC/covers" ]; then
  python3 covers.py all
  for f in "$ART"/PlanCovers/*.png "$ART"/Charity/*.png; do
    magick "$f" "${PNGOPT[@]}" "$f"
  done
else
  ./covers-from-src.sh
fi

echo
echo "Contact sheet"
python3 contact_sheet.py
echo "done -> $(du -sh "$ART" | cut -f1)"
