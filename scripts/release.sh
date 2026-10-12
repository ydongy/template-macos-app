#!/bin/bash
# Build, sign, notarize and package the app (name, domain and accounts come from Config/release.conf).
#
#   scripts/release.sh [--check] [--publish]
#
# Environment (all optional; without the first two the script builds an UNSIGNED dmg).
# Anything not set here is read from the login keychain: see scripts/release-credentials.sh.
#   SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)" - must be in the login keychain
#   NOTARY_PROFILE  keychain profile created with `xcrun notarytool store-credentials`
#   OUT_DIR         output directory (default: build/release)
#
# For --publish (R2's S3-compatible API; nothing is stored in the repo):
#   R2_ENDPOINT           https://<account-id>.r2.cloudflarestorage.com
#   R2_BUCKET             bucket name
#   R2_ACCESS_KEY_ID      token with write access to that bucket only
#   R2_SECRET_ACCESS_KEY
#   DOWNLOADS_URL         public base URL (default: DOWNLOADS_URL in Config/release.conf)
#   SITE_URL              public site (default: SITE_URL in Config/release.conf)
#   SPARKLE_BIN           directory with Sparkle's sign_update and generate_keys (default: the newest
#                         Sparkle package artifacts under ~/Library/Developer/Xcode/DerivedData);
#                         the private update key is read from the login keychain (generate_keys)
#   SPARKLE_ACCOUNT       keychain account of the update key (default: SPARKLE_ACCOUNT in
#                         Config/release.conf, created with generate_keys --account <name>).
#                         SPARKLE_KEY_ACCOUNT is accepted as an alias. Set it to ed25519, Sparkle's
#                         default account, to use a key you already share with another app
#   RELEASE_CONF          another settings file instead of Config/release.conf (used by the tests)
#   RELEASE_NO_KEYCHAIN=1 do not read settings from the login keychain (used by the tests)
#
# --check    only verify the prerequisites and print what would happen
# --publish  sign the dmg for Sparkle, upload to Cloudflare R2, publish appcast.xml and latest.json
#            (needs SIGN_IDENTITY and NOTARY_PROFILE). Refuses a build number that is already
#            published, or lower than the highest published one.
#
# No secrets are read or printed here; notarization credentials live in the keychain profile.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# --- settings --------------------------------------------------------------

# Product values live in Config/release.conf only. A few can be overridden from the environment.
env_downloads="${DOWNLOADS_URL:-}"
env_site="${SITE_URL:-}"
env_account="${SPARKLE_ACCOUNT:-${SPARKLE_KEY_ACCOUNT:-}}"
RELEASE_CONF="${RELEASE_CONF:-Config/release.conf}"
[[ -f "$RELEASE_CONF" ]] || { printf 'error: %s not found\n' "$RELEASE_CONF" >&2; exit 1; }
# shellcheck disable=SC1090
source "$RELEASE_CONF"
for _name in APP_NAME PROJECT SCHEME PRODUCT_DOMAIN SITE_URL DOWNLOADS_URL KEYCHAIN_PREFIX SPARKLE_ACCOUNT; do
  [[ -n "${!_name:-}" ]] || { printf 'error: %s is not set in %s\n' "$_name" "$RELEASE_CONF" >&2; exit 1; }
done
unset _name
DOWNLOADS_URL="${env_downloads:-$DOWNLOADS_URL}"
SITE_URL="${env_site:-$SITE_URL}"
SPARKLE_ACCOUNT="${env_account:-$SPARKLE_ACCOUNT}"
FORBID_SYMBOLS="${FORBID_SYMBOLS:-}"

CHECK_ONLY=0
PUBLISH=0
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --check) CHECK_ONLY=1 ;;
      --publish) PUBLISH=1 ;;
      -h | --help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
      *) echo "error: unknown argument: $arg" >&2; exit 64 ;;
    esac
  done
}

