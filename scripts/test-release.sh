#!/bin/bash
# Tests for scripts/release.sh and the scripts around it. Run: scripts/test-release.sh [--full]
#   default  prerequisite checks, error messages, release-notes extraction, artifact scan, notarization
#            failure handling, settings from Config/release.conf, publishing with stubbed curl, xcrun,
#            security and Sparkle tools (no credentials, no keychain items, no network needed)
#   --full   also runs a real unsigned build (archive, verify, dmg, checksum); takes a few minutes
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }
expect_fail() { # expect_fail <name> <expected-substring> <command...>
  local name="$1" needle="$2"; shift 2
  local out
  if out="$("$@" 2>&1)"; then fail "$name (command succeeded)"; return; fi
  if grep -qF -- "$needle" <<< "$out"; then pass "$name"; else fail "$name (missing '$needle' in: $out)"; fi
}

# The expected values are the ones in Config/release.conf: the tests never hard-code a product.
conf() { (source Config/release.conf && printf '%s' "${!1}"); }
NAME="$(conf APP_NAME)"
DOWNLOADS="$(conf DOWNLOADS_URL)"
ACCOUNT="$(conf SPARKLE_ACCOUNT)"
PREFIX="$(conf KEYCHAIN_PREFIX)"
DOMAIN="$(conf PRODUCT_DOMAIN)"
SITE="$(conf SITE_URL)"
DMG9="$NAME-9.9.9.dmg"

# Tests must not depend on what is stored on this Mac or in the caller's environment.
export RELEASE_NO_KEYCHAIN=1
unset DOWNLOADS_URL SITE_URL SPARKLE_ACCOUNT SPARKLE_KEY_ACCOUNT SPARKLE_BIN SIGN_IDENTITY NOTARY_PROFILE \
  OUT_DIR RELEASE_CONF CHANGELOG_FILE R2_ENDPOINT R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- configuration ---
for key in APP_NAME PROJECT SCHEME PRODUCT_DOMAIN SITE_URL DOWNLOADS_URL KEYCHAIN_PREFIX SPARKLE_ACCOUNT REPO_URL FORBID_SYMBOLS; do
  if [[ -n "$(conf "$key")" ]]; then pass "Config/release.conf sets $key"; else fail "Config/release.conf sets $key"; fi
