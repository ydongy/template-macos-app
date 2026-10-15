# AGENTS.md

## What it is

Template is a macOS menu bar app (SwiftUI, Swift 6, macOS 26.0+) whose panel shows one list of items with a status each, in four states: loading, loaded, empty and failed. Updates use Sparkle 2. The sample screen is called Example; replace its contents and keep the structure.

## Layout

```
project.yml, Config/      XcodeGen definition, version, Info.plist keys, release.conf
Template/                 App target: App/ · UI/Example/ · Resources/
TemplateCore/             Local package: Domain/ · Services/ · Design/
TemplateTests/            Swift Testing
docs/, design/            Design language, ADRs, mockups
scripts/                  Release tooling
```

Views depend only on models, models only on protocols. `Config/release.conf` is the single place for
product-specific release values.

## Commands

```bash
xcodegen generate
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild build -project Template.xcodeproj -scheme Template -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh
```

## Conventions

- User-visible text is an English literal that is also the String Catalog key, with all nine languages in
  `Template/Resources/Localizable.xcstrings`; `LocalizationCatalogTests` and `UserVisibleStringsTests` enforce it.
- Colors, spacing, radii, motion and sizes come from `TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`;
  change that file, `docs/design.md` and `design/tokens.html` together.
- `MockExampleSource` and preview data are DEBUG-only; `FORBID_SYMBOLS` in `Config/release.conf` fails the
  release script if they reach a Release build.
- Keep the lint paths in `.github/workflows/ci.yml` in step with the source directories.
- Commit messages and PR titles use Conventional Commits: `feat|fix|docs|refactor|perf|test|build|ci|chore|revert(scope)!: subject`.
  Branches are `<type>/<issue>-<slug>`; the maintainer squash-merges; no sign-off.
- A UI change starts from the mockup in `design/screens/`; the maintainer confirms the visual direction before UI
  code is written. Screenshots go in the pull request body, never in the repository.

## Issues and pull requests

`gh issue create` and `gh pr create --body` skip the issue forms and the pull request template, so write their
structure yourself. Search open issues first; one issue is one problem.

- Issue title: one short sentence that says the problem or the outcome, in English or Simplified Chinese. No type
  prefix such as `[feat]`; the label carries the type.
- Bug, `--label bug`: `## What happened`, `## What you expected`, `## Steps to reproduce`,
  `## Version and environment`.
- Feature or improvement, `--label enhancement`: `## Problem`, `## Proposed solution`,
  `## Alternatives considered` (when there were any), `## Done when`.
- Documentation, `--label documentation`: `## Where`, `## What is missing, unclear or wrong`, `## Suggested change`.
- Labels: the common set (`bug`, `enhancement`, `documentation`, `question`, `dependencies` and so on), plus any scope
  labels this repository adds; no labels that repeat a commit type or a process state.
- Pull request: the title is the Conventional Commits subject (it becomes the squash commit). The body has
  `## Summary` (what changes and why), `## Related issue` (`Closes #<n>`, or `None.`), `## How tested` (the
  commands run and their results, and what was not run) and `## Checklist`:
  `- [ ] PR title follows Conventional Commits`, `- [ ] Tests pass`,
  `- [ ] Documentation updated where behavior changed`, ticked only when true.

## Red lines

- Credentials never go into pull requests, issues, logs or chat. Never commit a Sparkle private key.
- Releases, signing and anything sent to an external service need the maintainer's confirmation.
- No blind `git add -A` of unknown files; stage the files you checked by name.