# Settings not given in the environment come from the keychain (see scripts/release-credentials.sh).
# RELEASE_NO_KEYCHAIN=1 turns that off (used by the tests).
load_from_keychain() {
  [[ "${RELEASE_NO_KEYCHAIN:-}" == "1" ]] && return 0
  local name value
  for name in R2_ENDPOINT R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY SIGN_IDENTITY NOTARY_PROFILE; do
    if [[ -z "${!name:-}" ]]; then
      value="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_PREFIX-release-$name" -w 2> /dev/null || true)"
      if [[ -n "$value" ]]; then export "$name=$value"; fi
    fi
  done
}
load_from_keychain

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
OUT_DIR="${OUT_DIR:-build/release}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# --- prerequisites ---------------------------------------------------------

check_prerequisites() {
  local tool
  for tool in xcodebuild codesign hdiutil shasum ditto; do
    command -v "$tool" > /dev/null || die "required tool not found: $tool"
  done

  SIGNED=0
  if [[ -n "$SIGN_IDENTITY" ]]; then
    security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY" \
      || die "signing identity not found in the keychain: $SIGN_IDENTITY (see: security find-identity -v -p codesigning)"
    SIGNED=1
  fi

  NOTARIZE=0
  if [[ -n "$NOTARY_PROFILE" ]]; then
    [[ $SIGNED -eq 1 ]] || die "NOTARY_PROFILE is set but SIGN_IDENTITY is not; only signed builds can be notarized"
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1 \
      || die "notarytool cannot use keychain profile '$NOTARY_PROFILE' (create it with: xcrun notarytool store-credentials)"
    NOTARIZE=1
  fi

  if [[ $PUBLISH -eq 1 ]]; then
    [[ $NOTARIZE -eq 1 ]] || die "--publish needs SIGN_IDENTITY and NOTARY_PROFILE: refusing to publish an unnotarized build"
    local name
    for name in R2_ENDPOINT R2_BUCKET R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY; do
      [[ -n "${!name:-}" ]] || die "--publish needs $name (see the header of scripts/release.sh and scripts/release-credentials.sh)"
    done
    [[ "$R2_ENDPOINT" =~ ^https://[A-Za-z0-9.]+\.r2\.cloudflarestorage\.com/?$ ]] \
      || die "R2_ENDPOINT is not an R2 endpoint URL (expected https://<account-id>.r2.cloudflarestorage.com); fix it with scripts/release-credentials.sh set R2_ENDPOINT"
    find_sparkle_tools
    command -v curl > /dev/null || die "--publish needs curl"
    command -v python3 > /dev/null || die "--publish needs python3 (to write appcast.xml and latest.json)"
  fi

  if [[ $SIGNED -eq 0 ]]; then
    warn "no SIGN_IDENTITY: building an UNSIGNED (ad-hoc) dmg; macOS will warn when it is opened"
  elif [[ $NOTARIZE -eq 0 ]]; then
    warn "no NOTARY_PROFILE: the build will be signed but NOT notarized"
  fi
}

# --- Sparkle ---------------------------------------------------------------

find_sparkle_tools() {
  local dir="${SPARKLE_BIN:-}" derived="$HOME/Library/Developer/Xcode/DerivedData" suffix="SourcePackages/artifacts/sparkle/Sparkle/bin"
  if [[ -z "$dir" ]]; then
    # The newest package artifacts of this app's own DerivedData first, then any other project's.
    dir="$(ls -dt "$derived/$APP_NAME"-*/"$suffix" 2> /dev/null | head -1 || true)"
    if [[ -z "$dir" ]]; then
      dir="$(ls -dt "$derived"/*/"$suffix" 2> /dev/null | head -1 || true)"
    fi
  fi
  [[ -n "$dir" && -x "$dir/sign_update" && -x "$dir/generate_keys" ]] \
    || die "Sparkle's sign_update / generate_keys not found (build the project once so the Sparkle package is fetched, or set SPARKLE_BIN)"
  SPARKLE_BIN="$dir"
}

# The app must carry the public key that matches the private key in the keychain, otherwise no
# installed copy could ever verify an update.
check_sparkle_key() {
  local plist="$APP/Contents/Info.plist" in_app in_keychain
  in_app="$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$plist" 2> /dev/null || true)"
  [[ -n "$in_app" ]] || die "SUPublicEDKey is empty in the built Info.plist (set SPARKLE_PUBLIC_KEY in project.yml): the app could not verify any update. Generate the key with generate_keys and set it before publishing"
  in_keychain="$("$SPARKLE_BIN/generate_keys" --account "$SPARKLE_ACCOUNT" -p 2> /dev/null || true)"
  [[ -n "$in_keychain" ]] || die "no Sparkle private key for account '$SPARKLE_ACCOUNT' in the keychain (run generate_keys --account $SPARKLE_ACCOUNT once, and back the key up)"
  [[ "$in_app" == "$in_keychain" ]] || die "SUPublicEDKey in Info.plist does not match the Sparkle key in the keychain"
}

# Sign the dmg. Prints the signature; fails (before anything is uploaded) if it cannot sign or verify.
sparkle_sign() {
  local signature
  signature="$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" -p "$DMG" 2> /dev/null)" || die "Sparkle could not sign the dmg (nothing was published)"
  [[ -n "$signature" ]] || die "Sparkle returned an empty signature (nothing was published)"
  "$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" --verify "$DMG" "$signature" > /dev/null 2>&1 \
    || die "the Sparkle signature does not verify (nothing was published)"
  printf '%s' "$signature"
}

