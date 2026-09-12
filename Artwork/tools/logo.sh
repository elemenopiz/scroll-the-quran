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

# One grey icon ground, as an editable SVG radial: centre `$1`, two steps darker at the
# rim. Five per cent of tone across the whole canvas is enough to stop the ground reading
# as flat vinyl and shallow enough that a 1024 px render shows no banding.
ground_svg() {  # ground_svg <centre hex> <side px> <out.png>
  local c="$1" r g b mid edge
  r=$((16#${c:1:2})); g=$((16#${c:3:2})); b=$((16#${c:5:2}))
  mid=$(printf '#%02X%02X%02X' $((r - 5)) $((g - 5)) $((b - 5)))
  edge=$(printf '#%02X%02X%02X' $((r - 13)) $((g - 13)) $((b - 13)))
  rsvg-convert -w "$2" -h "$2" -o "$3" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$2" height="$2" viewBox="0 0 512 512" fill="none">
<defs><radialGradient id="bg" cx="42%" cy="34%" r="82%">
<stop offset="0" stop-color="$c"/><stop offset="0.55" stop-color="$mid"/><stop offset="1" stop-color="$edge"/>
</radialGradient></defs>
<rect width="512" height="512" fill="url(#bg)"/>
</svg>
SVG
}

# iOS's own icon mask, so a candidate can be judged as the springboard will draw it.
# The corner radius is 22.37 % of the side — the continuous-curve squircle approximated
# by a plain round rect, which is close enough to see whether the ring is being cut.
ios_mask() {  # ios_mask <src.png> <side> <out.png>
  local r
  r=$(printf '%.2f' "$(echo "$2 * 0.2237" | bc -l)")
  rsvg-convert -w "$2" -h "$2" -o "$TMP/mask.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$2" height="$2" viewBox="0 0 $2 $2">
<rect width="$2" height="$2" rx="$r" ry="$r" fill="#FFFFFF"/></svg>
SVG
  magick "$1" -resize "$2x$2" "$TMP/mask.png" -alpha off -compose CopyOpacity -composite \
    "${PNGOPT[@]}" "$3"
}

ICON_SCALE=0.86   # the ring reads as a ring at 60 pt; its diagonal finials still clear
                  # iOS's corner mask by ~190 px on the 1024 (see AppIcon/icon-masked-60.png)
CARD_SCALE=0.80   # ReaderMetrics: 90 pt mark inside a 112 pt card

# The icon ground the app ships, and the two the owner was offered beside it.
ICON_GREY="#3C3C41"
ICON_GREY_CANDIDATES=("#5A5A60" "#3C3C41" "#2A2A2E")

echo "Logo mark (transparent)"
mkdir -p "$ART/Logo"
for s in 64 128 192 512; do
  recolour "$INK_DARK"  "$s" "$ART/Logo/mark-black-$s.png"
  recolour "$INK_LIGHT" "$s" "$ART/Logo/mark-white-$s.png"
done
say "Logo/mark-{black,white}-{64,128,192,512}.png"

echo "Reader logo card"
for s in 112 224 336; do
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
say "Logo/logo-card{,-light}-{112,224,336}.png"

echo "App icon"
mkdir -p "$ART/AppIcon"
# The app is dark, so both appearances sit on the same grey ground with a white mark;
# only the tinted layer differs (mono white on flat black, as iOS requires).
ground_svg "$ICON_GREY" 1024 "$TMP/bg-grey.png"
magick -size 1024x1024 xc:black "$TMP/bg-mono.png"

on_ground "$TMP/bg-grey.png" "$INK_LIGHT" 1024 "$ICON_SCALE" "$TMP/icon.png"
on_ground "$TMP/bg-mono.png" "$INK_LIGHT" 1024 "$ICON_SCALE" "$TMP/icon-mono.png"

# App-icon assets must be fully opaque: iOS applies its own mask and rejects alpha.
magick "$TMP/icon.png"      -background black -alpha remove -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-1024.png"
cp "$ART/AppIcon/appicon-1024.png" "$ART/AppIcon/appicon-dark-1024.png"
magick "$TMP/icon-mono.png" -background black -alpha remove -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-mono-1024.png"
magick "$ART/AppIcon/appicon-1024.png" -resize 180x180 -alpha off "${PNGOPT[@]}" "$ART/AppIcon/appicon-180.png"
ios_mask "$ART/AppIcon/appicon-1024.png" 180 "$ART/AppIcon/icon-masked-60.png"
say "AppIcon/appicon{,-dark,-mono}-1024.png, appicon-180.png, icon-masked-60.png"

echo "App-icon candidate sheet"
# Three greys, each flat at 180 px and again under iOS's 60 pt mask, so the ground can be
# picked on the two things that actually differ: how dark it reads, and how much of the
# ring the corner mask eats.
COLS=()
for grey in "${ICON_GREY_CANDIDATES[@]}"; do
  ground_svg "$grey" 1024 "$TMP/cand-bg.png"
  on_ground "$TMP/cand-bg.png" "$INK_LIGHT" 1024 "$ICON_SCALE" "$TMP/cand.png"
  magick "$TMP/cand.png" -background black -alpha remove -alpha off "$TMP/cand-flat.png"
  magick "$TMP/cand-flat.png" -resize 180x180 "$TMP/cand-180.png"
  ios_mask "$TMP/cand-flat.png" 180 "$TMP/cand-masked.png"
  rsvg-convert -w 220 -h 44 -o "$TMP/cand-label.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="44">
<rect width="220" height="44" fill="#1A1A1E"/>
<text x="110" y="30" font-family="Helvetica, Arial, sans-serif" font-size="21" fill="#D9D9D9" text-anchor="middle">$grey</text></svg>
SVG
  magick -background '#1A1A1E' -gravity center \
    \( "$TMP/cand-180.png" -bordercolor '#1A1A1E' -border 20 \) \
    \( "$TMP/cand-masked.png" -bordercolor '#1A1A1E' -border 20 \) \
    "$TMP/cand-label.png" -append "$TMP/col-$grey.png"
  COLS+=("$TMP/col-$grey.png")
done
magick "${COLS[@]}" -background '#1A1A1E' +append \
  -bordercolor '#1A1A1E' -border 24 "${PNGOPT[@]}" "$ART/AppIcon/icon-candidates.png"
say "AppIcon/icon-candidates.png (left to right: ${ICON_GREY_CANDIDATES[*]}; top flat, bottom masked at 60 pt)"
