#!/bin/bash
# Capture one screen from the booted simulator into .build/snapshots/<id>.png.
#
#   Tools/snapshot/capture.sh tabbar-dark            # launch the route from thresholds.json, then shoot
#   Tools/snapshot/capture.sh reader-dark --no-launch # shoot whatever is already on screen
#   Tools/snapshot/capture.sh discover-dark --appearance light   # the off-appearance walk
#
# The app is launched with `--screenshot <route>` and SCROLL_FIXED_DATE so the capture
# is deterministic, and the simulator appearance is set from the screen's `appearance`.
#
# `--appearance <light|dark>` overrides the screen's own appearance and writes to
# `<id>-<appearance>.png` instead of `<id>.png`, so a both-appearances walk cannot
# overwrite the capture the RMSE gate compares. There is no reference for the
# off-appearance shot; it is for looking at.
#
# **Waiting for first paint.** `SCROLL_CAPTURE_SETTLE` (default 6 s) is how long to give
# SwiftUI before shooting, and the shot is then *checked*: a screen that has not drawn is
# a perfectly flat rectangle, so the capture's standard deviation away from the status bar
# and the home indicator is measured and the capture retried (up to SCROLL_CAPTURE_TRIES,
# default 3) while it is flat. A too-early capture used to come back blank and read as a
# screen regression. Set SCROLL_CAPTURE_SETTLE lower for a hot loop on one screen.
set -euo pipefail
SIM="${SCROLL_SIM:-booted}"   # UDID or name; defaults to "booted" (ambiguous with several sims up)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THRESHOLDS="$ROOT/Tools/snapshot/thresholds.json"
OUTDIR="$ROOT/.build/snapshots"
BUNDLE_ID="com.scrollthequran.app"
FIXED_DATE="${SCROLL_FIXED_DATE:-2026-09-14}"
SETTLE="${SCROLL_CAPTURE_SETTLE:-6}"
TRIES="${SCROLL_CAPTURE_TRIES:-3}"

ID="${1:-}"
[ -n "$ID" ] || { echo "usage: capture.sh <screen-id> [--no-launch] [--appearance light|dark]" >&2; exit 2; }
shift
LAUNCH=1
FORCED_APPEARANCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-launch) LAUNCH=0; shift ;;
    --appearance)
      shift
      case "${1:-}" in
        light|dark) FORCED_APPEARANCE="$1"; shift ;;
        *) echo "capture.sh: --appearance takes 'light' or 'dark'" >&2; exit 2 ;;
      esac
      ;;
    *) echo "capture.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

command -v xcrun >/dev/null || { echo "capture.sh: xcrun is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "capture.sh: jq is required" >&2; exit 1; }

entry="$(jq -r --arg id "$ID" '.screens[$id] // empty' "$THRESHOLDS")"
[ -n "$entry" ] || { echo "capture.sh: unknown screen id '$ID' (see $THRESHOLDS)" >&2; exit 1; }
route="$(printf '%s' "$entry" | jq -r '.route')"
appearance="$(printf '%s' "$entry" | jq -r '.appearance')"
OUT_ID="$ID"
if [ -n "$FORCED_APPEARANCE" ] && [ "$FORCED_APPEARANCE" != "$appearance" ]; then
  appearance="$FORCED_APPEARANCE"
  OUT_ID="$ID-$FORCED_APPEARANCE"
fi

{ [ "$SIM" != booted ] || xcrun simctl list devices booted | grep -q '(Booted)'; } || {
  echo "capture.sh: no booted simulator. Boot one, e.g. 'xcrun simctl boot \"iPhone 17\"'." >&2
  exit 1
}

mkdir -p "$OUTDIR"

# Prints 1 when a capture has content, 0 when it is a screen that has not drawn yet.
# The central 80x60 % is measured, so the status bar (which always draws) and the home
# indicator cannot make a blank screen look painted. A flat rectangle scores 0; a drawn
# screen in this app scores several points in either appearance.
ink() {
  command -v magick >/dev/null || { echo 1; return; }
  local sd
  sd="$(magick "$1" -gravity center -crop '80x60%+0+0' +repage \
        -format '%[fx:standard_deviation*100]' info: 2>/dev/null)"
  awk -v v="${sd:-0}" 'BEGIN { print (v > 1.0) ? 1 : 0 }'
}

OUT="$OUTDIR/$OUT_ID.png"

if [ "$LAUNCH" -eq 1 ]; then
  xcrun simctl ui "$SIM" appearance "$appearance" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
  SIMCTL_CHILD_SCROLL_FIXED_DATE="$FIXED_DATE" \
    xcrun simctl launch "$SIM" "$BUNDLE_ID" --screenshot "$route" >/dev/null
  # Give SwiftUI a beat to lay out and any animation to settle, then prove it drew.
  painted=0
  for attempt in $(seq 1 "$TRIES"); do
    sleep "$SETTLE"
    xcrun simctl io "$SIM" screenshot --type=png "$OUT" >/dev/null 2>&1
    if [ "$(ink "$OUT")" -eq 1 ]; then painted=1; break; fi
    echo "capture.sh: $OUT_ID still blank after $((attempt * SETTLE))s, waiting" >&2
  done
  if [ "$painted" -eq 0 ]; then
    echo "capture.sh: $OUT_ID ($route) never drew — blank after $((TRIES * SETTLE))s." >&2
    echo "  xcrun simctl launch $SIM $BUNDLE_ID --screenshot $route" >&2
    exit 1
  fi
else
  xcrun simctl io "$SIM" screenshot --type=png "$OUT" >/dev/null 2>&1
fi

echo "$OUT"
