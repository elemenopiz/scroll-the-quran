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
# slides should advertise, then cut down to the phone's screen window: 1119x2496 px at
# +30+30 out of the 1179x2556 px frame (a 10 pt bezel on every side), with the 160 px
# (53.3 pt) corner radius the device has. The result drops straight into `PhoneFrame`,
# whose own clip shape has the same proportions.
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

# The phone's screen window inside a 1179x2556 px capture, and its corner radius.
# 30 px = the 10 pt bezel `OnboardingMetrics.phoneBezel` draws at @3x.
CROP_W=1119
CROP_H=2496
CROP_X=30
CROP_Y=30
CORNER=160

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

# Pixels to drop off the top of the captured window before it goes in the frame.
#
# `plans-sheet` is a *sheet*, so its capture carries 185 px of the dimmed parent screen
# above the sheet's rounded top edge. Inside a 228 pt phone frame that band reads as a
# black bar, and the reference slide shows the plans list filling the screen. 185 is
# measured: the sheet is full width from that row down.
trim_top_for() {
    case "$1" in
        plans) echo 185 ;;
        *) echo 0 ;;
    esac
}

# Pixels of the screen's own ground to put back at the top after trimming.
#
# `PhoneFrame` draws the Dynamic Island over the top 26 pt (136 px at this scale) of the
# window, so a trim that brings real content up to y 0 hides it: the plans sheet's
# "Reading Plans / Done" header ended up behind the island. Padding the trim back with the
# colour of the first surviving row puts the header where a status bar would leave it, and
# the band under the island is the sheet's own background rather than a black bar.
pad_top_for() {
    case "$1" in
        plans) echo 210 ;;
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

    # Normalise to the reference device (1179x2556) before cropping, so the window is
    # the same slice of the design whatever simulator this ran on, then round the
    # corners with an alpha mask.
    trim="$(trim_top_for "$name")"
    pad="$(pad_top_for "$name")"
    magick "$WORK/$name-raw.png" -alpha remove -alpha off -colorspace sRGB \
        -resize '1179x2556!' -crop "${CROP_W}x${CROP_H}+${CROP_X}+${CROP_Y}" +repage \
        -crop "${CROP_W}x$((CROP_H - trim))+0+${trim}" +repage \
        "$WORK/$name-trim.png"
    ground="$(magick "$WORK/$name-trim.png" -format '%[pixel:p{560,4}]' info:)"
    magick "$WORK/$name-trim.png" \
        -background "$ground" -gravity north -splice "0x${pad}" \
        -resize "${CROP_W}x${CROP_H}!" \
        "$WORK/$name-window.png"
    # White inside the rounded rectangle, black outside, no alpha of its own — the mask
    # is read as *intensity* by CopyOpacity. Drawing on `xc:none` instead leaves the
    # whole mask at alpha 0, which silently makes every shipped PNG invisible.
    magick -size "${CROP_W}x${CROP_H}" xc:black -fill white \
        -draw "roundrectangle 0,0,$((CROP_W - 1)),$((CROP_H - 1)),$CORNER,$CORNER" \
        -alpha off "$WORK/$name-mask.png"
    magick "$WORK/$name-window.png" "$WORK/$name-mask.png" \
        -alpha off -compose CopyOpacity -composite \
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