done
if [[ -z "$(awk '!/^#/ && !/^$/ && !/^[A-Z_]+="[^"$`]*"$/' Config/release.conf)" ]]; then
  pass "Config/release.conf has only comments and plain KEY=\"value\" lines"
else fail "Config/release.conf has only comments and plain KEY=\"value\" lines"; fi
if grep -ilF "$DOMAIN" scripts/release.sh scripts/bump.sh scripts/release-credentials.sh scripts/scan_secrets.py scripts/ax-audit.swift $(ls scripts/website-changelog.py 2> /dev/null) | grep -q .; then
  fail "the domain is written in Config/release.conf only"; else pass "the domain is written in Config/release.conf only"; fi

# --- argument and prerequisite errors ---
expect_fail "unknown argument is rejected" "unknown argument" scripts/release.sh --nope
expect_fail "notary profile without identity is rejected" "only signed builds can be notarized" \
  env NOTARY_PROFILE=x scripts/release.sh --check
expect_fail "missing signing identity is reported" "signing identity not found" \
  env SIGN_IDENTITY="Developer ID Application: Nobody (NOTREAL000)" scripts/release.sh --check
expect_fail "publish without credentials is refused" "refusing to publish an unnotarized build" \
  scripts/release.sh --check --publish
expect_fail "a missing settings file is reported" "not found" env RELEASE_CONF="$TMP/missing.conf" scripts/release.sh --check
printf 'APP_NAME="X"\n' > "$TMP/partial.conf"
expect_fail "an incomplete settings file is reported" "is not set in" env RELEASE_CONF="$TMP/partial.conf" scripts/release.sh --check
if scripts/release.sh --help 2> /dev/null | grep -q "scripts/release.sh \[--check\] \[--publish\]"; then pass "--help prints the header"; else fail "--help prints the header"; fi

# The real project: the scheme from Config/release.conf must build settings with a version and a build number.
unsigned_out="$(scripts/release.sh --check 2>&1)"
if grep -q "UNSIGNED" <<< "$unsigned_out"; then pass "unsigned mode warns"; else fail "unsigned mode warns ($unsigned_out)"; fi
if grep -q "output build/release/$NAME-[0-9][0-9.]*\.dmg" <<< "$unsigned_out"; then pass "the dmg is named after APP_NAME"; else fail "the dmg is named after APP_NAME ($unsigned_out)"; fi

# --- release notes come from CHANGELOG ---
# shellcheck disable=SC1091
RELEASE_SOURCED=1 source scripts/release.sh
set +e # release.sh turns errexit on; the tests handle failures themselves
VERSION=2.0.0
cat > "$TMP/CHANGELOG.md" <<'CL'
# Changelog

## [Unreleased]

### Added
- Not yet released

## [2.0.0] - 2026-11-01

### Added
- Email one-time-code access protection

### Fixed
- A crash at launch

## [1.0.0] - 2026-10-05

### Added
- First release

[Unreleased]: https://example.invalid/compare/v2.0.0...HEAD
[2.0.0]: https://example.invalid/compare/v1.0.0...v2.0.0
CL
notes="$(CHANGELOG_FILE="$TMP/CHANGELOG.md" release_notes)"
if grep -q "Email one-time-code access protection" <<< "$notes" && grep -q "A crash at launch" <<< "$notes" \
  && ! grep -q "^## " <<< "$notes" && ! grep -q "First release\|Not yet released\|example.invalid" <<< "$notes"; then
  pass "release notes are the section of one version"
else fail "release notes are the section of one version ($notes)"; fi
VERSION=1.0.0
notes="$(CHANGELOG_FILE="$TMP/CHANGELOG.md" release_notes)"
if [[ "$notes" == *"First release"* && "$notes" != *"example.invalid"* ]]; then
  pass "the last section stops before the link definitions"
else fail "the last section stops before the link definitions ($notes)"; fi
VERSION=3.0.0
notes="$(CHANGELOG_FILE="$TMP/CHANGELOG.md" release_notes)"
[[ -z "$notes" ]] && pass "a missing section gives empty notes (finish_dmg only warns)" || fail "a missing section gives empty notes ($notes)"
VERSION=1.0.0

# --- artifact scan (credential-like strings, build-machine paths and debug-only types) ---
mkdir -p "$TMP/scan-clean" "$TMP/scan-dirty"
printf 'plain release strings only, nothing to see\n' > "$TMP/scan-clean/binary"
fake_token="cf""ut_$(printf 'Ab1%.0s' {1..12})"   # assembled at run time: no token-shaped literal in this file
printf 'prefix %s suffix\n' "$fake_token" > "$TMP/scan-dirty/binary"
printf 'built in /Users/someone/work\n' > "$TMP/scan-dirty/other"
if python3 scripts/scan_secrets.py --path "$TMP/scan-clean" --forbid /Users/someone > /dev/null 2>&1; then
  pass "a clean artifact passes the scan"; else fail "a clean artifact passes the scan"; fi
scan_out="$(python3 scripts/scan_secrets.py --path "$TMP/scan-dirty" --forbid /Users/someone 2>&1 || true)"
# A hand-written Config/*-Info.plist may carry Sparkle's public key; the scan must treat it as public.
pubkey="$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" Config/Template-Info.plist 2> /dev/null || true)"
if [[ -n "$pubkey" ]]; then
  mkdir -p "$TMP/scan-pubkey"
  printf 'SUPublicEDKey %s\n' "$pubkey" > "$TMP/scan-pubkey/Info.plist"
  if python3 scripts/scan_secrets.py --path "$TMP/scan-pubkey" > /dev/null 2>&1; then pass "the Sparkle public key from Config/Template-Info.plist is not a finding"
  else fail "the Sparkle public key from Config/Template-Info.plist is not a finding"; fi
fi

if grep -q "cloudflare-token" <<< "$scan_out" && grep -q "forbidden string '/Users/someone'" <<< "$scan_out" \
  && ! grep -q "$fake_token" <<< "$scan_out"; then
  pass "the scan flags tokens and forbidden strings and never prints the value"
else fail "the scan flags tokens and forbidden strings and never prints the value ($scan_out)"; fi

run_scan_app() { # run_scan_app <app dir> [extra env...]; scan_app on a fake bundle
  local app="$1"; shift
  env "$@" bash -c 'RELEASE_SOURCED=1 source scripts/release.sh; APP="'"$app"'"; scan_app'
}
symbol1="$(conf FORBID_SYMBOLS | awk '{ print $1 }')"
mkdir -p "$TMP/app-clean/Contents" "$TMP/app-debug/Contents"
printf 'release code only\n' > "$TMP/app-clean/Contents/binary"
printf 'class %s {}\n' "$symbol1" > "$TMP/app-debug/Contents/binary"
if run_scan_app "$TMP/app-clean" > /dev/null 2>&1; then pass "scan_app accepts a clean bundle"; else fail "scan_app accepts a clean bundle"; fi
expect_fail "scan_app rejects a bundle with a FORBID_SYMBOLS type" "failed the artifact scan" run_scan_app "$TMP/app-debug"
expect_fail "scan_app rejects the build machine's home directory" "failed the artifact scan" \
  bash -c 'printf "%s/work\n" "$HOME" > "'"$TMP"'/app-clean/Contents/home"; RELEASE_SOURCED=1 source scripts/release.sh; APP="'"$TMP"'/app-clean"; scan_app'
rm -f "$TMP/app-clean/Contents/home"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/codesign" <<'STUB'
#!/bin/bash
[[ "$*" == *"--entitlements"* ]] && echo "[Key] com.apple.security.get-task-allow"
exit 0
STUB
chmod +x "$TMP/bin/codesign"
expect_fail "scan_app rejects the get-task-allow entitlement" "get-task-allow" run_scan_app "$TMP/app-clean" PATH="$TMP/bin:$PATH"
rm -f "$TMP/bin/codesign"

# --- notarization failures ---
cat > "$TMP/bin/xcrun" <<'STUB'
#!/bin/bash
case "$*" in
  *"notarytool submit"*) echo "  id: 1234"; echo "  status: ${FAKE_STATUS:-Invalid}"; exit "${FAKE_SUBMIT_EXIT:-0}" ;;
  *"notarytool log"*) echo "fake log: the signature is invalid"; exit 0 ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/xcrun"
