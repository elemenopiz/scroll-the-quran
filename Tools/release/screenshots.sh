#!/bin/bash
# Generate the App Store screenshot sets from the simulator.
#
#   Tools/release/screenshots.sh                 # build if needed, capture, frame, write both sets
#   Tools/release/screenshots.sh --no-build      # reuse the app already in .build/DerivedData
#   Tools/release/screenshots.sh --frames-only   # re-frame the captures in .build/screenshots
#   Tools/release/screenshots.sh --keep-booted   # leave the simulator running afterwards
#
# Each screen is launched through the app's own `--screenshot <route>` entry point with
# SCROLL_FIXED_DATE pinned, so the captures are deterministic (same streak, same date,
# same fixture verses) and premium content is unlocked by the fixture entitlement store.
#
# The raw capture is 1206x2622 (iPhone 17 at @3x), which is not an App Store size. Each
# one is scaled to fill the transparent PhoneFrame's screen window (x30 y30, 1119x2496,
# corner radius 160 in the frame's 1179x2556 artwork space — never stretched, see
# AppShell/ArtworkAssets.swift) and laid on a captioned canvas at the two sizes App Store
# Connect asks for:
#     6.9"  1290x2796   (iPhone 17 Pro Max / 16 Pro Max)
#     6.5"  1284x2778   (iPhone 14 Plus / 13 Pro Max)
#
# Simulator: ScrollSim-3d only. Set SCROLL_SIM to its UDID, or the script looks it up by
# name. It boots the device, uses `-destination id=<udid>` (never "booted") and shuts it
# down again at the end.
#
# Output: docs/store/screenshots/{6.9,6.5}/NN-<id>.png

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SIM_NAME="ScrollSim-3d"
DERIVED="$RELEASE_ROOT/.build/DerivedData"
RAW_DIR="$RELEASE_ROOT/.build/screenshots"
OUT_DIR="$RELEASE_ROOT/docs/store/screenshots"
FRAME="$RELEASE_ROOT/Artwork/Frames/phone-frame-1179x2556.png"
FONT="$RELEASE_ROOT/Packages/ScrollKit/Sources/DesignSystem/Resources/Fonts/Poppins-SemiBold.ttf"
FIXED_DATE="${SCROLL_FIXED_DATE:-2026-09-14}"
SETTLE="${SCROLL_CAPTURE_SETTLE:-3}"

# The frame's transparent screen window, in the frame's own pixels.
WIN_X=30; WIN_Y=30; WIN_W=1119; WIN_H=2496; WIN_R=160

# id|route|appearance|caption   — order is the App Store display order.
SHOTS=(
  "01-reader|reader|dark|One verse at a time"
  "02-home|home#scrolled|dark|Keep a daily rhythm"
  "03-discover|discover|dark|Discover by theme"
  "04-deepstudy|deepstudy|dark|Go deeper on every passage"
  "05-community|community|dark|Read together, give together"
)

BUILD=1
FRAMES_ONLY=0
KEEP_BOOTED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) BUILD=0; shift ;;
    --frames-only) FRAMES_ONLY=1; BUILD=0; shift ;;
    --keep-booted) KEEP_BOOTED=1; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" 2 ;;
  esac
done

cd "$RELEASE_ROOT"
need magick "brew install imagemagick"
need xcrun
[ -f "$FRAME" ] || die "no phone frame at $FRAME"
[ -f "$FONT" ] || die "no caption font at $FONT"

mkdir -p "$RAW_DIR" "$OUT_DIR/6.9" "$OUT_DIR/6.5"

# --- framing ---------------------------------------------------------------
# frame_one <raw.png> <canvas-w> <canvas-h> <caption> <out.png>
frame_one() {
  local raw="$1" cw="$2" ch="$3" caption="$4" out="$5"
  local tmp; tmp="$(mktemp -d)"

  # Scale the capture to *fill* the window (the capture is 0.460:1, the window 0.448:1),
  # centre-crop it, and round its corners to the window's radius.
  magick "$raw" -alpha off -resize "${WIN_W}x${WIN_H}^" -gravity center -extent "${WIN_W}x${WIN_H}" \
    \( -size "${WIN_W}x${WIN_H}" xc:black -fill white \
       -draw "roundrectangle 0,0,$((WIN_W-1)),$((WIN_H-1)),$WIN_R,$WIN_R" -alpha off \) \
    -compose CopyOpacity -composite "$tmp/screen.png"

  # Slide it into the frame's window, frame on top so the bezel and island overlap it.
  magick -size 1179x2556 xc:none \
    "$tmp/screen.png" -geometry "+${WIN_X}+${WIN_Y}" -composite \
    "$FRAME" -composite "$tmp/device.png"

  local phone_w phone_h phone_x phone_y cap_w cap_size cap_y
  phone_w=$(( cw * 80 / 100 ))
  phone_h=$(( phone_w * 2556 / 1179 ))
  phone_x=$(( (cw - phone_w) / 2 ))
  phone_y=$(( ch * 135 / 1000 ))
  cap_w=$(( cw * 84 / 100 ))
  cap_size=$(( cw * 54 / 1000 ))
  cap_y=$(( ch * 40 / 1000 ))

  magick "$tmp/device.png" -resize "${phone_w}x${phone_h}!" "$tmp/phone.png"
  magick -background none -fill '#FFFFFF' -font "$FONT" -pointsize "$cap_size" \
    -size "${cap_w}x" -gravity center caption:"$caption" "$tmp/caption.png"

  magick -size "${cw}x${ch}" gradient:'#241D16-#0B0B0D' \
    "$tmp/caption.png" -gravity north -geometry "+0+${cap_y}" -composite \
    "$tmp/phone.png" -gravity northwest -geometry "+${phone_x}+${phone_y}" -composite \
    -alpha remove -alpha off -colorspace sRGB -strip "$out"

  rm -rf "$tmp"
}

