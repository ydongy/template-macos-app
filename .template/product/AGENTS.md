<!-- template: AGENTS.md v1 -->
# AGENTS.md

## What it is

Template is a macOS menu bar app (SwiftUI, Swift 6, macOS 26.0+) whose panel shows one list of items with a status each, in four states: loading, loaded, empty and failed. It is closed source, notarized and downloaded from `https://example.com`; updates use Sparkle 2. The sample screen is called Example; a product replaces its contents and keeps the structure.

## Sources of truth

Read `handbook/core/` first, then only the guides, stacks and type preset that apply to this project.
Its documented platforms, languages, architecture and distribution remain project decisions.
The handbook link and docs workflow pin one revision; upgrade them together in a migration PR.

- What to build: `docs/spec.md` (stable headings; link `docs/spec.md#updates`, never a section number). How it looks and moves: `docs/design.md` and `design/README.md`. Why it is built this way: `docs/adr/README.md`. Legal facts and the code that must match them: `docs/legal.md`. What the app needs from the website: `docs/website.md`. The 1.0 baseline: `docs/milestones/v1.0.md`. This repository's differences from the handbook: `docs/process.md`.
- Docs win over code. If they disagree, fix the docs first, then the code, and say so in the PR.

How we work: the ydongy handbook (`https://github.com/ydongy/.github/tree/f61354c75725bf3688632a9d3040e5664046f81a/handbook`);
rules for AI collaborators: `handbook/core/agents.md`.

## Directory boundaries

```
project.yml              XcodeGen definition of Template.xcodeproj (both committed)
Config/                  Version.xcconfig (edit only via scripts/bump.sh), Template-Info.plist (Sparkle keys),
                         release.conf (product values for the release scripts)
Template/                App target
  App/                   @main, menu bar scene, updater, language, website links
  UI/Example/            The sample screen: view, model, row, preview data (DEBUG)
  Resources/             Localizable.xcstrings, ThirdPartyLicenses/
TemplateCore/            Local SwiftPM package, no third-party dependency (docs/adr/0001-templatecore-package-with-mainactor-default-isolation.md)
  Sources/TemplateCore/  Domain/ (nonisolated values) · Services/ (protocols, Live, DEBUG mock, UICopy) · Design/ (DesignTokens)
TemplateTests/           Unit tests (Swift Testing), @testable import of both modules
design/                  Mockups: screens/example.html, tokens.html
docs/                    spec · design · roadmap · legal · website · process · adr/ · milestones/
scripts/                 bump.sh · release.sh · release-credentials.sh · test-release.sh · scan_secrets.py ·
                         website-changelog.py · test_website_changelog.py · ax-audit.swift
```

- Views depend only on models, models only on protocols; `ExampleSource` has a Live and a Mock implementation. Core never references the app target.
- After changing `project.yml`, run `xcodegen generate` and commit the regenerated project. Layout rules: `handbook/types/app/layout.md`.

## Commands

```bash
xcodegen generate                       # after changing project.yml; commit Template.xcodeproj with it

# What CI runs (the shared workflow also builds Release)
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO

python3 <dotgithub>/scripts/check-docs.py .   # <dotgithub> = a checkout of ydongy/.github
python3 scripts/scan_secrets.py         # credential scan of the git history (--path <app> for a build)
swift scripts/ax-audit.swift            # accessibility audit of the running app
scripts/bump.sh <X.Y.Z>                 # the only way to change the version
scripts/release.sh --check              # release dry run; scripts/test-release.sh tests the script
python3 scripts/test_website_changelog.py
```

## Project rules

- No UI code before the screen is signed off in `design/screens/` (`handbook/playbooks/add-feature.md`). A new screen is `design/screens/<screen>.html` and `Template/UI/<Screen>/` with the same name.
- User-visible text is an English literal that is also the String Catalog key (`String.loc("…")`, `Text("…")`) with all nine languages in `Template/Resources/Localizable.xcstrings`; text that is not UI copy is `Text(verbatim:)`. `LocalizationCatalogTests` and `UserVisibleStringsTests` enforce this (`handbook/guides/localization.md`).
- Colors, spacing, radii, motion and sizes come from `TemplateCore/Sources/TemplateCore/Design/DesignTokens.swift`; change that file, `docs/design.md` and `design/tokens.html` together.
- TemplateCore has package-wide MainActor default isolation; domain value types are `nonisolated`. A MainActor-isolated protocol cannot be implemented by an actor, so test doubles are `final class` and private to their test file.
- `MockExampleSource` and preview data are DEBUG-only; `FORBID_SYMBOLS` in `Config/release.conf` makes the release script fail if they reach a Release build. A new Mock or Preview type is added to that list.
- Every interactive element has an `accessibilityIdentifier` named `<screen>.<element>` (`example.refresh`, `menubar.quit`) and a label; decorative elements use `accessibilityHidden(true)`.
- The updater is off while `SPARKLE_PUBLIC_KEY` in `project.yml` is empty. Never commit a private key.
- Keep `lint-paths` in `.github/workflows/ci.yml` and the source roots of `UserVisibleStringsTests` in step with the directories.
- Never force-unwrap user input; throw typed errors; error messages are localizable and say what happened and what to do.

## Red lines

Credentials never appear in PRs, issues, logs, reports or chat. Signing, release and anything sent to an
external service need the maintainer's confirmation. No blind staging. See `handbook/core/agents.md`.

- Never modify the user's dotfiles or global Git configuration.
- Changes involving credentials, the Keychain, networking or code signing need a security walkthrough recorded in the PR.
- Never tell the maintainer the project is "secure" or "risk-free" without a complete scan or walkthrough.
