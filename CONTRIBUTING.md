# Contributing

Thanks for helping. Issues and pull requests may be written in English or Simplified Chinese. Open an issue
before a large change so we can agree on the direction first. Do not report vulnerabilities in public issues; see
the Security section of the [README](README.md#security).

## Development setup

Requirements: macOS 26.0 or later, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
xcodegen generate   # after changing project.yml; commit the regenerated .xcodeproj with it
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh
scripts/test-init.sh    # template only: init.sh on throw-away copies for both licenses
```

## Commits, branches and pull requests

- Commit messages and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat|fix|docs|refactor|perf|test|build|ci|chore|revert(scope)!: subject`.
- Name branches `<type>/<issue>-<slug>`, for example `fix/12-panel-sorting`.
- The maintainer squash-merges, so the pull request title becomes the commit message. No DCO or sign-off is
  required.
- Keep a change focused, add or update tests, and add a line under `## [Unreleased]` in `CHANGELOG.md` when users
  would notice it.
- A UI change starts from the mockup in `design/screens/`; the maintainer confirms the visual direction before UI
  code is written. Screenshots go in the pull request body, not in the repository.