touch "$TMP/thing.zip"
expect_fail "rejected notarization is an error and prints the log" "notarization was not accepted" \
  env PATH="$TMP/bin:$PATH" bash -c 'RELEASE_SOURCED=1 source scripts/release.sh; NOTARY_PROFILE=fake; notarize "'"$TMP"'/thing.zip"'
expect_fail "failed submission is an error" "notarization submission failed" \
  env PATH="$TMP/bin:$PATH" FAKE_SUBMIT_EXIT=1 bash -c 'RELEASE_SOURCED=1 source scripts/release.sh; NOTARY_PROFILE=fake; notarize "'"$TMP"'/thing.zip"'
if env PATH="$TMP/bin:$PATH" FAKE_STATUS=Accepted bash -c 'RELEASE_SOURCED=1 source scripts/release.sh; NOTARY_PROFILE=fake; notarize "'"$TMP"'/thing.zip"' > /dev/null 2>&1; then
  pass "accepted notarization succeeds"; else fail "accepted notarization succeeds"; fi

# --- settings from the keychain (stubbed `security`) ---
mkdir -p "$TMP/kc"
cat > "$TMP/kc/security" <<STUB
#!/bin/bash
# find-generic-password -a <user> -s $PREFIX-release-<NAME> -w
echo "\$*" >> "\${FAKE_SECURITY_LOG:-/dev/null}"
service=""; while [[ \$# -gt 0 ]]; do [[ "\$1" == "-s" ]] && service="\$2"; shift; done
case "\$service" in
  $PREFIX-release-R2_BUCKET) echo "bucket-from-keychain" ;;
  $PREFIX-release-R2_ENDPOINT) echo "https://from-keychain.example" ;;
  *) exit 44 ;;
esac
STUB
chmod +x "$TMP/kc/security"
kc_out="$(env -u RELEASE_NO_KEYCHAIN PATH="$TMP/kc:$PATH" R2_BUCKET=from-env bash -c 'RELEASE_SOURCED=1 source scripts/release.sh; echo "$R2_BUCKET|$R2_ENDPOINT|${R2_ACCESS_KEY_ID:-unset}"')"
[[ "$kc_out" == "from-env|https://from-keychain.example|unset" ]] \
  && pass "keychain fills missing settings, environment wins, missing items stay unset" \
  || fail "keychain loading ($kc_out)"
if scripts/release-credentials.sh > /dev/null 2>&1; then fail "credentials script without arguments prints usage and fails"; else pass "credentials script without arguments prints usage and fails"; fi
# The format checks run before anything is stored, so these fail without touching the keychain.
expect_fail "endpoint that is not an R2 URL is rejected" "R2_ENDPOINT must look like" \
  bash -c 'echo "cfut_notanendpoint" | scripts/release-credentials.sh set R2_ENDPOINT'
expect_fail "API token value is rejected as an access key" "looks like a Cloudflare API token value" \
  bash -c 'echo "cfut_abcdef0123" | scripts/release-credentials.sh set R2_ACCESS_KEY_ID'
expect_fail "non-hex secret is rejected" "should be hexadecimal" \
  bash -c 'echo "not-hex-value" | scripts/release-credentials.sh set R2_SECRET_ACCESS_KEY'
expect_fail "credentials script rejects unknown names" "unknown name" scripts/release-credentials.sh set NOPE

# --- Config/release.conf is the only place with product values ---
cat > "$TMP/zzfake7.conf" <<'CONF'
APP_NAME="Zzfake7"
PROJECT="Zzfake7Project.xcodeproj"
SCHEME="Zzfake7Scheme"
PRODUCT_DOMAIN="zzfake7.test"
SITE_URL="https://zzfake7.test"
DOWNLOADS_URL="https://dl.zzfake7.test"
KEYCHAIN_PREFIX="zzfake7kc"
SPARKLE_ACCOUNT="zzfake7acct"
REPO_URL="https://github.com/example-org/zzfake7"
FORBID_SYMBOLS="ForbidOne ForbidTwo"
CONF
cat > "$TMP/bin/xcodebuild" <<'STUB'
#!/bin/bash
echo "$*" >> "${FAKE_XCODEBUILD_LOG:-/dev/null}"
case "$*" in
  *-showBuildSettings*)
    echo "    MARKETING_VERSION = ${FAKE_MARKETING_VERSION:-1.2.3}"
    echo "    CURRENT_PROJECT_VERSION = ${FAKE_BUILD:-42}" ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/xcodebuild"
