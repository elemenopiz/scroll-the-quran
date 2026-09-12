#!/bin/bash
# The single gate. Every task must leave this exiting 0.
#
#   Tools/verify.sh                          # generate, host build + tests, simulator build
#   Tools/verify.sh --ui                     # + XCUITest layout specs on the simulator
#   Tools/verify.sh --snap tabbar-dark home  # + capture those screens and compare to Reference/
#   Tools/verify.sh --snap all               # + every screen in Tools/snapshot/thresholds.json
#   Tools/verify.sh --snap all --both        # + a second capture of each in the other appearance
#   Tools/verify.sh --skip-sim               # host only (no Xcode / no simulator)
#
# `--snap all` is the whole sweep: every id in thresholds.json, which is a superset of
# `Reference/manifest.json` (it adds reader-light, verse-search, plans-sheet, plan-detail
# and the tabbar-dark crop). A manifest id with no thresholds entry is reported as a gap.
#
# `--both` adds an off-appearance capture of every requested screen, written to
# `.build/snapshots/<id>-<light|dark>.png`. Those are for *looking at* — the walk the
# professional-polish pass needs — and are not scored: the reference only exists in the
# screen's own appearance.
#
# Stages: xcodegen -> content checks -> swift build -> swift test -> xcodebuild build
#         -> [XCUITests] -> [snapshots]. Non-zero on the first failure.
set -uo pipefail
SIM="${SCROLL_SIM:-booted}"   # UDID or name; defaults to "booted" (ambiguous with several sims up)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="ScrollTheQuran"
# With SCROLL_SIM set, xcodebuild is pinned to that exact device so a parallel task
# cannot boot a second simulator behind our back; otherwise the default by-name lookup.
if [ "$SIM" = booted ]; then
  DESTINATION="platform=iOS Simulator,name=iPhone 17"
else
  DESTINATION="platform=iOS Simulator,id=$SIM"
fi
DERIVED=".build/DerivedData"
BUNDLE_ID="com.scrollthequran.app"

