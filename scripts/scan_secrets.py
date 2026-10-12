#!/usr/bin/env python3
"""Scan the whole git history (and optionally a build artifact) for credential-like material.

    python3 scripts/scan_secrets.py                 # every added line in every commit of every ref
    python3 scripts/scan_secrets.py --path build/release/Template.app --forbid "$HOME"   # a built app

Matches are never printed in full: only commit, file, line and a redacted prefix, so the report itself
cannot leak a secret. Exit status 1 when anything is found. This is a pattern scan, not a proof that
no secret exists: a clean result is not a statement that the project is secure.

The product name and the Sparkle public key come from Config/release.conf, project.yml and Config/*-Info.plist.
"""

from __future__ import annotations

import argparse
import math
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]



def read_conf(path: Path) -> dict[str, str]:
    """KEY="value" lines of Config/release.conf (the same file bash sources)."""
    values: dict[str, str] = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r'^([A-Z_]+)="(.*)"\s*$', line)
            if m:
                values[m.group(1)] = m.group(2)
    return values


def sparkle_public_key() -> str:
    """Sparkle's *public* EdDSA key is written into Info.plist: SPARKLE_PUBLIC_KEY in project.yml, or
    SUPublicEDKey in a hand-written Config/*-Info.plist."""
    project = ROOT / "project.yml"
    if project.is_file():
        m = re.search(r'^\s*SPARKLE_PUBLIC_KEY:\s*["\']?([A-Za-z0-9+/=]+)["\']?\s*$', project.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    for plist in sorted((ROOT / "Config").glob("*-Info.plist")):
        m = re.search(r"<key>SUPublicEDKey</key>\s*<string>([A-Za-z0-9+/=]+)</string>", plist.read_text(encoding="utf-8"))
        if m:
            return m.group(1)
    return ""


CONF = read_conf(Path(os.environ.get("RELEASE_CONF") or ROOT / "Config" / "release.conf"))
APP_NAME = CONF.get("APP_NAME", "Template")

# Public values that look like keys but are not secret.
ALLOW_SUBSTRINGS = tuple(value for value in (sparkle_public_key(), "not-a-real") if value)

# Paths whose credential-like strings were reviewed by hand and are deliberate fakes: redaction test fixtures
# (their values spell out words such as "Secret" / "Token" / "abc") and mockup placeholders (repeated "x").
ALLOW_PATHS = (f"{APP_NAME}Tests/", "design/")

PATTERNS: dict[str, re.Pattern[str]] = {
    "github-token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b"),
    "gitlab-token": re.compile(r"\bglpat-[A-Za-z0-9_\-]{18,}\b"),
    "gitea-or-generic-hex-token": re.compile(r"(?i)\b(?:token|secret|password|passwd|api[_-]?key)\b\s*[:=]\s*[\"']?[0-9a-f]{40}\b"),
    "cloudflare-token": re.compile(r"\bcf(?:ut|at|k)_[A-Za-z0-9]{20,}\b"),
    "dodo-api-key": re.compile(r"\b[A-Za-z0-9]{16}\.[A-Za-z0-9_\-]{40,}\b"),
    "aws-access-key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "slack-token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    "private-key-block": re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED |PGP )?PRIVATE KEY"),
    "credential-in-url": re.compile(r"https?://[^/\s:@]+:[^/\s@]{6,}@"),
    "assigned-secret": re.compile(
        r"(?i)\b(?:secret|password|passwd|token|api[_-]?key|access[_-]?key)[A-Za-z_]*\b\s*[:=]\s*[\"']([A-Za-z0-9+/=_\-]{24,})[\"']"
    ),
    "base64-private-key-like": re.compile(r"(?i)ed25519[^\n]{0,40}[\"']([A-Za-z0-9+/]{43}=)[\"']"),
}
# Personal data worth knowing about before a repository leaves private (reported separately, lower severity).
PERSONAL = {
    "home-path": re.compile(r"/Users/(?!Shared\b|<)[A-Za-z0-9._-]+/"),
    "email": re.compile(r"\b[A-Za-z0-9._%+-]+@(?!example\.|users\.noreply\.github\.com)[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
}


def entropy(text: str) -> float:
    if not text:
        return 0.0
    counts = {c: text.count(c) for c in set(text)}
    return -sum(n / len(text) * math.log2(n / len(text)) for n in counts.values())


def redact(value: str) -> str:
    return value[:4] + "…(" + str(len(value)) + " chars)"


def scan_line(line: str) -> list[tuple[str, str]]:
    if any(allowed in line for allowed in ALLOW_SUBSTRINGS):
        return []
    hits = []
    for name, pattern in PATTERNS.items():
        match = pattern.search(line)
        if not match:
            continue
        value = match.group(1) if match.groups() else match.group(0)
        if name == "assigned-secret" and entropy(value) < 3.5:
            continue  # placeholders such as "xxxxxxxx…"
        hits.append((name, redact(value)))
    return hits


def scan_history() -> tuple[list[str], list[str]]:
    secrets: list[str] = []
    personal: dict[str, set[str]] = {}
    proc = subprocess.Popen(
        ["git", "log", "--all", "-p", "--no-color", "--format=@@@%h", "-U0", "--no-ext-diff", "--text"],
        cwd=ROOT, stdout=subprocess.PIPE, text=True, errors="replace",
    )
    commit, path, line_no = "", "", 0
    assert proc.stdout is not None
    for raw in proc.stdout:
        line = raw.rstrip("\n")
        if line.startswith("@@@"):
            commit = line[3:]
        elif line.startswith("+++ b/"):
            path = line[6:]
        elif line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            line_no = int(m.group(1)) - 1 if m else 0
        elif line.startswith("+") and not line.startswith("+++"):
            line_no += 1
            for name, shown in scan_line(line[1:]):
                if path.startswith(ALLOW_PATHS):
                    continue
                secrets.append(f"{commit} {path}:{line_no} {name} {shown}")
            for name, pattern in PERSONAL.items():
                for m in pattern.finditer(line[1:]):
                    personal.setdefault(name, set()).add(f"{path}")
    proc.wait()
    summary = [f"{name}: {len(files)} file(s): " + ", ".join(sorted(files)[:6]) + ("…" if len(files) > 6 else "")
               for name, files in sorted(personal.items())]
    return sorted(set(secrets)), summary


def printable_strings(data: bytes) -> list[str]:
    return [chunk.decode("ascii") for chunk in re.findall(rb"[\x20-\x7e]{8,}", data)]


def scan_path(target: Path, forbidden: list[str]) -> list[str]:
    """Credential-like strings and forbidden substrings (build machine paths, demo code) in an artifact."""
    findings: list[str] = []
    files = [target] if target.is_file() else [p for p in target.rglob("*") if p.is_file() and not p.is_symlink()]
    for file in files:
        name = str(file.relative_to(target)) if target.is_dir() else file.name
        data = file.read_bytes()
        for index, line in enumerate(printable_strings(data), 1):
            for kind, shown in scan_line(line):
                findings.append(f"{name} string#{index} {kind} {shown}")
        for needle in forbidden:
            if needle.encode() in data:
                findings.append(f"{name}: contains forbidden string {needle!r}")
    return sorted(set(findings))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--path", type=Path, help="scan the printable strings of a built artifact instead of history")
    parser.add_argument("--forbid", action="append", default=[], metavar="TEXT",
                        help="with --path: also fail when this text appears anywhere in the artifact (repeatable)")
    args = parser.parse_args()
    if args.path:
        secrets, notes = scan_path(args.path, args.forbid), []
        label = f"artifact {args.path}"
    else:
        secrets, notes = scan_history()
        label = "git history (all refs)"
    print(f"Scanned {label}.")
    for item in notes:
        print("note:", item)
    if secrets:
        print(f"FOUND {len(secrets)} credential-like match(es) (values redacted):")
        for item in secrets:
            print(" ", item)
        return 1
    print("No credential-like patterns found (pattern scan only).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
