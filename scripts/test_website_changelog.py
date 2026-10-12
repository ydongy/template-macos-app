#!/usr/bin/env python3
"""Tests for scripts/website-changelog.py. Run: python3 scripts/test_website_changelog.py"""
import importlib.util
import json
import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("wc", HERE / "website-changelog.py")
wc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wc)

EN = """# Changelog

## [Unreleased]

### Added
- Not published yet

## [2.0.0] - 2026-10-03

Intro paragraph.

### Added
- Faster startup
- A new menu bar icon, with a long description that
  wraps onto a second line

### Fixed
- A crash at launch

## [1.0.0] - 2026-09-01

### Added
- Old thing

[Unreleased]: https://example.invalid/compare/v2.0.0...HEAD
[2.0.0]: https://example.invalid/compare/v1.0.0...v2.0.0
"""
ZH = """# 更新记录

## [Unreleased]

### 新增
- 尚未发布

## [2.0.0] - 2026-10-03

介绍段落。

### 新增
- 启动更快
- 新的菜单栏图标，描述很长，
  所以换了一行

### 修复
- 修复了启动时的崩溃

## [1.0.0] - 2026-09-01

### 新增
- 旧的东西

[Unreleased]: https://example.invalid/compare/v2.0.0...HEAD
[2.0.0]: https://example.invalid/compare/v1.0.0...v2.0.0
"""


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, check=True, text=True, capture_output=True).stdout.strip()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "CHANGELOG.md").write_text(EN)
        (self.root / "CHANGELOG.zh.md").write_text(ZH)
        self.old_root = wc.ROOT
        wc.ROOT = self.root

    def tearDown(self):
        wc.ROOT = self.old_root
        self.tmp.cleanup()

    def set_text(self, en=None, zh=None):
        if en is not None:
            (self.root / "CHANGELOG.md").write_text(en)
        if zh is not None:
            (self.root / "CHANGELOG.zh.md").write_text(zh)


class Lint(Base):
    def errors(self, bullet_en, bullet_zh="一个改动"):
        self.set_text(
            en=EN.replace("- Faster startup", f"- {bullet_en}"),
            zh=ZH.replace("- 启动更快", f"- {bullet_zh}"))
        return wc.build_entry("2.0.0", "2026-10-03")[1]

    def test_clean_text_passes(self):
        self.assertEqual(wc.build_entry("2.0.0", "2026-10-03")[1], [])

    def test_public_safety(self):
        for bad in [
            "Fixes #123", "Reverts a1b2c3d4e5", "See ydongy/example for details", "Stored in /Users/me/x",
            "Contact me@example.com", "Visit https://example.org/page", "Key abcdefghijklmnopqrstuvwxyz0123456789",
            "Written with Claude", "TODO: polish", "Fixes a vulnerability", "x" * 230,
        ]:
            with self.subTest(bad=bad):
                self.assertTrue(self.errors(bad), bad)

    def test_chinese_text_is_checked_too(self):
        self.assertTrue(self.errors("Fine", "修复了一个漏洞"))
        self.assertTrue(self.errors("Fine", "详见 #45"))

    def test_product_domains_are_allowed(self):
        self.assertEqual(self.errors(f"Details on https://{wc.DOMAIN}/faq"), [])

    def test_languages_must_match(self):
        self.set_text(zh=ZH.replace("- 修复了启动时的崩溃\n", ""))
        self.assertTrue(any("keep them in step" in e for e in wc.build_entry("2.0.0", "2026-10-03")[1]))

    def test_missing_section(self):
        with self.assertRaises(SystemExit):
            wc.build_entry("9.9.9", "2026-10-03")

    def test_dates_must_agree_and_default_to_the_heading(self):
        self.assertEqual(wc.build_entry("2.0.0")[0]["date"], "2026-10-03")
        self.set_text(zh=ZH.replace("## [2.0.0] - 2026-10-03", "## [2.0.0] - 2026-10-04"))
        self.assertTrue(any("different dates" in e for e in wc.build_entry("2.0.0")[1]))


