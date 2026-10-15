#!/bin/bash
# Tests scripts/init.sh on throw-away COPIES of this repository, once per license: renames each to a probe
# product, checks the generated files, and for the mit copy also lints, builds and tests the result. The
# proprietary copy gets the file-level assertions and the xcodegen/lint checks only; --full builds it too.
#
#   scripts/test-init.sh [--keep] [--full]
#
#   --keep  do not delete the copies (their path is printed)
#   --full  build and test the proprietary copy as well (slower)
set -uo pipefail
cd "$(dirname "$0")/.."
SRC="$PWD"

NAME=Probe DOMAIN=probe.test
# Words that must not survive in any generated project (spelled in parts so that this file passes its own check).
DC="docs-""check" HB="hand""book" MS="mile""stone" GH="ydongy/\\.""github"
OR="ORG_DOCS""_ROOT" TM="template"": "
BANNED="$HB|$DC|$OR|$GH|$TM"
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
common_assertions() { # common_assertions <owner> <license>
  for path in Probe/App/ProbeApp.swift Probe/UI/Example/ExampleView.swift Probe/Resources/Localizable.xcstrings \
    ProbeCore/Package.swift ProbeCore/Sources/ProbeCore/Design/DesignTokens.swift ProbeTests/LocalizationCatalogTests.swift \
    Probe.xcodeproj/project.pbxproj Config/Probe-Info.plist README.md README.zh-CN.md AGENTS.md CLAUDE.md LICENSE CHANGELOG.md THIRD_PARTY.md \
    docs/design.md docs/adr/README.md design/screens/example.html .github/workflows/ci.yml .github/dependabot.yml \
    CONTRIBUTING.md .github/CODEOWNERS .github/workflows/pr-title.yml .editorconfig; do
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
    | grep -v -e '^./Probe.xcodeproj' -e ':## Template$' || true)"
  if [[ -z "$stale" ]]; then pass "no file mentions Template or example.com"; else fail "no file mentions Template or example.com"; echo "$stale" | head; fi
  if grep -rIiE --exclude-dir=.git -e 'template-macos-app' . | grep -q .; then fail "no mention of the template repository"; else pass "no mention of the template repository"; fi
  if grep -rIniE --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData -e "$BANNED" . | grep -q .; then
    fail "no process-system word survives"; grep -rIniE --exclude-dir=.git --exclude-dir=build --exclude-dir=DerivedData -e "$BANNED" . | head
  else pass "no process-system word survives"; fi
  for path in .${DC}.json .repo-type GEMINI.md SECURITY.md .github/copilot-instructions.md .github/workflows/docs.yml docs/pro""cess.md docs/${MS}s; do
    [[ ! -e "$path" ]] && pass "absent: $path" || fail "absent: $path"
  done
  readme_assertions "$1" "$2"
  grep -q "test-init" CONTRIBUTING.md && fail "CONTRIBUTING.md names no template-only script" || pass "CONTRIBUTING.md names no template-only script"
  grep -q "^## Issues and pull requests" AGENTS.md && grep -q "## Version and environment" AGENTS.md && grep -q "## How tested" AGENTS.md \
    && pass "AGENTS.md spells out the issue forms and the pull request body" || fail "AGENTS.md spells out the issue forms and the pull request body"
  grep -qF 'no blind `git add -A`' AGENTS.md || grep -qF 'No blind `git add -A`' AGENTS.md \
    && pass "AGENTS.md has the staging red line" || fail "AGENTS.md has the staging red line"
  grep -q "Simplified Chinese" CONTRIBUTING.md && pass "CONTRIBUTING.md has the language rule" || fail "CONTRIBUTING.md has the language rule"
  grep -qx "design/screenshots/" .gitignore && pass "design/screenshots/ is ignored" || fail "design/screenshots/ is ignored"
  [[ "$(cat CLAUDE.md)" == "@AGENTS.md" ]] && pass "CLAUDE.md is @AGENTS.md" || fail "CLAUDE.md is @AGENTS.md"
  if grep -rqE --exclude-dir=.git "uses: ydongy/" .github; then fail "workflows are self-contained"; else pass "workflows are self-contained"; fi
  grep -q "XCODE_MAJOR" .github/workflows/ci.yml && pass "ci.yml selects Xcode by major version" || fail "ci.yml selects Xcode by major version"
}

