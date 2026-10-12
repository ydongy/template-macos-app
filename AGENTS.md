<!-- template: AGENTS.md v1 -->
# AGENTS.md

## What it is

ydongy's template repository for macOS menu bar apps (SwiftUI, Swift 6, macOS 26.0+, Sparkle updates,
notarized releases from the product website). It contains a complete, buildable skeleton for a product called
`Template`; `scripts/init.sh <Name> <domain>` turns it into a new product. It is never released itself.

## Sources of truth

Read `handbook/core/` first, then only the guides, stacks and type preset that apply to this project.
Its documented platforms, languages, architecture and distribution remain project decisions.
The handbook link and docs workflow pin one revision; upgrade them together in a migration PR.

- The rules the skeleton implements are the handbook; the skeleton must follow them and never the other way round.
  If they disagree, fix the handbook first or report it.
- The skeleton documents under `docs/` and `design/` are the app documentation set filled with neutral text;
  `.template/README.md` and `.template/AGENTS.md` are the product versions of these two files.
- `Config/release.conf` is the single place for product-specific release values.

How we work: the ydongy handbook (`https://github.com/ydongy/.github/tree/6b48552c969c28a954498123bb502a556f8eed79/handbook`);
rules for AI collaborators: `handbook/core/agents.md`.

## Directory boundaries

```
project.yml, Config/      XcodeGen definition, version, Info.plist keys, release.conf
Template/                 App target: App/ · UI/Example/ · Resources/
TemplateCore/             Local package: Domain/ · Services/ · Design/
TemplateTests/            Swift Testing
docs/, design/            Skeleton documents and mockups (type app after init.sh)
scripts/                  Release tooling and init.sh, test-init.sh (template only)
.template/                Product README.md and AGENTS.md installed by init.sh
```

Layout rules: `handbook/types/app/layout.md`. Views depend only on models, models only on protocols.

## Commands

```bash
xcodegen generate
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild build -project Template.xcodeproj -scheme Template -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh                      # tests of the release script, no credentials needed
python3 scripts/test_website_changelog.py
scripts/test-init.sh                         # init.sh on a throw-away copy: generate, lint, build, test
python3 <dotgithub>/scripts/check-docs.py .        # <dotgithub> = a checkout of ydongy/.github
```

## Project rules

- Only the neutral names appear: product `Template`, modules `Template`, `TemplateCore`, `TemplateTests`, domain
  `example.com`, bundle id `com.example.template`. No real product name or old name in any tracked file.
- Everything `init.sh` must rewrite is spelled exactly as above; when adding a file, run `scripts/test-init.sh`.
- `.repo-type` is `template` here; the skeleton documents are checked as type `app` after `init.sh`.
- Keep the skeleton minimal: one sample screen, no product features.

## Red lines

Credentials never appear in PRs, issues, logs, reports or chat. Signing, release and anything sent to an
external service need the maintainer's confirmation. No blind staging. See `handbook/core/agents.md`.