# write_appcast <signature>; prints the appcast with the one current version. Release notes are
# deliberately absent: the release history is a page on the website.
write_appcast() {
  local minimum size
  minimum="$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$APP/Contents/Info.plist" 2> /dev/null || true)"
  size="$(stat -f%z "$DMG")"
  APP_NAME="$APP_NAME" SITE="$SITE_URL" VERSION="$VERSION" BUILD="$BUILD_NUMBER" URL="$DOWNLOADS_URL/$DMG_NAME" \
    SIG="$1" SIZE="$size" MINIMUM="$minimum" python3 - << 'PY'
import datetime, os
from xml.sax.saxutils import escape, quoteattr

e = os.environ
date = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
minimum = e["MINIMUM"]
lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">',
    "  <channel>",
    "    <title>%s</title>" % escape(e["APP_NAME"]),
    "    <link>%s</link>" % escape(e["SITE"]),
    "    <item>",
    "      <title>Version %s</title>" % escape(e["VERSION"]),
    "      <pubDate>%s</pubDate>" % date,
    "      <sparkle:version>%s</sparkle:version>" % escape(e["BUILD"]),
    "      <sparkle:shortVersionString>%s</sparkle:shortVersionString>" % escape(e["VERSION"]),
]
if minimum:
    lines.append("      <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>" % escape(minimum))
lines += [
    "      <enclosure url=%s sparkle:edSignature=%s length=%s type=\"application/x-apple-diskimage\"/>"
    % (quoteattr(e["URL"]), quoteattr(e["SIG"]), quoteattr(e["SIZE"])),
    "    </item>",
    "  </channel>",
    "</rss>",
]
print("\n".join(lines))
PY
}

# --- version ---------------------------------------------------------------

read_version() { # both numbers come from Config/Version.xcconfig through the project's build settings
  local settings
  settings="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2> /dev/null || true)"
  VERSION="$(awk -F' = ' '/^ *MARKETING_VERSION =/ { print $2; exit }' <<< "$settings")"
  BUILD_NUMBER="$(awk -F' = ' '/^ *CURRENT_PROJECT_VERSION =/ { print $2; exit }' <<< "$settings")"
  [[ -n "$VERSION" ]] || die "could not read MARKETING_VERSION from $PROJECT (scheme $SCHEME)"
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "CURRENT_PROJECT_VERSION must be an integer (see Config/Version.xcconfig), got '$BUILD_NUMBER'"
  DMG_NAME="$APP_NAME-$VERSION.dmg"
}

