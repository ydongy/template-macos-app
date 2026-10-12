# Template

[![CI](https://github.com/ydongy/template/actions/workflows/ci.yml/badge.svg)](https://github.com/ydongy/template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Template is a macOS menu bar utility that shows one list of items with a status each, so that you can see at a glance what is fine and what needs a look, and keeps itself up to date.

## Features

- **At a glance**: lives in the menu bar; the panel lists the items, each with a status symbol, a detail line and a date.
- **Four states**: loading, loaded, empty and failed, each with a clear message and a way to try again.
- **Always current**: updates arrive inside the app (Sparkle) and are installed only after you confirm.
- **Nine languages**: English, Chinese (simplified and traditional), Japanese, Korean, French, German, Spanish and Portuguese (Brazil).
- **Private**: no account, no telemetry; the only network request is the update check.

## Quick start

Requires macOS 26.0 or later. Download the latest `.dmg` from [Releases](https://github.com/ydongy/template/releases),
or from [example.com](https://example.com), drag Template to Applications and open it.

## Development

Requirements: macOS 26.0 or later, Xcode 26.6 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen).
After changing `project.yml`, run `xcodegen generate` and commit `Template.xcodeproj`; CI fails if it is stale.
The version lives in `Config/Version.xcconfig` only and is changed with `scripts/bump.sh <X.Y.Z>`.

```bash
xcodegen generate
xcodebuild build -project Template.xcodeproj -scheme Template CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Template.xcodeproj -scheme Template -destination 'platform=macOS' \
  -testLanguage en -testRegion US CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --strict --recursive Template TemplateCore TemplateTests
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Third-party software is listed in [THIRD_PARTY.md](THIRD_PARTY.md).
