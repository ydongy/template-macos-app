<div align="center">

# Template

A macOS menu bar utility that shows one list of items with a status each, and keeps itself up to date.

[![CI](https://github.com/ydongy/template/actions/workflows/ci.yml/badge.svg)](https://github.com/ydongy/template/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](#requirements)
[![Website](https://img.shields.io/badge/website-example.com-informational.svg)](https://example.com)

**English** · [简体中文](README.zh-CN.md)

</div>

Template shows what is fine and what needs a look at a glance. The baseline is a sample list; replace it with your app.

## Features

- **At a glance**: lives in the menu bar; the panel lists the items, each with a status symbol, a detail line and a date.
- **Four states**: loading, loaded, empty and failed, each with a clear message and a way to try again.
- **Always current**: updates arrive inside the app (Sparkle) and are installed only after you confirm.
- **Nine languages**: English, Chinese (simplified and traditional), Japanese, Korean, French, German, Spanish and Portuguese (Brazil).
- **Private**: no account, no telemetry; the only network request is the update check.

## Requirements

- macOS 26.0 or later to run.
- To build: Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Quick start

Download the latest `.dmg` from [Releases](https://github.com/ydongy/template/releases) or from
[example.com](https://example.com), drag Template to Applications and open it. Updates are installed inside the
app after you confirm them.

## Development

After changing `project.yml`, run `xcodegen generate` and commit `Template.xcodeproj`; CI fails if it is stale.
The version lives in `Config/Version.xcconfig` only and is changed with `scripts/bump.sh <X.Y.Z>`.

```bash
xcodegen generate
xcodebuild build -project Template.xcodeproj -scheme Template CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
scripts/test-release.sh
```

| Path | Purpose |
|---|---|
| `Template/` | App target: entry point, updater, the Example screen, resources |
| `TemplateCore/` | Local Swift package: domain, services, design tokens |
| `TemplateTests/` | Swift Testing tests |
| `docs/`, `design/` | Design language, architecture decision records, mockups |
| `scripts/` | Release, version bump and secret scan scripts |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commit messages and pull request titles follow
[Conventional Commits](https://www.conventionalcommits.org/).

## Security

Report vulnerabilities privately through GitHub: **Security → Report a vulnerability**, or
<https://github.com/ydongy/template/security/advisories/new>.

## Acknowledgements

Built on [Sparkle](https://sparkle-project.org/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen);
see [THIRD_PARTY.md](THIRD_PARTY.md).

## License

[MIT](LICENSE).