RUN_UI=0
SKIP_SIM=0
SNAP_BOTH=0
SNAP_IDS=()
THRESHOLDS="Tools/snapshot/thresholds.json"
MANIFEST="Reference/manifest.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --ui) RUN_UI=1; shift ;;
    --skip-sim) SKIP_SIM=1; shift ;;
    --both) SNAP_BOTH=1; shift ;;
    --snap) shift; while [ $# -gt 0 ] && [[ "$1" != --* ]]; do SNAP_IDS+=("$1"); shift; done ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "verify.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# `--snap all` -> every screen id in thresholds.json, in the file's own order.
if [ "${#SNAP_IDS[@]}" -eq 1 ] && [ "${SNAP_IDS[0]}" = all ]; then
  if ! command -v jq >/dev/null; then
    echo "verify.sh: --snap all needs jq" >&2; exit 2
  fi
  SNAP_IDS=()
  while IFS= read -r id; do SNAP_IDS+=("$id"); done < <(jq -r '.screens | keys_unsorted[]' "$THRESHOLDS")
  # Every manifest screen must be scoreable; say so loudly rather than silently skipping.
  MISSING="$(jq -r --slurpfile t "$THRESHOLDS" \
    '[.screens[].id] - ($t[0].screens | keys) | join(" ")' "$MANIFEST")"
  if [ -n "$MISSING" ]; then
    echo "verify.sh: manifest ids with no thresholds entry: $MISSING" >&2
  fi
fi

FAILED=0
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '\033[33mWARN\033[0m %s\n' "$1"; }
fail() { printf '\033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

beautify() { if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi; }

APP_GROUP="group.com.scrollthequran"

# Put the simulator back to a first-run state for the app: no installed app, and an empty
# App Group container. See the call site for why the second half is not optional.
reset_state() {
  if [ "${SCROLL_ERASE:-0}" = 1 ]; then
    xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
    xcrun simctl erase "$SIM" >/dev/null 2>&1 || warn "could not erase $SIM"
    xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
    ok "erased $SIM"
    return
  fi

  # The group container's path, while the app that declares the group is still installed.
  local group
  group="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" "$APP_GROUP" 2>/dev/null || true)"
  xcrun simctl uninstall "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true

  # With the app gone `get_app_container` cannot answer any more, and the path it gave
  # before the uninstall can be stale — iOS recreates the group container under a fresh
  # UUID after an uninstall, so the old one no longer exists. Either way, fall back to
  # reading the group id out of each shared container's own metadata plist. The condition
  # is "not a directory", not "empty": a stale path is non-empty and used to skip this.
  if [ ! -d "${group:-}" ]; then
    local root="$HOME/Library/Developer/CoreSimulator/Devices/$SIM/data/Containers/Shared/AppGroup"
    if [ -d "$root" ]; then
      local meta id
      for candidate in "$root"/*; do
        meta="$candidate/.com.apple.mobile_container_manager.metadata.plist"
        [ -f "$meta" ] || continue
        id="$(/usr/libexec/PlistBuddy -c 'Print :MCMMetadataIdentifier' "$meta" 2>/dev/null || true)"
        [ "$id" = "$APP_GROUP" ] && { group="$candidate"; break; }
      done
    fi
  fi

  if [ -d "${group:-}" ]; then
    find "$group" -mindepth 1 -maxdepth 1 ! -name '.com.apple.mobile_container_manager.metadata.plist' \
      -exec rm -rf {} + 2>/dev/null || true
    ok "cleared $APP_GROUP at $group"
  else
    # Nothing left to clear, which on iOS 26 is the normal outcome: the uninstall above
    # takes the group container with it (its UUID is different after every reinstall).
    # The clearing branch stays for the OS versions where it does survive — that is what
    # made ReaderTests order-dependent in the first place — and for a container left
    # behind by a crashed run.
    ok "$APP_GROUP container is gone (removed with the app)"
  fi
}

# 1. Project generation ------------------------------------------------------
step "xcodegen generate"
if command -v xcodegen >/dev/null; then
  if xcodegen generate; then ok "project generated"; else fail "xcodegen generate"; fi
else
  fail "xcodegen is not installed (brew install xcodegen)"
fi

# 2. Content ----------------------------------------------------------------
step "Content checks"
if command -v jq >/dev/null; then
  BAD=0
  while IFS= read -r file; do
    jq -e . "$file" >/dev/null 2>&1 || { fail "invalid JSON: $file"; BAD=1; }
  done < <(find Content -name '*.json')
  [ "$BAD" -eq 0 ] && ok "all Content JSON parses"
else
  warn "jq missing, skipping JSON parse check"
fi

# 3. Host build and tests ----------------------------------------------------
step "swift build (host)"
BUILD_LOG="$(mktemp)"
if (cd Packages/ScrollKit && swift build 2>&1) > "$BUILD_LOG"; then
  tail -1 "$BUILD_LOG"; ok "ScrollKit builds"
else
  grep -E 'error:' "$BUILD_LOG" | head -20; fail "swift build"
fi
rm -f "$BUILD_LOG"

step "swift test (host)"
TEST_LOG="$(mktemp)"
if (cd Packages/ScrollKit && swift test 2>&1) > "$TEST_LOG"; then
  tail -1 "$TEST_LOG"
  ok "$(grep -o 'Test run with [0-9]* tests' "$TEST_LOG" | tail -1) passed"
else
  grep -E '✘|error:' "$TEST_LOG" | head -20
  fail "swift test"
fi
rm -f "$TEST_LOG"

# 4. Simulator build ---------------------------------------------------------
if [ "$SKIP_SIM" -eq 1 ]; then
  warn "--skip-sim: not building for the simulator"
elif ! command -v xcodebuild >/dev/null || ! xcodebuild -version >/dev/null 2>&1; then
  warn "xcodebuild unavailable, skipping the simulator stages"
  SKIP_SIM=1
else
  step "xcodebuild build ($DESTINATION)"
  set -o pipefail
  if xcodebuild build -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$DERIVED" 2>&1 | beautify | tail -5; then
    ok "app builds for the simulator"
  else
    fail "xcodebuild build"
  fi
  set +o pipefail
fi

# 5. XCUITests ---------------------------------------------------------------
if [ "$RUN_UI" -eq 1 ] && [ "$SKIP_SIM" -eq 0 ]; then
  step "xcodebuild test (XCUITest layout specs)"
  # A UI run has to start from a clean data container. The reader flows switch translation
  # and save a note, the community flow casts a vote, and all of that lands in the App Group
  # JSON `UserStore` persists to; leave it behind and the *next* run starts with PICKTHALL
  # selected and a note already in the editor, which fails tests that are correct
  # (`ReaderTests` measured the translation pill at 106.9 pt against a spec of 72.0).
  #
  # `simctl uninstall` does NOT clear the App Group container — that is shared state, and
  # iOS keeps it for the group, not for the app — so uninstalling alone left every run
  # order-dependent. Ask for the group container's path *before* uninstalling, and empty
  # it. `SCROLL_ERASE=1` erases the whole device instead, which is the bigger hammer and
  # costs a re-boot.
  reset_state
  set -o pipefail
  if xcodebuild test -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$DERIVED" 2>&1 | beautify | tail -20; then
    ok "UI tests passed"
  else
    fail "xcodebuild test"
  fi
  set +o pipefail
fi

# 6. Snapshots ---------------------------------------------------------------
if [ "${#SNAP_IDS[@]}" -gt 0 ] && [ "$SKIP_SIM" -eq 0 ]; then
  step "snapshots: ${SNAP_IDS[*]}"
  APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
  if [ -d "$APP" ] && { [ "$SIM" != booted ] || xcrun simctl list devices booted | grep -q '(Booted)'; }; then
    xcrun simctl install "$SIM" "$APP" >/dev/null && ok "installed $APP"
    for id in "${SNAP_IDS[@]}"; do
      if Tools/snapshot/capture.sh "$id" >/dev/null; then
        score="$(Tools/snapshot/compare.sh "$id")"
        status=$?
        if [ "$status" -eq 0 ]; then ok "$id RMSE $score"; else fail "$id RMSE $score is over threshold"; fi
      else
        fail "could not capture $id"
      fi
      # The other appearance, for the eye rather than the score: there is no reference
      # for it, so a failure here is "the screen did not draw", not "it drifted".
      if [ "$SNAP_BOTH" -eq 1 ]; then
        own="$(jq -r --arg id "$id" '.screens[$id].appearance' "$THRESHOLDS")"
        other=dark; [ "$own" = dark ] && other=light
        if Tools/snapshot/capture.sh "$id" --appearance "$other" >/dev/null; then
          ok "$id ($other) captured for review"
        else
          fail "could not capture $id in $other appearance"
        fi
      fi
    done
    # Leave the simulator on the appearance the next capture expects rather than on
    # whichever one the last --both shot happened to set.
    [ "$SNAP_BOTH" -eq 1 ] && xcrun simctl ui "$SIM" appearance dark >/dev/null 2>&1 || true
  else
    fail "need a booted simulator and a built $APP for --snap"
  fi
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf '\033[32m==> verify.sh: PASS\033[0m\n'
else
  printf '\033[31m==> verify.sh: FAIL\033[0m\n'
fi
exit "$FAILED"
