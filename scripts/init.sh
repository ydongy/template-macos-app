#!/bin/bash
# Turn this template into a new product. Run once, right after "Use this template".
#
#   scripts/init.sh <Name> <domain> [--license mit|proprietary] [--owner <github-user>]
#                   [--repo <repository-name>] [--no-generate]
#
#   <Name>    the product name in PascalCase (letters and digits, starts with a capital): ModuleName,
#             target, scheme and the user-visible name. Example: Acme
#   <domain>  the product domain, lowercase. The bundle id becomes com.<domain-reversed>.app (the tests
#             get .tests), the website https://<domain>, the downloads https://dl.<domain>,
#             support@<domain>. Example: acme.com
#   --license mit (default): an open-source project (MIT LICENSE, README, CONTRIBUTING, AGENTS.md, CHANGELOG,
#             self-contained CI, PR-title check, Dependabot, CODEOWNERS).
#             proprietary: the closed-source product skeleton (terms of service as LICENSE, specification,
#             legal, roadmap, website, process and release-plan documents, the repository-type marker and
#             documents-check config, workflows calling ydongy's shared CI, documents-check and release workflows).
#   --owner   GitHub user or organisation for CODEOWNERS and URLs (default: inferred from the git remote
#             "origin"; when it cannot be inferred CODEOWNERS gets the placeholder "* @<owner>")
#   --repo    GitHub repository name (default: the lowercase product name)
#   --no-generate  do not run xcodegen at the end
#
# What it does: copies the skeleton files of the chosen license from .template/ over the tree, renames
# directories and files (Template* -> <Name>*), rewrites every text file (names, bundle id, URLs, Sparkle feed,
# keychain prefix and Sparkle account in Config/release.conf, docs), regenerates the Xcode project, and deletes
# itself, scripts/test-init.sh and .template/. Nothing is committed.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '==> %s\n' "$*"; }

NAME="" DOMAIN="" REPO="" GENERATE=1 LICENSE_KIND="mit" OWNER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; [[ -n "$REPO" ]] || die "--repo needs a name"; shift 2 ;;
    --license) LICENSE_KIND="${2:-}"; shift 2 || die "--license needs mit or proprietary" ;;
    --owner) OWNER="${2:-}"; [[ -n "$OWNER" ]] || die "--owner needs a GitHub user or organisation"; shift 2 ;;
    --no-generate) GENERATE=0; shift ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$1"
      elif [[ -z "$DOMAIN" ]]; then DOMAIN="$1"
      else die "unexpected argument: $1"; fi
      shift ;;
  esac
done
[[ -n "$NAME" && -n "$DOMAIN" ]] || die "usage: scripts/init.sh <Name> <domain> [--license mit|proprietary] [--owner <github-user>] [--repo <repository-name>] [--no-generate]"
[[ "$LICENSE_KIND" == "mit" || "$LICENSE_KIND" == "proprietary" ]] || die "--license must be mit or proprietary, got '$LICENSE_KIND'"

