#!/bin/bash
# Tests scripts/init.sh on throw-away COPIES of this repository, once per license: renames each to a probe
# product, checks the generated files, and for the mit copy also lints, builds and tests the result. The
# proprietary copy gets the file-level assertions and the xcodegen/lint checks only; --full builds it too.
#
#   scripts/test-init.sh [--keep] [--full]
#
#   CHECK_DOCS=<path to check-docs.py>  checks the proprietary copy's documents; default:
#                                       ../.github/scripts/check-docs.py next to this repository, skipped
#                                       when absent
#   --keep  do not delete the copies (their path is printed)
#   --full  build and test the proprietary copy as well (slower)
set -uo pipefail
cd "$(dirname "$0")/.."
SRC="$PWD"

NAME=Probe DOMAIN=probe.test
# Words that must not survive in an open-source project (spelled in parts so that this file passes its own check).
DC="docs-""check" HB="hand""book" MS="mile""stone" GH="ydongy/\\.""github"
OR="ORG_DOCS""_ROOT"
BANNED="$HB|$DC|$OR|$GH|$MS"
KEEP=0 FULL=0
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    --full) FULL=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

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

# new_copy <dir> [remote-url]: a committed copy of this repository, optionally with an origin remote.
new_copy() {
  mkdir -p "$1"
  rsync -a --exclude .git --exclude build --exclude DerivedData --exclude .build "$SRC/" "$1/"
  (cd "$1" && git init -q -b main && git add -A && git -c user.name=test -c user.email=test@test.invalid commit -q -m "template" \
    && { [[ -z "${2:-}" ]] || git remote add origin "$2"; })
}

# Assertions shared by both licenses (run inside the initialised copy).
common_assertions() {
  for path in Probe/App/ProbeApp.swift Probe/UI/Example/ExampleView.swift Probe/Resources/Localizable.xcstrings \
    ProbeCore/Package.swift ProbeCore/Sources/ProbeCore/Design/DesignTokens.swift ProbeTests/LocalizationCatalogTests.swift \
    Probe.xcodeproj/project.pbxproj Config/Probe-Info.plist README.md AGENTS.md CLAUDE.md LICENSE CHANGELOG.md THIRD_PARTY.md \
    docs/design.md docs/adr/README.md design/screens/example.html .github/workflows/ci.yml .github/dependabot.yml; do
    [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
  done
  for path in Template TemplateCore TemplateTests Template.xcodeproj .template scripts/init.sh scripts/test-init.sh; do
    [[ ! -e "$path" ]] && pass "gone: $path" || fail "gone: $path"
  done
  grep -q "PRODUCT_BUNDLE_IDENTIFIER: test.probe.app$" project.yml && grep -q "PRODUCT_BUNDLE_IDENTIFIER: test.probe.app.tests$" project.yml \
    && pass "bundle ids are test.probe.app and test.probe.app.tests" || fail "bundle ids"
  grep -q "bundleIdPrefix: test.probe$" project.yml && pass "bundleIdPrefix follows the domain" || fail "bundleIdPrefix follows the domain"
  grep -q "SPARKLE_FEED_URL: https://dl.probe.test/appcast.xml" project.yml && pass "Sparkle feed follows the domain" || fail "Sparkle feed follows the domain"
  local conf_ok=1 line
  for line in 'APP_NAME="Probe"' 'PROJECT="Probe.xcodeproj"' 'SCHEME="Probe"' 'PRODUCT_DOMAIN="probe.test"' 'SITE_URL="https://probe.test"' \
    'DOWNLOADS_URL="https://dl.probe.test"' 'KEYCHAIN_PREFIX="probe"' 'SPARKLE_ACCOUNT="probe"' "REPO_URL=\"https://github.com/$1/probe\""; do
    grep -qxF "$line" Config/release.conf || { conf_ok=0; echo "missing in release.conf: $line"; }
  done
  [[ $conf_ok -eq 1 ]] && pass "Config/release.conf carries the product values" || fail "Config/release.conf carries the product values"
  # The record-template heading in docs/adr/README.md is literally "## Template" and stays.
  local stale
  stale="$(grep -rIn --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData -e Template -e example.com . \
    | grep -v -e '^./Probe.xcodeproj' -e ':## Template$' -e 'template: ' || true)"
  if [[ -z "$stale" ]]; then pass "no file mentions Template or example.com"; else fail "no file mentions Template or example.com"; echo "$stale" | head; fi
  if grep -rIiE --exclude-dir=.git -e 'template-macos-app' . | grep -q .; then fail "no mention of the template repository"; else pass "no mention of the template repository"; fi
}

# build_checks <dir>: the result is a working product.
build_checks() {
  git add -A
  check "xcodegen output is stable" bash -c 'xcodegen generate --quiet && git diff --exit-code -- "*.xcodeproj"'
  check "swift-format lint --strict" xcrun swift-format lint --strict --recursive Probe ProbeCore ProbeTests
  check "Release build" xcodebuild build -project Probe.xcodeproj -scheme Probe -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$TMP/dd" CODE_SIGNING_ALLOWED=NO
  local app="$TMP/dd/Build/Products/Release/Probe.app"
  if [[ -d "$app" ]]; then
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == "test.probe.app" ]] && pass "built bundle id" || fail "built bundle id"
    check "Release app has no mock or preview symbols" bash -c "! strings -a '$app/Contents/MacOS/Probe' | grep -E 'MockExampleSource|ExamplePreviewData'"
  else fail "Release app exists"; fi
  check "unit tests" xcodebuild test -project Probe.xcodeproj -scheme Probe -destination 'platform=macOS' \
    -derivedDataPath "$TMP/dd" -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
  check "release script tests" scripts/test-release.sh
  [[ ! -f scripts/test_website_changelog.py ]] || check "changelog script tests" python3 scripts/test_website_changelog.py
}

