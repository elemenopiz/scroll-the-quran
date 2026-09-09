#!/bin/bash
# Capture one screen from the booted simulator into .build/snapshots/<id>.png.
#
#   Tools/snapshot/capture.sh tabbar-dark            # launch the route from thresholds.json, then shoot
#   Tools/snapshot/capture.sh reader-dark --no-launch # shoot whatever is already on screen
#
# The app is launched with `--screenshot <route>` and SCROLL_FIXED_DATE so the capture
# is deterministic, and the simulator appearance is set from the screen's `appearance`.
set -euo pipefail
SIM="${SCROLL_SIM:-booted}"   # UDID or name; defaults to "booted" (ambiguous with several sims up)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THRESHOLDS="$ROOT/Tools/snapshot/thresholds.json"
OUTDIR="$ROOT/.build/snapshots"
BUNDLE_ID="com.scrollthequran.app"
FIXED_DATE="${SCROLL_FIXED_DATE:-2026-09-14}"
SETTLE="${SCROLL_CAPTURE_SETTLE:-2}"

ID="${1:-}"
[ -n "$ID" ] || { echo "usage: capture.sh <screen-id> [--no-launch]" >&2; exit 2; }
LAUNCH=1
[ "${2:-}" = "--no-launch" ] && LAUNCH=0

command -v xcrun >/dev/null || { echo "capture.sh: xcrun is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "capture.sh: jq is required" >&2; exit 1; }

entry="$(jq -r --arg id "$ID" '.screens[$id] // empty' "$THRESHOLDS")"
[ -n "$entry" ] || { echo "capture.sh: unknown screen id '$ID' (see $THRESHOLDS)" >&2; exit 1; }
route="$(printf '%s' "$entry" | jq -r '.route')"
appearance="$(printf '%s' "$entry" | jq -r '.appearance')"

{ [ "$SIM" != booted ] || xcrun simctl list devices booted | grep -q '(Booted)'; } || {
  echo "capture.sh: no booted simulator. Boot one, e.g. 'xcrun simctl boot \"iPhone 17\"'." >&2
  exit 1
}

mkdir -p "$OUTDIR"

if [ "$LAUNCH" -eq 1 ]; then
  xcrun simctl ui "$SIM" appearance "$appearance" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
  SIMCTL_CHILD_SCROLL_FIXED_DATE="$FIXED_DATE" \
    xcrun simctl launch "$SIM" "$BUNDLE_ID" --screenshot "$route" >/dev/null
  # Give SwiftUI a beat to lay out and any animation to settle.
  sleep "$SETTLE"
fi

xcrun simctl io "$SIM" screenshot --type=png "$OUTDIR/$ID.png" >/dev/null 2>&1
echo "$OUTDIR/$ID.png"