[[ "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]] || die "<Name> must be PascalCase letters and digits starting with a capital, got '$NAME'"
[[ "$NAME" != "Template" ]] || die "<Name> must not be 'Template'"
[[ "$DOMAIN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] \
  || die "<domain> must be a lowercase domain such as acme.com, got '$DOMAIN'"
[[ "$DOMAIN" != "example.com" ]] || die "<domain> must not be example.com"

LOWER="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"
REPO="${REPO:-$LOWER}"
[[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid repository name: $REPO"
REVERSED="$(printf '%s' "$DOMAIN" | awk -F. '{ for (i = NF; i >= 1; i--) printf "%s%s", $i, (i > 1 ? "." : "") }')"
BUNDLE_ID="$REVERSED.app"

[[ -d .template/oss && -d .template/product ]] || die "this repository is not an uninitialised template (.template/oss or .template/product is missing)"
[[ -f project.yml && -d Template && -d TemplateCore ]] || die "the template files are not where init.sh expects them"
[[ ! -e "$NAME" ]] || die "$NAME already exists"

# The GitHub owner: --owner, else the "origin" remote, else unknown (CODEOWNERS gets a placeholder).
OWNER_KNOWN=1
if [[ -z "$OWNER" ]]; then
  remote="$(git remote get-url origin 2> /dev/null || true)"
  OWNER="$(printf '%s' "$remote" | sed -nE 's#^(https://([^/@]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/[^/]+$#\3#p')"
fi
[[ -n "$OWNER" ]] || { OWNER_KNOWN=0; OWNER="ydongy"; }
[[ "$OWNER" =~ ^[A-Za-z0-9-]+$ ]] || die "invalid owner: $OWNER"

log "Initialising $NAME ($DOMAIN, bundle id $BUNDLE_ID, repository $OWNER/$REPO, license $LICENSE_KIND)"

# 0. The skeleton files of the chosen license go over the tree first, so that steps 1 and 2 treat them like
#    every other file. A proprietary product has no use for the open-source contribution machinery.
if [[ "$LICENSE_KIND" == "proprietary" ]]; then
  cp -R .template/product/. .
  rm -f CONTRIBUTING.md .github/workflows/pr-title.yml .github/CODEOWNERS
else
  cp -R .template/oss/. .
  if [[ $OWNER_KNOWN -eq 1 ]]; then printf '* @%s\n' "$OWNER" > .github/CODEOWNERS
  else printf '* @<owner>\n' > .github/CODEOWNERS; fi
fi
rm -rf .template

# 1. File and directory names (deepest first, so parents are renamed after their children).
find . -depth \( -name '*Template*' -o -name '*templatecore*' \) \
  -not -path './.git/*' -not -path '*/.build/*' -not -path './build/*' -not -path '*/DerivedData/*' \
  | while IFS= read -r path; do
    dir="$(dirname "$path")"; base="$(basename "$path")"
    new="${base//Template/$NAME}"; new="${new//templatecore/${LOWER}core}"
    mv "$path" "$dir/$new"
  done

# 2. Text files: names, bundle id, URLs, release settings, docs.
export NAME LOWER DOMAIN REPO BUNDLE_ID REVERSED OWNER
python3 - <<'PY'
import os, re, subprocess, sys

name, lower, domain = os.environ["NAME"], os.environ["LOWER"], os.environ["DOMAIN"]
repo, bundle, reversed_domain = os.environ["REPO"], os.environ["BUNDLE_ID"], os.environ["REVERSED"]
owner = os.environ["OWNER"]

# Order matters: the specific tokens first, the bare product name last.
rules = [
    ("com.example.template", bundle),
    ("bundleIdPrefix: com.example", f"bundleIdPrefix: {reversed_domain}"),
    ("https://github.com/ydongy/template", f"https://github.com/{owner}/{repo}"),
    ('KEYCHAIN_PREFIX="template"', f'KEYCHAIN_PREFIX="{lower}"'),
    ('SPARKLE_ACCOUNT="template"', f'SPARKLE_ACCOUNT="{lower}"'),
    ("sparkle-account: template", f"sparkle-account: {lower}"),
    ("template-release", f"{lower}-release"),
    ("template-downloads", f"{lower}-downloads"),
    ("templatecore", f"{lower}core"),
    ("example.com", domain),
    ("Template", name),
]
# The ADR index template has an H2 literally named "Template" (the heading of the record template):
# it is a heading name, not the product, and the docs check compares it.
KEEP = "\0KEEP-H2\0"


def apply(text):
    text = text.replace("\n## Template\n", "\n" + KEEP + "\n")
    for old, repl in rules:
        text = text.replace(old, repl)
    return text.replace(KEEP, "## Template")


skip_names = {"init.sh", "test-init.sh"}
skip_dirs = (".git/", ".template/", "build/", ".build/", "DerivedData/")

files = subprocess.run(
    ["find", ".", "-type", "f", "-not", "-path", "./.git/*", "-not", "-path", "./.template/*",
     "-not", "-path", "./build/*", "-not", "-path", "*/.build/*", "-not", "-path", "*/DerivedData/*"],
    capture_output=True, text=True, check=True).stdout.split("\n")
changed = 0
for path in files:
    path = path.removeprefix("./")
    if not path or os.path.basename(path) in skip_names or path.endswith(".pbxproj"):
        continue
    try:
        text = open(path, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue  # binary
    new = apply(text)
    if new != text:
        open(path, "w", encoding="utf-8").write(new)
        changed += 1
print(f"rewrote {changed} files")
PY

# 3. Remove the template-only scripts (this one last).
rm -f scripts/test-init.sh

# 4. Longer or shorter names change import order and line lengths: format the sources, then regenerate.
if xcrun --find swift-format > /dev/null 2>&1; then
  log "swift-format"
  xcrun swift-format format -i --recursive "$NAME" "${NAME}Core" "${NAME}Tests"
else
  printf 'warning: swift-format not found; run: xcrun swift-format format -i --recursive %s %sCore %sTests\n' "$NAME" "$NAME" "$NAME" >&2
fi
if [[ $GENERATE -eq 1 ]]; then
  command -v xcodegen > /dev/null || die "xcodegen is not installed (brew install xcodegen); run it yourself, then: xcodegen generate"
  log "xcodegen generate"
  xcodegen generate --quiet
fi

# 5. Anything that still says Template is a mistake, except the template markers.
leftover="$(grep -rIn --exclude-dir=.git --exclude-dir=build --exclude-dir=.build --exclude=init.sh \
  -e 'Template' -e 'example\.com' . | grep -v -e 'template: ' -e '(template: app/LICENSE' -e ':## Template$' || true)"
[[ $OWNER_KNOWN -eq 1 || "$LICENSE_KIND" == "proprietary" ]] || printf 'warning: could not infer the GitHub owner; .github/CODEOWNERS contains the placeholder "* @<owner>". Fix it (or rerun with --owner).\n' >&2
if [[ -n "$leftover" ]]; then
  printf 'warning: these lines still mention the template name or example.com:\n%s\n' "$leftover" >&2
fi

log "Done. Next:"
if [[ "$LICENSE_KIND" == "proprietary" ]]; then
cat <<EOF
  1. Edit docs/spec.md, docs/design.md and design/ for the real product; replace the Example screen.
  2. Sparkle: generate_keys --account $LOWER, put the public key in SPARKLE_PUBLIC_KEY (project.yml),
     then xcodegen generate.
  3. scripts/release-credentials.sh set   (signing, notarization, R2 settings in your login keychain)
  4. Review "git status" and commit the list of files you checked (no blind staging).
EOF
else
cat <<EOF
  1. Check LICENSE (copyright holder) and .github/CODEOWNERS; replace the Example screen and README text.
  2. Sparkle: generate_keys --account $LOWER, put the public key in SPARKLE_PUBLIC_KEY (project.yml),
     then xcodegen generate.
  3. Review "git status" and commit the list of files you checked (no blind staging).
EOF
fi
rm -f -- scripts/init.sh