# ---------------- refusals leave the copy untouched ----------------
echo "== refusals"
COPY="$TMP/refusals"; new_copy "$COPY"; cd "$COPY"
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
refuses "an unknown license is refused" "--license must be mit or proprietary" Acme acme.com --license gpl
[[ -z "$(git status --porcelain)" ]] && pass "refusals change nothing" || fail "refusals change nothing"

# ---------------- --license mit (default), owner inferred from the remote ----------------
echo "== --license mit (default), full build"
COPY="$TMP/mit"; new_copy "$COPY" "https://github.com/acme-inc/probe.git"; cd "$COPY"
if scripts/init.sh "$NAME" "$DOMAIN" > "$TMP/init.log" 2>&1; then pass "init.sh succeeds"; else fail "init.sh succeeds"; cat "$TMP/init.log"; fi
grep -q "^warning:" "$TMP/init.log" && { fail "init.sh reports no leftovers"; grep "^warning:" "$TMP/init.log"; } || pass "init.sh reports no leftovers"
common_assertions acme-inc
head -1 LICENSE | grep -q "^MIT License" && pass "LICENSE is MIT" || fail "LICENSE is MIT"
[[ "$(cat .github/CODEOWNERS)" == "* @acme-inc" ]] && pass "CODEOWNERS uses the owner from the remote" || fail "CODEOWNERS uses the owner from the remote"
for path in CONTRIBUTING.md .github/CODEOWNERS .github/workflows/pr-title.yml; do
  [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
done
for path in .${DC}.json .repo-type GEMINI.md SECURITY.md CHANGELOG.zh.md .github/copilot-instructions.md .github/workflows/docs.yml \
  .github/workflows/release.yml docs/spec.md docs/legal.md docs/roadmap.md docs/website.md docs/process.md docs/${MS}s .claude .codex \
  scripts/website-changelog.py scripts/test_website_changelog.py; do
  [[ ! -e "$path" ]] && pass "absent: $path" || fail "absent: $path"
done
[[ "$(cat CLAUDE.md)" == "@AGENTS.md" ]] && pass "CLAUDE.md is @AGENTS.md" || fail "CLAUDE.md is @AGENTS.md"
grep -q "project: Probe.xcodeproj\|Probe.xcodeproj" .github/workflows/ci.yml && grep -q "Probe ProbeCore ProbeTests" .github/workflows/ci.yml \
  && pass "ci.yml names the product" || fail "ci.yml names the product"
if grep -rIn --exclude-dir=.git -E "$BANNED" . | grep -q .; then
  fail "no banned process word"; grep -rIn --exclude-dir=.git -E "$BANNED" . | head
else pass "no banned process word"; fi
build_checks

# ---------------- --license mit without a remote: CODEOWNERS placeholder, explicit --owner ----------------
echo "== --license mit, no remote / --owner"
COPY="$TMP/mit-noremote"; new_copy "$COPY"; cd "$COPY"
scripts/init.sh --no-generate "$NAME" "$DOMAIN" > "$TMP/init2.log" 2>&1 && pass "init.sh succeeds without a remote" || { fail "init.sh succeeds without a remote"; cat "$TMP/init2.log"; }
[[ "$(cat .github/CODEOWNERS)" == "* @<owner>" ]] && pass "CODEOWNERS gets the placeholder" || fail "CODEOWNERS gets the placeholder"
grep -q "could not infer the GitHub owner" "$TMP/init2.log" && pass "the placeholder is reported" || fail "the placeholder is reported"
COPY="$TMP/mit-owner"; new_copy "$COPY"; cd "$COPY"
scripts/init.sh --no-generate --license mit --owner octo "$NAME" "$DOMAIN" > "$TMP/init3.log" 2>&1 && pass "init.sh --owner succeeds" || { fail "init.sh --owner succeeds"; cat "$TMP/init3.log"; }
[[ "$(cat .github/CODEOWNERS)" == "* @octo" ]] && grep -q "https://github.com/octo/probe" Config/release.conf \
  && pass "--owner drives CODEOWNERS and URLs" || fail "--owner drives CODEOWNERS and URLs"

# ---------------- --license proprietary ----------------
echo "== --license proprietary"
COPY="$TMP/proprietary"; new_copy "$COPY"; cd "$COPY"
if scripts/init.sh --license proprietary "$NAME" "$DOMAIN" > "$TMP/init4.log" 2>&1; then pass "init.sh succeeds"; else fail "init.sh succeeds"; cat "$TMP/init4.log"; fi
grep -q "^warning:" "$TMP/init4.log" && { fail "init.sh reports no leftovers"; grep "^warning:" "$TMP/init4.log"; } || pass "init.sh reports no leftovers"
common_assertions ydongy
head -1 LICENSE | grep -q "^Terms of Service" && pass "LICENSE is the proprietary terms" || fail "LICENSE is the proprietary terms"
[[ "$(cat .repo-type)" == "app" ]] && pass ".repo-type is app" || fail ".repo-type is app"
for path in docs/spec.md docs/legal.md docs/roadmap.md docs/website.md docs/process.md docs/${MS}s/v1.0.md .${DC}.json \
  .github/workflows/docs.yml .github/workflows/release.yml GEMINI.md SECURITY.md CHANGELOG.zh.md .github/copilot-instructions.md .claude/settings.json .codex/config.toml; do
  [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
done
for path in CONTRIBUTING.md .github/CODEOWNERS .github/workflows/pr-title.yml; do
  [[ ! -e "$path" ]] && pass "absent: $path" || fail "absent: $path"
done
for path in scripts/website-changelog.py scripts/test_website_changelog.py; do
  [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
done
grep -q "sparkle-account: probe" .github/workflows/release.yml && grep -q "project: Probe.xcodeproj" .github/workflows/ci.yml \
  && grep -q "lint-paths: Probe ProbeCore ProbeTests" .github/workflows/ci.yml && pass "workflows name the product" || fail "workflows name the product"
grep -q "uses: ydongy/.*/${DC}.yml" .github/workflows/docs.yml && pass "docs.yml calls the shared docs check" || fail "docs.yml calls the shared docs check"
grep -q '"pending": \[\]' .${DC}.json && pass ".${DC}.json is written" || fail ".${DC}.json"
if [[ $FULL -eq 1 ]]; then
  build_checks
else
  git add -A
  check "xcodegen output is stable" bash -c 'xcodegen generate --quiet && git diff --exit-code -- "*.xcodeproj"'
  check "swift-format lint --strict" xcrun swift-format lint --strict --recursive Probe ProbeCore ProbeTests
fi
CHECK_DOCS="${CHECK_DOCS:-$SRC/../.github/scripts/check-docs.py}"
if [[ -f "$CHECK_DOCS" ]]; then
  check "docs check as type app" python3 "$CHECK_DOCS" "$COPY"
else
  echo "skip docs check (no check-docs.py; set CHECK_DOCS)"
fi

exit $FAILED