# readme_assertions <owner> <license>: both READMEs are the generated product's, in the right language, linked to each other.
readme_assertions() {
  head -3 README.md | grep -qx '# Probe' && pass "README.md is the product's" || fail "README.md is the product's"
  head -3 README.zh-CN.md | grep -qx '# Probe' && pass "README.zh-CN.md is the product's" || fail "README.zh-CN.md is the product's"
  grep -qF '[简体中文](README.zh-CN.md)' README.md && grep -qF '[English](README.md)' README.zh-CN.md \
    && pass "READMEs link to each other" || fail "READMEs link to each other"
  grep -q '## Features' README.md && grep -q '## 功能特性' README.zh-CN.md && pass "READMEs have their sections" || fail "READMEs have their sections"
  grep -v '简体中文' README.md | grep -qE '[一-龥]' && fail "README.md is English only" || pass "README.md is English only"
  if [[ "$2" == proprietary ]]; then
    grep -q 'license-proprietary' README.md && grep -q 'license-proprietary' README.zh-CN.md \
      && ! grep -q 'actions/workflows/ci.yml/badge' README.md README.zh-CN.md && pass "proprietary badges, no CI badge" || fail "proprietary badges, no CI badge"
    local badge='![Status](https://img.shields.io/badge/status-pre--release-orange)'
    grep -qF "$badge" README.md && grep -qF "$badge" README.zh-CN.md && pass "READMEs carry the pre-release badge" || fail "READMEs carry the pre-release badge"
    grep -q '^Status: pre-release\..*\[docs/launch.md\](docs/launch.md)' README.md && grep -q '^当前状态：预发布。.*\[docs/launch.md\](docs/launch.md)' README.zh-CN.md \
      && pass "READMEs have the status sentence linking docs/launch.md" || fail "READMEs have the status sentence linking docs/launch.md"
    if grep -qE "badge/website|https://$DOMAIN|https://dl\.$DOMAIN|support@$DOMAIN" README.md README.zh-CN.md; then
      fail "pre-release READMEs name no website, download or mailbox"; grep -nE "badge/website|https://$DOMAIN|https://dl\.$DOMAIN|support@$DOMAIN" README.md README.zh-CN.md
    else pass "pre-release READMEs name no website, download or mailbox"; fi
  else
    grep -q "actions/workflows/ci.yml/badge" README.md && grep -q "actions/workflows/ci.yml/badge" README.zh-CN.md \
      && grep -q "github.com/$1/probe/" README.md && grep -q "github.com/$1/probe/" README.zh-CN.md \
      && pass "MIT README badges use owner/repo" || fail "MIT README badges use owner/repo"
  fi
  local link target
  for f in README.md README.zh-CN.md; do
    while IFS= read -r link; do
      target="${link%%#*}"; [[ -z "$target" || "$target" == http* ]] && continue
      [[ -e "$target" ]] || fail "$f: link target exists: $target"
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
  done
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

# ---------------- the launch copy of release.yml stays maintained in the template ----------------
echo "== .template/launch"
LAUNCH_WF="$SRC/.template/launch/.github/workflows/release.yml"
[[ -f "$LAUNCH_WF" ]] && pass "exists: .template/launch/.github/workflows/release.yml" || fail "exists: .template/launch/.github/workflows/release.yml"
grep -q "environment: release" "$LAUNCH_WF" && grep -q "scripts/release.sh" "$LAUNCH_WF" && ! grep -qE "uses: ydongy/|Template|example\.com" "$LAUNCH_WF" \
  && pass "launch release.yml is self-contained and names no product" || fail "launch release.yml is self-contained and names no product"
if command -v actionlint > /dev/null; then
  # Syntax, expressions and action inputs; shellcheck is off (its style notes are not errors here).
  check "actionlint: launch release.yml and the skeleton workflows" actionlint -shellcheck= "$LAUNCH_WF" \
    "$SRC/.template/product/.github/workflows/ci.yml" "$SRC"/.github/workflows/*.yml
else echo "skip actionlint (not installed)"; fi

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
common_assertions acme-inc mit
head -1 LICENSE | grep -q "^MIT License" && pass "LICENSE is MIT" || fail "LICENSE is MIT"
[[ "$(cat .github/CODEOWNERS)" == "* @acme-inc" ]] && pass "CODEOWNERS uses the owner from the remote" || fail "CODEOWNERS uses the owner from the remote"
for path in CHANGELOG.zh.md .github/workflows/release.yml docs/spec.md docs/legal.md docs/roadmap.md docs/website.md \
  docs/releasing.md docs/security .claude .codex scripts/website-changelog.py scripts/test_website_changelog.py; do
  [[ ! -e "$path" ]] && pass "absent: $path" || fail "absent: $path"
done
grep -q "project: Probe.xcodeproj\|Probe.xcodeproj" .github/workflows/ci.yml && grep -q "Probe ProbeCore ProbeTests" .github/workflows/ci.yml \
  && pass "ci.yml names the product" || fail "ci.yml names the product"
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
COPY="$TMP/proprietary"; new_copy "$COPY" "https://github.com/ydongy/probe.git"; cd "$COPY"
if scripts/init.sh --license proprietary "$NAME" "$DOMAIN" > "$TMP/init4.log" 2>&1; then pass "init.sh succeeds"; else fail "init.sh succeeds"; cat "$TMP/init4.log"; fi
grep -q "^warning:" "$TMP/init4.log" && { fail "init.sh reports no leftovers"; grep "^warning:" "$TMP/init4.log"; } || pass "init.sh reports no leftovers"
common_assertions ydongy proprietary
head -1 LICENSE | grep -qx "Copyright (c) 2026 ydongy. All rights reserved." && grep -qx "Probe Terms of Service" LICENSE \
  && pass "LICENSE is the proprietary terms" || fail "LICENSE is the proprietary terms"
grep -q "<!--" LICENSE && fail "LICENSE has no template comment" || pass "LICENSE has no template comment"
grep -q "All rights reserved" LICENSE && pass "LICENSE reserves all rights" || fail "LICENSE reserves all rights"
[[ "$(cat .github/CODEOWNERS)" == "* @ydongy" ]] && pass "CODEOWNERS is generated" || fail "CODEOWNERS is generated"
for path in docs/spec.md docs/legal.md docs/roadmap.md docs/website.md docs/releasing.md docs/launch.md docs/security/README.md CHANGELOG.zh.md \
  .claude/settings.json .codex/config.toml scripts/website-changelog.py scripts/test_website_changelog.py; do
  [[ -e "$path" ]] && pass "exists: $path" || fail "exists: $path"
done
grep -q "^## \[Unreleased\]" CHANGELOG.md && grep -q "^## \[Unreleased\]" CHANGELOG.zh.md && pass "both changelogs have [Unreleased]" || fail "both changelogs have [Unreleased]"
grep -q "Probe.xcodeproj" .github/workflows/ci.yml && grep -q "Probe ProbeCore ProbeTests" .github/workflows/ci.yml \
  && grep -q "Config/Version.xcconfig" .github/workflows/ci.yml && grep -q "workflow_dispatch" .github/workflows/ci.yml \
  && pass "ci.yml names the product and gates the macOS job" || fail "ci.yml names the product and gates the macOS job"
# Pre-release: no release workflow; docs/launch.md carries the launch steps and every place that names the domain.
[[ ! -e .github/workflows/release.yml ]] && pass "absent: .github/workflows/release.yml (pre-release)" || fail "absent: .github/workflows/release.yml (pre-release)"
launch_ok=1
for needle in '.template/launch/.github/workflows/release.yml' 'deployment branch policy' 'releasing.md#release-workflow-setup' \
  'Rehearsal' 'chore(release): launch <version>' '## After launch' 'project.yml' 'Config/release.conf' 'Probe/App/ProductLinks.swift' \
  'LICENSE' "support@$DOMAIN" "https://dl.$DOMAIN"; do
  grep -qF -- "$needle" docs/launch.md || { launch_ok=0; echo "missing in docs/launch.md: $needle"; }
done
[[ $launch_ok -eq 1 ]] && pass "docs/launch.md lists the launch steps and the domain places" || fail "docs/launch.md lists the launch steps and the domain places"
grep -q '^- \[ \] ' docs/launch.md && pass "docs/launch.md is a checklist" || fail "docs/launch.md is a checklist"
grep -qF '(launch.md)' docs/releasing.md && pass "docs/releasing.md points to docs/launch.md" || fail "docs/releasing.md points to docs/launch.md"
grep -q 'docs/launch.md' AGENTS.md && grep -q 'docs/launch.md' CONTRIBUTING.md && pass "AGENTS.md and CONTRIBUTING.md state the pre-release state" \
  || fail "AGENTS.md and CONTRIBUTING.md state the pre-release state"
if [[ $FULL -eq 1 ]]; then
  build_checks
else
  git add -A
  check "xcodegen output is stable" bash -c 'xcodegen generate --quiet && git diff --exit-code -- "*.xcodeproj"'
  check "swift-format lint --strict" xcrun swift-format lint --strict --recursive Probe ProbeCore ProbeTests
fi
exit $FAILED