: > "$TMP/xcodebuild.log"
other_out="$(env PATH="$TMP/bin:$PATH" RELEASE_CONF="$TMP/zzfake7.conf" FAKE_XCODEBUILD_LOG="$TMP/xcodebuild.log" scripts/release.sh --check 2>&1)"
if grep -q "output build/release/Zzfake7-1.2.3.dmg" <<< "$other_out" && ! grep -q "$NAME" <<< "$other_out"; then
  pass "another settings file renames the dmg"; else fail "another settings file renames the dmg ($other_out)"; fi
if grep -q -- "-project Zzfake7Project.xcodeproj -scheme Zzfake7Scheme" "$TMP/xcodebuild.log"; then
  pass "project and scheme come from the settings file"; else fail "project and scheme come from the settings file ($(cat "$TMP/xcodebuild.log"))"; fi
: > "$TMP/security.log"
env -u RELEASE_NO_KEYCHAIN PATH="$TMP/kc:$PATH" RELEASE_CONF="$TMP/zzfake7.conf" FAKE_SECURITY_LOG="$TMP/security.log" \
  bash -c 'RELEASE_SOURCED=1 source scripts/release.sh' > /dev/null 2>&1
if grep -q -- "-s zzfake7kc-release-R2_BUCKET" "$TMP/security.log" && ! grep -q -- "$PREFIX-release" "$TMP/security.log"; then
  pass "keychain items are named after KEYCHAIN_PREFIX"; else fail "keychain items are named after KEYCHAIN_PREFIX ($(cat "$TMP/security.log"))"; fi
: > "$TMP/security.log"
env PATH="$TMP/kc:$PATH" RELEASE_CONF="$TMP/zzfake7.conf" FAKE_SECURITY_LOG="$TMP/security.log" scripts/release-credentials.sh status > /dev/null 2>&1
if grep -q -- "-s zzfake7kc-release-SIGN_IDENTITY" "$TMP/security.log"; then
  pass "release-credentials.sh uses KEYCHAIN_PREFIX"; else fail "release-credentials.sh uses KEYCHAIN_PREFIX ($(cat "$TMP/security.log"))"; fi
mkdir -p "$TMP/app-other/Contents"
printf 'class ForbidTwo {}\n' > "$TMP/app-other/Contents/binary"
expect_fail "FORBID_SYMBOLS come from the settings file" "failed the artifact scan" run_scan_app "$TMP/app-other" RELEASE_CONF="$TMP/zzfake7.conf"
if run_scan_app "$TMP/app-other" > /dev/null 2>&1; then pass "the default FORBID_SYMBOLS do not include another product's"; else fail "the default FORBID_SYMBOLS do not include another product's"; fi
if [[ -f scripts/website-changelog.py ]]; then
hosts="$(python3 - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("wc", "scripts/website-changelog.py")
wc = importlib.util.module_from_spec(spec); spec.loader.exec_module(wc)
print(" ".join(wc.ALLOWED_HOSTS))
PY
)"
[[ "$hosts" == "$DOMAIN www.$DOMAIN dl.$DOMAIN" ]] && pass "website-changelog.py allows the hosts of PRODUCT_DOMAIN" || fail "website-changelog.py hosts ($hosts)"
fi

# --- publishing to R2 (stubbed curl) ---
cat > "$TMP/bin/curl" <<'STUB'
#!/bin/bash
# Uploads (-T) are recorded as "PUT <key>" in $FAKE_LOG and their headers in $FAKE_HEADERS; downloads serve
# $FAKE_SERVED. Uploads whose URL ends with $FAKE_FAIL_KEY fail. The appcast GET (the check that the build
# number is new) is recorded as "GET appcast.xml" and answers $FAKE_APPCAST_CODE (default 404) with the file
# $FAKE_APPCAST; FAKE_APPCAST_NETFAIL makes it fail like a network error.
url="${*: -1}"
if [[ " $* " == *" -T "* ]]; then
  [[ -n "${FAKE_FAIL_KEY:-}" && "$url" == *"$FAKE_FAIL_KEY" ]] && exit 22
  echo "PUT ${url##*/}" >> "$FAKE_LOG"
  headers=""; prev=""
  for arg in "$@"; do [[ "$prev" == "-H" && "$arg" != x-amz-* ]] && headers="$headers|$arg"; prev="$arg"; done
  echo "${url##*/}$headers" >> "${FAKE_HEADERS:-/dev/null}"
  exit 0
fi
if [[ "$url" == */appcast.xml ]]; then
  out=""; prev=""
  for arg in "$@"; do [[ "$prev" == "--output" ]] && out="$arg"; prev="$arg"; done
  echo "GET appcast.xml" >> "$FAKE_LOG"
  [[ -n "${FAKE_APPCAST_NETFAIL:-}" ]] && exit 6
  code="${FAKE_APPCAST_CODE:-404}"
  if [[ "$code" == "200" && -n "$out" ]]; then cp "$FAKE_APPCAST" "$out"; fi
  printf '%s' "$code"
  exit 0
