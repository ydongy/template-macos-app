# template-macos-app

[![CI](https://github.com/ydongy/template-macos-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ydongy/template-macos-app/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A GitHub template for macOS menu bar apps: SwiftUI, Swift 6, macOS 26.0+, Sparkle updates, a project that builds,
tests and releases from the first commit. The product is called `Template` here until `scripts/init.sh` gives it
its real name.

## Quick start

1. On GitHub choose **Use this template** and create your repository.
2. Clone it and run `scripts/init.sh <Name> <domain> [--license mit|proprietary] [--owner <github-user>]`, for example:

   ```bash
   scripts/init.sh Acme acme.com                       # open-source project (MIT), the default
   scripts/init.sh Acme acme.com --license proprietary # closed-source product skeleton
   ```

3. Check the result:

   ```bash
   xcodebuild test -project Acme.xcodeproj -scheme Acme -destination 'platform=macOS' \
     -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
   xcrun swift-format lint --strict --recursive Acme AcmeCore AcmeTests
   ```

4. Generate the Sparkle key (`generate_keys --account <name>`), put the public key in `SPARKLE_PUBLIC_KEY` in
   `project.yml`, run `xcodegen generate`, and replace the Example screen with your first real screen.

## init.sh options

| Option | Meaning |
|---|---|
| `<Name>` | Product name in PascalCase; becomes the module, target, scheme and visible name |
| `<domain>` | Product domain, lowercase; the bundle id becomes `com.<domain-reversed>.app`, downloads `https://dl.<domain>` |
| `--license mit` (default) | Open-source project: MIT `LICENSE`, `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, self-contained `ci.yml`, `pr-title.yml`, Dependabot and `CODEOWNERS` |
| `--license proprietary` | Everything `mit` installs (proprietary terms as `LICENSE`, `CONTRIBUTING.md`, `CODEOWNERS`, `pr-title.yml`, Dependabot, `AGENTS.md`, `CLAUDE.md`), plus the closed-source layer: specification, design, legal, website, releasing, roadmap, ADR and security-review documents, `CHANGELOG.zh.md` and the website changelog tool, a self-contained `release.yml`, a `ci.yml` that runs the macOS job only for release candidates, `.claude/` and `.codex/` |
| `--owner <user>` | GitHub user or organisation for `CODEOWNERS` and URLs; inferred from `git remote origin` when omitted, otherwise `CODEOWNERS` gets a `* @<owner>` placeholder to fill in |
| `--repo <name>` | Repository name (default: the lowercase product name) |
| `--no-generate` | Do not run `xcodegen` at the end |

The skeleton files for each option live in `.template/oss/` and `.template/product/`; `init.sh` installs one of
them over the tree and deletes `.template/`, itself and `scripts/test-init.sh`. See [.template/README.md](.template/README.md).

## Project layout

| Path | Purpose |
|---|---|
| `project.yml`, `Config/` | XcodeGen definition, `Version.xcconfig`, Info.plist keys, `release.conf` (every product-specific release value) |
| `Template/` | App target: `App/` (entry point, language, links, updater), `UI/Example/` (the sample screen), `Resources/` |
| `TemplateCore/` | Local Swift package: `Domain/`, `Services/`, `Design/` (`DesignTokens`) |
| `TemplateTests/` | Swift Testing: model, links, language, bundle and localization tests |
| `docs/`, `design/` | Design language, architecture decision records, token page and Example screen mockup |
| `scripts/` | `release.sh`, `release-credentials.sh`, `bump.sh`, `scan_secrets.py`, `init.sh` and their tests |
| `.template/` | Optional skeletons that `init.sh` installs |

## Development

Requirements: macOS 26.0 or later, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
scripts/test-release.sh
scripts/test-init.sh    # runs init.sh on throw-away copies for both licenses
```

`Template` and `example.com` are the placeholders `init.sh` replaces; do not write a real product name anywhere.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Third-party software is listed in [THIRD_PARTY.md](THIRD_PARTY.md).
