#!/bin/bash
# Tests scripts/init.sh on a throw-away COPY of this repository: renames it to a probe product,
# then generates, lints, builds and tests the result and checks its documents.
#
#   scripts/test-init.sh [--keep]
#
#   CHECK_DOCS=<path to check-docs.py>  default: ../.github/scripts/check-docs.py next to this
#                                       repository; the documents check is skipped when neither exists
#   --keep  do not delete the copy (its path is printed)
set -uo pipefail
cd "$(dirname "$0")/.."
SRC="$PWD"

NAME=Probe DOMAIN=probe.test
KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

FAILED=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; FAILED=1; }
check() { # check <name> <command...>
  local name="$1"; shift
  if "$@" > "$TMP/last.log" 2>&1; then pass "$name"; else fail "$name"; tail -n 20 "$TMP/last.log"; fi
}

TMP="$(mktemp -d)"
cleanup() { if [[ $KEEP -eq 1 ]]; then echo "kept: $TMP"; else rm -rf "$TMP"; fi; }
trap cleanup EXIT
COPY="$TMP/copy"
mkdir -p "$COPY"
rsync -a --exclude .git --exclude build --exclude DerivedData --exclude .build "$SRC/" "$COPY/"
cd "$COPY"
git init -q -b main && git add -A && git -c user.name=test -c user.email=test@test.invalid commit -q -m "template"

# --- refusals leave the copy untouched ---
refuses() { # refuses <name> <needle> <args...>
  local name="$1" needle="$2"; shift 2
  local out
  if out="$(scripts/init.sh --no-generate "$@" 2>&1)"; then fail "$name (succeeded)"; return; fi
  if grep -qF -- "$needle" <<< "$out"; then pass "$name"; else fail "$name ($out)"; fi
}
refuses "a lowercase name is refused" "PascalCase" acme acme.com
refuses "the template name is refused" "must not be 'Template'" Template acme.com
refuses "an uppercase domain is refused" "lowercase domain" Acme Acme.com
refuses "the placeholder domain is refused" "must not be example.com" Acme example.com
refuses "a missing domain is refused" "usage" Acme
[[ -z "$(git status --porcelain)" ]] && pass "refusals change nothing" || fail "refusals change nothing"

# --- the real run ---
if scripts/init.sh "$NAME" "$DOMAIN" > "$TMP/init.log" 2>&1; then pass "init.sh succeeds"; else fail "init.sh succeeds"; cat "$TMP/init.log"; fi
grep -q "^warning:" "$TMP/init.log" && fail "init.sh reports no leftovers" || pass "init.sh reports no leftovers"

[[ "$(cat .repo-type)" == "app" ]] && pass ".repo-type is app" || fail ".repo-type is app"
for path in Probe/App/ProbeApp.swift Probe/UI/Example/ExampleView.swift Probe/Resources/Localizable.xcstrings \
  ProbeCore/Package.swift ProbeCore/Sources/ProbeCore/Design/DesignTokens.swift ProbeTests/LocalizationCatalogTests.swift \
  Probe.xcodeproj/project.pbxproj Config/Probe-Info.plist README.md AGENTS.md docs/spec.md design/screens/example.html; do
  [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
done
for path in Template TemplateCore TemplateTests Template.xcodeproj .template scripts/init.sh scripts/test-init.sh; do
  [[ ! -e "$path" ]] && pass "gone: $path" || fail "gone: $path"
done
grep -q "PRODUCT_BUNDLE_IDENTIFIER: test.probe.app$" project.yml && grep -q "PRODUCT_BUNDLE_IDENTIFIER: test.probe.app.tests$" project.yml \
  && pass "bundle ids are test.probe.app and test.probe.app.tests" || fail "bundle ids"
grep -q "bundleIdPrefix: test.probe$" project.yml && pass "bundleIdPrefix follows the domain" || fail "bundleIdPrefix follows the domain"
grep -q "SPARKLE_FEED_URL: https://dl.probe.test/appcast.xml" project.yml && pass "Sparkle feed follows the domain" || fail "Sparkle feed follows the domain"
conf_ok=1
for line in 'APP_NAME="Probe"' 'PROJECT="Probe.xcodeproj"' 'SCHEME="Probe"' 'PRODUCT_DOMAIN="probe.test"' 'SITE_URL="https://probe.test"' \
  'DOWNLOADS_URL="https://dl.probe.test"' 'KEYCHAIN_PREFIX="probe"' 'SPARKLE_ACCOUNT="probe"' 'REPO_URL="https://github.com/ydongy/probe"'; do
  grep -qxF "$line" Config/release.conf || { conf_ok=0; echo "missing in release.conf: $line"; }
done
[[ $conf_ok -eq 1 ]] && pass "Config/release.conf carries the product values" || fail "Config/release.conf carries the product values"
grep -q "sparkle-account: probe" .github/workflows/release.yml && grep -q "project: Probe.xcodeproj" .github/workflows/ci.yml \
  && grep -q "lint-paths: Probe ProbeCore ProbeTests" .github/workflows/ci.yml && pass "workflows name the product" || fail "workflows name the product"
grep -q '"pending": \[\]' .docs-check.json && pass ".docs-check.json is written" || fail ".docs-check.json"
# The record-template heading in docs/adr/README.md is literally "## Template" and stays.
stale="$(grep -rIn --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData -e Template -e example.com . \
  | grep -v -e '^./Probe.xcodeproj' -e ':## Template$' -e 'template: ' || true)"
if [[ -z "$stale" ]]; then pass "no file mentions Template or example.com"; else fail "no file mentions Template or example.com"; echo "$stale" | head; fi
if grep -rIiE --exclude-dir=.git -e 'template-macos-app' . | grep -q .; then fail "no mention of the template repository"; else pass "no mention of the template repository"; fi

# --- the result is a working product ---
git add -A
check "xcodegen output is stable" bash -c 'xcodegen generate --quiet && git diff --exit-code -- "*.xcodeproj"'
check "swift-format lint --strict" xcrun swift-format lint --strict --recursive Probe ProbeCore ProbeTests
check "Release build" xcodebuild build -project Probe.xcodeproj -scheme Probe -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$TMP/dd" CODE_SIGNING_ALLOWED=NO
app="$TMP/dd/Build/Products/Release/Probe.app"
if [[ -d "$app" ]]; then
  [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == "test.probe.app" ]] && pass "built bundle id" || fail "built bundle id"
  check "Release app has no mock or preview symbols" bash -c "! strings -a '$app/Contents/MacOS/Probe' | grep -E 'MockExampleSource|ExamplePreviewData'"
else fail "Release app exists"; fi
check "unit tests" xcodebuild test -project Probe.xcodeproj -scheme Probe -destination 'platform=macOS' \
  -derivedDataPath "$TMP/dd" -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
check "release script tests" scripts/test-release.sh
check "changelog script tests" python3 scripts/test_website_changelog.py

CHECK_DOCS="${CHECK_DOCS:-$SRC/../.github/scripts/check-docs.py}"
if [[ -f "$CHECK_DOCS" ]]; then
  check "docs check as type app" python3 "$CHECK_DOCS" "$COPY"
else
  echo "skip docs check (no check-docs.py; set CHECK_DOCS)"
fi

exit $FAILED
