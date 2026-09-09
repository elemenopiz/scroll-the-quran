#!/usr/bin/env bash
# Regenerate every asset in Artwork/ from source.
# Requires: ImageMagick 7 (`magick`), librsvg (`rsvg-convert`), python3.
set -euo pipefail
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

echo "1/7  SVG sources"
python3 compose.py  >/dev/null
python3 envelope.py >/dev/null
python3 frame.py "$SRC/phone-frame.svg"
say "src/*.svg"

echo "2/7  App icon"
mkdir -p "$ART/AppIcon"
for v in "" "-dark"; do
  rsvg-convert -w 1024 -h 1024 "$SRC/appicon$v.svg" -o "$TMP/i.png"
  magick "$TMP/i.png" -background white -alpha remove -alpha off \
         "${PNGOPT[@]}" "$ART/AppIcon/appicon$v-1024.png"
  say "AppIcon/appicon$v-1024.png"
done
rsvg-convert -w 1024 -h 1024 "$SRC/appicon-mono.svg" -o "$TMP/m.png"
magick "$TMP/m.png" -background black -alpha remove -alpha off \
       "${PNGOPT[@]}" "$ART/AppIcon/appicon-mono-1024.png"
magick "$ART/AppIcon/appicon-1024.png" -resize 180x180 -alpha off \
       "${PNGOPT[@]}" "$ART/AppIcon/appicon-180.png"
say "AppIcon/appicon-mono-1024.png, appicon-180.png"

echo "3/7  Logo mark + reader logo card"
mkdir -p "$ART/Logo"
for v in black white; do
  svg "$SRC/mark-$v.svg" 512 512 "$ART/Logo/mark-$v-512.png"
  for s in 64 128 192; do svg "$SRC/mark-$v.svg" $s $s "$ART/Logo/mark-$v-$s.png"; done
done
for s in 96 192 288; do
  svg "$SRC/logo-card.svg"       $s $s "$ART/Logo/logo-card-$s.png"
  svg "$SRC/logo-card-light.svg" $s $s "$ART/Logo/logo-card-light-$s.png"
done
say "Logo/mark-*, Logo/logo-card-*"

echo "4/7  Paywall timeline glyphs"
mkdir -p "$ART/Icons"
for g in lock bell check; do
  for s in 64 128 192; do svg "$SRC/glyph-$g.svg" $s $s "$ART/Icons/icon-$g-$s.png"; done
done
say "Icons/icon-{lock,bell,check}-{64,128,192}.png"

echo "5/7  Gift: envelopes + cloud sky"
mkdir -p "$ART/Gift"
for n in closed open open-back open-front card; do
  svg "$SRC/envelope-$n.svg" 1200 900 "$ART/Gift/envelope-$n-1200x900.png"
  grain "$ART/Gift/envelope-$n-1200x900.png" 4 0.45
  say "Gift/envelope-$n-1200x900.png"
done
python3 clouds.py "$ART/Gift/gift-clouds-1179x2556.png" 5
magick "$ART/Gift/gift-clouds-1179x2556.png" "${PNGOPT[@]}" "$ART/Gift/gift-clouds-1179x2556.png"
say "Gift/gift-clouds-1179x2556.png"

echo "6/7  Onboarding phone frame"
mkdir -p "$ART/Frames"
svg "$SRC/phone-frame.svg" 1179 2556 "$ART/Frames/phone-frame-1179x2556.png"
say "Frames/phone-frame-1179x2556.png"

echo "7/7  Reading-plan covers + charity cards"
python3 covers.py all
for f in "$ART"/PlanCovers/*.png "$ART"/Charity/*.png; do
  magick "$f" "${PNGOPT[@]}" "$f"
done

echo
echo "Contact sheet"
python3 contact_sheet.py
echo "done -> $(du -sh "$ART" | cut -f1)"
