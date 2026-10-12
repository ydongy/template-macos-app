#!/bin/bash
# Turn this template into a new product. Run once, right after "Use this template".
#
#   scripts/init.sh <Name> <domain> [--repo <repository-name>] [--no-generate]
#
#   <Name>    the product name in PascalCase (letters and digits, starts with a capital): ModuleName,
#             target, scheme and the user-visible name. Example: Acme
#   <domain>  the product domain, lowercase. The bundle id becomes com.<domain-reversed>.app (the tests
#             get .tests), the website https://<domain>, the downloads https://dl.<domain>,
#             support@<domain>. Example: acme.com
#   --repo    GitHub repository name under ydongy (default: the lowercase product name)
#   --no-generate  do not run xcodegen at the end
#
# What it does: renames directories and files (Template* -> <Name>*), rewrites every text file
# (names, bundle id, URLs, Sparkle feed, keychain prefix and Sparkle account in Config/release.conf,
# docs), switches .repo-type from template to app, replaces README.md, AGENTS.md and LICENSE (the
# product's terms of service, instead of this repository's MIT license) with the versions from .template/,
# writes an empty .docs-check.json, regenerates the Xcode project, and deletes itself, scripts/test-init.sh and .template/. Nothing is committed.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '==> %s\n' "$*"; }

NAME="" DOMAIN="" REPO="" GENERATE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; [[ -n "$REPO" ]] || die "--repo needs a name"; shift 2 ;;
    --no-generate) GENERATE=0; shift ;;
    -h | --help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$1"
      elif [[ -z "$DOMAIN" ]]; then DOMAIN="$1"
      else die "unexpected argument: $1"; fi
      shift ;;
  esac
done
[[ -n "$NAME" && -n "$DOMAIN" ]] || die "usage: scripts/init.sh <Name> <domain> [--repo <repository-name>] [--no-generate]"

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

[[ -f .repo-type && "$(cat .repo-type)" == "template" ]] || die "this repository is not an uninitialised template (.repo-type is not 'template')"
[[ -d .template && -f project.yml && -d Template && -d TemplateCore ]] || die "the template files are not where init.sh expects them"
[[ ! -e "$NAME" ]] || die "$NAME already exists"

log "Initialising $NAME ($DOMAIN, bundle id $BUNDLE_ID, repository ydongy/$REPO)"

# 1. File and directory names (deepest first, so parents are renamed after their children).
find . -depth \( -name '*Template*' -o -name '*templatecore*' \) \
  -not -path './.git/*' -not -path '*/.build/*' -not -path './build/*' -not -path '*/DerivedData/*' \
  | while IFS= read -r path; do
    dir="$(dirname "$path")"; base="$(basename "$path")"
    new="${base//Template/$NAME}"; new="${new//templatecore/${LOWER}core}"
    mv "$path" "$dir/$new"
  done

# 2. Text files: names, bundle id, URLs, release settings, docs.
export NAME LOWER DOMAIN REPO BUNDLE_ID REVERSED
python3 - <<'PY'
import os, re, subprocess, sys

name, lower, domain = os.environ["NAME"], os.environ["LOWER"], os.environ["DOMAIN"]
repo, bundle, reversed_domain = os.environ["REPO"], os.environ["BUNDLE_ID"], os.environ["REVERSED"]

# Order matters: the specific tokens first, the bare product name last.
rules = [
    ("com.example.template", bundle),
    ("bundleIdPrefix: com.example", f"bundleIdPrefix: {reversed_domain}"),
    ("https://github.com/ydongy/template", f"https://github.com/ydongy/{repo}"),
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

# 3. The product versions of README.md, AGENTS.md and LICENSE (terms of service); the type switches to app.
for f in README.md AGENTS.md LICENSE; do
  [[ -f ".template/$f" ]] || die ".template/$f is missing"
done
python3 - <<'PY'
import os
name, lower, domain = os.environ["NAME"], os.environ["LOWER"], os.environ["DOMAIN"]
repo, bundle, reversed_domain = os.environ["REPO"], os.environ["BUNDLE_ID"], os.environ["REVERSED"]
rules = [
    ("com.example.template", bundle),
    ("https://github.com/ydongy/template", f"https://github.com/ydongy/{repo}"),
    ("templatecore", f"{lower}core"),
    ("example.com", domain),
    ("Template", name),
]
for f in ("README.md", "AGENTS.md", "LICENSE"):
    text = open(f".template/{f}", encoding="utf-8").read()
    for old, repl in rules:
        text = text.replace(old, repl)
    open(f, "w", encoding="utf-8").write(text)
PY
rm -rf .template
printf 'app\n' > .repo-type
cat > .docs-check.json <<'JSON'
{
  "ignore": [],
  "pending": []
}
JSON

# 4. Remove the template-only scripts (this one last).
rm -f scripts/test-init.sh

# 5. Longer or shorter names change import order and line lengths: format the sources, then regenerate.
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

# 6. Anything that still says Template is a mistake, except the template markers.
leftover="$(grep -rIn --exclude-dir=.git --exclude-dir=build --exclude-dir=.build --exclude=init.sh \
  -e 'Template' -e 'example\.com' . | grep -v -e 'template: ' -e '(template: app/LICENSE' -e ':## Template$' || true)"
if [[ -n "$leftover" ]]; then
  printf 'warning: these lines still mention the template name or example.com:\n%s\n' "$leftover" >&2
fi

log "Done. Next:"
cat <<EOF
  1. Edit docs/spec.md, docs/design.md and design/ for the real product; replace the Example screen.
  2. Sparkle: generate_keys --account $LOWER, put the public key in SPARKLE_PUBLIC_KEY (project.yml),
     then xcodegen generate.
  3. scripts/release-credentials.sh set   (signing, notarization, R2 settings in your login keychain)
  4. Review "git status" and commit the list of files you checked (no blind staging).
EOF
rm -f -- scripts/init.sh