# --- capture ---------------------------------------------------------------
if [ "$FRAMES_ONLY" -eq 0 ]; then
  step "Simulator"
  SIM="${SCROLL_SIM:-}"
  if [ -z "$SIM" ]; then
    SIM="$(xcrun simctl list devices -j | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
print(next((x["udid"] for v in d.values() for x in v if x["name"]=="'"$SIM_NAME"'"), ""))')"
  fi
  [ -n "$SIM" ] || die "no simulator named $SIM_NAME. Create it, or set SCROLL_SIM to a UDID."
  ok "$SIM_NAME $SIM"

  STATE="$(xcrun simctl list devices -j | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
print(next((x["state"] for v in d.values() for x in v if x["udid"]=="'"$SIM"'"), "missing"))')"
  if [ "$STATE" != Booted ]; then
    xcrun simctl boot "$SIM" || die "could not boot $SIM"
    xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
    ok "booted"
  else
    ok "already booted"
  fi

  APP="$DERIVED/Build/Products/Debug-iphonesimulator/ScrollTheQuran.app"
  if [ "$BUILD" -eq 1 ]; then
    step "Build for the simulator"
    need xcodegen
    xcodegen generate >/dev/null || die "xcodegen generate"
    set -o pipefail
    xcodebuild build -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,id=$SIM" \
      -derivedDataPath "$DERIVED" 2>&1 | beautify | tail -5 || die "xcodebuild build"
    set +o pipefail
  fi
  [ -d "$APP" ] || die "no app at $APP — drop --no-build"
  xcrun simctl install "$SIM" "$APP" >/dev/null || die "simctl install"
  ok "installed $APP_BUNDLE_ID"

  step "Capture"
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r id route appearance _caption <<< "$shot"
    xcrun simctl ui "$SIM" appearance "$appearance" >/dev/null 2>&1 || true
    xcrun simctl terminate "$SIM" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    SIMCTL_CHILD_SCROLL_FIXED_DATE="$FIXED_DATE" \
      xcrun simctl launch "$SIM" "$APP_BUNDLE_ID" --screenshot "$route" >/dev/null \
      || die "could not launch --screenshot $route"
    sleep "$SETTLE"
    xcrun simctl io "$SIM" screenshot --type=png "$RAW_DIR/$id.png" >/dev/null 2>&1 \
      || die "could not capture $id"
    ok "$id ($route, $appearance) $(magick identify -format '%wx%h' "$RAW_DIR/$id.png")"
  done
  xcrun simctl terminate "$SIM" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

  if [ "$KEEP_BOOTED" -eq 0 ]; then
    xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
    ok "simulator shut down"
  fi
fi

# --- frame -----------------------------------------------------------------
step "Frame"
for shot in "${SHOTS[@]}"; do
  IFS='|' read -r id _route _appearance caption <<< "$shot"
  raw="$RAW_DIR/$id.png"
  [ -f "$raw" ] || die "no capture at $raw — run without --frames-only"
  frame_one "$raw" 1290 2796 "$caption" "$OUT_DIR/6.9/$id.png"
  frame_one "$raw" 1284 2778 "$caption" "$OUT_DIR/6.5/$id.png"
  ok "$id -> 6.9/$id.png, 6.5/$id.png"
done

step "Verify the sets"
FAILED=0
for spec in "6.9 1290 2796" "6.5 1284 2778"; do
  set -- $spec
  dir="$OUT_DIR/$1"; want="${2}x${3}"
  count=0
  for f in "$dir"/*.png; do
    got="$(magick identify -format '%wx%h' "$f")"
    if [ "$got" != "$want" ]; then printf 'FAIL %s is %s, expected %s\n' "$f" "$got" "$want"; FAILED=1; fi
    alpha="$(magick identify -format '%A' "$f")"
    [ "$alpha" = "Undefined" ] || [ "$alpha" = "False" ] || { printf 'FAIL %s still has an alpha channel\n' "$f"; FAILED=1; }
    count=$((count + 1))
  done
  [ "$count" -ge 1 ] && [ "$count" -le 10 ] || { printf 'FAIL %s has %s screenshots (App Store allows 1-10)\n' "$dir" "$count"; FAILED=1; }
  [ "$FAILED" -eq 0 ] && ok "$1: $count screenshots at $want, no alpha"
done
[ "$FAILED" -eq 0 ] || die "the generated sets are not App Store shaped"

printf '\n\033[32m==> screenshots PASS\033[0m — see docs/store/screenshots.md\n'
