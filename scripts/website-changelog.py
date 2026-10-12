#!/usr/bin/env python3
"""Prepare the public changelog entry for a release on the website.

    scripts/website-changelog.py --version 1.0.0 --website-dir ~/src/<website repo> [--date 2026-10-02] [--open-pr]

What it does
  1. Reads the section "## [X.Y.Z] - date" (Keep a Changelog) for the version from CHANGELOG.md (English)
     and CHANGELOG.zh.md (Chinese). The bullets of all its subsections (### Added, ### Fixed, ...) are
     the entry's items; the date comes from the heading unless --date is given.
  2. Checks that both are complete and that the text is safe to publish (see LINT below).
  3. Dry run (default): prints the entry and changes nothing.
     With --open-pr: adds the entry to changelog.json in the website repo, regenerates the pages
     and feeds with the repo's own scripts/build.py, and opens a PULL REQUEST.
     It never pushes to main and never merges: the text is public, so a person reads the diff first.

LINT (the text is public, so it is checked and the script refuses on any hit)
  issue / PR references (#123), commit hashes, repository names, local paths, e-mail addresses,
  URLs outside the product domains, token-like strings, internal or tooling words (Claude, AI agent,
  TODO, WIP, ...), security wording (vulnerability, CVE, exploit: write those by hand, with care),
  and bullets longer than 220 characters.
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import date as _date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def product_domain():
    """PRODUCT_DOMAIN from Config/release.conf (the same file bash sources)."""
    for line in (ROOT / "Config" / "release.conf").read_text(encoding="utf-8").splitlines():
        m = re.match(r'^PRODUCT_DOMAIN="([^"]+)"\s*$', line)
        if m:
            return m.group(1)
    raise SystemExit("error: PRODUCT_DOMAIN is not set in Config/release.conf")


DOMAIN = product_domain()
ALLOWED_HOSTS = (DOMAIN, "www." + DOMAIN, "dl." + DOMAIN)
MAX_ITEM = 220

LINT = [
    (r"#\d+\b", "issue or PR reference"),
    (r"\b[0-9a-f]{7,40}\b", "commit hash or long hex string"),
    (r"ydongy/", "repository name"),
    (r"(?:^|[\s(`])(?:/Users/|/private/|~/|/Library/)", "local file path"),
    (r"[\w.+-]+@[\w-]+\.[\w.-]+", "e-mail address"),
    (r"\b[A-Za-z0-9_\-+/]{32,}={0,2}", "token-like string"),
    (r"(?i)\b(claude|anthropic|chatgpt|openai|llm|ai agent|copilot)\b", "tooling or AI wording"),
    (r"(?i)\b(todo|fixme|wip|hack|workaround|internal(?:ly)?|dogfood|debug)\b", "internal wording"),
    (r"(?i)\b(vulnerab\w*|cve-\d+|exploit\w*|security (?:fix|issue|hole))|漏洞", "security wording"),
    (r"(?i)\b(private repo|source code)\b", "internal wording"),
]


HEADING = r"^## \[{v}\](?:[ ]+[-\u2013\u2014][ ]+(\d{{4}}-\d{{2}}-\d{{2}}))?[ ]*$"


def section(path, version):
    """Returns (date, summary, items) of the section for `version`; `version` may be 'Unreleased'."""
    text = Path(path).read_text(encoding="utf-8")
    m = re.search(HEADING.format(v=re.escape(version)), text, re.M)
    if not m:
        raise SystemExit(f"error: no '## [{version}]' section in {Path(path).name}")
    body = text[m.end():].split("\n## ", 1)[0]
    items, summary = [], []
    for line in body.splitlines():
        if re.match(r"^\[[^\]]+\]: ", line) or line.startswith("#"):
            continue  # link definitions, subsection headings
        if line.startswith("- "):
            items.append(line[2:].strip())
        elif line.startswith((" ", "\t")) and items and line.strip():
            items[-1] += " " + line.strip()  # a wrapped bullet
        elif line.strip():
            summary.append(line.strip())
    return m.group(1), " ".join(summary), items


def lint(label, text):
    problems = []
    for pattern, what in LINT:
        for m in re.finditer(pattern, text):
            problems.append(f"{label}: {what}: '{m.group(0).strip()}' in: {text[:80]}")
    for url in re.findall(r"https?://([^/\s)>\]]+)", text):
        if url.lower() not in ALLOWED_HOSTS:
            problems.append(f"{label}: URL outside the product domains: {url}")
    return problems


def build_entry(version, date=None):
    d_en, s_en, i_en = section(ROOT / "CHANGELOG.md", version)
    d_zh, s_zh, i_zh = section(ROOT / "CHANGELOG.zh.md", version)
    date = date or d_en or _date.today().isoformat()
    errors = []
    if d_en and d_zh and d_en != d_zh:
        errors.append(f"the sections have different dates: {d_en} and {d_zh}")
    if not i_en:
        errors.append("the English section has no bullets")
    if len(i_en) != len(i_zh):
        errors.append(f"English has {len(i_en)} bullets, Chinese has {len(i_zh)}: keep them in step")
    if bool(s_en) != bool(s_zh):
        errors.append("only one language has an intro paragraph")
    for lang, summary, items in (("en", s_en, i_en), ("zh", s_zh, i_zh)):
        for n, text in enumerate([summary] + items):
            if not text:
                continue
            errors += lint(f"{lang}", text)
            if n >= 1 and len(text) > MAX_ITEM:
                errors.append(f"{lang}: bullet longer than {MAX_ITEM} characters: {text[:60]}...")
    # The website shows a title when an entry has one; the changelog format has none.
    entry = {"version": version, "date": date, "title": {"en": "", "zh": ""}}
    if s_en:
        entry["summary"] = {"en": s_en, "zh": s_zh}
    entry["items"] = {"en": i_en, "zh": i_zh}
    return entry, errors


def insert(entries, entry):
    """Returns (new_entries, changed). Same version: identical is a no-op, different is an error."""
    for i, old in enumerate(entries):
        if old["version"] == entry["version"]:
            same = {k: v for k, v in old.items() if k != "date"} == {k: v for k, v in entry.items() if k != "date"}
            if same:
                return entries, False
            raise SystemExit(
                f"error: version {entry['version']} is already in changelog.json with different text; "
                "published entries are not rewritten by this script, edit the website repo by hand")
    return [entry] + entries, True


def run(*cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True).stdout.strip()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", required=True)
    ap.add_argument("--date", help="default: the date in the CHANGELOG heading")
    ap.add_argument("--website-dir", required=True, help="local clone of the website repo")
    ap.add_argument("--open-pr", action="store_true", help="write the change on a branch and open a pull request")
    a = ap.parse_args(argv)
    if not re.fullmatch(r"\d+\.\d+\.\d+", a.version):
        raise SystemExit("error: --version must be X.Y.Z (run scripts/bump.sh first)")
    if a.date and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", a.date):
        raise SystemExit("error: --date must be YYYY-MM-DD")

    entry, errors = build_entry(a.version, a.date)
    if errors:
        print("Refusing to prepare a public changelog entry:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    site = Path(a.website_dir).expanduser()
    path = site / "changelog.json"
    if not path.is_file():
        raise SystemExit(f"error: {path} not found (is --website-dir a clone of the website repo?)")
    entries, changed = insert(json.loads(path.read_text(encoding="utf-8")), entry)
    print(json.dumps(entry, ensure_ascii=False, indent=2))
    if not changed:
        print("\nAlready in changelog.json with the same text: nothing to do.")
        return 0
    if not a.open_pr:
        print("\nDry run: nothing written. Check the text above, then add --open-pr.")
        return 0

    if run("git", "status", "--porcelain", cwd=site):
        raise SystemExit("error: the website clone has uncommitted changes; clean it first")
    branch = f"changelog-{a.version}"
    run("git", "checkout", "-B", branch, "origin/main", cwd=site)
    path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    run(sys.executable, "scripts/build.py", cwd=site)
    run("git", "add", "-A", cwd=site)
    run("git", "commit", "-m", f"changelog: {a.version}", cwd=site)
    run("git", "-c", "credential.helper=", "-c", "credential.helper=!env -u GH_TOKEN gh auth git-credential",
        "push", "-u", "origin", branch, cwd=site)
    body = ("Public text: read it before merging. It was generated from CHANGELOG.md / CHANGELOG.zh.md "
            "of the app repo and passed the public-safety lint.\n\n" + "\n".join(f"- {i}" for i in entry["items"]["en"]))
    url = run("gh", "pr", "create", "--title", f"changelog: {a.version}", "--body", body, "--base", "main", cwd=site)
    print(f"\nPull request: {url}\nNothing is public until you merge it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
