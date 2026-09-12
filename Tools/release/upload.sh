#!/bin/bash
# Validate and upload the exported .ipa to App Store Connect.
#
#   Tools/release/upload.sh                 # xcrun altool --validate-app (the default; no upload)
#   Tools/release/upload.sh --upload --yes  # xcrun altool --upload-app  (SENDS THE BUILD)
#
# Uploading publishes a build to App Store Connect under your developer account, so this
# script never runs by accident: it needs credentials that are not in the repository and
# it refuses to upload without --yes.
#
# Credentials, in order of preference:
#   1. App Store Connect API key (recommended, no 2FA prompt):
#        export ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
#      with the .p8 at ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8
#      (Users and Access > Integrations > App Store Connect API in App Store Connect).
#   2. Apple ID plus an app-specific password kept in the keychain:
#        xcrun notarytool store-credentials  # or: security add-generic-password ...
#        export ASC_USERNAME=you@example.com ASC_PASSWORD='@keychain:AC_PASSWORD'
#      App-specific passwords are created at https://account.apple.com > Sign-In and Security.
#
# Never paste a password on the command line; use @keychain: or the API key.
#
# Input: .build/release/export/ScrollTheQuran.ipa   (Tools/release/export.sh)

# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTION=validate
CONFIRMED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --validate) ACTION=validate; shift ;;
    --upload) ACTION=upload; shift ;;
    --yes) CONFIRMED=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" 2 ;;
  esac
done
cd "$RELEASE_ROOT"
need xcrun

step "Find the build"
IPA="$(find "$EXPORT_DIR" -name '*.ipa' -maxdepth 1 2>/dev/null | head -1)"
[ -n "$IPA" ] || die "no .ipa in $EXPORT_DIR — run Tools/release/export.sh first"
ok "$IPA"

step "Credentials"
AUTH=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
  [ -f "$KEY_FILE" ] || die "ASC_KEY_ID is set but $KEY_FILE does not exist"
  AUTH=(--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
  ok "App Store Connect API key $ASC_KEY_ID"
elif [ -n "${ASC_USERNAME:-}" ] && [ -n "${ASC_PASSWORD:-}" ]; then
  AUTH=(--username "$ASC_USERNAME" --password "$ASC_PASSWORD")
  ok "Apple ID $ASC_USERNAME with an app-specific password"
else
  die "no App Store Connect credentials. Set ASC_KEY_ID + ASC_ISSUER_ID (API key), or ASC_USERNAME + ASC_PASSWORD (app-specific password). See the header of this script." "$NO_TEAM_EXIT"
fi

if [ "$ACTION" = validate ]; then
  step "Validate (no upload)"
  xcrun altool --validate-app -f "$IPA" -t ios "${AUTH[@]}" --output-format normal \
    || die "altool --validate-app"
  printf '\n\033[32m==> validation PASS\033[0m — re-run with --upload --yes to send the build.\n'
  exit 0
fi

step "Upload"
if [ "$CONFIRMED" -ne 1 ]; then
  die "--upload sends the build to App Store Connect. Re-run with --upload --yes once you mean it."
fi
xcrun altool --upload-app -f "$IPA" -t ios "${AUTH[@]}" --output-format normal \
  || die "altool --upload-app"

cat <<'NEXT'

==> upload PASS

  The build takes 5-30 minutes to process. In App Store Connect:
    TestFlight > iOS builds   — the build appears here first
    Distribution > iOS App 1.0.0 > Build  — select it once processing finishes
  Then answer "Missing Compliance" if it is asked (it should not be: Info.plist
  already declares ITSAppUsesNonExemptEncryption = false).
NEXT
