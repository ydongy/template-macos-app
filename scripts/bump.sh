#!/bin/bash
# Set the next version. The only supported way to edit Config/Version.xcconfig.
#
#   scripts/bump.sh <X.Y.Z> [--date YYYY-MM-DD]
#
# Sets MARKETING_VERSION, raises CURRENT_PROJECT_VERSION by one, turns the "Unreleased" section of
# CHANGELOG.md (and CHANGELOG.zh.md when present) into the new version's section with the date,
# adds the compare links at the bottom when the file has none, and prints the commands to tag the
# release. Nothing is committed or tagged here.
#
# The first release (no tag v1.0.0 or later exists yet; earlier v0.x tags do not count) keeps the
# version and build number the project already carries: 1.0.0 and build 1.
# Product values (APP_NAME, REPO_URL) come from Config/release.conf.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

XCCONFIG=Config/Version.xcconfig
CONF="${RELEASE_CONF:-Config/release.conf}"
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f "$CONF" ]] || die "$CONF not found"
APP_NAME="$(source "$CONF" && printf '%s' "${APP_NAME:-}")"
REPO_URL="$(source "$CONF" && printf '%s' "${REPO_URL:-}")"
[[ -n "$APP_NAME" && -n "$REPO_URL" ]] || die "APP_NAME and REPO_URL must be set in $CONF"

VERSION="${1:-}"; DATE="$(date +%F)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: scripts/bump.sh <X.Y.Z> [--date YYYY-MM-DD]"
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date) DATE="${2:-}"; [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "--date needs YYYY-MM-DD"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

current="$(awk -F' = ' '/^MARKETING_VERSION =/ { print $2 }' "$XCCONFIG")"
build="$(awk -F' = ' '/^CURRENT_PROJECT_VERSION =/ { print $2 }' "$XCCONFIG")"
[[ -n "$current" && "$build" =~ ^[0-9]+$ ]] || die "cannot parse $XCCONFIG"

# The first release keeps the version the project already carries (or moves it forward); later ones
# must be newer. Tags below 1.0.0 are internal and do not count.
first_release=0
if ! git tag -l 'v[1-9]*.*.*' | grep -q .; then first_release=1; fi
if [[ $first_release -eq 1 ]]; then
  [[ "$VERSION" == "$current" ]] || printf '%s\n%s\n' "$current" "$VERSION" | sort -V -c 2> /dev/null \
    || die "$VERSION is older than $current"
else
  [[ "$VERSION" != "$current" ]] || die "already at $VERSION"
  printf '%s\n%s\n' "$current" "$VERSION" | sort -V -c 2> /dev/null || die "$VERSION is not newer than $current"
fi
git tag -l "v$VERSION" | grep -q . && die "tag v$VERSION already exists"
changelogs=(CHANGELOG.md)
[[ -f CHANGELOG.zh.md ]] && changelogs+=(CHANGELOG.zh.md)
for changelog in "${changelogs[@]}"; do
  [[ -f "$changelog" ]] || die "$changelog not found"
  grep -q '^## \[Unreleased\]' "$changelog" || die "$changelog has no '## [Unreleased]' section"
done

# Build number: raised by one, except that the first release keeps the number the project starts with.
next=$((build + 1))
if [[ $first_release -eq 1 && "$build" -eq 1 ]]; then next=1; fi
sed -i '' -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" \
          -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $next/" "$XCCONFIG"

# Keep a Changelog: "## [Unreleased]" stays on top; its content becomes the new version's section.
for changelog in "${changelogs[@]}"; do
  python3 - "$changelog" "$VERSION" "$DATE" "$REPO_URL" <<'PY'
import re, sys
path, version, date, base = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text = text.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## [{version}] - {date}\n", 1)
# Compare links at the bottom: update them when the file has them, add them when it has none yet.
m = re.search(r"^\[Unreleased\]: (https://\S+?)/compare/(\S+?)\.\.\.HEAD$", text, re.M)
if m:
    base, prev = m.group(1), m.group(2)
    text = text.replace(m.group(0), f"[Unreleased]: {base}/compare/v{version}...HEAD\n[{version}]: {base}/compare/{prev}...v{version}", 1)
elif not re.search(r"^\[Unreleased\]: ", text, re.M):
    text = text.rstrip("\n") + f"\n\n[Unreleased]: {base}/compare/v{version}...HEAD\n[{version}]: {base}/releases/tag/v{version}\n"
open(path, "w", encoding="utf-8").write(text)
PY
  echo "updated $changelog"
done

echo "version $current ($build) -> $VERSION ($next)"
echo "next: review the diff, commit as 'build(release): version $VERSION', merge, then:"
echo "  git tag -a v$VERSION -m '$APP_NAME $VERSION' && git push origin v$VERSION"
