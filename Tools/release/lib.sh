#!/bin/bash
# Shared helpers for the Tools/release/* scripts. Sourced, never run directly.
#
# The one thing every script here needs and nobody has yet is a Team ID. It lives in
# Config/Local.xcconfig (gitignored; copy Config/Local.xcconfig.example), which
# Config/Base.xcconfig already `#include?`s, so the same value drives Xcode builds and
# these scripts. `require_team` is the single place that fails when it is missing.

set -uo pipefail

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$RELEASE_ROOT/ScrollTheQuran.xcodeproj"
SCHEME="ScrollTheQuran"
APP_BUNDLE_ID="com.quranscroller.app"
WIDGET_BUNDLE_ID="com.quranscroller.app.widget"
APP_GROUP="group.com.quranscroller"
BUILD_DIR="$RELEASE_ROOT/.build/release"
ARCHIVE_PATH="$BUILD_DIR/ScrollTheQuran.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
LOCAL_XCCONFIG="$RELEASE_ROOT/Config/Local.xcconfig"

step()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()    { printf '\033[32mOK\033[0m   %s\n' "$1"; }
warn()  { printf '\033[33mWARN\033[0m %s\n' "$1"; }
die()   { printf '\033[31mFAIL\033[0m %s\n' "$1" >&2; exit "${2:-1}"; }

beautify() { if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi; }

need() { command -v "$1" >/dev/null || die "$1 is required but not on PATH${2:+ ($2)}"; }

# The Team ID, from the environment or Config/Local.xcconfig. Empty when unset.
team_id() {
  if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    printf '%s' "$DEVELOPMENT_TEAM"
    return
  fi
  [ -f "$LOCAL_XCCONFIG" ] || return 0
  sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([A-Za-z0-9]*\).*/\1/p' \
    "$LOCAL_XCCONFIG" | tail -1
}

# Exit code 3 = "no signing identity configured". Callers can special-case it.
NO_TEAM_EXIT=3

require_team() {
  local team
  team="$(team_id)"
  if [ -z "$team" ] || [ "$team" = "ABCDE12345" ]; then
    cat >&2 <<MSG

$(printf '\033[31mFAIL\033[0m') signing step: no Apple Developer Team ID configured.

  Everything up to this point succeeded. Signing an App Store build needs the Team ID
  of your Apple Developer Program membership, which is not in the repository (it is
  account-specific and Config/Local.xcconfig is gitignored).

  To fix it:
    1. Sign in at https://developer.apple.com/account and copy the 10-character
       Team ID from Membership details (it looks like A1B2C3D4E5).
    2. cp Config/Local.xcconfig.example Config/Local.xcconfig
    3. Edit Config/Local.xcconfig and set:  DEVELOPMENT_TEAM = <your team id>
    4. Open Xcode once and sign in under Settings > Accounts so automatic signing can
       create the certificates and profiles for:
         $APP_BUNDLE_ID
         $WIDGET_BUNDLE_ID
       Both need the App Group $APP_GROUP; the app also needs Sign in with Apple.
    5. Re-run this script.

  One-off alternative, without writing the file:
    DEVELOPMENT_TEAM=A1B2C3D4E5 $0 $*

MSG
    exit "$NO_TEAM_EXIT"
  fi
  printf '%s' "$team"
}
