#!/bin/bash
# Build the App Store archive.
#
#   Tools/release/archive.sh                 # preflight, then archive
#   Tools/release/archive.sh --preflight     # checks only; never invokes xcodebuild archive
#   Tools/release/archive.sh --dry-run       # preflight + print the xcodebuild command
#
# Stages, in order, so a failure tells you exactly how far it got:
#   1. preflight  tools, project generation, Release settings, privacy manifest, version
#   2. signing    resolve DEVELOPMENT_TEAM from Config/Local.xcconfig (fails clearly here
#                 when the Apple Developer Team ID has not been configured yet)
#   3. archive    xcodebuild archive, generic/platform=iOS, Release, -allowProvisioningUpdates
#   4. verify     the archived .app really contains PrivacyInfo.xcprivacy and the dSYMs
#
# Output: .build/release/ScrollTheQuran.xcarchive
# Next:   Tools/release/export.sh, then Tools/release/upload.sh

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE=archive
while [ $# -gt 0 ]; do
  case "$1" in
    --preflight) MODE=preflight; shift ;;
    --dry-run) MODE=dry-run; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" 2 ;;
  esac
done

cd "$RELEASE_ROOT"

# 1. Preflight ---------------------------------------------------------------
step "Preflight"
need xcodebuild "install Xcode and run xcode-select --switch"
need xcodegen "brew install xcodegen"
need plutil
ok "xcodebuild $(xcodebuild -version | head -1 | awk '{print $2}'), xcodegen $(xcodegen --version | awk '{print $NF}')"

xcodegen generate >/dev/null || die "xcodegen generate"
ok "project generated"

[ -f "$RELEASE_ROOT/App/PrivacyInfo.xcprivacy" ] || die "App/PrivacyInfo.xcprivacy is missing"
plutil -lint "$RELEASE_ROOT/App/PrivacyInfo.xcprivacy" >/dev/null || die "App/PrivacyInfo.xcprivacy is not a valid plist"
grep -q "PrivacyInfo.xcprivacy in Resources" "$PROJECT/project.pbxproj" \
  || die "PrivacyInfo.xcprivacy is not in the app's Resources build phase"
ok "privacy manifest present and in the Resources phase"

SETTINGS="$(xcodebuild -project "$PROJECT" -target "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null)"
setting() { printf '%s\n' "$SETTINGS" | sed -n "s/^[[:space:]]*$1 = \(.*\)$/\1/p" | head -1; }

MARKETING="$(setting MARKETING_VERSION)"
BUILD_NUMBER="$(setting CURRENT_PROJECT_VERSION)"
[ -n "$MARKETING" ] || die "MARKETING_VERSION is not set"
[ -n "$BUILD_NUMBER" ] || die "CURRENT_PROJECT_VERSION is not set"
ok "version $MARKETING ($BUILD_NUMBER), bundle id $(setting PRODUCT_BUNDLE_IDENTIFIER)"

for pair in \
  "SWIFT_OPTIMIZATION_LEVEL=-O" \
  "SWIFT_COMPILATION_MODE=wholemodule" \
  "DEBUG_INFORMATION_FORMAT=dwarf-with-dsym" \
  "STRIP_INSTALLED_PRODUCT=YES" \
  "ENABLE_TESTABILITY=NO"; do
  key="${pair%%=*}"; want="${pair#*=}"; got="$(setting "$key")"
  [ "$got" = "$want" ] || die "Release setting $key is '$got', expected '$want' (see Config/Release.xcconfig)"
done
ok "Release build settings are the shipping ones"

ENCRYPTION="$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' App/Info.plist 2>/dev/null)"
[ "$ENCRYPTION" = "false" ] || die "App/Info.plist ITSAppUsesNonExemptEncryption must be false (got '${ENCRYPTION:-missing}')"
ok "export compliance declared in Info.plist (ITSAppUsesNonExemptEncryption = false)"

if [ "$MODE" = preflight ]; then
  printf '\n\033[32m==> preflight PASS\033[0m — run without --preflight to archive.\n'
  exit 0
fi

# 2. Signing -----------------------------------------------------------------
step "Signing"
TEAM="$(require_team "$@")" || exit $?
ok "DEVELOPMENT_TEAM = $TEAM"

# 3. Archive -----------------------------------------------------------------
step "Archive"
mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH"

CMD=(xcodebuild archive
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration Release
  -destination 'generic/platform=iOS'
  -archivePath "$ARCHIVE_PATH"
  -allowProvisioningUpdates
  DEVELOPMENT_TEAM="$TEAM"
  CODE_SIGN_STYLE=Automatic)

if [ "$MODE" = dry-run ]; then
  printf 'would run:\n  %s\n' "${CMD[*]}"
  exit 0
fi

set -o pipefail
"${CMD[@]}" 2>&1 | beautify | tail -30 || die "xcodebuild archive"
set +o pipefail
ok "archived to $ARCHIVE_PATH"

# 4. Verify ------------------------------------------------------------------
step "Verify the archive"
APP="$ARCHIVE_PATH/Products/Applications/ScrollTheQuran.app"
[ -d "$APP" ] || die "no app in the archive at $APP"
[ -f "$APP/PrivacyInfo.xcprivacy" ] || die "PrivacyInfo.xcprivacy is not in the built app"
ok "PrivacyInfo.xcprivacy is in the built app"
[ -d "$APP/PlugIns/ScrollTheQuranWidget.appex" ] || warn "the widget extension is not embedded"
ls "$ARCHIVE_PATH/dSYMs" >/dev/null 2>&1 && ok "dSYMs: $(ls "$ARCHIVE_PATH/dSYMs" | tr '\n' ' ')" || warn "no dSYMs in the archive"
ok "CFBundleShortVersionString $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist"))"

printf '\n\033[32m==> archive PASS\033[0m — next: Tools/release/export.sh\n'