fi
cat "$FAKE_SERVED"
STUB
chmod +x "$TMP/bin/curl"

# Sparkle's tools, stubbed: sign_update prints a fixed signature; generate_keys -p prints the key.
mkdir -p "$TMP/sparkle"
cat > "$TMP/sparkle/sign_update" <<'STUB'
#!/bin/bash
echo "$*" >> "${FAKE_SPARKLE_LOG:-/dev/null}"
case " $* " in *" --verify "*) [[ -z "${FAKE_VERIFY_FAIL:-}" ]]; exit $? ;; esac
[[ -n "${FAKE_SIGN_FAIL:-}" ]] && exit 1
echo "SIGNATUREBASE64=="
STUB
cat > "$TMP/sparkle/generate_keys" <<'STUB'
#!/bin/bash
# generate_keys --account <name> -p
echo "$*" >> "${FAKE_SPARKLE_LOG:-/dev/null}"
[[ -n "${FAKE_NO_KEYCHAIN_KEY:-}" ]] && exit 1
echo "${FAKE_KEYCHAIN_KEY:-PUBKEY}"
STUB
chmod +x "$TMP/sparkle/sign_update" "$TMP/sparkle/generate_keys"

setup_publish() { # prepares a fake build in $TMP/pub
  rm -rf "$TMP/pub"; mkdir -p "$TMP/pub/$NAME.app/Contents"
  plutil -create xml1 "$TMP/pub/$NAME.app/Contents/Info.plist"
  plutil -insert LSMinimumSystemVersion -string "26.0" "$TMP/pub/$NAME.app/Contents/Info.plist"
  plutil -insert SUPublicEDKey -string "${APP_PUBLIC_KEY-PUBKEY}" "$TMP/pub/$NAME.app/Contents/Info.plist"
  echo "fake dmg contents" > "$TMP/pub/$DMG9"
  (cd "$TMP/pub" && shasum -a 256 "$DMG9" > "$DMG9.sha256")
  printf -- '- A change\n' > "$TMP/pub/release-notes.md"
  : > "$TMP/log"; : > "$TMP/headers"
}
run_publish() { # run_publish <extra env...>; prints publish() output
  env PATH="$TMP/bin:$PATH" FAKE_LOG="$TMP/log" FAKE_HEADERS="$TMP/headers" SPARKLE_BIN="$TMP/sparkle" "$@" bash -c '
    RELEASE_SOURCED=1 source scripts/release.sh
    OUT_DIR="'"$TMP"'/pub"; APP="$OUT_DIR/$APP_NAME.app"; DMG_NAME="$APP_NAME-9.9.9.dmg"; DMG="$OUT_DIR/$DMG_NAME"
    VERSION=9.9.9; BUILD_NUMBER=42; R2_ENDPOINT=https://x.r2.cloudflarestorage.com; R2_BUCKET=b
    R2_ACCESS_KEY_ID=id; R2_SECRET_ACCESS_KEY=secret
    publish'
}
SERVED="$TMP/pub/$DMG9"

setup_publish
if run_publish FAKE_SERVED="$SERVED" > /dev/null 2>&1 \
  && [[ "$(paste -sd, "$TMP/log")" == "GET appcast.xml,PUT $DMG9,PUT $DMG9.sha256,PUT appcast.xml,PUT latest.json" ]]; then
  pass "publish checks the appcast, uploads the installer first, then appcast.xml, then latest.json"
