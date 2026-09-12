#!/bin/bash
# Render the onboarding slides' phone-frame mockups from the real app.
#
#   SCROLL_SIM=<udid> Tools/snapshot/render-mockups.sh              # all four
#   SCROLL_SIM=<udid> Tools/snapshot/render-mockups.sh reader       # just one
#
# The funnel slides show our own screens inside a `PhoneFrame`. `FeatureOnboarding` sits
# below `FeatureReader`/`FeatureHome`/`FeatureDiscover` in the package graph and cannot
# import them, so the screens are captured here and shipped as PNGs
# (`Sources/FeatureOnboarding/Resources/Mockup-<name>.png`), which `MockupArt` draws.
#
# Each capture is the app launched with `--screenshot <route>` and the fixture state the
# slides should advertise, kept **whole** — status bar, Dynamic Island, home indicator and
# all — and shipped at 690x1500 px with the display's 55 pt corner radius cut into its
# alpha. Nothing is cropped: `PhoneFrame`'s screen window has the device's own 402:874
# aspect, so `MockupArt` fits the capture into it edge to edge. (Until Phase 4h these were
# 1119x2496 windows cut out of a 1179x2556 frame and then scaled to *fill* a window of a
# different aspect, which sliced the clock off the status bar and the outer tab labels off
# both sides — and cost 4.4 MB of bundle.)
#
# Re-run after any change to the reader, plans, discover or search screens, and commit
# the PNGs — the app never renders these live.
set -euo pipefail

SIM="${SCROLL_SIM:-booted}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTDIR="$ROOT/Packages/ScrollKit/Sources/FeatureOnboarding/Resources"
WORK="$ROOT/.build/mockups"
BUNDLE_ID="com.scrollthequran.app"
FIXED_DATE="${SCROLL_FIXED_DATE:-2026-09-14}"
FIXTURE="${SCROLL_FIXTURE_STATE:-premium-active-plan}"
SETTLE="${SCROLL_CAPTURE_SETTLE:-3}"

# The capture's native size (iPhone 17 Pro, 402x874 pt at @3x) and the size we ship.
# 690 px is ~3x the ~223 pt the screen window is drawn at on a slide; the corner radius is
# the display's own 55 pt at the shipped scale (55 * 690 / 402).
NATIVE_W=1206
NATIVE_H=2622
OUT_W=690
OUT_H=1500
CORNER=94

# name -> --screenshot route. The names are `OnboardingContent.Mockup` raw values.
# `deepstudy` renders `verse-search`: the reference slide 4 (onboarding-slide4-search.png)
# shows the search screen, which is what that slide's phone frame has to hold.
route_for() {
    case "$1" in
        reader) echo "reader" ;;
        plans) echo "plans-sheet" ;;
        discover) echo "discover" ;;
        deepstudy) echo "verse-search" ;;
        *) return 1 ;;
    esac
}

# Pixels to drop off the top of the capture, and pixels of the screen's own ground to put
# back in their place.
#
# `plans-sheet` is a *sheet*, so its capture carries 236 px of the dimmed parent screen
# above the sheet's first full-width row. Inside a 223 pt phone frame that band reads as a
# black bar, and the reference slide shows the plans list filling the screen. 236 is
# measured — it is the first row where the sheet's own #FAFAFC reaches both edges, i.e.
# past its rounded top corners — and trimming and padding by the same amount leaves every
# row of the sheet exactly where
# it was while replacing the dimmed band with the sheet's own background. This is the one
# mockup with no status bar in it: iOS dims the parent screen to *black* behind a sheet,
# where the reference's slide 2 shows a light grey band with the clock still legible on it,
# and a black bar across the top of the phone is the worse of the two wrongs.
trim_top_for() {
    case "$1" in
        plans) echo 236 ;;
        *) echo 0 ;;
    esac
}

pad_top_for() {
    case "$1" in
        plans) echo 236 ;;
        *) echo 0 ;;
    esac
}

command -v magick >/dev/null || { echo "render-mockups.sh: ImageMagick 7 (magick) is required" >&2; exit 1; }

NAMES=("$@")
if [ "${#NAMES[@]}" -eq 0 ]; then
    NAMES=(reader plans discover deepstudy)
fi

{ [ "$SIM" != booted ] || xcrun simctl list devices booted | grep -q '(Booted)'; } || {
    echo "render-mockups.sh: no booted simulator (set SCROLL_SIM=<udid>)." >&2
    exit 1
}

mkdir -p "$OUTDIR" "$WORK"

# The slides are a light-appearance screen; the mockups inside them are light too.
xcrun simctl ui "$SIM" appearance light >/dev/null 2>&1 || true

for name in "${NAMES[@]}"; do
    route="$(route_for "$name")" || { echo "render-mockups.sh: unknown mockup '$name'" >&2; exit 1; }

    xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
    SIMCTL_CHILD_SCROLL_FIXED_DATE="$FIXED_DATE" \
        xcrun simctl launch "$SIM" "$BUNDLE_ID" \
        --screenshot "$route" --fixture-state "$FIXTURE" >/dev/null
    sleep "$SETTLE"
    xcrun simctl io "$SIM" screenshot --type=png "$WORK/$name-raw.png" >/dev/null 2>&1

    # Normalise to the device's native @3x size, so the shipped PNG is the same slice of
    # the design whatever simulator this ran on, then scale it down and round the corners
    # with an alpha mask.
    trim="$(trim_top_for "$name")"
    pad="$(pad_top_for "$name")"
    magick "$WORK/$name-raw.png" -alpha remove -alpha off -colorspace sRGB \
        -resize "${NATIVE_W}x${NATIVE_H}!" \
        -crop "${NATIVE_W}x$((NATIVE_H - trim))+0+${trim}" +repage \
        "$WORK/$name-trim.png"
    ground="$(magick "$WORK/$name-trim.png" -format '%[pixel:p{600,40}]' info:)"
    magick "$WORK/$name-trim.png" \
        -background "$ground" -gravity north -splice "0x${pad}" \
        -resize "${OUT_W}x${OUT_H}!" \
        "$WORK/$name-window.png"
    # White inside the rounded rectangle, black outside, no alpha of its own — the mask
    # is read as *intensity* by CopyOpacity. Drawing on `xc:none` instead leaves the
    # whole mask at alpha 0, which silently makes every shipped PNG invisible.
    magick -size "${OUT_W}x${OUT_H}" xc:black -fill white \
        -draw "roundrectangle 0,0,$((OUT_W - 1)),$((OUT_H - 1)),$CORNER,$CORNER" \
        -alpha off "$WORK/$name-mask.png"
    magick "$WORK/$name-window.png" "$WORK/$name-mask.png" \
        -alpha off -compose CopyOpacity -composite \
        -strip -define png:compression-level=9 \
        "$OUTDIR/Mockup-$name.png"

    # Prove it: an all-transparent or all-flat capture is the failure mode this script
    # has, and both look fine in a directory listing.
    alpha="$(magick "$OUTDIR/Mockup-$name.png" -alpha extract -format '%[fx:maxima]' info:)"
    ink="$(magick "$OUTDIR/Mockup-$name.png" -alpha off -format '%[fx:standard_deviation]' info:)"
    awk -v a="$alpha" -v i="$ink" 'BEGIN { exit !(a > 0.9 && i > 0.02) }' || {
        echo "render-mockups.sh: $name came out blank (alpha max $alpha, contrast $ink)" >&2
        exit 1
    }

    echo "$OUTDIR/Mockup-$name.png  ($route, alpha $alpha, contrast $ink)"
done

xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
