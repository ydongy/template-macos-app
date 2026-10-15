<div align="center">

# Template

A macOS menu bar utility that shows one list of items with a status each, and keeps itself up to date.

[![License](https://img.shields.io/badge/license-proprietary-lightgrey.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](#requirements)
![Status](https://img.shields.io/badge/status-pre--release-orange)

**English** · [简体中文](README.zh-CN.md)

</div>

Status: pre-release. Template is not available yet; what remains before launch is in [docs/launch.md](docs/launch.md).
The app, the tests and the release scripts exist; the Example screen is a placeholder for the first real screen.

## Features

- **At a glance**: lives in the menu bar; the panel lists the items, each with a status symbol, a detail line and a date.
- **Four states**: loading, loaded, empty and failed, each with a clear message and a way to try again.
- **Always current**: updates arrive inside the app and are installed only after you confirm.
- **Nine languages**: English, Chinese (simplified and traditional), Japanese, Korean, French, German, Spanish and Portuguese (Brazil).
- **Private**: no account, no telemetry; the only network request is the update check.

## Requirements

- macOS 26.0 or later to run.
- To build: Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Quick start

There are no downloads yet. Build and run the app from source as described under [Development](#development);
local builds are unsigned development builds, not releases.

## Development

After changing `project.yml`, run `xcodegen generate` and commit `Template.xcodeproj`; CI fails if it is stale.
The version lives in `Config/Version.xcconfig` only and is changed with `scripts/bump.sh <X.Y.Z>`.

```bash
xcodegen generate

xcodebuild build -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Template.xcodeproj -scheme Template \
  -destination 'platform=macOS' -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO

xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
```

### Documentation

| Document | Contents |
|---|---|
| [docs/spec.md](docs/spec.md) | What to build |
| [docs/design.md](docs/design.md) | Design language |
| [docs/roadmap.md](docs/roadmap.md) | What comes next |
| [docs/launch.md](docs/launch.md) | Launch checklist |
| [docs/legal.md](docs/legal.md) | Legal facts and the code they must match |
| [docs/website.md](docs/website.md) | What the app depends on from the website |
| [docs/releasing.md](docs/releasing.md) | How a release is made |
| [docs/security/](docs/security/README.md) | One security review per version |
| [docs/adr/](docs/adr/README.md) | Decisions |
| [design/README.md](design/README.md) | Design mockups |
| [CHANGELOG.md](CHANGELOG.md) | Changes |
| [THIRD_PARTY.md](THIRD_PARTY.md) | Third-party software |
| [AGENTS.md](AGENTS.md) | Brief for AI collaborators |

## Contributing

Commit scopes, branches, changelog and releasing rules are in [CONTRIBUTING.md](CONTRIBUTING.md). Commit messages
and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/).

## Security

Report vulnerabilities privately as the account's security policy describes (GitHub private vulnerability
reporting); do not open a public issue. Security reviews are kept in [docs/security/](docs/security/README.md).

## Acknowledgements

Built on [Sparkle](https://sparkle-project.org/) and [XcodeGen](https://github.com/yonaskolb/XcodeGen);
see [THIRD_PARTY.md](THIRD_PARTY.md).

## License

Proprietary. All rights reserved. [LICENSE](LICENSE) is the terms of service and the license agreement, to be
published on the product website at launch.