else fail "publish checks the appcast, uploads the installer first, then appcast.xml, then latest.json ($(paste -sd, "$TMP/log"))"; fi
appcast_ok="$(python3 -c '
import sys, xml.etree.ElementTree as ET, os
ns = {"s": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
root = ET.parse(sys.argv[1]).getroot()
item = root.find("channel/item")
enc = item.find("enclosure")
S = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
ok = (item.find("s:version", ns).text == "42" and item.find("s:shortVersionString", ns).text == "9.9.9"
      and item.find("s:minimumSystemVersion", ns).text == "26.0"
      and item.find("title").text == "Version 9.9.9" and item.find("pubDate").text.endswith("+0000")
      and enc.get("url") == sys.argv[3] + "/" + sys.argv[4]
      and enc.get(S + "edSignature") == "SIGNATUREBASE64=="
      and enc.get("length") == str(os.path.getsize(sys.argv[2]))
      and enc.get("type") == "application/x-apple-diskimage"
      and item.find("description") is None and len(root.findall("channel/item")) == 1)
print("yes" if ok else "no")' "$TMP/pub/appcast.xml" "$TMP/pub/$DMG9" "$DOWNLOADS" "$DMG9" 2>&1)"
[[ "$appcast_ok" == "yes" ]] && pass "appcast.xml has version, build, url, signature, length, minimum macOS and no release notes" || fail "appcast.xml content ($appcast_ok)"
feed_ok="$(python3 -c '
import json, sys
f = json.load(open(sys.argv[1]))
ok = f["version"] == "9.9.9" and f["build"] == 42 and f["url"] == sys.argv[2] + "/" + sys.argv[3] \
    and len(f["sha256"]) == 64 and f["minimumOS"] == "26.0" and "notes" not in f
print("yes" if ok else "no")' "$TMP/pub/latest.json" "$DOWNLOADS" "$DMG9" 2>&1)"
[[ "$feed_ok" == "yes" ]] && pass "latest.json has version, build, url, sha256 and minimumOS and no notes" || fail "latest.json content ($feed_ok)"
headers="$(cat "$TMP/headers")"
if grep -q "^appcast.xml|Content-Type: application/xml|Cache-Control: no-cache$" <<< "$headers" \
  && grep -q "^latest.json|Content-Type: application/json|Cache-Control: no-cache$" <<< "$headers" \
  && grep -q "^$DMG9|Content-Type: application/x-apple-diskimage$" <<< "$headers"; then
  pass "content types and cache headers of dmg, appcast.xml and latest.json"; else fail "content types and cache headers ($headers)"; fi

setup_publish
expect_fail "failed installer upload stops before latest.json" "uploading $DMG9 to R2 failed" \
  run_publish FAKE_SERVED="$SERVED" FAKE_FAIL_KEY="$DMG9"
grep -q latest.json "$TMP/log" && fail "latest.json untouched after a failed upload" || pass "latest.json untouched after a failed upload"

setup_publish
echo "something else" > "$TMP/other"
expect_fail "hash mismatch stops before the appcast" "does not match the local file" \
  run_publish FAKE_SERVED="$TMP/other"
grep -q "PUT appcast.xml\|PUT latest.json" "$TMP/log" && fail "feeds untouched after a hash mismatch" || pass "feeds untouched after a hash mismatch"

# The key is looked up under the account in Config/release.conf unless SPARKLE_ACCOUNT says otherwise.
setup_publish
run_publish FAKE_SERVED="$SERVED" FAKE_SPARKLE_LOG="$TMP/sparkle.log" > /dev/null 2>&1
if grep -q -- "--account $ACCOUNT " "$TMP/sparkle.log" && ! grep -v -- "--account $ACCOUNT " "$TMP/sparkle.log" | grep -q .; then
  pass "Sparkle tools use the keychain account '$ACCOUNT' by default"; else fail "Sparkle tools use the keychain account '$ACCOUNT' by default"; fi
: > "$TMP/sparkle.log"; setup_publish
run_publish FAKE_SERVED="$SERVED" FAKE_SPARKLE_LOG="$TMP/sparkle.log" SPARKLE_ACCOUNT=ed25519 > /dev/null 2>&1
if grep -q -- "--account ed25519" "$TMP/sparkle.log" && ! grep -q -- "--account $ACCOUNT " "$TMP/sparkle.log"; then
  pass "SPARKLE_ACCOUNT=ed25519 shares Sparkle's default key"; else fail "SPARKLE_ACCOUNT=ed25519 shares Sparkle's default key"; fi
: > "$TMP/sparkle.log"; setup_publish
run_publish FAKE_SERVED="$SERVED" FAKE_SPARKLE_LOG="$TMP/sparkle.log" SPARKLE_KEY_ACCOUNT=aliased > /dev/null 2>&1
if grep -q -- "--account aliased" "$TMP/sparkle.log" && ! grep -q -- "--account $ACCOUNT " "$TMP/sparkle.log"; then
  pass "SPARKLE_KEY_ACCOUNT is an alias of SPARKLE_ACCOUNT"; else fail "SPARKLE_KEY_ACCOUNT is an alias of SPARKLE_ACCOUNT"; fi
: > "$TMP/sparkle.log"; setup_publish
run_publish FAKE_SERVED="$SERVED" FAKE_SPARKLE_LOG="$TMP/sparkle.log" SPARKLE_ACCOUNT=first SPARKLE_KEY_ACCOUNT=second > /dev/null 2>&1
if grep -q -- "--account first" "$TMP/sparkle.log" && ! grep -q -- "--account second" "$TMP/sparkle.log"; then
  pass "SPARKLE_ACCOUNT wins over its alias"; else fail "SPARKLE_ACCOUNT wins over its alias"; fi

# Another settings file flows into the published files (names, URLs, Sparkle account).
setup_publish
mkdir -p "$TMP/pub/Zzfake7.app/Contents"; cp "$TMP/pub/$NAME.app/Contents/Info.plist" "$TMP/pub/Zzfake7.app/Contents/"
cp "$TMP/pub/$DMG9" "$TMP/pub/Zzfake7-9.9.9.dmg"; (cd "$TMP/pub" && shasum -a 256 Zzfake7-9.9.9.dmg > Zzfake7-9.9.9.dmg.sha256)
: > "$TMP/sparkle.log"
run_publish FAKE_SERVED="$SERVED" FAKE_SPARKLE_LOG="$TMP/sparkle.log" RELEASE_CONF="$TMP/zzfake7.conf" > /dev/null 2>&1
if grep -q 'url="https://dl.zzfake7.test/Zzfake7-9.9.9.dmg"' "$TMP/pub/appcast.xml" && grep -q "<title>Zzfake7</title>" "$TMP/pub/appcast.xml" \
  && grep -q "<link>https://zzfake7.test</link>" "$TMP/pub/appcast.xml" && grep -q -- "--account zzfake7acct " "$TMP/sparkle.log" \
  && grep -q "PUT Zzfake7-9.9.9.dmg" "$TMP/log"; then
  pass "app name, URLs and Sparkle account in the published files come from the settings file"
else fail "settings file in the published files ($(head -12 "$TMP/pub/appcast.xml" 2>&1))"; fi
setup_publish
run_publish FAKE_SERVED="$SERVED" DOWNLOADS_URL=https://mirror.example.invalid SITE_URL=https://site.example.invalid > /dev/null 2>&1
if grep -q 'url="https://mirror.example.invalid/' "$TMP/pub/appcast.xml" && grep -q "<link>https://site.example.invalid</link>" "$TMP/pub/appcast.xml"; then
  pass "DOWNLOADS_URL and SITE_URL in the environment win"; else fail "DOWNLOADS_URL and SITE_URL in the environment win"; fi

# Anything wrong with the Sparkle key or signature stops the publish before the first upload.
no_upload() { ! grep -q '^PUT' "$TMP/log"; }
setup_publish
expect_fail "a failed Sparkle signature publishes nothing" "Sparkle could not sign the dmg" \
  run_publish FAKE_SERVED="$SERVED" FAKE_SIGN_FAIL=1
no_upload && pass "no upload after a failed signature" || fail "no upload after a failed signature"
setup_publish
expect_fail "a signature that does not verify publishes nothing" "does not verify" \
  run_publish FAKE_SERVED="$SERVED" FAKE_VERIFY_FAIL=1
no_upload && pass "no upload after a signature that does not verify" || fail "no upload after a signature that does not verify"
APP_PUBLIC_KEY="" setup_publish
expect_fail "an empty public key in the app is refused" "SUPublicEDKey is empty" \
  run_publish FAKE_SERVED="$SERVED"
no_upload && pass "no upload without a public key in the app" || fail "no upload without a public key in the app"
setup_publish
expect_fail "a public key that does not match the keychain key is refused" "does not match the Sparkle key" \
  run_publish FAKE_SERVED="$SERVED" FAKE_KEYCHAIN_KEY=OTHERKEY
no_upload && pass "no upload with a mismatching key" || fail "no upload with a mismatching key"
setup_publish
expect_fail "no private key in the keychain is refused" "no Sparkle private key for account" \
  run_publish FAKE_SERVED="$SERVED" FAKE_NO_KEYCHAIN_KEY=1
no_upload && pass "no upload without a private key" || fail "no upload without a private key"

# --- the build number must be new (the published appcast is fetched before anything is uploaded) ---
make_appcast() { # make_appcast <file> <build> <version> [<build> <version> ...]
  local file="$1"; shift
  {
    echo '<?xml version="1.0" encoding="utf-8"?>'
    echo '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>x</title>'
    while [[ $# -ge 2 ]]; do
      echo "<item><title>Version $2</title><sparkle:version>$1</sparkle:version><sparkle:shortVersionString>$2</sparkle:shortVersionString></item>"
      shift 2
    done
    echo '</channel></rss>'
  } > "$file"
}
publish_with_appcast() { # publish_with_appcast <appcast file or -> [extra env...]
  local file="$1"; shift
  setup_publish
  run_publish FAKE_SERVED="$SERVED" FAKE_APPCAST="$file" FAKE_APPCAST_CODE=200 "$@"
}

make_appcast "$TMP/appcast-lower.xml" 41 9.9.8 40 9.9.7
if publish_with_appcast "$TMP/appcast-lower.xml" > /dev/null 2>&1 && grep -q "^PUT appcast.xml" "$TMP/log"; then
  pass "a build number higher than the published ones is published"; else fail "a build number higher than the published ones is published"; fi

make_appcast "$TMP/appcast-equal.xml" 42 9.9.8
expect_fail "a build number that is already published is refused" "build number 42 is already published (version 9.9.8)" \
  publish_with_appcast "$TMP/appcast-equal.xml"
no_upload && pass "no upload for an already published build number" || fail "no upload for an already published build number"

make_appcast "$TMP/appcast-mixed.xml" 50 9.9.9 42 9.9.8
expect_fail "an already published build number is found among several items" "build number 42 is already published (version 9.9.8)" \
  publish_with_appcast "$TMP/appcast-mixed.xml"

make_appcast "$TMP/appcast-higher.xml" 43 10.0.0 41 9.9.8
expect_fail "a build number lower than the highest published one is refused" "lower than the highest published build 43 (version 10.0.0)" \
  publish_with_appcast "$TMP/appcast-higher.xml"
no_upload && pass "no upload for a build number below the published ones" || fail "no upload for a build number below the published ones"

setup_publish
if run_publish FAKE_SERVED="$SERVED" > /dev/null 2>&1 && grep -q "^PUT appcast.xml" "$TMP/log"; then
  pass "no appcast yet (HTTP 404) is the first release and passes"; else fail "no appcast yet (HTTP 404) is the first release and passes"; fi

make_appcast "$TMP/appcast-empty.xml"
if publish_with_appcast "$TMP/appcast-empty.xml" > /dev/null 2>&1; then
  pass "an appcast without items passes"; else fail "an appcast without items passes"; fi

setup_publish
expect_fail "a network failure refuses to publish" "published appcast could not be checked" \
  run_publish FAKE_SERVED="$SERVED" FAKE_APPCAST_NETFAIL=1
no_upload && pass "no upload after a network failure" || fail "no upload after a network failure"

setup_publish
expect_fail "a server error refuses to publish" "published appcast could not be checked" \
  run_publish FAKE_SERVED="$SERVED" FAKE_APPCAST_CODE=503
no_upload && pass "no upload after a server error" || fail "no upload after a server error"

printf '<html><body>not an appcast\n' > "$TMP/appcast-broken.xml"
expect_fail "malformed XML refuses to publish" "published appcast could not be checked" \
  publish_with_appcast "$TMP/appcast-broken.xml"
no_upload && pass "no upload after malformed XML" || fail "no upload after malformed XML"

printf '<?xml version="1.0"?><feed><entry/></feed>\n' > "$TMP/appcast-feed.xml"
expect_fail "XML that is not an appcast refuses to publish" "published appcast could not be checked" \
  publish_with_appcast "$TMP/appcast-feed.xml"

cat > "$TMP/appcast-nobuild.xml" <<'XML'
<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><title>x</title></item></channel></rss>
XML
expect_fail "an item without a build number refuses to publish" "published appcast could not be checked" \
  publish_with_appcast "$TMP/appcast-nobuild.xml"

# The same check runs in `--check --publish`, after the version is read and before any build.
mkdir -p "$TMP/main-bin"
cat > "$TMP/main-bin/security" <<'STUB'
#!/bin/bash
[[ "$1" == "find-identity" ]] && echo '  1) ABCDEF "Developer ID Application: Test (TEST000000)"'
exit 0
STUB
chmod +x "$TMP/main-bin/security"
run_check_publish() { # run_check_publish <extra env...>
  env PATH="$TMP/main-bin:$TMP/bin:$PATH" FAKE_LOG="$TMP/log" SPARKLE_BIN="$TMP/sparkle" \
    SIGN_IDENTITY="Developer ID Application: Test (TEST000000)" NOTARY_PROFILE=fake \
    R2_ENDPOINT=https://x.r2.cloudflarestorage.com R2_BUCKET=b R2_ACCESS_KEY_ID=id R2_SECRET_ACCESS_KEY=secret \
    "$@" scripts/release.sh --check --publish
}
: > "$TMP/log"
if out="$(run_check_publish 2>&1)" && grep -q "Check passed: signed=1 notarize=1 publish=1" <<< "$out" && grep -q "first release" <<< "$out"; then
  pass "--check --publish passes for a first release"; else fail "--check --publish passes for a first release ($out)"; fi
make_appcast "$TMP/appcast-same42.xml" 42 1.2.3
expect_fail "--check --publish refuses an already published build number" "build number 42 is already published (version 1.2.3)" \
  run_check_publish FAKE_APPCAST="$TMP/appcast-same42.xml" FAKE_APPCAST_CODE=200
expect_fail "--check --publish refuses when the published appcast cannot be checked" "published appcast could not be checked" \
  run_check_publish FAKE_APPCAST_NETFAIL=1
if out="$(run_check_publish FAKE_APPCAST="$TMP/appcast-lower.xml" FAKE_APPCAST_CODE=200 FAKE_BUILD=100 2>&1)"; then
  pass "--check --publish passes for a higher build number"; else fail "--check --publish passes for a higher build number ($out)"; fi
: > "$TMP/log"
env PATH="$TMP/main-bin:$TMP/bin:$PATH" FAKE_LOG="$TMP/log" scripts/release.sh --check > /dev/null 2>&1
if ! grep -q appcast "$TMP/log"; then pass "without --publish the appcast is not fetched"; else fail "without --publish the appcast is not fetched"; fi

# --- real unsigned build ---
if [[ "${1:-}" == "--full" ]]; then
  OUT_DIR="$TMP/out" scripts/release.sh > "$TMP/full.log" 2>&1 || { tail -20 "$TMP/full.log"; fail "unsigned build runs"; }
  dmg="$(ls "$TMP"/out/"$NAME"-*.dmg 2> /dev/null | head -1)"
  [[ -n "$dmg" ]] && pass "unsigned build produces a dmg" || fail "unsigned build produces a dmg"
  (cd "$TMP/out" && shasum -a 256 -c ./*.sha256 > /dev/null 2>&1) && pass "checksum verifies" || fail "checksum verifies"
  [[ -f "$TMP/out/release-notes.md" ]] && pass "release notes written" || fail "release notes written"
  hdiutil verify "$dmg" > /dev/null 2>&1 && pass "dmg verifies" || fail "dmg verifies"
fi

exit $FAILED
