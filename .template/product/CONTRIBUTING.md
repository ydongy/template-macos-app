# Contributing

Template is closed source; this guide is for the maintainer, collaborators and any future contributor. Issues and
pull requests may be written in English or Simplified Chinese. Open an issue before a large change so the
direction is agreed first.

## Development setup

Requirements: macOS 26.0 or later, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
xcodegen generate   # after changing project.yml; commit the regenerated .xcodeproj with it
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh
python3 scripts/test_website_changelog.py
python3 scripts/scan_secrets.py
```

## Commits, branches and pull requests

- Commit messages and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat|fix|docs|refactor|perf|test|build|ci|chore|revert(scope)!: subject`. The scope is optional; pick one of
  the table below. `pr-title.yml` checks the title.
- Name branches `<type>/<issue>-<slug>`, for example `fix/12-panel-sorting`.
- The maintainer squash-merges, so the pull request title becomes the commit message. No DCO or sign-off is
  required.
- A UI change starts from the mockup in `design/screens/`; the maintainer confirms the visual direction before UI
  code is written. Screenshots of the running app are not tracked: capture them into `design/screenshots/` (ignored)
  and show light and dark in the pull request description.
- Keep a change focused and add or update tests.

| Scope | For |
|---|---|
| `app` | `Template/App`: entry point, menu bar scene, updater, language, links |
| `core` | `TemplateCore`: domain, services, design tokens |
| `ui` | `Template/UI`: screens, models, rows |
| `design` | `design/` mockups and `docs/design.md` |
| `docs` | everything else in `docs/`, README, AGENTS |
| `release` | `scripts/release.sh`, `Config/release.conf`, changelog tooling, `release.yml` |
| `build` | `project.yml`, the generated project, signing settings |
| `ci` | `.github/workflows` |
| `deps` | dependency bumps |

## CI

`.github/workflows/ci.yml` is one self-contained workflow with two kinds of job, because hosted macOS minutes cost
more in a private repository. A Linux job runs on every pull request and push to `main`: shell and Python syntax,
the changelog tooling tests and the secret scan of the history. The macOS job (project up to date, format check,
release script tests, Release build, unit tests) runs only on a manual run (Actions, CI, Run workflow) and for a
pull request that changes `Config/Version.xcconfig`; run the Xcode commands above locally before asking for review.

## Changelog

`CHANGELOG.md` (English) and `CHANGELOG.zh.md` (Chinese) carry the same bullets under `## [Unreleased]`. Write what
a user would notice, with no issue or PR numbers, hashes or tooling words. The Chinese file feeds the changelog
page of the product website (`scripts/website-changelog.py`), which is why it stays.

## Releasing

A release is a merged version bump: `scripts/bump.sh <X.Y.Z>` edits `Config/Version.xcconfig` and turns
`[Unreleased]` into the new version in both changelogs, and merging that pull request to `main` publishes the
release. Steps, secrets and recovery are in [docs/releasing.md](docs/releasing.md). Each version also gets a
security review in `docs/security/`.
