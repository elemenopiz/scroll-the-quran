#!/usr/bin/env bash
# Derive every app-facing rendition of the brand mark from the supplied logo.
#
# Master: Artwork/Logo/Variants/logo-transparent.png (black arabesque ring on alpha,
# 1254 square). Everything below is that one artwork re-coloured, re-scaled and set
# on the grounds the app already uses — so the icon, the paywall header, the reader
# card and the bare marks are all provably the same shape.
#
# Requires: ImageMagick 7 (`magick`), librsvg (`rsvg-convert`).
set -euo pipefail
cd "$(dirname "$0")"
ART="$(cd .. && pwd)"
SRC="$ART/src"
MASTER="$ART/Logo/Variants/logo-transparent.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PNGOPT=(-strip -define png:compression-level=9 -define png:compression-filter=5)

INK_DARK="#0B0B0D"    # mark on light ground — matches Tokens.textPrimary ink
INK_LIGHT="#FFFFFF"   # mark on dark ground
CARD_DARK="#1E1E23"
CARD_LIGHT="#EFEDE7"

say() { printf '  %s\n' "$1"; }

# The supplied PNG carries ~4 % of empty margin and is 9 px off square. Trim it to the
# ink, then re-centre on a square canvas so every downstream size shares one origin.
magick "$MASTER" -trim +repage \
  -background none -gravity center -extent "%[fx:max(w,h)]x%[fx:max(w,h)]" \
  -resize 2048x2048 "$TMP/master.png"

# The artwork is a solid silhouette, so its alpha *is* the shape. Flooding a colour
# through that alpha recolours it with no fringing — a `-colorize` would leave the
# original near-black bleeding into the white variant's edges.
recolour() {  # recolour <hex> <size> <out.png>
  magick "$TMP/master.png" -resize "$2x$2" -alpha extract "$TMP/a.png"
  magick -size "$2x$2" "xc:$1" "$TMP/a.png" -alpha off \
    -compose CopyOpacity -composite "${PNGOPT[@]}" "$3"
}

# The mark on a ground, inset to `scale` of the canvas.
on_ground() {  # on_ground <ground.png> <ink hex> <side> <scale> <out.png>
  local mark_px
  mark_px=$(printf '%.0f' "$(echo "$3 * $4" | bc -l)")
  recolour "$2" "$mark_px" "$TMP/m.png"
  magick "$1" "$TMP/m.png" -gravity center -compose over -composite "$TMP/c.png"
  magick "$TMP/c.png" "${PNGOPT[@]}" "$5"
}

ICON_SCALE=0.78   # ring reads as a ring at 60 pt without crowding iOS's corner mask
CARD_SCALE=0.74   # ReaderMetrics: 70 pt mark inside a 94 pt card

echo "Logo mark (transparent)"
mkdir -p "$ART/Logo"
for s in 64 128 192 512; do
  recolour "$INK_DARK"  "$s" "$ART/Logo/mark-black-$s.png"
  recolour "$INK_LIGHT" "$s" "$ART/Logo/mark-white-$s.png"
done
say "Logo/mark-{black,white}-{64,128,192,512}.png"

echo "Reader logo card"
for s in 96 192 288; do
  r=$(printf '%.4f' "$(echo "$s * 0.2175" | bc -l)")   # 21.75 % of the side
  rsvg-convert -w "$s" -h "$s" -o "$TMP/gd.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$s" height="$s" viewBox="0 0 $s $s">
<rect width="$s" height="$s" rx="$r" ry="$r" fill="$CARD_DARK"/></svg>
SVG
  rsvg-convert -w "$s" -h "$s" -o "$TMP/gl.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$s" height="$s" viewBox="0 0 $s $s">
<rect width="$s" height="$s" rx="$r" ry="$r" fill="$CARD_LIGHT"/></svg>
SVG
  on_ground "$TMP/gd.png" "$INK_LIGHT" "$s" "$CARD_SCALE" "$ART/Logo/logo-card-$s.png"
  on_ground "$TMP/gl.png" "$INK_DARK"  "$s" "$CARD_SCALE" "$ART/Logo/logo-card-light-$s.png"
done
say "Logo/logo-card{,-light}-{96,192,288}.png"

echo "App icon"
mkdir -p "$ART/AppIcon"
# Same radial grounds the previous icon used, kept as SVG so the stops stay editable.
rsvg-convert -w 1024 -h 1024 -o "$TMP/bg-light.png" "$SRC/appicon-ground.svg"
rsvg-convert -w 1024 -h 1024 -o "$TMP/bg-dark.png"  "$SRC/appicon-ground-dark.svg"
magick -size 1024x1024 xc:black "$TMP/bg-mono.png"

on_ground "$TMP/bg-light.png" "$INK_DARK"  1024 "$ICON_SCALE" "$TMP/icon.png"
on_ground "$TMP/bg-dark.png"  "$INK_LIGHT" 1024 "$ICON_SCALE" "$TMP/icon-dark.png"
on_ground "$TMP/bg-mono.png"  "$INK_LIGHT" 1024 "$ICON_SCALE" "$TMP/icon-mono.png"

# App-icon assets must be fully opaque: iOS applies its own mask and rejects alpha.
magick "$TMP/icon.png"      -background white -alpha remove -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-1024.png"
magick "$TMP/icon-dark.png" -background black -alpha remove -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-dark-1024.png"
magick "$TMP/icon-mono.png" -background black -alpha remove -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-mono-1024.png"
magick "$ART/AppIcon/appicon-1024.png" -resize 180x180 -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-180.png"
say "AppIcon/appicon{,-dark,-mono}-1024.png, appicon-180.png"
