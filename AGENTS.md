# AGENTS.md

## What it is

A GitHub template repository for macOS menu bar apps (SwiftUI, Swift 6, macOS 26.0+, Sparkle updates, notarized
releases). It contains a complete, buildable skeleton for a product called `Template`; `scripts/init.sh` turns it
into a new project. The template itself is MIT licensed and never released.

## Layout

```
project.yml, Config/      XcodeGen definition, version, Info.plist keys, release.conf
Template/                 App target: App/ · UI/Example/ · Resources/
TemplateCore/             Local package: Domain/ · Services/ · Design/
TemplateTests/            Swift Testing
docs/, design/            Design language, ADRs, mockups
scripts/                  Release tooling; init.sh and test-init.sh (template only)
.template/oss/            Files init.sh installs for --license mit
.template/product/        Files init.sh installs for --license proprietary
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
scripts/test-init.sh           # init.sh on throw-away copies for both licenses
```

## Conventions

- Only the neutral names appear: product `Template`, modules `Template`, `TemplateCore`, `TemplateTests`, domain
  `example.com`, bundle id `com.example.template`. No real product name in any tracked file; `init.sh` rewrites
  exactly these spellings. When adding a file, run `scripts/test-init.sh`.
- Keep the skeleton minimal: one sample screen, no product features.
- User-visible text is an English literal that is also the String Catalog key, with all nine languages in
  `Template/Resources/Localizable.xcstrings`; `LocalizationCatalogTests` and `UserVisibleStringsTests` enforce it.
- Colors, spacing, radii, motion and sizes come from `TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`;
  change that file, `docs/design.md` and `design/tokens.html` together.
- `MockExampleSource` and preview data are DEBUG-only; `FORBID_SYMBOLS` in `Config/release.conf` fails the
  release script if they reach a Release build.
- Keep the lint paths in `.github/workflows/ci.yml` in step with the source directories.
- Commit messages and PR titles use Conventional Commits: `feat|fix|docs|refactor|perf|test|build|ci|chore|revert(scope)!: subject`.

## Red lines

Credentials never appear in PRs, issues, logs or chat. Never commit a Sparkle private key. Signing, release and
anything sent to an external service need the maintainer's confirmation. No blind staging.
