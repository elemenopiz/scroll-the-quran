#!/bin/bash
# The single gate. Every task must leave this exiting 0.
#
#   Tools/verify.sh                          # generate, host build + tests, simulator build
#   Tools/verify.sh --ui                     # + XCUITest layout specs on the simulator
#   Tools/verify.sh --snap tabbar-dark home  # + capture those screens and compare to Reference/
#   Tools/verify.sh --skip-sim               # host only (no Xcode / no simulator)
#
# Stages: xcodegen -> content checks -> swift build -> swift test -> xcodebuild build
#         -> [XCUITests] -> [snapshots]. Non-zero on the first failure.
set -uo pipefail
SIM="${SCROLL_SIM:-booted}"   # UDID or name; defaults to "booted" (ambiguous with several sims up)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="ScrollTheQuran"
# `SCROLL_SIM` names the one simulator a task is allowed to touch. When it is set, xcodebuild
# targets that device by id instead of picking (and booting) whatever is called "iPhone 17".
if [ "${SCROLL_SIM:-booted}" != booted ]; then
  DESTINATION="platform=iOS Simulator,id=$SCROLL_SIM"
else
  DESTINATION="platform=iOS Simulator,name=iPhone 17"
fi
DERIVED=".build/DerivedData"
BUNDLE_ID="com.scrollthequran.app"

RUN_UI=0
SKIP_SIM=0
SNAP_IDS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ui) RUN_UI=1; shift ;;
    --skip-sim) SKIP_SIM=1; shift ;;
    --snap) shift; while [ $# -gt 0 ] && [[ "$1" != --* ]]; do SNAP_IDS+=("$1"); shift; done ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "verify.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

FAILED=0
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '\033[33mWARN\033[0m %s\n' "$1"; }
fail() { printf '\033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

beautify() { if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi; }

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
    done
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