class Insert(Base):
    def test_new_version_goes_first_same_is_noop_different_is_refused(self):
        entry, _ = wc.build_entry("2.0.0", "2026-10-03")
        old = [{"version": "1.0.0", "date": "2026-10-01", "title": {"en": "First", "zh": "首个版本"},
                "items": {"en": ["Old thing"], "zh": ["旧的东西"]}}]
        new, changed = wc.insert(old, entry)
        self.assertTrue(changed)
        self.assertEqual([r["version"] for r in new], ["2.0.0", "1.0.0"])
        again, changed = wc.insert(new, dict(entry, date="2030-01-01"))
        self.assertFalse(changed)
        with self.assertRaises(SystemExit):
            wc.insert(new, dict(entry, items={"en": ["Other"], "zh": ["别的"]}))

    def test_entry_shape_matches_the_website(self):
        entry, _ = wc.build_entry("2.0.0", "2026-10-03")
        self.assertEqual(entry["title"], {"en": "", "zh": ""})
        self.assertEqual(entry["summary"], {"en": "Intro paragraph.", "zh": "介绍段落。"})
        self.assertEqual(entry["items"]["en"], [
            "Faster startup", "A new menu bar icon, with a long description that wraps onto a second line",
            "A crash at launch"])


class RealFiles(unittest.TestCase):
    def test_repository_changelogs_are_publishable_and_in_step(self):
        text = (HERE.parent / "CHANGELOG.md").read_text(encoding="utf-8")
        labels = ["Unreleased"] + re.findall(r"^## \[(\d+\.\d+\.\d+)\]", text, re.M)
        for label in labels:
            with self.subTest(section=label):
                self.assertEqual(wc.build_entry(label, "2026-10-02")[1], [])


class OpenPullRequest(Base):
    """Runs the --open-pr path against a local bare 'origin' and a stub gh."""

    def test_branch_commit_push_and_pr_never_touch_main(self):
        origin = self.root / "origin.git"
        site = self.root / "site"
        git(self.root, "init", "--bare", "-b", "main", str(origin))
        git(self.root, "clone", str(origin), str(site))
        git(site, "config", "user.email", "t@example.com")
        git(site, "config", "user.name", "t")
        (site / "scripts").mkdir()
        (site / "scripts" / "build.py").write_text("open('built.txt', 'w').write('regenerated')\n")
        (site / "changelog.json").write_text("[]\n")
        git(site, "add", "-A")
        git(site, "commit", "-m", "init")
        git(site, "push", "-u", "origin", "HEAD:main")
        git(site, "fetch", "origin")
        stub = self.root / "bin"
        stub.mkdir()
        gh = stub / "gh"
        gh.write_text('#!/bin/bash\necho "$@" > "$GH_LOG"\necho https://example.invalid/pull/1\n')
        gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
        env = dict(os.environ, PATH=f"{stub}:{os.environ['PATH']}", GH_LOG=str(self.root / "gh.log"))
        old_env = os.environ.copy()
        os.environ.update(env)
        try:
            # The helper config in the script is for GitHub; with a local remote it is not used.
            code = wc.main(["--version", "2.0.0", "--date", "2026-10-03", "--website-dir", str(site), "--open-pr"])
        finally:
            os.environ.clear()
            os.environ.update(old_env)
        self.assertEqual(code, 0)
        self.assertEqual(git(site, "branch", "--show-current"), "changelog-2.0.0")
        self.assertEqual(git(origin, "rev-parse", "--verify", "changelog-2.0.0")[:1] != "", True)
        self.assertEqual(git(origin, "log", "main", "--format=%s"), "init")  # main untouched
        self.assertEqual(json.loads((site / "changelog.json").read_text())[0]["version"], "2.0.0")
        self.assertEqual((site / "built.txt").read_text(), "regenerated")
        self.assertIn("pr create", (self.root / "gh.log").read_text())

    def test_dry_run_writes_nothing(self):
        site = self.root / "site"
        site.mkdir()
        (site / "changelog.json").write_text("[]\n")
        wc.main(["--version", "2.0.0", "--website-dir", str(site)])
        self.assertEqual((site / "changelog.json").read_text(), "[]\n")

    def test_lint_failure_stops_before_anything_is_touched(self):
        self.set_text(en=EN.replace("Faster startup", "Fixes #9"))
        site = self.root / "site"
        site.mkdir()
        (site / "changelog.json").write_text("[]\n")
        self.assertEqual(wc.main(["--version", "2.0.0", "--website-dir", str(site), "--open-pr"]), 1)
        self.assertEqual((site / "changelog.json").read_text(), "[]\n")


if __name__ == "__main__":
    unittest.main(verbosity=1)