# published_builds <appcast file>; prints "<build> <version>" for every item, fails when it is not an appcast.
published_builds() {
  python3 - "$1" << 'PY'
import sys
import xml.etree.ElementTree as ET

S = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
root = ET.parse(sys.argv[1]).getroot()
if root.tag != "rss":
    sys.exit(1)
for item in root.iter("item"):
    enclosure = item.find("enclosure")
    build = item.findtext(S + "version")
    if build is None and enclosure is not None:
        build = enclosure.get(S + "version")
    version = item.findtext(S + "shortVersionString")
    if version is None and enclosure is not None:
        version = enclosure.get(S + "shortVersionString")
    if build is None or not build.strip().isdigit():
        sys.exit(2)
    print(build.strip(), (version or "unknown").strip())
PY
}

# Sparkle offers an update only when its build number is higher than the installed one, so a build
# number that is already in the published appcast, or lower than the newest there, can never reach
# anybody. Runs before anything is uploaded. No appcast yet (HTTP 404) is the first release.
check_build_number_unpublished() {
  local url="$DOWNLOADS_URL/appcast.xml" file code published build version highest="" highest_version=""
  file="$(mktemp)"
  if ! code="$(curl --silent --location --write-out '%{http_code}' --output "$file" "$url" 2> /dev/null)"; then
    rm -f "$file"
    die "the published appcast could not be checked ($url is not reachable); refusing to publish"
  fi
  if [[ "$code" == "404" ]]; then
    rm -f "$file"
    log "No appcast published yet at $url: first release"
    return 0
  fi
  if [[ "$code" != "200" ]]; then
    rm -f "$file"
    die "the published appcast could not be checked ($url answered HTTP $code); refusing to publish"
  fi
  published="$(published_builds "$file" 2> /dev/null)" \
    || { rm -f "$file"; die "the published appcast could not be checked ($url is not a readable appcast); refusing to publish"; }
  rm -f "$file"
  while read -r build version; do
    [[ -n "$build" ]] || continue
    if (( 10#$build == 10#$BUILD_NUMBER )); then
      die "build number $BUILD_NUMBER is already published (version $version) in $url; raise CURRENT_PROJECT_VERSION with scripts/bump.sh"
    fi
    if [[ -z "$highest" ]] || (( 10#$build > 10#$highest )); then highest="$build"; highest_version="$version"; fi
  done <<< "$published"
  if [[ -n "$highest" ]] && (( 10#$BUILD_NUMBER < 10#$highest )); then
    die "build number $BUILD_NUMBER is lower than the highest published build $highest (version $highest_version) in $url: installed copies would never be offered this update"
  fi
  log "Build number $BUILD_NUMBER is new (highest published: ${highest:-none})"
}

release_notes() {
  local file="${CHANGELOG_FILE:-CHANGELOG.md}"
  [[ -f "$file" ]] || die "$file not found"
  # The section "## [X.Y.Z] - date" of Keep a Changelog, without link definitions at the bottom.
  awk -v v="$VERSION" '
    index($0, "## [" v "]") == 1 { found = 1; next }
    found && /^## / { exit }
    found && /^\[[^]]+\]: / { next }
    found { print }
  ' "$file" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# --- steps -----------------------------------------------------------------

archive_app() {
  log "Archiving $APP_NAME $VERSION ($BUILD_NUMBER)"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  local identity="${SIGN_IDENTITY:--}"
  # No -derivedDataPath: packages are resolved into the default DerivedData, where find_sparkle_tools looks.
  xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$OUT_DIR/$APP_NAME.xcarchive" \
    CODE_SIGN_IDENTITY="$identity" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    SPARKLE_FEED_URL="$DOWNLOADS_URL/appcast.xml" \
    > "$OUT_DIR/archive.log" 2>&1 \
    || { tail -n 30 "$OUT_DIR/archive.log" >&2; die "archive failed (full log: $OUT_DIR/archive.log)"; }
  APP="$OUT_DIR/$APP_NAME.app"
  ditto "$OUT_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$APP"
}

scan_app() { # credential-like strings, build-machine paths, debug-only types and debug entitlements must not ship
  log "Scanning the app bundle"
  local args=(--forbid "$HOME") symbol
  for symbol in $FORBID_SYMBOLS; do args+=(--forbid "$symbol"); done
  python3 scripts/scan_secrets.py --path "$APP" "${args[@]}" \
    || die "the app bundle failed the artifact scan (see above)"
  local entitlements
  entitlements="$(codesign -d --entitlements - "$APP" 2>&1 || true)"
  if grep -q "get-task-allow" <<< "$entitlements"; then
    die "the app carries the get-task-allow entitlement (a debug build): it must not be distributed"
  fi
}

verify_app() {
  log "Verifying the app bundle"
  codesign --verify --deep --strict "$APP" || die "codesign verification failed"
  local details
  details="$(codesign -dv "$APP" 2>&1)"
  grep -q "flags=.*runtime" <<< "$details" || die "Hardened Runtime is not enabled on the app"
  local shown
  shown="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")"
  [[ "$shown" == "$VERSION" ]] || die "app reports version $shown, expected $VERSION"
  if [[ $PUBLISH -eq 1 ]]; then
    local key feed
    key="$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$APP/Contents/Info.plist" 2> /dev/null || true)"
    [[ -n "$key" ]] || die "the app has no SUPublicEDKey: it could not verify updates"
    feed="$(/usr/libexec/PlistBuddy -c "Print SUFeedURL" "$APP/Contents/Info.plist" 2> /dev/null || true)"
    [[ "$feed" == "$DOWNLOADS_URL/appcast.xml" ]] || die "the app's SUFeedURL ($feed) does not match $DOWNLOADS_URL/appcast.xml"
  fi
  if [[ $SIGNED -eq 1 ]]; then
    grep -q "Authority=Developer ID Application" <<< "$details" || die "app is not signed with a Developer ID Application certificate"
  fi
}

notarize() { # notarize <file>
  local file="$1"
  log "Submitting $(basename "$file") for notarization (this can take a few minutes)"
  local result
  if ! result="$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)"; then
    printf '%s\n' "$result" >&2
    die "notarization submission failed"
  fi
  printf '%s\n' "$result"
  if ! grep -q "status: Accepted" <<< "$result"; then
    local id
    id="$(awk '/^ *id:/ { print $2; exit }' <<< "$result")"
    [[ -z "$id" ]] || xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    die "notarization was not accepted"
  fi
}

notarize_app() {
  local zip="$OUT_DIR/$APP_NAME-notarize.zip"
  ditto -c -k --keepParent "$APP" "$zip"
  notarize "$zip"
  rm -f "$zip"
  log "Stapling the app"
  xcrun stapler staple "$APP" || die "stapling the app failed"
}

make_dmg() {
  log "Creating $DMG_NAME"
  local stage="$OUT_DIR/dmg-stage"
  rm -rf "$stage"
  mkdir -p "$stage"
  ditto "$APP" "$stage/$APP_NAME.app"
  ln -s /Applications "$stage/Applications"
  DMG="$OUT_DIR/$DMG_NAME"
  hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -format UDZO -ov "$DMG" > /dev/null \
    || die "creating the dmg failed"
  rm -rf "$stage"
  if [[ $SIGNED -eq 1 ]]; then
    codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG" || die "signing the dmg failed"
  fi
}

finish_dmg() {
  if [[ $NOTARIZE -eq 1 ]]; then
    notarize "$DMG"
    log "Stapling the dmg"
    xcrun stapler staple "$DMG" || die "stapling the dmg failed"
    spctl --assess --type open --context context:primary-signature "$DMG" \
      || die "Gatekeeper rejected the dmg"
    spctl --assess --type execute "$APP" || die "Gatekeeper rejected the app"
  fi
  (cd "$OUT_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
  # The notes are for the GitHub release; they are not part of the appcast or latest.json.
  release_notes > "$OUT_DIR/release-notes.md"
  [[ -s "$OUT_DIR/release-notes.md" ]] || warn "CHANGELOG.md has no section for $VERSION; release notes are empty"
}

r2_put() { # r2_put <file> <key> <content-type> [cache-control]
  local file="$1" key="$2" type="$3" cache="${4:-}"
  local hash
  hash="$(shasum -a 256 "$file" | awk '{ print $1 }')"
  local args=(--fail --silent --show-error
    --aws-sigv4 "aws:amz:auto:s3" --user "$R2_ACCESS_KEY_ID:$R2_SECRET_ACCESS_KEY"
    -H "x-amz-content-sha256: $hash" -H "Content-Type: $type")
  if [[ -n "$cache" ]]; then args+=(-H "Cache-Control: $cache"); fi
  curl "${args[@]}" -T "$file" "$R2_ENDPOINT/$R2_BUCKET/$key" > /dev/null \
    || die "uploading $key to R2 failed (nothing was published)"
}

verify_download() { # the file served from the public address must match what we built
  local expected="$1" key="$2"
  local actual
  actual="$(curl --fail --silent --show-error --location "$DOWNLOADS_URL/$key" | shasum -a 256 | awk '{ print $1 }')" \
    || die "could not download $DOWNLOADS_URL/$key to verify it"
  [[ "$actual" == "$expected" ]] \
    || die "$DOWNLOADS_URL/$key does not match the local file (expected $expected, got $actual); appcast.xml and latest.json were not published"
}

write_latest() { # write_latest <sha256>; the small feed the website's download button reads (no release notes)
  local minimum
  minimum="$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$APP/Contents/Info.plist" 2> /dev/null || true)"
  VERSION="$VERSION" BUILD="$BUILD_NUMBER" URL="$DOWNLOADS_URL/$DMG_NAME" SHA="$1" MINIMUM="$minimum" python3 -c '
import json, os, datetime
feed = {
    "version": os.environ["VERSION"],
    "build": int(os.environ["BUILD"]),
    "url": os.environ["URL"],
    "sha256": os.environ["SHA"],
    "publishedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if os.environ["MINIMUM"]:
    feed["minimumOS"] = os.environ["MINIMUM"]
print(json.dumps(feed, indent=2))
'
}

publish() {
  log "Publishing $VERSION to R2 ($R2_BUCKET)"
  local sha signature
  sha="$(awk '{ print $1 }' "$DMG.sha256")"
  # Check, sign and verify first: if anything is wrong, nothing has been uploaded yet.
  check_build_number_unpublished
  check_sparkle_key
  signature="$(sparkle_sign)"
  write_appcast "$signature" > "$OUT_DIR/appcast.xml"
  write_latest "$sha" > "$OUT_DIR/latest.json"
  r2_put "$DMG" "$DMG_NAME" "application/x-apple-diskimage"
  r2_put "$DMG.sha256" "$DMG_NAME.sha256" "text/plain"
  verify_download "$sha" "$DMG_NAME"
  # The feeds go last (appcast for the app, latest.json for the website), so nobody sees a version
  # whose installer is not there yet.
  r2_put "$OUT_DIR/appcast.xml" "appcast.xml" "application/xml" "no-cache"
  r2_put "$OUT_DIR/latest.json" "latest.json" "application/json" "no-cache"
  log "Published: $DOWNLOADS_URL/appcast.xml and latest.json"
  log "Next: the public changelog on the website is NOT updated automatically. Review CHANGELOG.md and CHANGELOG.zh.md, then run:"
  log "  scripts/website-changelog.py --version $VERSION --website-dir <clone of the website repo> --open-pr"
}

# --- main ------------------------------------------------------------------

main() {
  parse_args "$@"
  check_prerequisites
  read_version
  if [[ $PUBLISH -eq 1 ]]; then check_build_number_unpublished; fi
  log "Version $VERSION, build $BUILD_NUMBER, output $OUT_DIR/$DMG_NAME"
  if [[ $CHECK_ONLY -eq 1 ]]; then
    log "Check passed: signed=$SIGNED notarize=$NOTARIZE publish=$PUBLISH"
    return 0
  fi

  archive_app
  scan_app
  verify_app
  if [[ $NOTARIZE -eq 1 ]]; then notarize_app; fi
  make_dmg
  finish_dmg
  if [[ $PUBLISH -eq 1 ]]; then publish; fi

  log "Done: $DMG"
  if [[ $SIGNED -eq 0 ]]; then warn "this dmg is unsigned and must not be distributed"; fi
}

# Sourced by scripts/test-release.sh to test single functions.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
